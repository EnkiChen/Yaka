//
//  VT264Decoder.m
//  Yaka
//
//  Created by Enki on 2019/8/31.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "VT264Decoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import "H264Common.h"

namespace {

struct DecodeCallbackParams {
    OSStatus status;
    VTDecodeInfoFlags infoFlags;
    CVImageBufferRef pixelBuffer;
    CMTime presentationTimeStamp;
    CMTime presentationDuration;
};

}

@interface VT264Decoder()

@property(nonatomic, assign) CMVideoFormatDescriptionRef videoFormatDescription;
@property(nonatomic, assign) VTDecompressionSessionRef decoderSession;

@property(nonatomic, strong) NSMutableData *sps;
@property(nonatomic, strong) NSMutableData *pps;

@end

@implementation VT264Decoder

@synthesize delegate;

- (instancetype)init {
    self = [super init];
    if ( self ) {
        
    }
    return self;
}

- (void)dealloc {
    [self destroySession];
}

- (void)initDecoder {

}

- (void)releaseDecoder {
    [self destroySession];
}

- (void)decode:(Nal*) nal {
    uint8_t *bytes = nal.buffer.bytes;
    int length = (int)nal.buffer.length;
    while (length > H264::kNaluLongStartSequenceSize) {
        int startIndex = H264::findNalu(bytes, length);
        if (startIndex == -1) {
            break;
        }
        int nextIndex = H264::findNalu(bytes + startIndex + H264::kNaluLongStartSequenceSize, length - startIndex - H264::kNaluLongStartSequenceSize);
        if ( nextIndex == -1 ) {
            [self decodeFrame:bytes + startIndex length:length - startIndex presentationTimeStamp:nal.presentationTimeStamp];
            break;
        } else {
            [self decodeFrame:bytes + startIndex length:nextIndex + H264::kNaluLongStartSequenceSize presentationTimeStamp:nal.presentationTimeStamp];
            bytes += startIndex + H264::kNaluLongStartSequenceSize + nextIndex;
            length -= startIndex + H264::kNaluLongStartSequenceSize + nextIndex;
        }
    }
}

- (void)decodeFrame:(uint8_t*)buffer length:(NSUInteger)length presentationTimeStamp:(CMTime)pts {
    if ( length < H264::kNaluLongStartSequenceSize || !H264::isNalu(buffer) ) {
        return;
    }
    
    H264::NaluType type = H264::naluType(buffer[H264::kNaluLongStartSequenceSize]);
    uint32 *pnalu = (uint32*)buffer;
    pnalu[0] = CFSwapInt32HostToBig(uint32(length - H264::kNaluLongStartSequenceSize));

    switch ( type ) {
        case H264::kSps:
            self.sps = [[NSMutableData alloc] initWithBytes:buffer + H264::kNaluLongStartSequenceSize
                                                     length:length - H264::kNaluLongStartSequenceSize];
            break;
        case H264::kPps:
            self.pps = [[NSMutableData alloc] initWithBytes:buffer + H264::kNaluLongStartSequenceSize
                                                     length:length - H264::kNaluLongStartSequenceSize];
            break;
        case H264::kIdr:
        case H264::kSlice:
            [self decode:buffer length:length presentationTimeStamp:pts];
            break;
        default:
            break;
    }
}

