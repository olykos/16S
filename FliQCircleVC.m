//
//  FliQCircleVC.m
//  FliQApp
//
//  Created by C74 on 08/04/15.
//  Copyright (c) 2015 c107. All rights reserved.
//

/*
 This class is the core of the application. All important events are handled in this class.
 If you modify this class make sure it won't affect any other events or operations.
 */

#import "FliQCircleVC.h"
#import "JDDroppableView.h"
#import "FliQVC.h"
#import <objc/runtime.h>
#import "ContactVC.h"
#import "Reachability.h"
#import "UserValues.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "IncomingFliQVC.h"


const NSInteger numberOfContactBubbles = 15; // Increase this count to decrease space between two information circles on the outside of the red circle
BOOL readyForSegue = NO;

#define NOTIFY_MTU      20

@interface FliQCircleVC ()<JDDroppableViewDelegate, CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>
{
    AppDelegate *appDelegate;
    CGPoint initialCenterPointOfRedCircle;
    ContactVC *contactVC;
    NSInteger NumberOfBubblesInRedCircle;
    NSInteger TotalNumberOfBubbles;
    int radius;
    UIPanGestureRecognizer *panGestureOnRedCircle;
    int RadiusForOuterCircle;
    int RadiusForInnerCircle;
}

//------------------------------ CoreBluetooth properties ----------------------------------------

@property (strong) dispatch_queue_t bluetoothQueue;

//Central
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableSet *discoveredPeripherals;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;

@property (strong, nonatomic) NSString *receivedString;
@property (strong, nonatomic) NSMutableData *receivedFliqData;

@property (strong, nonatomic) NSDictionary *fliqDict;

//Peripheral
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *fliqCharacteristic;

@property (strong, nonatomic) NSMutableData *fliqDataToSend;
@property (nonatomic, readwrite) NSInteger fliqDataIndex;



@end

@implementation FliQCircleVC

@synthesize buttonsInOuterView, buttonsInRedCircle, valuesAddedByUser, userPersonalDetail;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    appDelegate = AppContext;
    
    NumberOfBubblesInRedCircle = 13;
    TotalNumberOfBubbles = 5; //Total information circle textField Except FliQID
    
    //    buttonsInRedCircle = [[NSMutableDictionary alloc] init];
    //    buttonsInOuterView = [[NSMutableDictionary alloc] init];
    //    valuesAddedByUser = [[NSMutableDictionary alloc] init];
    
    buttonsInRedCircle = [[NSMutableDictionary alloc] init];
    buttonsInOuterView = [[NSMutableDictionary alloc] init];
    
    contactVC = [[ContactVC alloc] init];
    
    panGestureOnRedCircle = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(redCircleMoved:)];
    panGestureOnRedCircle.delegate = self;
    panGestureOnRedCircle.cancelsTouchesInView = NO;

    if (![DefaultsValues getCustomObjFromUserDefaults_ForKey:UserPersonalDetails]
        || [[DefaultsValues getCustomObjFromUserDefaults_ForKey:UserPersonalDetails] valueForKey:FQ_USER_CONTACT_DICT ]== nil) {
        [self ShowAlertDialogue:APP_NAME withMessage:PROFILE_INFO_ALERT isOkButton:YES isCancelButton:NO];
    }
    
    
    self.bluetoothQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    //allocate a peripheral manager - does not begin advertising, but is needed in case advertise button is pressed
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.bluetoothQueue];
    
}

#pragma mark - View cycle

-(void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:YES];
    
    radius = RadiusForOuterCircle;
    
    NSLog(@"%@", [DefaultsValues getCustomObjFromUserDefaults_ForKey:UserPersonalDetails]);
//    NSLog(@"%@",[DefaultsValues getCustomObjFromUserDefaults_ForKey:UserContactDetails]  );
    
    //    NSLog(@"%@", [appDelegate getCustomObjFromUserDefaults_ForKey:UserPersonalDetails]);
    //    NSLog(@"%@",[appDelegate getCustomObjFromUserDefaults_ForKey:UserContactDetails]  );
    
    userPersonalDetail = [[NSMutableDictionary alloc] init];
    
    self.view.frame = CGRectMake(0, 0, self.view.superview.frame.size.width, self.view.superview.frame.size.height);
    
    
    // you can increse size of red circle from storyboard but make sure it is in horizontally center of screen and leave space from buttom to display informaion circle below red circle else take care of here.
    
    [self.scrollRedCircle addGestureRecognizer:panGestureOnRedCircle];
    
    self.scrollRedCircle.backgroundColor = DARK_RED_COLOR;
    
    id nextResponder = [self.view.superview.superview.superview nextResponder];
    
    if ([nextResponder  isKindOfClass:[FliQVC class]]){
        self.scrollRedCircle.frame = CGRectMake(((self.view.frame.size.width / 2) - (self.scrollRedCircle.frame.size.width/2)), 2, self.scrollRedCircle.frame.size.width, self.scrollRedCircle.frame.size.width);
    }
    else if ([nextResponder isKindOfClass:[ContactVC class]]){
        self.scrollRedCircle.frame = CGRectMake(((self.view.frame.size.width / 2) - (self.scrollRedCircle.frame.size.width/2)), self.view.superview.frame.size.height/2 - 60, self.scrollRedCircle.frame.size.width, self.scrollRedCircle.frame.size.width);
    }
    
    self.scrollRedCircle.layer.cornerRadius = self.scrollRedCircle.frame.size.width / 2;
    self.scrollRedCircle.layer.masksToBounds = NO;
    self.scrollRedCircle.userInteractionEnabled = YES;
    
    RadiusForOuterCircle = self.scrollRedCircle.frame.size.width/2 + 19;
    RadiusForInnerCircle = self.scrollRedCircle.frame.size.width/2 - 20;
    
    //This variable is taken To set original postition after drag up red circle.
    initialCenterPointOfRedCircle = self.scrollRedCircle.center;
    
    self.scrollSmallCircles.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.scrollSmallCircles.backgroundColor = WHITE_COLOR;
    self.scrollSmallCircles.userInteractionEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"clearRedCircle"
                                                  object:nil];
    //Initialize observer to call method to initialize micro phone for voice input.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearDataFromRedcircle)
                                                 name:@"clearRedCircle"
                                               object:nil];
    [self getDataFromUserDefaults];
    
}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:YES];
    
    //    [DefaultsValues setCustomObjToUserDefaults:buttonsInOuterView ForKey:ButtonNOTAddedInRedCircle];
    //    [DefaultsValues setCustomObjToUserDefaults:buttonsInRedCircle ForKey:ButtonAddedInRedCircle];
}

