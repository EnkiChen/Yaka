//
//  VideoCapture.m
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "CameraCapture.h"
#import "PixelBufferTools.h"

@interface CameraCapture() <AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic, strong) AVCaptureSession* captureSession;

@end

@implementation CameraCapture

@synthesize delegate;

+ (NSArray<AVCaptureDevice *> *)allCameraCapture {
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
}

- (void)start {
    if ( self.captureSession == nil ) {
        [self setup];
    }
    
    if ( !self.captureSession.isRunning ) {
        [self.captureSession startRunning];
    }
}

- (void)stop {
    if ( self.captureSession.isRunning ) {
        [self.captureSession stopRunning];
    }
}

- (BOOL)isRunning {
    return self.captureSession.isRunning;
}

- (void)addPreview:(AVCaptureVideoPreviewLayer*) previewLayer {
    if ( previewLayer != nil && self.captureSession ) {
        [previewLayer setSession:self.captureSession];
    }
}

- (void)removePreview:(AVCaptureVideoPreviewLayer*) previewLayer {
    if ( previewLayer != nil && self.captureSession ) {
        [previewLayer setSession:nil];
    }
}

- (void)setCaptureDevice:(AVCaptureDevice *)captureDevice {
    if ( _captureDevice == captureDevice ) {
        return;
    }
    
    _captureDevice = captureDevice;
    [self.captureSession beginConfiguration];
    NSArray* currentInputs = [self.captureSession inputs];
    for (int i = 0; i < currentInputs.count; i++) {
        AVCaptureInput* currentInput = (AVCaptureInput*)[currentInputs objectAtIndex:i];
        [self.captureSession removeInput:currentInput];
    }
    
    if (self.captureDevice == nil ) {
        self.captureDevice =  [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    AVCaptureDeviceInput* captureInput = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice
                                                                               error:nil];
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    [self.captureSession commitConfiguration];
}

- (void)setup {
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession beginConfiguration];
    
    AVCaptureVideoDataOutput* captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    
    [captureOutput setVideoSettings:videoSettings];
    [captureOutput setSampleBufferDelegate:self
                                     queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    if ([self.captureSession canAddOutput:captureOutput]) {
        [self.captureSession addOutput:captureOutput];
    }
    
    NSArray* currentInputs = [self.captureSession inputs];
    if ([currentInputs count] > 0) {
        AVCaptureInput* currentInput = (AVCaptureInput*)[currentInputs objectAtIndex:0];
        [self.captureSession removeInput:currentInput];
    }
    
    NSError* deviceError = nil;
    if (self.captureDevice == nil ) {
        self.captureDevice =  [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    AVCaptureDeviceInput* captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice
                                                                               error:&deviceError];
    
    if ([self.captureSession canAddInput:captureInput]) {
        [self.captureSession addInput:captureInput];
    }
    
    [self.captureSession commitConfiguration];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:imageBuffer rotation:VideoRotation_0];
    videoFrame.pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (self.delegate) {
        [self.delegate captureSource:self onFrame:videoFrame];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
}

@end
