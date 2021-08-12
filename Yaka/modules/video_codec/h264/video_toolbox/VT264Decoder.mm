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
    VT264Decoder *decoder;
    void *image_buffer;
};

CFDictionaryRef CreateCFTypeDictionary(CFTypeRef* keys,
                                       CFTypeRef* values,
                                       size_t size) {
    return CFDictionaryCreate(kCFAllocatorDefault, keys, values, size,
                              &kCFTypeDictionaryKeyCallBacks,
                              &kCFTypeDictionaryValueCallBacks);
}

}

@interface VT264Decoder()

@property(nonatomic, strong) dispatch_queue_t decoder_queue;

@property(nonatomic, assign) CMVideoFormatDescriptionRef videoFormat;
@property(nonatomic, assign) VTDecompressionSessionRef decompressionSession;
@property(nonatomic, assign) DecodeCallbackParams decodeParams;

@property(nonatomic, strong) NSMutableData *paramSps;
@property(nonatomic, strong) NSMutableData *paramPps;

@property(nonatomic, assign) NSUInteger frameCount;
@property(nonatomic, assign) NSUInteger naluCount;

- (void)onDecompression:(OSStatus)status imageBufferRef:(CVImageBufferRef) imageBuffer timestamp:(CMTime) timestamp duration:(CMTime) duration;

@end

void decompressionOutputCallback(void *decoder,
                                 void *params,
                                 OSStatus status,
                                 VTDecodeInfoFlags infoFlags,
                                 CVImageBufferRef imageBuffer,
                                 CMTime timestamp,
                                 CMTime duration) {
    
    DecodeCallbackParams *decodeParams = (DecodeCallbackParams*)params;
    VT264Decoder *vtb_decoder = decodeParams->decoder;
    [vtb_decoder onDecompression:status imageBufferRef:imageBuffer timestamp:timestamp duration:duration];
}

@implementation VT264Decoder

@synthesize delegate;

- (instancetype)init {
    self = [super init];
    if ( self ) {
        
    }
    return self;
}

- (void)dealloc {
    [self destroyDecompressionSession];
}

- (void)initDecoder {
    _decodeParams.decoder = self;
    self.decoder_queue = dispatch_queue_create("com.yaka.decoder_queue", nil);
}

- (void)releaseDecoder {
    [self destroyDecompressionSession];
}

- (void)decode:(Nal*) nal {
    if ( self.decoder_queue == nil ) {
        NSLog(@"not initialized decoder！");
        return;
    }
    
    uint8_t *bytes = nal.buffer.bytes;
    int length = (int)nal.buffer.length;
    while (length > H264::kNaluLongStartSequenceSize) {
        int startIndex = H264::findNalu(bytes, length);
        if (startIndex == -1) {
            break;
        }
        int nextIndex = H264::findNalu(bytes + startIndex + H264::kNaluLongStartSequenceSize, length - startIndex - H264::kNaluLongStartSequenceSize);
        if ( nextIndex == -1 ) {
            [self decodeFrame:bytes + startIndex length:length - startIndex];
            break;
        } else {
            [self decodeFrame:bytes + startIndex length:nextIndex + H264::kNaluLongStartSequenceSize];
            bytes += startIndex + H264::kNaluLongStartSequenceSize + nextIndex;
            length -= startIndex + H264::kNaluLongStartSequenceSize + nextIndex;
        }
    }
}

- (void)decodeFrame:(uint8_t*) buffer length:(NSUInteger) length {
    if ( length < 4 || !H264::isNalu(buffer) ) {
        return;
    }
    
    H264::NaluType type = H264::naluType(buffer[H264::kNaluLongStartSequenceSize]);
    uint32 *pnalu = (uint32*)buffer;
    pnalu[0] = CFSwapInt32HostToBig(uint32(length - H264::kNaluLongStartSequenceSize));

    switch ( type ) {
        case H264::kSps:
            self.paramSps = [[NSMutableData alloc] initWithBytes:buffer + H264::kNaluLongStartSequenceSize
                                                          length:length - H264::kNaluLongStartSequenceSize];
            break;
        case H264::kPps:
            self.paramPps = [[NSMutableData alloc] initWithBytes:buffer + H264::kNaluLongStartSequenceSize
                                                          length:length - H264::kNaluLongStartSequenceSize];
            break;
        case H264::kIdr:
            self.frameCount++;
            if ( [self updateDecompressionSession] ) {
                [self decode:buffer length:length];
            }
            break;
        case H264::kSlice:
            self.frameCount++;
            [self decode:buffer length:length];
            break;
        default:
            break;
    }
    self.naluCount++;
}