-( void)clearDataFromRedcircle{
    
    buttonsInRedCircle = [[NSMutableDictionary alloc] init]; //ORESTIS: - double check the memory usage of this approach instead of clearing the dictionary.
    buttonsInOuterView = [[NSMutableDictionary alloc] init];
    
    [self getDataFromUserDefaults];
    
}

#pragma mark - Fetch all data from userDefaults

/*
 This method is called when thid view appeare on screen.
 
 Output: This method collect all the information from the AppDelegate userdefaults like contact information added in red circle, not added and information added by user in profile screen.
 */
-(void) getDataFromUserDefaults{
    
    NSMutableDictionary * tempDic = [[DefaultsValues getCustomObjFromUserDefaults_ForKey:UserPersonalDetails] mutableCopy]  ;
    NSArray *keys = [[tempDic allKeys] copy];
    
    for (int i = 0; i < [keys count]; i++) {
        if ([tempDic valueForKey:keys[i]]) {
            [userPersonalDetail setObject:[tempDic valueForKey:keys[i]] forKey: keys[i]];
        }
    }
    
    valuesAddedByUser = [[NSMutableDictionary alloc] init];
    tempDic = [[userPersonalDetail objectForKey:FQ_USER_CONTACT_DICT] mutableCopy];
    keys = [[tempDic allKeys] copy];
    
    for (int i = 0; i < [keys count]; i++) {
        if ([[tempDic valueForKey:keys[i]] length] > 0) {
            [valuesAddedByUser setObject:[tempDic valueForKey:keys[i]] forKey: keys[i]];
        }
    }
    
    TotalNumberOfBubbles = [valuesAddedByUser count];
    
    
    
    tempDic = [[DefaultsValues getCustomObjFromUserDefaults_ForKey:ButtonNOTAddedInRedCircle] mutableCopy] ;
    keys = [[tempDic allKeys] copy];
    
    for (int i = 0; i < [keys count]; i++) {
        if ([[tempDic valueForKey:keys[i]] length] > 0) {
            [buttonsInOuterView setObject:[tempDic valueForKey:keys[i]] forKey: keys[i]];
        }
    }
    
    tempDic = [[DefaultsValues getCustomObjFromUserDefaults_ForKey:ButtonAddedInRedCircle] mutableCopy]  ;
    keys = [[tempDic allKeys] copy];
    
    for (int i = 0; i < [keys count]; i++) {
        if ([[tempDic valueForKey:keys[i]] length] > 0) {
            [buttonsInRedCircle setObject:[tempDic valueForKey:keys[i]] forKey: keys[i]];
        }
    }
    
    if (buttonsInOuterView == nil || ([buttonsInOuterView count] == 0 && [buttonsInRedCircle count] == 0)) {
        buttonsInOuterView = [valuesAddedByUser mutableCopy];
        [DefaultsValues setCustomObjToUserDefaults:buttonsInOuterView ForKey:ButtonNOTAddedInRedCircle];
    }
    
    NSMutableDictionary *mergedDictionary = [buttonsInOuterView mutableCopy ];
    
    [mergedDictionary addEntriesFromDictionary:buttonsInRedCircle];
    
    if (![mergedDictionary isEqualToDictionary:valuesAddedByUser] )
    {
        for (int i = 0; i < [[mergedDictionary allKeys] count]; i++) {
            if (![valuesAddedByUser objectForKey:[mergedDictionary allKeys][i]]) {
                [buttonsInOuterView setValue:nil forKey:[mergedDictionary allKeys][i]];
                [buttonsInRedCircle setValue:nil forKey:[mergedDictionary allKeys][i]];
            }
        }
    }
    
    if ([valuesAddedByUser count] > ([buttonsInOuterView count] + [buttonsInRedCircle count])) {
        keys = [[valuesAddedByUser allKeys] copy];
        
        for (int i = 0; i < [keys count]; i++) {
            if (![buttonsInOuterView objectForKey:[valuesAddedByUser allKeys][i]]) {
                if (![buttonsInRedCircle objectForKey:[valuesAddedByUser allKeys][i]]) {
                    [buttonsInOuterView setObject:[valuesAddedByUser allKeys][i] forKey:[valuesAddedByUser allKeys][i]];
                }
            }
        }
    }
    else if ([valuesAddedByUser count] < ([buttonsInOuterView count] + [buttonsInRedCircle count]))
    {
        for (int i = 0; i < [[mergedDictionary allKeys] count]; i++) {
            if (![valuesAddedByUser objectForKey:[mergedDictionary allKeys][i]]) {
                [buttonsInRedCircle setValue:nil forKey:[mergedDictionary allKeys][i]];
                [buttonsInOuterView setValue:nil forKey:[mergedDictionary allKeys][i]];
            }
        }
    }
    
    [self addAllSmallCircleToRespectiveView];
}

#pragma mark - create message to share

/*
 This method called when user swipe big red circle on screen.
 
 This method generate message based on information added in red circle.
 */
