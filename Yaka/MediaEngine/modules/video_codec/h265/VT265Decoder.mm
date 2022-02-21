//
//  VT265Decoder.m
//  Yaka
//
//  Created by Enki on 2021/8/10.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "VT265Decoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import "H264Common.h"


namespace {
    
typedef enum {
    NAL_TRAIL_N    = 0,
    NAL_TRAIL_R    = 1,
    NAL_TSA_N      = 2,
    NAL_TSA_R      = 3,
    NAL_STSA_N     = 4,
    NAL_STSA_R     = 5,
    NAL_RADL_N     = 6,
    NAL_RADL_R     = 7,
    NAL_RASL_N     = 8,
    NAL_RASL_R     = 9,
    NAL_BLA_W_LP   = 16,
    NAL_BLA_W_RADL = 17,
    NAL_BLA_N_LP   = 18,
    NAL_IDR_W_RADL = 19,
    NAL_IDR_N_LP   = 20,
    NAL_CRA_NUT    = 21,
    NAL_VPS        = 32,
    NAL_SPS        = 33,
    NAL_PPS        = 34,
    NAL_AUD        = 35,
    NAL_EOS_NUT    = 36,
    NAL_EOB_NUT    = 37,
    NAL_FD_NUT     = 38,
    NAL_SEI_PREFIX = 39,
    NAL_SEI_SUFFIX = 40,
} NaluType265;

struct DecodeCallbackParams {
    OSStatus status;
    VTDecodeInfoFlags infoFlags;
    CVImageBufferRef pixelBuffer;
    CMTime presentationTimeStamp;
    CMTime presentationDuration;
};

}

@interface VT265Decoder ()

@property(nonatomic, assign) VTDecompressionSessionRef decoderSession;
@property(nonatomic, assign) CMFormatDescriptionRef formatDescription;

@property(nonatomic, strong) NSMutableData *vps;
@property(nonatomic, strong) NSMutableData *sps;
@property(nonatomic, strong) NSMutableData *pps;

@end

@implementation VT265Decoder

@synthesize delegate;

- (void)dealloc {
    [self destroySession];
}

- (void)initDecoder {
    
}

