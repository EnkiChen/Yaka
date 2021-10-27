//
//  MainViewController.h
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GLVideoRenderView.h"
#import "SampleVideoRenderView.h"
#import "MTLNSVideoView.h"
#import "PalyCtrlView.h"

@interface MainViewController : NSViewController

@property (weak) IBOutlet GLVideoRenderView *glVideoView;
@property (weak) IBOutlet SampleVideoRenderView *sampleRenderView;
@property (weak) IBOutlet MTLNSVideoView *metalRenderView;
@property (weak) IBOutlet PalyCtrlView *palyCtrlView;

@end

