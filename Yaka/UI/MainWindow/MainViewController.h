//
//  MainViewController.h
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PalyCtrlView.h"
#import "MultiPlayView.h"

@interface MainViewController : NSViewController

@property (weak) IBOutlet MultiPlayView *multiPlayView;
@property (weak) IBOutlet PalyCtrlView *palyCtrlView;

@end

