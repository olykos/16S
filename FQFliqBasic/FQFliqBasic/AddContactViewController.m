//
//  AddContactViewController.m
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 1/24/15.
//  Copyright (c) 2015 Orestis Lykouropoulos. All rights reserved.
//

#import "AddContactViewController.h"
#import <AddressBook/AddressBook.h>
#import "UserValues.h"


@interface AddContactViewController ()

@property (strong, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) IBOutlet UILabel *phoneLabel;
@property (strong, nonatomic) IBOutlet UILabel *emailLabel;
@property (strong, nonatomic) IBOutlet UILabel *facebookLabel;
@property (strong, nonatomic) IBOutlet UILabel *twitterLabel;
@property (strong, nonatomic) IBOutlet UILabel *linkedInLabel;

@property (strong, nonatomic) IBOutlet UISwitch *phoneSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *emailSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *facebookSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *twitterSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *linkedInSwitch;

@property (strong, nonatomic) NSMutableDictionary *fliqDict;

@property (nonatomic, assign) BOOL contactWasSaved;

//IBActions
- (IBAction)addButtonPressed:(UIButton *)sender;
@end

@implementation AddContactViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    NSLog(@"fliq string: %@", self.fliqString);
    [self decodeFliq:self.fliqString];
    [self updateLabels];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - show information method
-(void)updateLabels
{
    self.nameLabel.text = [NSString stringWithFormat:@"%@ %@", self.fliqDict[FQ_INCOMING_FIRST_NAME], self.fliqDict[FQ_INCOMING_LAST_NAME]];
    self.phoneLabel.text = self.fliqDict[FQ_INCOMING_PHONE];
    self.emailLabel.text = self.fliqDict[FQ_INCOMING_EMAIL];
    self.facebookLabel.text = self.fliqDict[FQ_INCOMING_FACEBOOK];
    self.twitterLabel.text = self.fliqDict[FQ_INCOMING_TWITTER];
    self.linkedInLabel.text = self.fliqDict[FQ_INCOMING_LINKEDIN];
    
    if ([self.fliqDict[FQ_INCOMING_PHONE] isEqualToString:@"nil"]){
        self.phoneSwitch.hidden = YES;
        self.phoneLabel.text = @"-";
    }
    if ([self.fliqDict[FQ_INCOMING_EMAIL] isEqualToString:@"nil"]){
        self.emailSwitch.hidden = YES;
        self.emailLabel.text = @"-";
    }
    if ([self.fliqDict[FQ_INCOMING_FACEBOOK] isEqualToString:@"nil"]){
        self.facebookSwitch.hidden = YES;
        self.facebookLabel.text = @"-";
    }
    if ([self.fliqDict[FQ_INCOMING_TWITTER] isEqualToString:@"nil"]){
        self.twitterSwitch.hidden = YES;
        self.twitterLabel.text = @"-";
    }
    if ([self.fliqDict[FQ_INCOMING_LINKEDIN] isEqualToString:@"nil"]){
        self.linkedInSwitch.hidden = YES;
        self.linkedInLabel.text = @"-";
    }
    
}

#pragma mark - decode fliq & save to contacts

-(void)decodeFliq:(NSString *)fliqString
{
    NSArray *fliqArray = [fliqString componentsSeparatedByString:@":"];
    self.fliqDict = [[NSMutableDictionary alloc] initWithCapacity:7];
    
    NSLog(@"%@", fliqArray);
    
    self.fliqDict[FQ_INCOMING_FIRST_NAME] = fliqArray[0];
    self.fliqDict[FQ_INCOMING_LAST_NAME] = fliqArray[1];
    self.fliqDict[FQ_INCOMING_PHONE] = fliqArray[2];
    self.fliqDict[FQ_INCOMING_EMAIL] = fliqArray[3];
    self.fliqDict[FQ_INCOMING_FACEBOOK] = fliqArray[4];
    self.fliqDict[FQ_INCOMING_TWITTER] = fliqArray[5];
    self.fliqDict[FQ_INCOMING_LINKEDIN] = fliqArray[6];
    
}


-(void)saveFliqToContacts
{
    [self checkAuthorizationAndAddToContacts];
}

- (void)checkAuthorizationAndAddToContacts {
    
    //can't add contact alert
    UIAlertView *cantAddContactAlert = [[UIAlertView alloc] initWithTitle: @"Cannot Add Contact" message: @"You must give the app permission to add the contact first." delegate:nil cancelButtonTitle: @"OK" otherButtonTitles: nil];
    
    if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusDenied ||
        ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusRestricted){
        NSLog(@"Denied");
        [cantAddContactAlert show];
        
    } else if (ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusAuthorized){
        NSLog(@"Authorized");
        [self addToContacts];
        
    } else{ //ABAddressBookGetAuthorizationStatus() == kABAuthorizationStatusNotDetermined
        NSLog(@"Not determined");
        ABAddressBookRequestAccessWithCompletion(ABAddressBookCreateWithOptions(NULL, nil), ^(bool granted, CFErrorRef error) {
            if (!granted){
                NSLog(@"Just denied");
                [cantAddContactAlert show];
                return;
            }
            NSLog(@"Just authorized");
            [self checkAuthorizationAndAddToContacts];
        });
    }
}