-(void) createMessageToShare{
    //    "Hey, its John, my phone number is ______, my facebook is: link, and my e-mail is "_____."
    NSString *message = [[NSString alloc] init];
    
    if ([userPersonalDetail valueForKey:FQ_USER_FullName]) {
        message = [NSString stringWithFormat:@"Hi, this is %@,",[userPersonalDetail valueForKey:FQ_USER_FullName]];
    }else {
        
        [self ShowAlertDialogue:APP_NAME withMessage:FULL_NAME_WARNING isOkButton:YES isCancelButton:NO];
        return;
    }
    
    //    if ([userPersonalDetail valueForKey:FliQIDofUser] && [message length] > 0) {
    //        message = [NSString stringWithFormat:@"%@ my FliQID is %@,", message, [userPersonalDetail valueForKey:FliQIDofUser]];
    //    }
    
    if ([buttonsInRedCircle count] > 0) {
        if ([buttonsInRedCircle valueForKey:FQ_USER_PrimaryContactOfUser]) {
            message = [NSString stringWithFormat:@"%@ my phone number is %@,", message, [valuesAddedByUser valueForKey:FQ_USER_PrimaryContactOfUser]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_WorkContactOfUser]) {
            message = [NSString stringWithFormat:@"%@ my work number is %@,", message, [valuesAddedByUser valueForKey:FQ_USER_WorkContactOfUser]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_EmailID]) {
            message = [NSString stringWithFormat:@"%@ my e-mail is %@,", message, [valuesAddedByUser valueForKey:FQ_USER_EmailID]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_EmailID_Secondary]) {
            message = [NSString stringWithFormat:@"%@ my second e-mail is %@,", message, [valuesAddedByUser valueForKey:FQ_USER_EmailID_Secondary]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_FacebookID]) {
            message = [NSString stringWithFormat:@"%@ my Facebook is: %@,", message, [valuesAddedByUser valueForKey:FQ_USER_FacebookID]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_TwitterID]) {
            message = [NSString stringWithFormat:@"%@ my Twitter is: https://mobile.twitter.com/%@,", message, [valuesAddedByUser valueForKey:FQ_USER_TwitterID]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_LinkedInID]) {
            message = [NSString stringWithFormat:@"%@ my LinkedIn is: https://www.linkedin.com/in/%@,", message, [valuesAddedByUser valueForKey:FQ_USER_LinkedInID]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_GooglePlusID]) {
            message = [NSString stringWithFormat:@"%@ my Google+ is: https://www.plus.google.com/%@,", message, [valuesAddedByUser valueForKey:FQ_USER_GooglePlusID]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_SnapChatID]) {
            message = [NSString stringWithFormat:@"%@ my Snapchat is: https://www.snapchat.com/add/%@,", message, [valuesAddedByUser valueForKey:FQ_USER_SnapChatID]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_PrimaryWebsiteOfUser]) {
            message = [NSString stringWithFormat:@"%@ my website is: %@,", message, [valuesAddedByUser valueForKey:FQ_USER_PrimaryWebsiteOfUser]];
        }
        
        if ([buttonsInRedCircle valueForKey:FQ_USER_AnotherWebsiteOfUser]) {
            message = [NSString stringWithFormat:@"%@ my other website is: %@,", message, [valuesAddedByUser valueForKey:FQ_USER_AnotherWebsiteOfUser]];
        }
        
        NSMutableArray *allSeparatorStrings = [[NSArray arrayWithArray:[message componentsSeparatedByString:@","]]mutableCopy];
        
        [allSeparatorStrings removeLastObject];
        
        message = @"";
        
        for (int i = 0 ; i < ([allSeparatorStrings count] - 1) ; i++) {
            message = [NSString stringWithFormat:@"%@%@,",message, [allSeparatorStrings objectAtIndex:i]];
        }
        
        if ([allSeparatorStrings count] > 3) {
            message = [NSString stringWithFormat:@"%@ and %@.", message,[allSeparatorStrings lastObject]];
        }else
        {
            message = [NSString stringWithFormat:@"%@ %@.", message,[allSeparatorStrings lastObject]];
        }
        
        appDelegate.messageToSendInformation = message;
        
        NSLog(@"Final message to share = %@", appDelegate.messageToSendInformation);
        
        id nextResponder = [self.view.superview.superview.superview nextResponder];
        
//        if ([nextResponder  isKindOfClass:[FliQVC class]]){
//            
//            [self ShowAlertDialogue:APP_NAME withMessage:appDelegate.messageToSendInformation isOkButton:YES isCancelButton:NO];
//            //            UIAlertView *alertMessage = [[UIAlertView alloc] initWithTitle:@"Message"
//            //                                            message:appDelegate.messageToSendInformation
//            //                                            delegate:self
//            //                                            cancelButtonTitle:@"OK"
//            //                                            otherButtonTitles:nil, nil];
//            //            [alertMessage show];
//        }
        //else
            if ([nextResponder isKindOfClass:[ContactVC class]]){
        
            UIAlertView *alertMessage = [[UIAlertView alloc] initWithTitle:@"FliQ to Phone!"
                                                                   message:appDelegate.messageToSendInformation
                                                                  delegate:self
                                                         cancelButtonTitle:@"Cancel"
                                                         otherButtonTitles:@"Send", nil];
            alertMessage.tag = 101;
            [alertMessage show];
        }
        else{
            NSLog(@"Else condition......If any other parent contains this class than can write code for it here....");
            NSLog(@"fliq recipient: %@", self.fliqRecipientUUID);
        }
    }
    else{
        
        [self ShowAlertDialogue:APP_NAME withMessage:INFORMATION_CIRCLE_WARNING isOkButton:YES isCancelButton:NO];
        //        UIAlertView *alertInformationCircle = [[UIAlertView alloc] initWithTitle:APP_NAME
        //                                                             message: INFORMATION_CIRCLE_WARNING
        //                                                                        delegate:nil
        //                                                               cancelButtonTitle:@"OK"
        //                                                               otherButtonTitles:nil, nil];
        //        [alertInformationCircle show];
    }
}

#pragma mark - UIAlertview delegate method on click of buttons

/*
 This method is default method of UIAlertViewDelegate. It is called when user click on buttons of Alerview is delegate is set to self.
 @param:
 1. alertView: Presented Alertview
 2. buttonIndex: index of button on which user clicks.
 
 output: It opens SMS composer controller when user take action on alertView send button.
 */
-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 101) {
        if(buttonIndex == 1)
        {
            if ([[appDelegate.userDefaults valueForKey:ContactToSend] length] > 0) {
                
                //check if internet connection is available
                //if not send from phone, else use Twillio to send text
                Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
                NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
                if (networkStatus == NotReachable) {
                    [self openMessageComposerViewController];
                    NSLog(@"There IS NO internet connection");
                } else {
                    [self openMessageComposerViewController]; //just for now
                    NSLog(@"There IS internet connection");        
                }
                
                
                
                
            } else {
                [self ShowAlertDialogue:APP_NAME withMessage:ADD_CONTACT_WARNING isOkButton:YES isCancelButton:NO];
            }
        }
    }
}

#pragma mark - MessageComposer Delegate method

/*
 This method is default method of MFMessageComposeViewControllerDelegate. It is called when user click on send/cancel button of message composer controller.
 @param:
 1. controller: Message composer controller.
 2. result: Result of action taken on controller.
 
 output: It close/dismiss the controller when user take action on composer controller.
 */
-(void) messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [controller dismissViewControllerAnimated:YES completion:NULL];
}


#pragma mark - Add small circles to views

/*
 This method will called when this view will appear and when user drag and drop any information circle.
 output: This method will call other method to generate information circles at dynamic position.
 */
-(void) addAllSmallCircleToRespectiveView{
    
    //Remove all information circles from red circle and out side red circle.
    for (id view in self.scrollRedCircle.subviews)
    {
        if ([view isKindOfClass:[JDDroppableView class]])
        {
            [view removeFromSuperview];
        }
    }
    
    for (id view in self.scrollSmallCircles.subviews)
    {
        if ([view isKindOfClass:[JDDroppableView class]])
        {
            [view removeFromSuperview];
        }
    }
    
    //Add information circles in respective views.
    NSSortDescriptor *sortOrder = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];
    
    NSArray *objects = [[buttonsInRedCircle allKeys] sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortOrder]];
    
    for (int i = 0; i <= (int)([objects count] - 1) ; i++)
    {
        if ([[objects objectAtIndex:i] length] > 0) {
            [self addRemoveSmallCircleToViewAtIndex:i toView:self.scrollRedCircle withKey:[objects objectAtIndex:i]];
        }
    }
    
    sortOrder = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:NO];
    [buttonsInOuterView removeObjectForKey:FQ_USER_FullName]; //quick fix of Narola bug, ideally the source should be fixed
    
    objects = [[buttonsInOuterView allKeys] sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortOrder]];
    
    for (int i = 0; i <=  (int)(TotalNumberOfBubbles - 1); i++)
    {
        if ((int)(i - (TotalNumberOfBubbles - [objects count])) >= 0) {
            if ([[objects objectAtIndex:(i - (TotalNumberOfBubbles - [objects count]))] length] > 0 ) {
                
                [self addRemoveSmallCircleToViewAtIndex:i toView:self.scrollSmallCircles withKey:[objects objectAtIndex:(i - (TotalNumberOfBubbles - [objects count]))]];
            }
        }
    }
}