- (void)decode:(uint8_t*)buffer length:(NSUInteger)length presentationTimeStamp:(CMTime)pts {
    if (self.decoderSession == nil) {
        if (self.sps != nil && self.pps != nil) {
            [self setupDecoder:self.sps pps:self.pps];
        } else {
            NSLog(@"not sps pps.");
            return;
        }
    }
    
    CMBlockBufferRef blockBuffer = nil;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, buffer, length,
                                                         kCFAllocatorNull, nil, 0, length,
                                                         0, &blockBuffer);

    if (status != kCMBlockBufferNoErr) {
        NSLog(@"create block Bbuffer fail with error code : %d", status);
        return;
    }
    
    CMSampleBufferRef sampleBuffer = nil;
    status = CMSampleBufferCreate(nullptr, blockBuffer, true, nullptr,
                                  nullptr, self.videoFormatDescription, 1, 0, nullptr, 0,
                                  nullptr, &sampleBuffer);

    if (status != noErr) {
        CFRelease(blockBuffer);
        NSLog(@"create sample Bbuffer fail with error code : %d", status);
        return;
    }
    
    DecodeCallbackParams callbackInfo;
    VTDecodeFrameFlags flags = 0;
    VTDecodeInfoFlags flagOut = 0;
    status = VTDecompressionSessionDecodeFrame(self.decoderSession, sampleBuffer, flags, &callbackInfo, &flagOut);

    if (status == noErr) {
        if (callbackInfo.status == noErr && callbackInfo.pixelBuffer != nil) {
            VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:callbackInfo.pixelBuffer rotation:VideoRotation_0];
            videoFrame.presentationTimeStamp = pts;
            [self.delegate decoder:self onDecoded:videoFrame];
            CVPixelBufferRelease(callbackInfo.pixelBuffer);
        } else {
            NSLog(@"decode frame status : %d", callbackInfo.status);
        }
    } else {
        NSLog(@"decode frame fail with error code : %d", status);
    }

    CFRelease(blockBuffer);
    CFRelease(sampleBuffer);
}

- (void)destroySession {
    if (_decoderSession) {
        VTDecompressionSessionWaitForAsynchronousFrames(_decoderSession);
        VTDecompressionSessionInvalidate(_decoderSession);
        CFRelease(_decoderSession);
        _decoderSession = nil;
    }
    if (_videoFormatDescription != NULL) {
        CFRelease(_videoFormatDescription);
        _videoFormatDescription = NULL;
    }
}

- (BOOL)setupDecoder:(NSData*) sps pps:(NSData*) pps {
    if ( self.decoderSession != nil ) {
        return NO;
    }
    
    CMVideoFormatDescriptionRef videoFormatDescription;
    
    const uint8_t* param_set_ptrs[2] = {(const uint8_t*)sps.bytes, (const uint8_t*)pps.bytes};
    size_t param_set_sizes[2] = {sps.length, pps.length};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2,
                                                                          param_set_ptrs,
                                                                          param_set_sizes,
                                                                          4,
                                                                          &videoFormatDescription);
    
    if ( status != noErr ) {
        NSLog(@"failed to create video format description.");
        return YES;
    }
    
    self.videoFormatDescription = videoFormatDescription;

    BOOL isFullRange = NO;
    CFDictionaryRef attrs =  CMFormatDescriptionGetExtensions(videoFormatDescription);
    Boolean isHaveFullRange = CFDictionaryContainsKey(attrs, CFSTR("FullRangeVideo"));
    if (isHaveFullRange == true) {
        NSNumber *fullRange = (NSNumber *)CFDictionaryGetValue(attrs, CFSTR("FullRangeVideo"));
        isFullRange = [fullRange boolValue];
    }
    
    uint32_t videoFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    if (isFullRange) {
        videoFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    } else {
        videoFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    }
    
    CFNumberRef formatRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &videoFormat);
    const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
    const void *values[] = { formatRef };
    attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
    CFRelease(formatRef);
    
    VTDecompressionOutputCallbackRecord callbackInfo;
    callbackInfo.decompressionOutputCallback = decompressionOutputCallback;
    callbackInfo.decompressionOutputRefCon = (__bridge void *)self;
    status = VTDecompressionSessionCreate(nil, videoFormatDescription, nil, nil, &callbackInfo, &_decoderSession);
    
    if (attrs) {
        CFRelease(attrs);
        attrs = nil;
    }
    
    if (status != noErr) {
        NSLog(@"createSession error:%d", status);
    }
    
    VTSessionSetProperty(_decoderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    return status == noErr;
}

void decompressionOutputCallback(void *decoder,
                                 void *params,
                                 OSStatus status,
                                 VTDecodeInfoFlags infoFlags,
                                 CVImageBufferRef imageBuffer,
                                 CMTime timestamp,
                                 CMTime duration) {
    DecodeCallbackParams *callbackInfo = (DecodeCallbackParams *)params;
    if (callbackInfo != nil) {
        callbackInfo->status = status;
        callbackInfo->infoFlags = infoFlags;
        callbackInfo->pixelBuffer = CVPixelBufferRetain(imageBuffer);
        callbackInfo->presentationTimeStamp = timestamp;
        callbackInfo->presentationDuration = duration;
    }
}

@end
