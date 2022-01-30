//
//  PalyCtrlView.h
//  Yaka
//
//  Created by Enki on 2021/7/18.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CtrlType) {
    CtrlType_Play = 0,
    CtrlType_Pause = 1,
    CtrlType_Rewind = 2,
    CtrlType_FastForward = 3,
    CtrlType_SkipToStart = 4,
    CtrlType_SkipToEnd = 5,
    CtrlType_RecordStart = 6,
    CtrlType_RecordStop = 7,
};

typedef NS_ENUM(NSInteger, PlayControlState) {
    PlayControlState_Play = 0,
    PlayControlState_Stop = 1,
    PlayControlState_RecordStart = 2,
    PlayControlState_RecordStop = 3,
};

@class PalyCtrlView;

@protocol PalyCtrlViewDelegae <NSObject>

- (void)palyCtrlView:(PalyCtrlView*)palyCtrlView progressUpdated:(NSInteger)index;

- (void)palyCtrlView:(PalyCtrlView*)palyCtrlView fpsUpdated:(int)fps;

- (void)palyCtrlView:(PalyCtrlView*)palyCtrlView playStatusUpdated:(CtrlType)ctrlType;

@end

@interface PalyCtrlView : NSView

@property (weak) id<PalyCtrlViewDelegae> delegate;

@property (nonatomic, assign) PlayControlState playState;
@property (nonatomic, assign) BOOL isDragging;

@property (weak) IBOutlet NSButton *playButton;
@property (weak) IBOutlet NSSlider *progressSlider;

@property (weak) IBOutlet NSTextField *textCurFrameIndex;
@property (weak) IBOutlet NSTextField *textMaxFrameIndex;

@property (weak) IBOutlet NSTextField *textFps;
@property (weak) IBOutlet NSStepper *fpsStepper;

@end

NS_ASSUME_NONNULL_END