/*
 This method is called by other method to insert information circle in red circle as well as outside of red circle.
 @param:
 1. i: it is index of information circle at that position it will placed.
 2. superview: either Red circle or outside of red circle. Based on dragged and dropped information circle by user.
 3. key: It is a id of information button like facebook, twitter, email etc..
 
 output: Placed information circle dynamically inside/outside of the red circle.
 */
- (void)addRemoveSmallCircleToViewAtIndex:(int)i toView:(id)superView withKey:(NSString *) key
{
    JDDroppableView * dropview = [[JDDroppableView alloc] initWithDropTarget:nil];
    dropview.delegate = self;
    
    float angleBetweenButtons = 0;
    double x = 0;
    double y = 0;
    
    NumberOfBubblesInRedCircle = [buttonsInRedCircle count];
    
    if (superView == self.scrollRedCircle) {
        // increse radius to increse space between two information circles in red circle
        radius = RadiusForInnerCircle;
        [dropview addDropTarget:self.scrollSmallCircles];
        angleBetweenButtons = (2 * M_PI) / NumberOfBubblesInRedCircle;
    }
    else{
        // increse radius to increse space between information circles and red circle
        radius = RadiusForOuterCircle;
        [dropview addDropTarget:self.scrollRedCircle];
        angleBetweenButtons = (2 * M_PI) / numberOfContactBubbles;
    }
    
    dropview.frame = CGRectMake(0, 0, 40, 40);
    dropview.layer.cornerRadius = dropview.frame.size.width/2;
    UIImageView *imgIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 35, 35)];
    
    if([key isEqualToString:FQ_USER_FliQIDofUser]) {
        imgIcon.image = [UIImage imageNamed:@"fliq_share"];
        dropview.accessibilityIdentifier = FQ_USER_FliQIDofUser;
    }else if([key isEqualToString:FQ_USER_PrimaryContactOfUser]) {
        imgIcon.image = [UIImage imageNamed:@"contact"];
        dropview.accessibilityIdentifier = FQ_USER_PrimaryContactOfUser;
    }else if([key isEqualToString:FQ_USER_EmailID]) {
        imgIcon.image = [UIImage imageNamed:@"email"];
        dropview.accessibilityIdentifier = FQ_USER_EmailID;
    }else if([key isEqualToString:FQ_USER_EmailID_Secondary]) {
        imgIcon.image = [UIImage imageNamed:@"email_secondary"];
        dropview.accessibilityIdentifier = FQ_USER_EmailID_Secondary;
    }else if([key isEqualToString:FQ_USER_LinkedInID]) {
        imgIcon.image = [UIImage imageNamed:@"linkedin"];
        dropview.accessibilityIdentifier = FQ_USER_LinkedInID;
    }else if([key isEqualToString:FQ_USER_FacebookID] ) {
        imgIcon.image = [UIImage imageNamed:@"facebook"];
        dropview.accessibilityIdentifier = FQ_USER_FacebookID;
    }else if([key isEqualToString:FQ_USER_TwitterID]) {
        imgIcon.image = [UIImage imageNamed:@"twitter"];
        dropview.accessibilityIdentifier = FQ_USER_TwitterID;
    }else if([key isEqualToString:FQ_USER_WorkContactOfUser]) {
        imgIcon.image = [UIImage imageNamed:@"contact_work"];
        dropview.accessibilityIdentifier = FQ_USER_WorkContactOfUser;
    }else if([key isEqualToString:FQ_USER_GooglePlusID]) {
        imgIcon.image = [UIImage imageNamed:@"google_plus"];
        dropview.accessibilityIdentifier = FQ_USER_GooglePlusID;
    }else if([key isEqualToString:FQ_USER_SnapChatID]) {
        imgIcon.image = [UIImage imageNamed:@"snapchat"];
        dropview.accessibilityIdentifier = FQ_USER_SnapChatID;
    }else if([key isEqualToString:FQ_USER_PrimaryWebsiteOfUser] ) {
        imgIcon.image = [UIImage imageNamed:@"globe_dark"];
        dropview.accessibilityIdentifier = FQ_USER_PrimaryWebsiteOfUser;
    }else if([key isEqualToString:FQ_USER_AnotherWebsiteOfUser]) {
        imgIcon.image = [UIImage imageNamed:@"globe_light"];
        dropview.accessibilityIdentifier = FQ_USER_AnotherWebsiteOfUser;
    }else{
        imgIcon.image = [UIImage imageNamed:@"user"];
        dropview.accessibilityIdentifier = @"user";
    }
    
    imgIcon.center = dropview.center;
    
    [dropview addSubview:imgIcon];
    [dropview setBackgroundColor:[UIColor clearColor]];
    
    // Here consider x as y for vertical distances and consider y as x for horizontal distances.
    
    if (superView == self.scrollSmallCircles) {
        int a = (int)(i + (numberOfContactBubbles - TotalNumberOfBubbles - 2));
        x = (self.scrollRedCircle.center.y) - cosf(a * -angleBetweenButtons) * radius;
        y = (self.scrollRedCircle.center.x) - sinf(a * -angleBetweenButtons) * radius;
        
    }else{
        
        if (NumberOfBubblesInRedCircle == 1) {
            x = self.scrollRedCircle.frame.size.height/2;
            y = self.scrollRedCircle.frame.size.width/2;
        }
        else{
            if (NumberOfBubblesInRedCircle == 2) {
                y = (self.scrollRedCircle.frame.size.height/2) - cosf(i * -angleBetweenButtons) * radius;
                x = (self.scrollRedCircle.frame.size.width/2) - sinf(i * -angleBetweenButtons) * radius;
            }
            else{
                x = (self.scrollRedCircle.frame.size.height/2) - cosf(i * -angleBetweenButtons) * radius;
                y = (self.scrollRedCircle.frame.size.width/2) - sinf(i * -angleBetweenButtons) * radius;
            }
        }
    }
    
    dropview.center = CGPointMake(y, x);
    [superView addSubview:dropview];
}

