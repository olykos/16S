//
//  SecondViewController.m
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 1/7/15.
//  Copyright (c) 2015 Orestis Lykouropoulos. All rights reserved.
//

#import "PeripheralViewController.h"
#import "UserValues.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <AddressBook/AddressBook.h>
#import "AddContactViewController.h"

@interface PeripheralViewController () <CBPeripheralManagerDelegate>

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

//bluetooth properties
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *fliqCharacteristic;
@property (strong, nonatomic) NSData *fliqDataToSend;
@property (nonatomic, readwrite) NSInteger fliqDataIndex;

@property (strong, nonatomic) NSString *fliqString;

@property (strong, nonatomic) CBMutableCharacteristic *writableCharacteristic;

- (IBAction)fliqButtonPressed:(UIButton *)sender;

#define NOTIFY_MTU      20

@end

@implementation PeripheralViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.nameLabel.text = PERIPHERAL_NAME;
    self.phoneLabel.text = PERIPHERAL_PHONE;
    self.emailLabel.text = PERIPHERAL_EMAIL;
    self.facebookLabel.text = PERIPHERAL_FACEBOOK;
    self.twitterLabel.text = PERIPHERAL_TWITTER;
    self.linkedInLabel.text = PERIPHERAL_LINKEDIN;
    
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Don't keep it going while we're not showing.
    [self.peripheralManager stopAdvertising];
    
    
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)fliqButtonPressed:(UIButton *)sender {
    
    self.fliqDataToSend = [[self composeFliq] dataUsingEncoding:NSUTF8StringEncoding];

    NSLog(@"Fliq button pressed from peripheral");
    [self.peripheralManager stopAdvertising]; //reset in case we are
    NSLog(@"start advertising");
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:FQ_PERSONAL_UUID]] }];
}

#pragma mark - CBPeripheralManagerDelegate methods

-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:FQ_PERSONAL_UUID] primary:YES];
        
        self.fliqCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
        
        self.writableCharacteristic =[[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:FQ_WRITEABLE_CHARACTERISTIC_UID] properties:CBCharacteristicPropertyNotify|CBCharacteristicPropertyWrite|CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable|CBAttributePermissionsWriteable];

        
        transferService.characteristics = @[self.fliqCharacteristic, self.writableCharacteristic];
        
        [self.peripheralManager addService:transferService];
        NSLog(@"added service");
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
            
            return;
        }
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    [self sendData];
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    NSLog(@"called didReceiveWriteRequests");
    CBATTRequest       *fliqRequest = [requests  objectAtIndex:0];
    NSData             *request_data = fliqRequest.value;
    CBCharacteristic   *write_characteristic = fliqRequest.characteristic;
    //CBCentral*            write_central = request.central;
    
    if ([ write_characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_WRITEABLE_CHARACTERISTIC_UID]] )
    {
        NSString *fliqString = [[NSString alloc] initWithData:request_data encoding:NSUTF8StringEncoding];
        self.fliqString = fliqString;
        
        [peripheral respondToRequest:fliqRequest withResult:CBATTErrorSuccess];
        [self performSegueWithIdentifier:@"peripheralToAddContactVCSegue" sender:self];
    } else {
        NSLog(@"Wrong characteristic.");
        [peripheral respondToRequest:fliqRequest withResult:CBATTErrorAttributeNotFound];
    }
}


#pragma mark - segue method
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //I don't think I need to check the sender's class in this case but here's a note to keep that in mind
    if ([segue.destinationViewController isKindOfClass:[AddContactViewController class]]) {
        AddContactViewController *destinationVC = segue.destinationViewController;
        destinationVC.fliqString = self.fliqString;
    }
    
}

#pragma mark - composeFliq method
-(NSString *)composeFliq
{
    NSArray *nameArray = [self.nameLabel.text componentsSeparatedByString:@" "];
    NSString *firstName = nameArray[0];
    NSString *lastName = nameArray[1];
    
    NSString *phone;
    if (self.phoneSwitch.isOn) phone = self.phoneLabel.text;
    else phone = @"nil";
    
    NSString *email;
    if (self.emailSwitch.isOn) email = self.emailLabel.text;
    else email = @"nil";
    
    NSString *facebook;
    if (self.facebookSwitch.isOn) facebook = self.facebookLabel.text;
    else facebook = @"nil";
    
    NSString *twitter;
    if (self.twitterSwitch.isOn) twitter = self.twitterLabel.text;
    else twitter = @"nil";
    
    NSString *linkedIn;
    if (self.linkedInSwitch.isOn) linkedIn = self.linkedInLabel.text;
    else linkedIn = @"nil";
    
    NSString *fliq = [NSString stringWithFormat:@"%@:%@:%@:%@:%@:%@:%@", firstName, lastName, phone, email, facebook, twitter, linkedIn];
    
    NSLog(@"%@", fliq); //just for now
    
    return fliq;
}


@end
