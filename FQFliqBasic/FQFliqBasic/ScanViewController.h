//
//  ScanViewController.h
//  FQFliqBasic
//
//  Created by Orestis Lykouropoulos on 4/1/15.
//  Copyright (c) 2015 Orestis Lykouropoulos. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ScanViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) NSMutableArray *fliqPeripherals;

@end