#pragma mark - Get movement of Red Circle

/*
 This method will check wheter user tap/drag red circle or information circles in red view.
 @param:
 1. recognizer: It is a Gesture reognizer on red circle.
 2. touch: get touch event on view.
 
 output: If user tap on information circle it will return NO and if outside of information circle but still in red circle than it will return YES.
 */
-(BOOL)gestureRecognizer:(UIGestureRecognizer *) recognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isKindOfClass:[JDDroppableView class]])
    {
        return NO;
    }
    else
    {
        if (([buttonsInRedCircle count] == 0) && (touch.view == self.scrollRedCircle)) {
            
            [self ShowAlertDialogue:APP_NAME withMessage:INFORMATION_CIRCLE_WARNING isOkButton:YES isCancelButton:NO];
            //            UIAlertView *alertInformationCircle = [[UIAlertView alloc] initWithTitle:APP_NAME
            //                                                                             message: INFORMATION_CIRCLE_WARNING
            //                                                                            delegate:nil
            //                                                                   cancelButtonTitle:@"OK"
            //                                                                   otherButtonTitles:nil, nil];
            //            [alertInformationCircle show];
            
            return NO;
        }
        else
            return YES;
    }
}

/*
 This method will called when user drag up big red circle on screen.
 @param:
 1. recognizer: It is a Gesture reognizer on red circle.
 
 output: If user drag red circle than message is generated to share with contact. Also animation done in this method with drag and fade out.
 */
-(void) redCircleMoved:(UIPanGestureRecognizer *) recognizer
{
    CGPoint translation = [recognizer translationInView:self.view];
    recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                         recognizer.view.center.y + translation.y);
    [recognizer setTranslation:CGPointMake(0, 0) inView:self.view];
    
    [self.view bringSubviewToFront:recognizer.view];
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        CGPoint velocity = [recognizer velocityInView:self.view];
        CGFloat magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
        CGFloat slideMult = magnitude / 200;
        
        float slideFactor = 0.1 * slideMult; // Increase for more of a slide
        __block CGPoint finalPoint = CGPointMake(recognizer.view.center.x + (velocity.x * slideFactor),recognizer.view.center.y + (velocity.y * slideFactor));
        
        finalPoint.x = MIN(MAX(finalPoint.x, 0), self.scrollSmallCircles.bounds.size.width);
        finalPoint.y = MIN(MAX(finalPoint.y, 0), self.scrollSmallCircles.bounds.size.height);
        
        if (initialCenterPointOfRedCircle.y > self.scrollRedCircle.center.y ) {

            if (self.fliqRecipientUUID != nil) {
            
                self.fliqDataToSend = [[[self composeFliq] dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
                
                self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.bluetoothQueue options:nil];
                self.receivedFliqData = [[NSMutableData alloc] init];
                self.fliqDict = [[NSDictionary alloc] init];
                
                [self.peripheralManager stopAdvertising]; //reset in case we are
                [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:FQ_PERSONAL_UUID]] }];
                
                
            } else {
                [self createMessageToShare];
            }
            [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                
                // If red circle is dragged little bit up than it will goes to the upper side of screen with animation and disappears from scrern.
                //Changes made by narola - 9-2-16
                recognizer.view.center = CGPointMake(finalPoint.x, (self.view.frame.origin.y - recognizer.view.frame.size.height)-200);
                
            } completion:^(BOOL finished) {
                
                //For fade out effect after swipe, we set original position of red circle but alpha = 0 so it is still disappear on screen.
                
                recognizer.view.alpha = 0;
                recognizer.view.center = initialCenterPointOfRedCircle;
                
                [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveEaseOut
                                 animations:^{
                                     // Set alpha 1 to display red circle with fadeout animation style.
                                     recognizer.view.alpha = 1;
                                     
                                 } completion:^(BOOL finished) {
                                     
                                 }];
            }];
        }
        else{
            
            [self ShowAlertDialogue:APP_NAME withMessage:DRAG_WARNING isOkButton:YES isCancelButton:NO];
            
            [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                
                // If red circle is dragged down side or left or right side but horizontally down than message will not be created. For that user has to drag up red circle.
                
                recognizer.view.center = initialCenterPointOfRedCircle;
                
            } completion:^(BOOL finished) {
            }];
        }
    }
}

#pragma mark - Set animationtion
/*
 This method is not currently in use. It coded to implement animation in application but not working properly.
 */
- (void)scrollToBottomAnimated:(BOOL)animated
{
    [self.scrollRedCircle.layer removeAllAnimations];
    
    CGFloat bottomScrollPosition = self.scrollSmallCircles.contentSize.height;
    bottomScrollPosition -= self.scrollSmallCircles.frame.size.height;
    bottomScrollPosition += self.scrollSmallCircles.contentInset.top;
    bottomScrollPosition = MAX(-self.scrollSmallCircles.contentInset.top,bottomScrollPosition);
    CGPoint newOffset = CGPointMake(-self.scrollSmallCircles.contentInset.left, bottomScrollPosition);
    if (newOffset.y != self.scrollSmallCircles.contentOffset.y) {
        [self.scrollSmallCircles setContentOffset: newOffset animated: animated];
    }
}

#pragma mark - JDDroppableViewDelegate

/*
 This method will call when small information circle is start dragging by users.
 @param:
 1. view: small information circle.
 
 Output: performs action which you code in this method, right now it create orange background for view.
 */
- (void)droppableViewBeganDragging:(JDDroppableView*)view;
{
    [UIView animateWithDuration:0.33 animations:^{
        view.backgroundColor = [UIColor orangeColor];
        view.alpha = 0.8;
    }];
}

/*
 This method will call when small information circle is moving while draged by user.
 @param:
 1. view: small information circle.
 
 Output: performs action which you code in this method.
 */
- (void)droppableViewDidMove:(JDDroppableView*)view;
{
    //
}

/*
 This method will call when small information circle is dropped by user.
 @param:
 1.view: small information circle.
 2.target: Big red circle.
 
 Output: performs action which you code in this method, right now it clear background for view.
 Which we set in droppableViewBeganDragging.
 */
- (void)droppableViewEndedDragging:(JDDroppableView*)view onTarget:(UIView *)target
{
    [UIView animateWithDuration:0.33 animations:^{
        if (!target) {
            view.backgroundColor = [UIColor clearColor];
        } else {
            view.backgroundColor = [UIColor clearColor];
        }
        view.alpha = 1.0;
    }];
}

/*
 This method will call when small information circle is entered in red big circle.
 @param:
 1.view: small information circle.
 2.target: Big red circle.
 
 Output: performs action which you code in this method.
 */
- (void)droppableView:(JDDroppableView*)view enteredTarget:(UIView*)target
{
    
}