- (void)decode:(uint8_t*) buffer length:(NSUInteger) length {
    
    if ( _decompressionSession == nil ) {
        NSLog(@"not initialized decompression session！");
        return;
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
                                  nullptr, _videoFormat, 1, 0, nullptr, 0,
                                  nullptr, &sampleBuffer);

    if (status != noErr) {
        CFRelease(blockBuffer);
        NSLog(@"create sample Bbuffer fail with error code : %d", status);
        return;
    }
    
    status = VTDecompressionSessionDecodeFrame(_decompressionSession, sampleBuffer, 0, &_decodeParams, nil);
    
    if (status != noErr) {
        NSLog(@"decode frame fail with error code : %d", status);
    }

    CFRelease(blockBuffer);
    CFRelease(sampleBuffer);
}

- (void)onDecompression:(OSStatus) status
         imageBufferRef:(CVImageBufferRef) imageBuffer
              timestamp:(CMTime) timestamp
               duration:(CMTime) duration {
    
    if ( status != noErr ) {
        NSLog(@"decode frame fail with error code : %d", status);
        return;
    }
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:imageBuffer rotation:VideoRotation_0];
    [videoFrame.buffer toI420];
    __weak VT264Decoder *weak_self = self;
    dispatch_async(self.decoder_queue, ^{
        if (weak_self.delegate) {
            [weak_self.delegate decoder:weak_self onDecoded:videoFrame];
        }
    });
}

- (void)createDecompressionSession {
    static size_t const attributesSize = 3;
    CFTypeRef keys[attributesSize] = {
#if TARGET_OS_IPHONE
        kCVPixelBufferOpenGLESCompatibilityKey,
#else
        kCVPixelBufferOpenGLCompatibilityKey,
#endif
        kCVPixelBufferIOSurfacePropertiesKey,
        kCVPixelBufferPixelFormatTypeKey
    };
    CFDictionaryRef ioSurfaceValue = CreateCFTypeDictionary(nil, nil, 0);
    int64_t nv12type = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    CFNumberRef pixelFormat = CFNumberCreate(nil, kCFNumberLongType, &nv12type);
    CFTypeRef values[attributesSize] = {kCFBooleanTrue, ioSurfaceValue, pixelFormat};
    CFDictionaryRef attributes = CreateCFTypeDictionary(keys, values, attributesSize);
    if ( ioSurfaceValue ) {
        CFRelease(ioSurfaceValue);
        ioSurfaceValue = nil;
    }
    if ( pixelFormat ) {
        CFRelease(pixelFormat);
        pixelFormat = nil;
    }
    VTDecompressionOutputCallbackRecord record = {
        decompressionOutputCallback, nil,
    };
    OSStatus status = VTDecompressionSessionCreate(nil, _videoFormat, nil, attributes, &record, &_decompressionSession);
    CFRelease(attributes);
    if ( status != noErr ) {
        [self destroyDecompressionSession];
    }
    
    [self configureDecompressionSession];
}

- (void)configureDecompressionSession {

#if TARGET_OS_IPHONE
    VTSessionSetProperty(_decompressionSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
#endif
}

- (void)destroyDecompressionSession {
    if (_decompressionSession) {
#if TARGET_OS_IPHONE
        if ([UIDevice isIOS11OrLater]) {
            VTDecompressionSessionWaitForAsynchronousFrames(_decompressionSession);
        }
#endif
        VTDecompressionSessionInvalidate(_decompressionSession);
        CFRelease(_decompressionSession);
        _decompressionSession = nil;
    }
}

- (BOOL)updateDecompressionSession {
    if ( self.paramSps.length == 0 || self.paramPps.length == 0 ) {
        return NO;
    }
    
    CMVideoFormatDescriptionRef videoFormat;
    
    const uint8_t* param_set_ptrs[2] = {(const uint8_t*)self.paramSps.mutableBytes, (const uint8_t*)self.paramPps.mutableBytes};
    size_t param_set_sizes[2] = {self.paramSps.length, self.paramPps.length};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, param_set_ptrs, param_set_sizes, 4, &videoFormat);
    
    if ( status != noErr ) {
        NSLog(@"failed to create video format description.");
        return YES;
    }
    
    CMVideoDimensions cur_vd = CMVideoFormatDescriptionGetDimensions(videoFormat);
    
    if ( _videoFormat != nil ) {
        CMVideoDimensions old_vd = CMVideoFormatDescriptionGetDimensions(_videoFormat);
        if ( cur_vd.height != old_vd.height || cur_vd.width != old_vd.width ) {
            NSLog(@"video dimensions has changed to : %dx%d", cur_vd.width, cur_vd.height);
        }
        CFRelease(_videoFormat);
    } else {
        NSLog(@"video dimensions is : %dx%d", cur_vd.width, cur_vd.height);
    }
    
    _videoFormat = videoFormat;
    
    [self destroyDecompressionSession];
    [self createDecompressionSession];
    
    return YES;
}

@end
