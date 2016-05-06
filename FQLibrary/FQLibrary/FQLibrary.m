//
//  FQLibrary.m
//  FQLibrary
//
//  Created by Orestis Lykouropoulos on 4/29/16.
//  Copyright © 2016 Orestis Lykouropoulos. All rights reserved.
//

#import "FQLibrary.h"

@implementation FQLibrary

- (NSArray *)fqScan
{
    NSLog(@"I'm scanning!");
    return [[NSArray alloc] init];
}

- (void)sendFliq:(NSArray *)selectedPeripheral
{
    NSLog(@"I'm sending a FliQ!");
}

@end