/*
 This method will call when small information circle is left/drag-outside red big circle.
 @param:
 1.view: small information circle.
 2.target: Big red circle.
 
 Output: performs action which you code in this method.
 */
- (void)droppableView:(JDDroppableView*)view leftTarget:(UIView*)target
{
    
}

/*
 This method will call when small information circle is dropped on red big circle.
 @param:
 1.view: small information circle.
 2.target: Big red circle.
 
 Output: Performs task when we drop view. If target is red circle than it will add sircle in red circle and if terget is outside red circle(scrollInformationCircle) than it will remove circle from red circle and place it outside of red circle.
 */
- (BOOL)shouldAnimateDroppableViewBack:(JDDroppableView*)view wasDroppedOnTarget:(UIView*)target
{
    [self droppableView:view leftTarget:target];
    
    if ((((view.center.x + self.scrollRedCircle.frame.origin.x) > self.scrollRedCircle.frame.origin.x) && ((view.center.x + self.scrollRedCircle.frame.origin.x) < (self.scrollRedCircle.frame.origin.x + self.scrollRedCircle.frame.size.width )))
        &&
        (((view.center.y + self.scrollRedCircle.frame.origin.y) > self.scrollRedCircle.frame.origin.y) && ((view.center.y + self.scrollRedCircle.frame.origin.y) < (self.scrollRedCircle.frame.origin.y + self.scrollRedCircle.frame.size.height )))
        &&
        target == self.scrollSmallCircles ) {
        
        return YES;
    }
    
    // animate out and remove view
    [UIView animateWithDuration:0.33 animations:^{
        
        view.alpha = 1.0;
        
    } completion:^(BOOL finished) {
        
        if (target == self.scrollSmallCircles) {
            
            [view addDropTarget:self.scrollRedCircle];
            
            if ([view.accessibilityIdentifier isEqualToString:FQ_USER_FacebookID]) {
                [buttonsInOuterView setObject:FQ_USER_FacebookID forKey:FQ_USER_FacebookID];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_FacebookID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_TwitterID]) {
                [buttonsInOuterView setObject:FQ_USER_TwitterID forKey:FQ_USER_TwitterID];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_TwitterID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_EmailID]) {
                [buttonsInOuterView setObject:FQ_USER_EmailID forKey:FQ_USER_EmailID];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_EmailID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_EmailID_Secondary]) {
                [buttonsInOuterView setObject:FQ_USER_EmailID_Secondary forKey:FQ_USER_EmailID_Secondary];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_EmailID_Secondary];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_PrimaryContactOfUser]) {
                [buttonsInOuterView setObject:FQ_USER_PrimaryContactOfUser forKey:FQ_USER_PrimaryContactOfUser];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_PrimaryContactOfUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_LinkedInID]) {
                [buttonsInOuterView setObject:FQ_USER_LinkedInID forKey:FQ_USER_LinkedInID];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_LinkedInID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_FliQIDofUser]) {
                [buttonsInOuterView setObject:FQ_USER_FliQIDofUser forKey:FQ_USER_FliQIDofUser];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_FliQIDofUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_WorkContactOfUser]) {
                [buttonsInOuterView setObject:FQ_USER_WorkContactOfUser forKey:FQ_USER_WorkContactOfUser];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_WorkContactOfUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_GooglePlusID]) {
                [buttonsInOuterView setObject:FQ_USER_GooglePlusID forKey:FQ_USER_GooglePlusID];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_GooglePlusID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_SnapChatID]) {
                [buttonsInOuterView setObject:FQ_USER_SnapChatID forKey:FQ_USER_SnapChatID];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_SnapChatID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_PrimaryWebsiteOfUser]) {
                [buttonsInOuterView setObject:FQ_USER_PrimaryWebsiteOfUser forKey:FQ_USER_PrimaryWebsiteOfUser];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_PrimaryWebsiteOfUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_AnotherWebsiteOfUser]) {
                [buttonsInOuterView setObject:FQ_USER_AnotherWebsiteOfUser forKey:FQ_USER_AnotherWebsiteOfUser];
                [buttonsInRedCircle setValue:nil forKey:FQ_USER_AnotherWebsiteOfUser];
            }
            
        } else if(target == self.scrollRedCircle){
            
            [view addDropTarget:self.scrollSmallCircles];
            
            if ([view.accessibilityIdentifier isEqualToString:FQ_USER_FacebookID]) {
                [buttonsInRedCircle setObject:FQ_USER_FacebookID forKey:FQ_USER_FacebookID];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_FacebookID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_TwitterID]) {
                [buttonsInRedCircle setObject:FQ_USER_TwitterID forKey:FQ_USER_TwitterID];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_TwitterID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_EmailID]) {
                [buttonsInRedCircle setObject:FQ_USER_EmailID forKey:FQ_USER_EmailID];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_EmailID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_EmailID_Secondary]) {
                [buttonsInRedCircle setObject:FQ_USER_EmailID_Secondary forKey:FQ_USER_EmailID_Secondary];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_EmailID_Secondary];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_PrimaryContactOfUser]) {
                [buttonsInRedCircle setObject:FQ_USER_PrimaryContactOfUser forKey:FQ_USER_PrimaryContactOfUser];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_PrimaryContactOfUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_LinkedInID]) {
                [buttonsInRedCircle setObject:FQ_USER_LinkedInID forKey:FQ_USER_LinkedInID];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_LinkedInID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_FliQIDofUser]) {
                [buttonsInRedCircle setObject:FQ_USER_FliQIDofUser forKey:FQ_USER_FliQIDofUser];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_FliQIDofUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_WorkContactOfUser]) {
                [buttonsInRedCircle setObject:FQ_USER_WorkContactOfUser forKey:FQ_USER_WorkContactOfUser];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_WorkContactOfUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_GooglePlusID]) {
                [buttonsInRedCircle setObject:FQ_USER_GooglePlusID forKey:FQ_USER_GooglePlusID];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_GooglePlusID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_SnapChatID]) {
                [buttonsInRedCircle setObject:FQ_USER_SnapChatID forKey:FQ_USER_SnapChatID];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_SnapChatID];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_PrimaryWebsiteOfUser]) {
                [buttonsInRedCircle setObject:FQ_USER_PrimaryWebsiteOfUser forKey:FQ_USER_PrimaryWebsiteOfUser];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_PrimaryWebsiteOfUser];
            }
            else if ([view.accessibilityIdentifier isEqualToString:FQ_USER_AnotherWebsiteOfUser]) {
                [buttonsInRedCircle setObject:FQ_USER_AnotherWebsiteOfUser forKey:FQ_USER_AnotherWebsiteOfUser];
                [buttonsInOuterView setValue:nil forKey:FQ_USER_AnotherWebsiteOfUser];
            }
        }
        
        [view removeFromSuperview];
        
        [self addAllSmallCircleToRespectiveView];
        
        [DefaultsValues setCustomObjToUserDefaults:buttonsInOuterView ForKey:ButtonNOTAddedInRedCircle];
        [DefaultsValues setCustomObjToUserDefaults:buttonsInRedCircle ForKey:ButtonAddedInRedCircle];
    }];
    
    return NO;
}

