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
//      NSUUID *fliqBeaconUUID = [[NSUUID alloc] initWithUUIDString:@"FDA50693-A4E2-4FB1-AFCF-C6EB07647825"];
        NSUUID *fliqBeaconUUID = [[NSUUID alloc] initWithUUIDString:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"];
        
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:fliqBeaconUUID
                                                                          identifier:@"ranged region"];
        
        [self.locationManager startRangingBeaconsInRegion:beaconRegion];

    }

}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    NSLog(@"Authorization status change callback");
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        NSLog(@"Location services authorized");
        
//        NSUUID *fliqBeaconUUID = [[NSUUID alloc] initWithUUIDString:@"FDA50693-A4E2-4FB1-AFCF-C6EB07647825"];
        NSUUID *fliqBeaconUUID = [[NSUUID alloc] initWithUUIDString:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"];
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:fliqBeaconUUID
                                                                          identifier:@"ranged region"];
        
        [self.locationManager startRangingBeaconsInRegion:beaconRegion];

    } else if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        NSLog(@"Location services authorization denied");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)displayWebView {
    
    //Get closest beacon with nonnegative accuracy
    [self sortBeaconArray];
    NSEnumerator *e = [self.fliqBeaconsArray objectEnumerator];
    
    CLBeacon *closestBeacon = [e nextObject];
    while (closestBeacon.accuracy < 0) {
        if ((closestBeacon = [e nextObject]) == nil) {
            NSLog(@"Unable to find beacon with nonnegative accuracy value – exiting displayWebView.");
            return;
        }
    }
    
    // Construct firebase request URL using closest beacon's major/minor values
    NSString *beaconURL = [NSString stringWithFormat:@"https://fliq.firebaseio.com/%@/%@", closestBeacon.major.stringValue, closestBeacon.minor.stringValue];
    
    NSLog(@"Beacon URL: %@", beaconURL);
    
    // Create a reference to a Firebase database URL
    Firebase *firebaseRef = [[Firebase alloc] initWithUrl:beaconURL];
    
    [firebaseRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        if (snapshot.value == [NSNull null]) {
            NSLog(@"Snapshot value was null – exiting displayWebView.");
            return;
        } else {
            NSLog(@"Retrieved data from Firebase – key: %@; value: %@", snapshot.key, snapshot.value);
        }
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:snapshot.value]];
        
        self.webView.scalesPageToFit = YES;
        
        NSLog(@"Loading request");
        [self.webView loadRequest:request];
        self.activityIndicator.hidden = YES;
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
    self.fliqBeaconsArray = beacons;
    NSLog(@"BEACONS ARRAY: %@", beacons);
    [self displayWebView];
}


- (IBAction)backBtnPressed:(id)sender {
    [self performSegueWithIdentifier:@"segueToScanVC" sender:self];
}
@end
