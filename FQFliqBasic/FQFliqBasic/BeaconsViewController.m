//
//  BeaconsViewController.m
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 5/6/16.
//  Copyright © 2016 Orestis Lykouropoulos. All rights reserved.
//

#import "BeaconsViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <Firebase/Firebase.h>
#import "UserValues.h"
@import CoreLocation;

@interface BeaconsViewController () <CLLocationManagerDelegate>

- (IBAction)backBtnPressed:(id)sender;

@end

@implementation BeaconsViewController 

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //CL setup
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    
    if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        NSLog(@"This app is not authorized to use Location Services. Aborting Beacon mode.");
        return;
    }
    
    if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
        
    }
    
    if ([CLLocationManager isRangingAvailable] == NO) {
        NSLog(@"This device does not support Bluetooth ranging. Aborting Beacon mode.");
        return;
    }
    
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        NSUUID *fliqBeaconUUID = [[NSUUID alloc] initWithUUIDString:@"FDA50693-A4E2-4FB1-AFCF-C6EB07647825"];
        
        
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:fliqBeaconUUID
                                                                          identifier:@"ranged region"];
        
        [self.locationManager startRangingBeaconsInRegion:beaconRegion];

    }

}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    NSLog(@"Callback");
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        NSLog(@"Authorized");
        
        NSUUID *fliqBeaconUUID = [[NSUUID alloc] initWithUUIDString:@"FDA50693-A4E2-4FB1-AFCF-C6EB07647825"];
        
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:fliqBeaconUUID
                                                                          identifier:@"ranged region"];
        
        [self.locationManager startRangingBeaconsInRegion:beaconRegion];

    } else if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        NSLog(@"Denied");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)displayWebView {
    NSLog(@"Stopping beacon scan...");
    [self.centralManager stopScan];
    
    [self sortBeaconArray];
    NSLog(@"%@", self.fliqBeaconsArray);
    
    /*Parse beacons array to get ID of closest beacon
    //CBPeripheral *closestBeacon = [self.fliqBeaconsArray objectAtIndex:0];
    NSString *beacon_ID = closestBeacon.name;*/
    
    //Get closest beacon with nonnegative accuracy
    NSEnumerator *e = [self.fliqBeaconsArray objectEnumerator];
    CLBeacon *closestBeacon;
    while(closestBeacon = [e nextObject]){
        if(closestBeacon.accuracy > 0){
            return;
        }
    }
    /*
    if ([beacon_ID hasPrefix:@"AprilBeacon_"])
        beacon_ID = [beacon_ID substringFromIndex:[@"AprilBeacon_" length]];
    
    NSString *beaconURL = @"https://fliq.firebaseio.com/";
    beaconURL = [beaconURL stringByAppendingString:beacon_ID];


    NSLog(@"Beacon URL: %@", beacon_URL);
    
    // Create a reference to a Firebase database URL
    Firebase *firebaseRef = [[Firebase alloc] initWithUrl:beacon_URL];
    
    [firebaseRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
       
        if (snapshot.value == [NSNull null]) {
            NSLog(@"was null");
            return;
        } else {
            NSLog(@"Retrieved data from Firebase – key: %@    %@", snapshot.key, snapshot.value);
        }

        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:snapshot.value]];
        
        self.webView.scalesPageToFit = YES;
        
        NSLog(@"Loading request");
        [self.webView loadRequest:request];
        self.activityIndicator.hidden = YES;
    }];*/
}

//Sorts the fliq beacons array by accuracy
-(void)sortBeaconArray{
    [self.fliqBeaconsArray sortedArrayUsingComparator:^NSComparisonResult(CLBeacon *beacon1, CLBeacon*beacon2){
        return [[NSNumber numberWithDouble:beacon1.accuracy] compare:[NSNumber numberWithDouble:beacon2.accuracy]];
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


- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(CLBeaconRegion *)region
{
    NSLog(@"BEACONS ARRAY: %@", beacons);
}





- (IBAction)backBtnPressed:(id)sender {
    [self performSegueWithIdentifier:@"segueToScanVC" sender:self];
}
@end