#pragma mark ----------------------------- CB Central methods ----------------------------------------------

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"Central State Powered ON");
        // Scan for devices
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:self.fliqRecipientUUID]] options:nil]; //Apple's sample code allows for duplicates for some reason - just a note idk why
        NSLog(@"Started scan with recipient UUID: %@", self.fliqRecipientUUID);
    }
    
    //other possible scenarios
    else if (central.state == CBCentralManagerStateUnsupported) {
        NSLog(@"Bluetooth 4.0 unsupported");
        return;
    }
    else if (central.state == CBCentralManagerStatePoweredOff) {
        NSLog(@"Central State Powered OFF");
        return;
    }
    else if (central.state == CBCentralManagerStateUnknown) {
        NSLog(@"Central State Unknown");
        return;
    }
    else if (central.state == CBCentralManagerStateUnauthorized) {
        NSLog(@"Central State Unauthorized");
        return;
    }
    else if (central.state == CBCentralManagerStateResetting) {
        NSLog(@"Central State Resetting");
        return;
    }
    
}

//called every time a new peripheral is discovered
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (self.discoveredPeripheral != peripheral) {
        // Save a local copy of the peripheral
        self.discoveredPeripheral = peripheral;
        
        NSLog(@"Discovered peripheral: %@ with RSSI: %@", peripheral.name, RSSI);
        
        [self.centralManager connectPeripheral:peripheral options:nil];
        NSLog(@"establishing connection with %@", peripheral.name);
    }
    
}

//connection unsuccesful
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"Failed to connect with %@", peripheral.name);
    [self cleanup];
}

//connection succesful
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral %@ connected", peripheral.name);
    
    //    //Stop scanning to save battery power
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    peripheral.delegate = self;
    [self.receivedFliqData setLength:0];
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:self.fliqRecipientUUID]]];
}

//discovering services of connected peripheral
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        //handle error
        NSLog(@"Error discovering service for peripheral %@. Error: %@", peripheral.name, [error localizedDescription]);
        [self cleanup];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        
        NSLog(@"Discovered service %@", service);
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID]] forService:service]; //photo to be added later
    }
}

//discover characteristics
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        //do some cleanup
        [self cleanup];
        NSLog(@"Error discovering characteristics for peripheral %@ , service %@. Error: %@", peripheral.name, service, [error localizedDescription]);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Discovered characteristic %@", characteristic);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"Subscribed to characteristic %@", characteristic);
            
        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"did update value");
    if (error) {
        NSLog(@"Error updating value for characteristic %@. Error: %@", characteristic, [error localizedDescription]);
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSLog(@"Received: %@", stringFromData);
    
    //check if this is the end of the message
    if ([stringFromData isEqualToString:@"EOM"]) {
        
        NSLog(@"received EOM fliq");
        
        NSString *fliqString = [[NSString alloc] initWithData:self.receivedFliqData encoding:NSUTF8StringEncoding];
        
        self.fliqString = fliqString;
        NSLog(@"F string: %@", self.fliqString);
        
        NSData *jsonData = [fliqString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *dictError;
        self.fliqDict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&dictError];
        if(dictError){
            NSLog(@"Error creating fliqDict. Error: %@", [dictError localizedDescription]);
        }
        NSLog(@"printing fliqDict:%@", _fliqDict);
        
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        [self cleanup]; //needed?
        
        int i = 0;
        while (!readyForSegue && i < 8) {
            [NSThread sleepForTimeInterval:0.5f];
            i++;
            NSLog(@"sleep again...");
        }
        readyForSegue = NO;
        dispatch_async(dispatch_get_main_queue(),^{
            
            [self.parentViewController performSegueWithIdentifier:@"incoming_fliq_segue" sender:self.parentViewController];
        });

        
        
    }
    
    [self.receivedFliqData appendData:characteristic.value];
    
    
}

//- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
//{
//
//    if (error) {
//        NSLog(@"Error changing notification state: %@", error.localizedDescription);
//    }
//
//    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID]]) {
//        return;
//    }
//
//    if (characteristic.isNotifying) {
//        NSLog(@"Notification on %@", characteristic);
//    }
//    else {
//        // Notification has stopped
//        [self.centralManager cancelPeripheralConnection:peripheral];
//    }
//}
//

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
    self.discoveredPeripheral = nil;
    
}



#pragma mark - CB Peripheral methods
-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:FQ_PERSONAL_UUID] primary:YES];
        
        self.fliqCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
        
        
        transferService.characteristics = @[self.fliqCharacteristic];
        
        [self.peripheralManager addService:transferService];
        NSLog(@"added service with UUID: %@", FQ_PERSONAL_UUID);
    }
    else if (peripheral.state == CBPeripheralManagerStatePoweredOff){
        NSLog(@"peripheral state powered off");
        return;
    }
    else if (peripheral.state == CBPeripheralManagerStateResetting){
        NSLog(@"peripheral state resetting");
        return;
    }
    else if (peripheral.state == CBPeripheralManagerStateUnauthorized){
        NSLog(@"peripheral state unauthorized");
        return;
    }
    else if (peripheral.state == CBPeripheralManagerStateUnknown){
        NSLog(@"peripheral state unknown");
        return;
    }
    else if (peripheral.state == CBPeripheralManagerStateUnsupported){
        NSLog(@"peripheral state unsupported");
        return;
    }
}

