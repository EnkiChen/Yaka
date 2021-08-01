//
//  DesktopCapture.m
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "DesktopCapture.h"

@implementation DirectDisplay

@end

@interface DesktopCapture() <AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, strong) AVCaptureSession* captureSession;

@end

@implementation DesktopCapture

@synthesize delegate;

+ (NSArray<DirectDisplay*>*)allDirectDisplay {
    uint32_t count = 0;
    CGDirectDisplayID displayIDs[10] = {0};
    CGGetOnlineDisplayList(10, displayIDs, &count);
    NSMutableArray *directDisplays = [[NSMutableArray alloc] initWithCapacity:count];
    for (int i = 0; i < count; i++) {
        DirectDisplay *directDisplay = [[DirectDisplay alloc] init];
        directDisplay.displayId = displayIDs[i];
        directDisplay.bounds = CGDisplayBounds(displayIDs[i]);
        [directDisplays addObject:directDisplay];
    }
    return directDisplays;
}

-(void)start {
    if ( self.captureSession == nil ) {
        [self setup];
    }
    
    if ( !self.captureSession.isRunning ) {
        [self.captureSession startRunning];
    }
}

-(void)stop {
    if ( self.captureSession.isRunning ) {
        [self.captureSession stopRunning];
    }
}

-(BOOL)isRunning {
    return self.captureSession.isRunning;
}

- (void)setDirectDisplay:(DirectDisplay *)directDisplay {
    if (_directDisplay != nil && _directDisplay != directDisplay && _directDisplay.displayId != directDisplay.displayId) {
        CGDirectDisplayID displayId = directDisplay.displayId;
        NSArray* currentInputs = [self.captureSession inputs];
        if ([currentInputs count] > 0) {
            AVCaptureInput* currentInput = (AVCaptureInput*)[currentInputs objectAtIndex:0];
            [self.captureSession removeInput:currentInput];
        }
        AVCaptureScreenInput* newCaptureInput = [[AVCaptureScreenInput alloc] initWithDisplayID:displayId];
        newCaptureInput.minFrameDuration = CMTimeMake(1, 15);
        [self.captureSession beginConfiguration];
        BOOL addedCaptureInput = NO;
        if ([self.captureSession canAddInput:newCaptureInput]) {
            [self.captureSession addInput:newCaptureInput];
            addedCaptureInput = YES;
        } else {
            addedCaptureInput = NO;
        }
        [self.captureSession commitConfiguration];
    }
    _directDisplay = directDisplay;
}

- (void)setup {
    
    if ( self.captureSession ) {
        return;
    }
    
    self.captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureVideoDataOutput* captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    
    captureOutput.videoSettings = videoSettings;
    
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    [captureOutput setSampleBufferDelegate:self
                                     queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    NSArray* currentInputs = [self.captureSession inputs];

    if ([currentInputs count] > 0) {
        AVCaptureInput* currentInput = (AVCaptureInput*)[currentInputs objectAtIndex:0];
        [self.captureSession removeInput:currentInput];
    }
    
    CGDirectDisplayID displayId = CGMainDisplayID();
    if (self.directDisplay != nil) {
        displayId = self.directDisplay.displayId;
    }
    
    AVCaptureScreenInput* newCaptureInput = [[AVCaptureScreenInput alloc] initWithDisplayID:displayId];
    
    newCaptureInput.minFrameDuration = CMTimeMake(1, 15);
    
    [self.captureSession beginConfiguration];
    
    BOOL addedCaptureInput = NO;
    if ([self.captureSession canAddInput:newCaptureInput]) {
        [self.captureSession addInput:newCaptureInput];
        addedCaptureInput = YES;
    } else {
        addedCaptureInput = NO;
    }
    
    [self.captureSession commitConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:imageBuffer rotation:VideoRotation_0];
    
    if (self.delegate) {
        [self.delegate captureSource:self onFrame:videoFrame];
    }
    
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
}

@end
