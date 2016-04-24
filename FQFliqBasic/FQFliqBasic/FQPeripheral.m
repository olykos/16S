//
//  FQPeripheral.m
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 5/6/15.
//  Copyright (c) 2015 Orestis Lykouropoulos. All rights reserved.
//

#import "FQPeripheral.h"
#import "UserValues.h"

@implementation FQPeripheral

/* Designated Initializer */
-(id)initWithData:(NSDictionary *)data
{
    /* Designated Initializer must call the super classes initialization method */
    self = [super init];
    
    /* Setup the object with values from the NSDictionary */
    if (self){
        self.firstName = data[DICT_PERIPHERAL_INITIALS];
        self.fliqUUID = data[DICT_PERIPHERAL_FQ_UUID];
        NSData *dataFromBase64String = [[NSData alloc] initWithBase64EncodedString:data[DICT_PERIPHERAL_SCAN_PROFILE_PIC] options:0];
        self.scanProfilePic = [UIImage imageWithData:dataFromBase64String];
        
        self.RSSI = data[DICT_PERIPHERAL_RSSI];
    }
    
    return self;
}

/* Default initializer calls the new designated initializer initWithData */
-(id)init
{
    self = [self initWithData:nil];
    return self;
}



@end
