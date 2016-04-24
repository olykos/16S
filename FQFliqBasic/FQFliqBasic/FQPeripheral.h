//
//  FQPeripheral.h
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 5/6/15.
//  Copyright (c) 2015 Orestis Lykouropoulos. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FQPeripheral : NSObject

@property (strong, nonatomic) NSString *firstName;
@property (strong, nonatomic) NSString *fliqUUID;
@property (strong, nonatomic) UIImage *scanProfilePic;
@property (strong, nonatomic) NSNumber *RSSI;

/* Custom Initializer which has a single parameter of class NSDictionary. */
-(id)initWithData:(NSDictionary *)data;

@end