- (void)decode:(Nal*)nal {
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

- (void)releaseDecoder {
    [self destroySession];
}

- (void)decodeFrame:(uint8_t*)buffer length:(NSUInteger)length presentationTimeStamp:(CMTime)pts {
    if (length < H264::kNaluLongStartSequenceSize ) {
        return;
    }

    int nalType = (buffer[H264::kNaluLongStartSequenceSize] & 0x7E) >> 1;
    uint32 *pnalu = (uint32*)buffer;
    pnalu[0] = CFSwapInt32HostToBig(uint32(length - H264::kNaluLongStartSequenceSize));

    switch ( nalType ) {
        case NAL_VPS:
            self.vps = nil;
            self.sps = nil;
            self.pps = nil;
            self.vps = [[NSMutableData alloc] initWithBytes:buffer + H264::kNaluLongStartSequenceSize
                                                     length:length - H264::kNaluLongStartSequenceSize];
            break;
        case NAL_SPS:
            self.sps = [[NSMutableData alloc] initWithBytes:buffer + H264::kNaluLongStartSequenceSize
                                                     length:length - H264::kNaluLongStartSequenceSize];
            break;
        case NAL_PPS:
            self.pps = [[NSMutableData alloc] initWithBytes:buffer + H264::kNaluLongStartSequenceSize
                                                     length:length - H264::kNaluLongStartSequenceSize];
            if (self.decoderSession != nil && self.formatDescription != nil) {
                CMFormatDescriptionRef formatDescription = [self createFormatDescription:self.vps sps:self.sps pps:self.pps];
                if (!CMFormatDescriptionEqual(formatDescription, self.formatDescription)) {
                    [self destroySession];
                }
                CFRelease(formatDescription);
            }
            break;
        case NAL_SEI_PREFIX:
        case NAL_SEI_SUFFIX:
            break;
        default:
            [self decode:buffer length:length presentationTimeStamp:pts];
            break;
    }
}

- (void)decode:(uint8_t*)buffer length:(NSUInteger)length presentationTimeStamp:(CMTime)pts {
    
    if ( self.decoderSession == nil ) {
        if (self.vps != nil && self.sps != nil && self.pps != nil) {
            [self setupDecoder:self.vps sps:self.sps pps:self.pps];
        } else {
            NSLog(@"not vps sps pps.");
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
    status = CMSampleBufferCreate(NULL, blockBuffer, true, NULL, NULL, self.formatDescription, 1, 0, NULL, 0, NULL, &sampleBuffer);

    if (status != noErr) {
        CFRelease(blockBuffer);
        NSLog(@"create sample buffer fail with error code : %d", status);
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
            int nalType = (buffer[H264::kNaluLongStartSequenceSize] & 0x7E) >> 1;
            NSLog(@"decode frame status : %d, nalu type : %d, length: %lu", callbackInfo.status, nalType, (unsigned long)length);
        }
    } else {
        int nalType = (buffer[H264::kNaluLongStartSequenceSize] & 0x7E) >> 1;
        NSLog(@"decode frame fail with error code : %d, nalu type : %d, length: %lu", status, nalType, (unsigned long)length);
    }

    CFRelease(blockBuffer);
    CFRelease(sampleBuffer);
}

- (BOOL)setupDecoder:(NSData*) vps sps:(NSData*) sps pps:(NSData*) pps {
    if (self.decoderSession != nil) {
        return YES;
    }

    self.formatDescription = [self createFormatDescription:vps sps:sps pps:pps];
    if (self.formatDescription == nil) {
        return NO;
    }
    
    BOOL isFullRange = NO;
    int bits = 8;
    CFStringRef transfer = nil;
    CFStringRef colorPrimaries = nil;
    CFStringRef yCbCrMatrix = nil;
    
    CFDictionaryRef attrs =  CMFormatDescriptionGetExtensions(self.formatDescription);
    Boolean isHaveFullRange = CFDictionaryContainsKey(attrs, CFSTR("FullRangeVideo"));
    if (isHaveFullRange == true) {
        NSNumber *fullRange = (NSNumber *)CFDictionaryGetValue(attrs, CFSTR("FullRangeVideo"));
        isFullRange = [fullRange boolValue];
    }
    
    Boolean isHaveBitsPerComponent = CFDictionaryContainsKey(attrs, CFSTR("BitsPerComponent"));
    if (isHaveBitsPerComponent) {
        NSNumber *bitsPerComponent = (NSNumber *)CFDictionaryGetValue(attrs, CFSTR("BitsPerComponent"));
        bits = [bitsPerComponent intValue];
    }
    
    Boolean isHaveTransfer = CFDictionaryContainsKey(attrs, CFSTR("CVImageBufferTransferFunction"));
    if (isHaveTransfer) {
        transfer = (CFStringRef)CFDictionaryGetValue(attrs, CFSTR("CVImageBufferTransferFunction"));
    }
    
    Boolean isHaveColorPrimaries = CFDictionaryContainsKey(attrs, CFSTR("CVImageBufferColorPrimaries"));
    if (isHaveColorPrimaries) {
        colorPrimaries = (CFStringRef)CFDictionaryGetValue(attrs, CFSTR("CVImageBufferColorPrimaries"));
    }
    
    Boolean isHaveYCbCrMatrix = CFDictionaryContainsKey(attrs, CFSTR("CVImageBufferYCbCrMatrix"));
    if (isHaveYCbCrMatrix) {
        yCbCrMatrix = (CFStringRef)CFDictionaryGetValue(attrs, CFSTR("CVImageBufferYCbCrMatrix"));
    }

    attrs = nil;
    uint32_t videoFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;

    if ( bits == 8 ) {
        if (isFullRange) {
            videoFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        } else {
            videoFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
        }
    } else if ( bits == 10 ) {
        if (isFullRange) {
            videoFormat = kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
        } else {
            videoFormat = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange;
        }
    }
    
    if ( bits == 8 || bits == 10 ) {
        CFNumberRef formatRef = CFNumberCreate(NULL, kCFNumberSInt32Type, &videoFormat);
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        const void *values[] = { formatRef };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        CFRelease(formatRef);
    }

    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = decompressionOutputCallback;
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    NSDictionary *videoDecoderSpecification = @{AVVideoCodecKey: AVVideoCodecTypeHEVC};
    
    OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                   self.formatDescription,
                                                   (__bridge CFDictionaryRef)videoDecoderSpecification,
                                                   attrs,
                                                   &callBackRecord,
                                                   &_decoderSession);
    if (attrs != nil) {
        CFRelease(attrs);
    }

    if (status != noErr) {
        NSLog(@"createSession error:%d", status);
    }
    
    VTSessionSetProperty(_decoderSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    return status == noErr;
}

- (void)destroySession {
    if (_decoderSession) {
        VTDecompressionSessionWaitForAsynchronousFrames(_decoderSession);
        VTDecompressionSessionInvalidate(_decoderSession);
        CFRelease(_decoderSession);
        _decoderSession = nil;
    }

    if (_formatDescription != NULL) {
        CFRelease(_formatDescription);
        _formatDescription = NULL;
    }
}

- (CMFormatDescriptionRef)createFormatDescription:(NSData*)vps
                                              sps:(NSData*)sps
                                              pps:(NSData*)pps {
    const uint8_t * const param_set_ptrs[3] = {(const uint8_t *)vps.bytes, (const uint8_t *)sps.bytes, (const uint8_t *)pps.bytes};
    const size_t param_set_sizes[3] = {vps.length, sps.length, pps.length };
    CMFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault,
                                                                          3,
                                                                          param_set_ptrs,
                                                                          param_set_sizes,
                                                                          4,
                                                                          NULL,
                                                                          &formatDescription);
    if (status != noErr) {
        NSLog(@"create format description error, status:%d!!", status);
        return nil;
    }
    return formatDescription;
}

static void decompressionOutputCallback(void *decompressionOutputRefCon,
                                        void *sourceFrameRefCon,
                                        OSStatus status,
                                        VTDecodeInfoFlags infoFlags,
                                        CVImageBufferRef pixelBuffer,
                                        CMTime presentationTimeStamp,
                                        CMTime presentationDuration) {
    DecodeCallbackParams *callbackInfo = (DecodeCallbackParams *)sourceFrameRefCon;
    if (callbackInfo != nil) {
        callbackInfo->status = status;
        callbackInfo->infoFlags = infoFlags;
        callbackInfo->pixelBuffer = CVPixelBufferRetain(pixelBuffer);
        callbackInfo->presentationTimeStamp = presentationTimeStamp;
        callbackInfo->presentationDuration = presentationDuration;
    }
}

@end
