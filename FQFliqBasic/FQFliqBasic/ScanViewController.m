//
//  ScanViewController.m
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 4/1/15.
//  Copyright (c) 2015 Orestis Lykouropoulos. All rights reserved.
//

#import "ScanViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "UserValues.h"
#import "PeripheralViewController.h"
#import "CentralViewController.h"
#import "FQPeripheral.h"


@interface ScanViewController () <CBCentralManagerDelegate, CBPeripheralManagerDelegate, CBPeripheralDelegate>


#define NOTIFY_MTU      20 //maximum number of bytes per BTLE message chunk

//actions
- (IBAction)nextButtonPressed:(UIButton *)sender;
- (IBAction)scanButtonPressed:(UIButton *)sender;

//------------------------------- TableView properties ---------------------------------------------
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableArray *discoveredPeripheralsArray;

//------------------------------- General properties --------------------------------------------
@property (strong, nonatomic) NSString *selectedUUID;
@property (strong, nonatomic) NSString *scanInfo; //string with name,picture and fliqid
@property (strong,nonatomic) NSMutableDictionary *rssiDict;
@property (strong, nonatomic) NSMutableData *fliqDataToSend;
@property (nonatomic, readwrite) NSInteger fliqDataIndex;

//------------------------------ CoreBluetooth properties ----------------------------------------

@property (strong) dispatch_queue_t bluetoothQueue;

//Central
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) NSString *receivedString;
@property (strong, nonatomic) NSMutableData *receivedFliqData;

//Peripheral
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic *scanCharacteristic;


@end

@implementation ScanViewController

@synthesize fliqPeripherals;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.fliqPeripherals =[[NSMutableArray alloc] init];
    self.rssiDict = [[NSMutableDictionary alloc] init];
    
    /* Set the tableView's datasource and delegate properties to self so that the UITableViewControllerDelegate and UITableViewControllerDataSource know to pass message to this instance of the viewController. */
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    self.bluetoothQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0); //experiment with priority maybe

    //allocate a peripheral manager - does not begin advertising, but is needed in case advertise button is pressed
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:self.bluetoothQueue];
    
    self.selectedUUID = nil;
    
    //------- fill all information to send and create data package ----
    
    // fill imageData with contents of the image data
    NSString *path = [[NSBundle mainBundle] pathForResource:@"2" ofType:@"jpg"];
    NSData *imageData = [NSData dataWithContentsOfFile:path];
    // base64 encode the binary data into a string format
    NSString *imageBase64String = [imageData base64EncodedStringWithOptions:0]; // iOS 7+
    
    NSArray *array = @[@"Orestis", FQ_PERSONAL_UUID, imageBase64String];
    self.scanInfo = [array componentsJoinedByString:@"*"];
    
    self.fliqDataToSend = [[self.scanInfo dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
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


- (IBAction)scanButtonPressed:(UIButton *)sender {
    //stop whichever manager is on if any
    [self.centralManager stopScan];
    [self.peripheralManager stopAdvertising];
    [self.discoveredPeripheralsArray removeAllObjects];
    [self.tableView reloadData];
    
    self.selectedUUID = nil;
    
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.bluetoothQueue options:nil];
    self.receivedFliqData = [[NSMutableData alloc] init];
    
    [self.peripheralManager stopAdvertising]; //reset in case we are
    [self.peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:FQ_SCAN_UUID]] }];

    //first scan for 3 seconds and get UUIDs of peripherals around
    //empty all relevant lists etc
    [self.fliqPeripherals removeAllObjects];
    [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(stopFirstScan) userInfo:nil repeats:NO];
}

- (void)stopFirstScan {
    NSLog(@"Stopping first scan...");
    [self connectToFliqPeriperhals];
    [self.centralManager stopScan];
}

-(void) connectToFliqPeriperhals
{
    if ([self.fliqPeripherals count] == 0) {
        return;
    } else {
        CBPeripheral *p = [self.fliqPeripherals lastObject];
        [self.fliqPeripherals removeLastObject];
        NSLog(@"Connecting to %@",p);
        self.discoveredPeripheral = p;
        [self.centralManager connectPeripheral:self.discoveredPeripheral options:nil];
    }
}

#pragma mark ----------------------------- CB Central methods ----------------------------------------------

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"Central State Powered ON");
        // Scan for devices
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:FQ_SCAN_UUID]] options:nil]; //Apple's sample code allows for duplicates for some reason - just a note idk why
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
        // Reject any where the value is above reasonable range
        if (RSSI.integerValue > -15) {
            return;
        }