-(void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    if (error) {
        NSLog(@"Error advertising: %@", [error localizedDescription]);
        return;
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    //    self.dataToSend = [self.peripheralTextView.text dataUsingEncoding:NSUTF8StringEncoding];
    //
    //    [self.peripheralManager updateValue:self.dataToSend forCharacteristic:[characteristic mutableCopy] onSubscribedCentrals:@[central]];
    
    //reset index
    self.fliqDataIndex = 0;
    readyForSegue = NO;
    [self sendData];
}

/** Recognise when the central unsubscribes
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic %@", characteristic);
}

- (void)sendData {
    
    static BOOL sendingEOM = NO;
    
    // end of message?
    if (sendingEOM) {
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.fliqCharacteristic onSubscribedCentrals:nil];
        
        if (didSend) {
            // It did, so mark it as sent
            sendingEOM = NO;
            NSLog(@"Sent: EOM");
            
        }
        // didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return;
    }
    
    // We're sending data
    // Is there any left to send?
    if (self.fliqDataIndex >= self.fliqDataToSend.length) {
        // No data left.  Do nothing
        return;
    }
    
    // There's data left, so send until the callback fails, or we're done.
    BOOL didSend = YES;
    
    while (didSend) {
        // Work out how big it should be
        NSInteger amountToSend = self.fliqDataToSend.length - self.fliqDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.fliqDataToSend.bytes+self.fliqDataIndex length:amountToSend];
        
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.fliqCharacteristic onSubscribedCentrals:nil];
        
        // If it didn't work, drop out and wait for the callback
        if (!didSend) {
            return;
        }
        
        NSString *stringFromData = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSLog(@"Sent: %@", stringFromData);
        
        // It did send, so update our index
        self.fliqDataIndex += amountToSend;
        
        // Was it the last one?
        if (self.fliqDataIndex >= self.fliqDataToSend.length) {
            
            // Set this so if the send fails, we'll send it next time
            sendingEOM = YES;
            
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.fliqCharacteristic onSubscribedCentrals:nil];
            
            if (eomSent) {
                // It sent, we're all done
                sendingEOM = NO;
                NSLog(@"Sent: EOM");
            }
            
            readyForSegue = YES;
            return;
        }
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self sendData];
} //check if needed


#pragma mark - cleanup
//below code provided by Apple sample
/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
    // Don't do anything if we're not connected
    if (self.discoveredPeripheral.state == CBPeripheralStateDisconnected) {
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if (self.discoveredPeripheral.services != nil) {
        for (CBService *service in self.discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            // It is notifying, so unsubscribe
                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            
                            // And we're done.
                            NSLog(@"cleaned succesfully");
                            return;
                        }
                    }
                }
            }
        }
    }
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}

#pragma mark - composeFliq method

//this code should be able to be reduced usign a for loop going through the keys, but keys should be cleaned and consolidated first.
-(NSString *)composeFliq
{
    NSArray *nameArray = [userPersonalDetail[FQ_USER_FullName] componentsSeparatedByString:@" "];
    NSString *firstName = nameArray.count > 0?nameArray[0]:@"";
    NSString *lastName =  nameArray.count > 1?[nameArray lastObject]:@"";
    
    NSString *phone1 = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_PrimaryContactOfUser] != nil) {
        if (valuesAddedByUser[FQ_USER_PrimaryContactOfUser] != nil ) {
            phone1 = valuesAddedByUser[FQ_USER_PrimaryContactOfUser];
        }
    }
    
    NSString *phone2 = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_WorkContactOfUser] != nil) {
        if (valuesAddedByUser[FQ_USER_WorkContactOfUser] != nil ) {
            phone2 = valuesAddedByUser[FQ_USER_WorkContactOfUser];
        }
    }
    
    NSString *email1 = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_EmailID] != nil) {
        
        if (valuesAddedByUser[FQ_USER_EmailID] != nil ) {
            email1 = valuesAddedByUser[FQ_USER_EmailID];
        }
    }
    
    NSString *email2 = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_EmailID_Secondary] != nil) {
        
        if (valuesAddedByUser[FQ_USER_EmailID_Secondary] != nil ) {
            email2 = valuesAddedByUser[FQ_USER_EmailID_Secondary];
        }
    }
    
    NSString *facebook = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_FacebookID] != nil) {
        
        if (valuesAddedByUser[FQ_USER_FacebookID] != nil ) {
            facebook = valuesAddedByUser[FQ_USER_FacebookID];
        }
    }
    
    NSString *gplus = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_GooglePlusID] != nil) {
        
        if (valuesAddedByUser[FQ_USER_GooglePlusID] != nil ) {
            gplus = valuesAddedByUser[FQ_USER_GooglePlusID];
        }
    }
    
    NSString *linkedin = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_LinkedInID] != nil) {
        
        if (valuesAddedByUser[FQ_USER_LinkedInID] != nil ) {
            linkedin = valuesAddedByUser[FQ_USER_LinkedInID];
        }
    }
    
    NSString *twitter = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_TwitterID] != nil) {
        
        if (valuesAddedByUser[FQ_USER_TwitterID] != nil ) {
            twitter = valuesAddedByUser[FQ_USER_TwitterID];
        }
    }
    
    NSString *snapchat = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_SnapChatID] != nil) {
        
        if (valuesAddedByUser[FQ_USER_SnapChatID] != nil ) {
            snapchat = valuesAddedByUser[FQ_USER_SnapChatID];
        }
    }
    
    NSString *website1 = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_PrimaryWebsiteOfUser] != nil) {
        
        if (valuesAddedByUser[FQ_USER_PrimaryWebsiteOfUser] != nil ) {
            website1 = valuesAddedByUser[FQ_USER_PrimaryWebsiteOfUser];
        }
    }
    
    NSString *website2 = @"nil"; //default
    if (buttonsInRedCircle[FQ_USER_AnotherWebsiteOfUser] != nil) {
        
        if (valuesAddedByUser[FQ_USER_AnotherWebsiteOfUser] != nil ) {
            website2 = valuesAddedByUser[FQ_USER_AnotherWebsiteOfUser];
        }
    }
    
    
    //NSString *fliq = [NSString stringWithFormat:@"%@*%@*%@*%@*%@*%@*%@*%@*%@*%@*%@*%@*%@", firstName, lastName, phone1, phone2, email1, email2, facebook, gplus, linkedin, twitter, snapchat, website1, website2];
    
    //NSString *fliq = [NSString stringWithFormat:@"&data={\"firstName\":\"%@\",\"lastName\":\"%@\",\"phone1\":\"%@\",\"phone2\":\"%@\",\"email1\":\"%@\",\"email2\":\"%@\",\"facebook\":\"%@\",\"gplus\":\"%@\",\"linkedin\":\"%@\",\"twitter\":\"%@\",\"snapchat\":\"%@\",\"website1\":\"%@\",\"website2\":\"%@\"}",firstName,lastName,phone1,phone2,email1,email2,facebook,gplus,linkedin,twitter,snapchat,website1,website2];
    
    //create dictionary
    NSArray *keys = [NSArray arrayWithObjects: @"firstName",@"lastName", @"phone1", @"phone2", @"email1", @"email2", @"facebook", @"gplus", @"linkedin", @"twitter", @"snapchat", @"website1", @"website 2", nil];
    NSArray *objects = [NSArray arrayWithObjects:firstName, lastName, phone1, phone2, email1, email2, facebook, gplus, linkedin, twitter, snapchat, website1, website2, nil];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:objects forKeys:keys];
    
    //convert to JSONString
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    NSString *fliq;
    if (! jsonData) {
        fliq = @"";
        NSLog(@"Got an error: %@", error);
    } else {
         fliq = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    
    NSLog(@"%@", fliq); //just for now

    return fliq;
}


@end