- (void)addToContacts{
    
    CFErrorRef * error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, error);
    ABRecordRef newPerson = ABPersonCreate();
    
    //name
    NSString *firstName = self.fliqDict[FQ_INCOMING_FIRST_NAME];
    NSString *lastName = self.fliqDict[FQ_INCOMING_LAST_NAME];
    
    CFErrorRef firstNameError = NULL;
    bool didSetFirstName = ABRecordSetValue(newPerson, kABPersonFirstNameProperty, (__bridge CFStringRef)firstName, &firstNameError);
    if (!didSetFirstName) {
        NSLog(@"error setting first name record value");
        /* Handle error here. */}
    
    CFErrorRef lastNameError = NULL;
    bool didSetLastName = ABRecordSetValue(newPerson, kABPersonLastNameProperty, (__bridge CFStringRef)lastName, &lastNameError);
    if (!didSetLastName) {
        NSLog(@"error setting  last name record value");
        /* Handle error here. */}
    
    //phone
    if (![self.fliqDict[FQ_INCOMING_PHONE] isEqualToString:@"nil"] && self.phoneSwitch.isOn){
        ABMutableMultiValueRef phoneMulti =  ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(phoneMulti ,(__bridge CFStringRef) self.fliqDict[FQ_INCOMING_PHONE],kABPersonPhoneMainLabel, NULL);
        ABRecordSetValue(newPerson, kABPersonPhoneProperty,  phoneMulti, nil);
    }
    
    // email
    if (![self.fliqDict[FQ_INCOMING_EMAIL] isEqualToString:@"nil"] && self.emailSwitch.isOn){
        
        ABMutableMultiValueRef emailMulti = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(emailMulti, (__bridge CFStringRef) self.fliqDict[FQ_INCOMING_EMAIL], kABWorkLabel, NULL);
        
        ABRecordSetValue(newPerson, kABPersonEmailProperty, emailMulti, nil);
    }
    
    //social
    if (!([self.fliqDict[FQ_INCOMING_FACEBOOK] isEqualToString:@"nil"] && [self.fliqDict[FQ_INCOMING_TWITTER] isEqualToString:@"nil"] && [self.fliqDict[FQ_INCOMING_LINKEDIN] isEqualToString:@"nil"])) {
        
        ABMultiValueRef socialMulti = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);
        
        //facebook
        if (![self.fliqDict[FQ_INCOMING_FACEBOOK] isEqualToString:@"nil"] && self.facebookSwitch.isOn){
            ABMultiValueAddValueAndLabel(socialMulti, (__bridge CFTypeRef)([NSDictionary dictionaryWithObjectsAndKeys:(NSString *)kABPersonSocialProfileServiceFacebook, kABPersonSocialProfileServiceKey, self.fliqDict[FQ_INCOMING_FACEBOOK], kABPersonSocialProfileUsernameKey,nil]), kABPersonSocialProfileServiceFacebook, NULL);
        }
        
        //twitter
        if (![self.fliqDict[FQ_INCOMING_TWITTER] isEqualToString:@"nil"] && self.twitterSwitch.isOn) {
            
            ABMultiValueAddValueAndLabel(socialMulti, (__bridge CFTypeRef)([NSDictionary dictionaryWithObjectsAndKeys:(NSString *)kABPersonSocialProfileServiceTwitter, kABPersonSocialProfileServiceKey, self.fliqDict[FQ_INCOMING_TWITTER], kABPersonSocialProfileUsernameKey,nil]), kABPersonSocialProfileServiceTwitter, NULL);
        }           
        
        //linkedIn
        if (![self.fliqDict[FQ_INCOMING_LINKEDIN] isEqualToString:@"nil"] && self.linkedInSwitch.isOn) {
            
            ABMultiValueAddValueAndLabel(socialMulti, (__bridge CFTypeRef)([NSDictionary dictionaryWithObjectsAndKeys:(NSString *)kABPersonSocialProfileServiceLinkedIn, kABPersonSocialProfileServiceKey, self.fliqDict[FQ_INCOMING_LINKEDIN], kABPersonSocialProfileUsernameKey,nil]), kABPersonSocialProfileServiceLinkedIn, NULL);
        }
        
        ABRecordSetValue(newPerson, kABPersonSocialProfileProperty, socialMulti, NULL);
    }
    
    
    //save
    ABAddressBookAddRecord(addressBook, newPerson, nil);
    if (ABAddressBookSave(addressBook, nil)) {
        NSLog(@"Saved successfuly");
        [self setContactWasSaved:YES];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Contact added succesfully" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
        [alert show];
    } else {
        NSLog(@"Error saving person to AddressBook");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Error adding contact" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
        [alert show];
    }
}



- (IBAction)addButtonPressed:(UIButton *)sender {
    
    if (![self contactWasSaved]) {
        [self saveFliqToContacts];
    }
    else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Contact has already been added" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
        [alert show];
    }
    
}
@end
