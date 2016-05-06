//
//  FQLibrary.h
//  FQLibrary
//
//  Created by Orestis Lykouropoulos on 4/29/16.
//  Copyright © 2016 Orestis Lykouropoulos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface FQLibrary : NSObject

/*! Scans for nearby FliQ Devices and returns an of FQPeripheral objects
*/
- (NSArray *)fqScan;

/*! Exchanges a FliQ with selectedPeripheral
*/
- (void) sendFliq:(NSArray *)selectedPeripheral;

@end


