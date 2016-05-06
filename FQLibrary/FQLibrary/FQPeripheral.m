//
//  FQPeripheral.m
//  FliQApp
//
//  Created by C74 on 28/05/15.
//  Copyright (c) 2015 c107. All rights reserved.
//

#import "FQPeripheral.h"
#import "UserValues.h"

@implementation FQPeripheral

@synthesize firstName;
@synthesize scanProfilePic;
@synthesize fliqUUID;
@synthesize RSSI;

@synthesize sharedInformation;

/* Designated Initializer */
-(id)initWithData:(NSDictionary *)data
{
    /* Designated Initializer must call the super classes initialization method */
    self = [super init];
    
    /* Setup the object with values from the NSDictionary */
    if (self){
        self.firstName = data[DICT_PERIPHERAL_INITIALS];
        self.fliqUUID = data[DICT_PERIPHERAL_FQ_UUID];
        if (data[DICT_PERIPHERAL_SCAN_PROFILE_PIC])
        {
            NSData *dataFromBase64String = [[NSData alloc] initWithBase64EncodedString:data[DICT_PERIPHERAL_SCAN_PROFILE_PIC] options:0];
            self.scanProfilePic = [UIImage imageWithData:dataFromBase64String];
        }
       else
           self.scanProfilePic = [UIImage imageNamed:@"user"];
        if (data[DICT_PERIPHERAL_RSSI]) {
            self.RSSI = data[DICT_PERIPHERAL_RSSI];
        }
    }
    
    return self;
}

@end
