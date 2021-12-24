//
//  PalyCtrlView.m
//  Yaka
//
//  Created by Enki on 2021/7/18.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "PalyCtrlView.h"

@interface PalyCtrlView ()<NSTextFieldDelegate>

@end

@implementation PalyCtrlView


- (void)setPlayState:(PlayControlState)playState {
    if (playState == PlayControlState_Play) {
        self.playButton.tag = CtrlType_Play;
        if (@available(macOS 10.12.2, *)) {
            [self.playButton setImage:[NSImage imageNamed:NSImageNameTouchBarPlayTemplate]];
        } else {
            // Fallback on earlier versions
        }
    } else if (playState == PlayControlState_Stop) {
        self.playButton.tag = CtrlType_Pause;
        if (@available(macOS 10.12.2, *)) {
            [self.playButton setImage:[NSImage imageNamed:NSImageNameTouchBarPauseTemplate]];
        } else {
            // Fallback on earlier versions
        }
    } else if (playState == PlayControlState_RecordStart) {
        self.playButton.tag = CtrlType_RecordStart;
        if (@available(macOS 10.12.2, *)) {
            [self.playButton setImage:[NSImage imageNamed:NSImageNameTouchBarRecordStartTemplate]];
        } else {
            // Fallback on earlier versions
        }
    } else if (playState == PlayControlState_RecordStop) {
        self.playButton.tag = CtrlType_RecordStop;
        if (@available(macOS 10.12.2, *)) {
            [self.playButton setImage:[NSImage imageNamed:NSImageNameTouchBarRecordStopTemplate]];
        } else {
            // Fallback on earlier versions
        }
    }
}
- (PlayControlState)playState {
    if (self.playButton.tag == CtrlType_Play) {
        return PlayControlState_Play;
    } else {
        return PlayControlState_Stop;
    }
}

- (IBAction)onSliderValueChanged:(id)sender {
    NSEvent *event = [[NSApplication sharedApplication] currentEvent];
    if (event.type == NSEventTypeLeftMouseDown) {
        self.isDragging = YES;
    }
    
    NSSlider *slider = sender;
    if (self.delegate != nil) {
        [self.delegate palyCtrlView:self progressUpdated:[slider integerValue]];
    }
    
    if (event.type == NSEventTypeLeftMouseUp) {
        self.isDragging = NO;
    }
}

- (IBAction)onPlayStateChanged:(NSButton *)sender {
    CtrlType type = (CtrlType)sender.tag;
    if (self.delegate != nil) {
        [self.delegate palyCtrlView:self playStatusUpdated:type];
    }
}

- (IBAction)onFormatComboboxChanged:(id)sender {
    NSComboBox *formatCombobox = sender;
    if (self.delegate != nil) {
        [self.delegate palyCtrlView:self formatUpdated:formatCombobox.indexOfSelectedItem];
    }
}

- (IBAction)onFpsStepperChanged:(id)sender {
    [self.textFps setStringValue:[sender stringValue]];
    if (self.delegate != nil) {
        [self.delegate palyCtrlView:self fpsUpdated:[sender intValue]];
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    [self.fpsStepper setIntValue:self.textFps.intValue];
    if (self.delegate != nil) {
        [self.delegate palyCtrlView:self fpsUpdated:self.textFps.intValue];
    }
}

@end
