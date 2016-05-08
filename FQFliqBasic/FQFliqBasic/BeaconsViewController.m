//
//  BeaconsViewController.m
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 5/6/16.
//  Copyright © 2016 Orestis Lykouropoulos. All rights reserved.
//

#import "BeaconsViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#import "UserValues.h"

@interface BeaconsViewController () <CBCentralManagerDelegate>

- (IBAction)backBtnPressed:(id)sender;

@end

@implementation BeaconsViewController 

- (void)viewDidLoad {
    [super viewDidLoad];
    //Do any additional setup after loading the view.
    self.rssiDict = [[NSMutableDictionary alloc] init];
    [self.activityIndicator startAnimating];
    // Do any additional setup after loading the view.
    
    
    [self.fliqBeaconsArray removeAllObjects];
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.bluetoothQueue options:nil];
    self.fliqBeaconsArray = [[NSMutableArray alloc] init];
    
    [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(displayWebView) userInfo:nil repeats:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)displayWebView {
    NSLog(@"Stopping beacon scan...");
    [self.centralManager stopScan];
    [self sortPeripheralArray];
    NSLog(@"%@", self.fliqBeaconsArray);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://openmerchantaccount.com/img2/NMFimg.jpg"]];
    self.webView.scalesPageToFit = YES;
    
    NSLog(@"Loading request");
    [self.webView loadRequest:request];
    self.activityIndicator.hidden = YES;
    
    
}

//Sorts the fliq beacons array by rssi
-(void)sortPeripheralArray{
    [self.fliqBeaconsArray sortedArrayUsingComparator:^NSComparisonResult(CBPeripheral *peripheral1, CBPeripheral *peripheral2){
        NSNumber *rssi1 = [self.rssiDict valueForKey:[peripheral1.identifier UUIDString]];
        NSNumber *rssi2 = [self.rssiDict valueForKey:[peripheral2.identifier UUIDString]];
        return [rssi1 compare:rssi2];
    }];
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

#pragma mark ----------------------------- CB Central methods ----------------------------------------------

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    
    if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"Central State Powered ON");
        // Scan for device]
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
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
    
    
    if(![self.fliqBeaconsArray containsObject:peripheral])
        if ([peripheral.name hasPrefix:@"AprilBeacon_"]){
            [self.fliqBeaconsArray addObject:peripheral];
            [self.rssiDict setObject:RSSI forKey:peripheral.identifier];
        }
    NSLog(@"LIST OF PERIPHERALS FIRST ROUND: %@", self.fliqBeaconsArray);
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
    //not needed
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
        //        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:FQ_USER_INITIALS_UUID]] forService:service];
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
        //        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_USER_INITIALS_UUID]]) {
        //            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        //            NSLog(@"Subscribed to characteristic %@", characteristic);
        //        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
   //not needed
    
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
    self.discoveredPeripheral = nil;
    
}


#pragma mark - cleanup
//below code provided by Apple sample
/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanup
{
    //    // Don't do anything if we're not connected
    //    if (self.discoveredPeripheral.state == CBPeripheralStateDisconnected) {
    //        return;
    //    }
    //
    //    // See if we are subscribed to a characteristic on the peripheral
    //    if (self.discoveredPeripheral.services != nil) {
    //        for (CBService *service in self.discoveredPeripheral.services) {
    //            if (service.characteristics != nil) {
    //                for (CBCharacteristic *characteristic in service.characteristics) {
    //                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:FQ_CHARACTERISTIC_UUID]]) {
    //                        if (characteristic.isNotifying) {
    //                            // It is notifying, so unsubscribe
    //                            [self.discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
    //
    //                            // And we're done.
    //                            NSLog(@"cleaned succesfully");
    //                            return;
    //                        }
    //                    }
    //                }
    //            }
    //        }
    //    }
    //    
    //    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    //    [self.centralManager cancelPeripheralConnection:self.discoveredPeripheral];
}


- (IBAction)backBtnPressed:(id)sender {
    [self performSegueWithIdentifier:@"segueToScanVC" sender:self];
}
@end
