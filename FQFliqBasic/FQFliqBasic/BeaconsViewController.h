//
//  BeaconsViewController.h
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 5/6/16.
//  Copyright © 2016 Orestis Lykouropoulos. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <Firebase/Firebase.h>

@import CoreLocation;

@interface BeaconsViewController : UIViewController

@property (strong,nonatomic) NSMutableDictionary *rssiDict;
@property (strong, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

//------------------------------ CoreBluetooth properties ----------------------------------------

@property (strong) dispatch_queue_t bluetoothQueue;

//Central
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableSet *discoveredPeripherals;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;


//Peripheral
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;

@property (strong, nonatomic) NSMutableArray *fliqBeaconsArray;

//CL
@property (strong, nonatomic) CLLocationManager *locationManager;

@end
