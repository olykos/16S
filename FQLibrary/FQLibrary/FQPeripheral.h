//
//  FQPeripheral.h
//  FliQApp
//
//  Created by C74 on 28/05/15.
//  Copyright (c) 2015 c107. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FQPeripheral : NSObject

@property (strong, nonatomic) NSString *firstName;
@property (strong, nonatomic) NSString *fliqUUID;
@property (strong, nonatomic) UIImage *scanProfilePic;
@property (strong, nonatomic) NSNumber *RSSI;

@property (strong, nonatomic) NSMutableDictionary *sharedInformation;

/* Custom Initializer which has a single parameter of class NSDictionary. */
-(id)initWithData:(NSDictionary *)data;

@end
