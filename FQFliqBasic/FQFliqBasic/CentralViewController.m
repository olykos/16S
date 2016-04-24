//
//  FirstViewController.m
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 1/7/15.
//  Copyright (c) 2015 Orestis Lykouropoulos. All rights reserved.
//

#import "CentralViewController.h"
#import "UserValues.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import <AddressBook/AddressBook.h>
#import "AddContactViewController.h"

@interface CentralViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

//interface properties
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

//CoreBluetooth properties
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) NSMutableData *receivedFliqData;

@property (strong, nonatomic) NSString *fliqString;



//actions
- (IBAction)fliqButtonPressed:(UIButton *)sender;
@end

@implementation CentralViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.nameLabel.text = CENTRAL_NAME;
    self.phoneLabel.text = CENTRAL_PHONE;
    self.emailLabel.text = CENTRAL_EMAIL;
    self.facebookLabel.text = CENTRAL_FACEBOOK;
    self.twitterLabel.text = CENTRAL_TWITTER;
    self.linkedInLabel.text = CENTRAL_LINKEDIN;
    
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped. View will disappear.");
    
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)fliqButtonPressed:(UIButton *)sender {
    NSLog(@"Fliq button pressed from central.");
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
    self.receivedFliqData = [[NSMutableData alloc] init];
    NSLog(@"initialized empty received fliq data");
}


#pragma mark - CB methods

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"Central State Powered ON");
        // Scan for devices
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:self.fliqRecipientUUID]] options:nil]; //Apple's sample code allows for duplicates for some reason - just a note idk why
        NSLog(@"Started scan");
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
    //    // Reject any where the value is above reasonable range
    //    if (RSSI.integerValue > -15) {
    //        return;
    //    }
    //
    //    // Reject if the signal strength is too low to be close enough (Close is around -22dB)
    //    if (RSSI.integerValue < -35) {
    //        return;
    //    }
    
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
    //do a cleanup later
    [self cleanup];
}

//connection succesful
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Peripheral %@ connected", peripheral.name);
    
    //Stop scanning to save battery power
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    [self.receivedFliqData setLength:0];
    
    peripheral.delegate = self;
    
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
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID],[CBUUID UUIDWithString:FQ_WRITEABLE_CHARACTERISTIC_UID]] forService:service];
    }
}

//discover characteristics
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        //do some cleanup
        NSLog(@"Error discovering characteristics for peripheral %@ , service %@. Error: %@", peripheral.name, service, [error localizedDescription]);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Discovered characteristic %@", characteristic);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"Subscribed to characteristic %@", characteristic);
            
            //            NSLog(@"Reading value for characteristic %@", characteristic);
            //            [peripheral readValueForCharacteristic:characteristic]; probably use this later instead of subscription
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_WRITEABLE_CHARACTERISTIC_UID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic]; //check if this is needed
            NSLog(@"Subscribed to characteristic %@", characteristic);

            NSLog(@"Writing to characteristic %@", characteristic);

            NSData *fliqData = [[self composeFliq] dataUsingEncoding:NSUTF8StringEncoding];
            [peripheral writeValue:fliqData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            
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
        
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
        [self cleanup];

        [self performSegueWithIdentifier:@"centralToAddContactVCSegue" sender:self];
        
    }
    
    [self.receivedFliqData appendData:characteristic.value];
    
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying) {
        NSLog(@"Notification on %@", characteristic);
    }
    else {
        // Notification has stopped
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
    self.discoveredPeripheral = nil;
    
//    [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:self.fliqRecipientUUID]] options:nil];
}


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

#pragma mark - segue method
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //I don't think I need to check the sender's class in this case but here's a note to keep that in mind
    if ([segue.destinationViewController isKindOfClass:[AddContactViewController class]]) {
        AddContactViewController *destinationVC = segue.destinationViewController;
        destinationVC.fliqString = self.fliqString;
    }
    
}

#pragma mark - composeFliq
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