//    
//        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
//        if (RSSI.integerValue < -70) {
//            return;
//        }
    
    
    if(![self.fliqPeripherals containsObject:peripheral])
        [self.fliqPeripherals addObject:peripheral];
        [self.rssiDict setObject:RSSI forKey:peripheral.identifier];
    NSLog(@"LIST OF PERIPHERALS FIRST ROUND: %@", self.fliqPeripherals);
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
    
    //Stop scanning to save battery power
    [self.centralManager stopScan];
    NSLog(@"Scanning stopped");
    
    peripheral.delegate = self;
    [self.receivedFliqData setLength:0];
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:FQ_SCAN_UUID]]];
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
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:FQ_USER_INITIALS_UUID]] forService:service];
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
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_USER_INITIALS_UUID]]) {
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
        
        NSLog(@"received EOM scan\n\n\n");
        NSString *receivedString = [[NSString alloc] initWithData:self.receivedFliqData encoding:NSUTF8StringEncoding];
        
        self.receivedString = receivedString;
        
        //remember scanned info in temporary dictionary used for table view
        NSMutableDictionary *peripheralInfo = [[NSMutableDictionary alloc] init];
        [peripheralInfo setObject:[self.receivedString componentsSeparatedByString:@"*"][0] forKey:DICT_PERIPHERAL_INITIALS];
        [peripheralInfo setObject:[self.receivedString componentsSeparatedByString:@"*"][1] forKey:DICT_PERIPHERAL_FQ_UUID]; //change that soon
        [peripheralInfo setObject:[self.receivedString componentsSeparatedByString:@"*"][2] forKey:DICT_PERIPHERAL_SCAN_PROFILE_PIC]; //change that soon
        [peripheralInfo setObject:[self.rssiDict objectForKey:peripheral.identifier] forKey:DICT_PERIPHERAL_RSSI];
        
        //create FQPeripheral object, used for table view
        FQPeripheral *discoveredPeripheral = [[FQPeripheral alloc] initWithData:peripheralInfo];
        [self.discoveredPeripheralsArray addObject:discoveredPeripheral];
        
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"RSSI"
                                                                       ascending:NO];
        NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
        self.discoveredPeripheralsArray = [[self.discoveredPeripheralsArray sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
        
//        [self.tableView reloadData]; //is this really working?
        dispatch_async(dispatch_get_main_queue(), ^ {
            [self.tableView reloadData];
        });
        
        [peripheral setNotifyValue:NO forCharacteristic:characteristic];
//        [self cleanup];
        [self connectToFliqPeriperhals];
        
//        restart process to scan for other peripherals
//        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:FQ_SCAN_UUID]] options:nil];
//        NSLog(@"Restarted scan after EOM");
        
        //        [self performSegueWithIdentifier:@"scanToMainVCSegue" sender:self];
        
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
        
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:FQ_SCAN_UUID] primary:YES];
        
        self.scanCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:FQ_USER_INITIALS_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
        transferService.characteristics = @[self.scanCharacteristic];
        
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
        BOOL didSend = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.scanCharacteristic onSubscribedCentrals:nil];
        
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
    
    // There's data left, so send until the     fails, or we're done.
    BOOL didSend = YES;
    
    while (didSend) {
        // Work out how big it should be
        NSInteger amountToSend = self.fliqDataToSend.length - self.fliqDataIndex;
        
        // Can't be longer than 20 bytes
        if (amountToSend > NOTIFY_MTU) amountToSend = NOTIFY_MTU;
        
        // Copy out the data we want
        NSData *chunk = [NSData dataWithBytes:self.fliqDataToSend.bytes+self.fliqDataIndex length:amountToSend];
        
        didSend = [self.peripheralManager updateValue:chunk forCharacteristic:self.scanCharacteristic onSubscribedCentrals:nil];
        
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
            
            BOOL eomSent = [self.peripheralManager updateValue:[@"EOM" dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.scanCharacteristic onSubscribedCentrals:nil];
            
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

#pragma mark - segue methods
- (IBAction)nextButtonPressed:(UIButton *)sender {
    
    if(self.selectedUUID == nil){
        [self performSegueWithIdentifier:@"scanToPeripheralVCSegue" sender:self];
    } else {
        [self performSegueWithIdentifier:@"scanToCentralVCSegue" sender:self];
    }
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[PeripheralViewController class]]) {
        //PeripheralViewController *destinationVC = segue.destinationViewController;
        //do stuff later maybe;
    }
    
    if ([segue.destinationViewController isKindOfClass:[CentralViewController class]]) {
        CentralViewController *destinationVC = segue.destinationViewController;
        destinationVC.fliqRecipientUUID = self.selectedUUID;
    }
    
}

#pragma mark - Table view methods

/* Lazy instantation in the discoveredPeripheralsArray getter.*/
-(NSMutableArray *)discoveredPeripheralsArray
{
    if (!_discoveredPeripheralsArray){
        _discoveredPeripheralsArray = [[NSMutableArray alloc] init];
    }
    return _discoveredPeripheralsArray;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.discoveredPeripheralsArray count]; //will change
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    
    // Configure the cell...
    if(indexPath.row < [self.discoveredPeripheralsArray count]) {
        FQPeripheral *peripheral = self.discoveredPeripheralsArray[indexPath.row];
        cell.textLabel.text = peripheral.firstName;
        cell.imageView.image = peripheral.scanProfilePic;
    }
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    FQPeripheral *selectedPeripheral = self.discoveredPeripheralsArray[indexPath.row];
    self.selectedUUID = selectedPeripheral.fliqUUID;
    NSLog(@"Selected:%@:<%@>", selectedPeripheral.firstName, self.selectedUUID);
}






@end
