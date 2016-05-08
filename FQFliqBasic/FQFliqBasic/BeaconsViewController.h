//
//  BeaconsViewController.h
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 5/6/16.
//  Copyright © 2016 Orestis Lykouropoulos. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>


@interface BeaconsViewController : UIViewController

@property (strong,nonatomic) NSMutableDictionary *rssiDict;
@property (strong, nonatomic) IBOutlet UIImageView *displayImage;

//------------------------------ CoreBluetooth properties ----------------------------------------

@property (strong) dispatch_queue_t bluetoothQueue;

//Central
@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableSet *discoveredPeripherals;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;


//Peripheral
@property (strong, nonatomic) CBPeripheralManager *peripheralManager;

@property (strong, nonatomic) NSMutableArray *fliqBeaconsArray;

@end
