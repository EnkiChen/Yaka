//
//  SampleRenderView.m
//  Yaka
//
//  Created by Enki on 2019/3/4.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "SampleVideoRenderView.h"
#import <AVFoundation/AVFoundation.h>

@interface SampleVideoRenderView ()

@property(nonatomic, strong) AVSampleBufferDisplayLayer *displayLayer;

@end

@implementation SampleVideoRenderView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if ( self ) {
        self.displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
        self.displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        self.displayLayer.opaque = YES;
        self.layer = self.displayLayer;
        self.displayLayer.backgroundColor = [NSColor blackColor].CGColor;
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self.displayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    self.displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.displayLayer.opaque = YES;
    self.layer = self.displayLayer;
    self.displayLayer.backgroundColor = [NSColor blackColor].CGColor;
}

- (void)renderFrame:(nullable VideoFrame *)frame {
    if ([frame.buffer isKindOfClass:CVPixelBuffer.class]) {
        CVPixelBuffer *pixelBuffer = (CVPixelBuffer*)frame.buffer;
        [self dispatchPixelBuffer:pixelBuffer.pixelBuffer];
        return;
    }
    
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
    CVPixelBufferCreate(kCFAllocatorDefault,
                        frame.width, frame.height,
                        kCVPixelFormatType_420YpCbCr8Planar,
                        (__bridge CFDictionaryRef)pixelAttributes,
                        &pixelBuffer);
    
    id<I420Buffer> buffer = [frame.buffer toI420];
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    uint8_t* y_src = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    size_t y_stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t y_width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    size_t y_height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    for ( int i = 0; i < y_height; i++ ) {
        memcpy(y_src + y_stride * i, buffer.dataY + buffer.strideY * i, y_width);
    }
    
    uint8_t *u_src = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    size_t u_stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    size_t u_width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
    size_t u_height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    for ( int i = 0; i < u_height; i++ ) {
        memcpy(u_src + u_stride * i, buffer.dataU + buffer.strideU * i, u_width);
    }
    
    uint8_t *v_src = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2);
    size_t v_stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 2);
    size_t v_width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 2);
    size_t v_height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 2);
    for ( int i = 0; i < v_height; i++ ) {
        memcpy(v_src + v_stride * i, buffer.dataV + buffer.strideV * i, v_width);
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    [self dispatchPixelBuffer:pixelBuffer];
    CFRelease(pixelBuffer);
}

- (void)enableMirror:(BOOL) enableMirror {
    
}

- (void)dispatchPixelBuffer:(CVImageBufferRef) pixelBuffer
{
    if (!pixelBuffer){
        return;
    }
    
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};

    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    
    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(videoInfo);
    
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    [self enqueueSampleBuffer:sampleBuffer toLayer:self.displayLayer];
    CFRelease(sampleBuffer);
}

- (void)enqueueSampleBuffer:(CMSampleBufferRef) sampleBuffer toLayer:(AVSampleBufferDisplayLayer*) layer
{
    if (sampleBuffer) {
        CFRetain(sampleBuffer);
        [layer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
        if (layer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            NSLog(@"ERROR: %@", layer.error);
        }
    }
}

@end
