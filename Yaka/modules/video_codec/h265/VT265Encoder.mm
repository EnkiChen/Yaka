//
//  VT265Encoder.m
//  Yaka
//
//  Created by Enki on 2021/8/10.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "VT265Encoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import "H264Common.h"

namespace {
const static uint8_t kNaluStartCode[] = {0, 0, 0, 1};
const size_t kNaluLongStartSequenceSize = 4;
}

@interface VT265Encoder ()

@property (nonatomic, assign) VTCompressionSessionRef encoderSession;
@property (nonatomic, assign) NSUInteger pts;

@end

@implementation VT265Encoder

@synthesize delegate;

- (void)dealloc {
    [self destroySession];
}

- (void)initEncoder {

}

- (void)reconfig:(EncoderParams *) params {
    
}

- (void)encode:(VideoFrame*) frame {
    if (!VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
        NSLog(@"HardwareEncoder : Not support H265 Encode/Decode!");
        return;
    }

    if ([frame.buffer isKindOfClass:CVPixelBuffer.class]) {
        CVPixelBuffer *pixelBuffer = (CVPixelBuffer*)frame.buffer;
        [self encodePixelBuffer:pixelBuffer.pixelBuffer presentationTimeStamp:CMTimeMake(self.pts++, 1000)];
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
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    
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
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    
    [self encodePixelBuffer:pixelBuffer presentationTimeStamp:CMTimeMake(self.pts++, 1000)];
    CFRelease(pixelBuffer);
}

- (void)releaseEncoder {
    [self destroySession];
}

- (void)encodePixelBuffer:(CVPixelBufferRef) pixelBuffer presentationTimeStamp:(CMTime) pts {
    if (self.encoderSession == nil) {
        [self setupEncoder:pixelBuffer];
    }

    CFMutableDictionaryRef frameProps = NULL;
    VTEncodeInfoFlags infoFlags = 0;
    VTCompressionSessionEncodeFrame(self.encoderSession, pixelBuffer, pts, kCMTimeInvalid, frameProps, NULL, &infoFlags);
}

- (void)setupEncoder:(CVPixelBufferRef) pixelBuffer {
    if (self.encoderSession != nil) {
        return;
    }
    
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);

    const void *keys[] = {
        kCVPixelBufferPixelFormatTypeKey,
        kCVPixelBufferWidthKey,
        kCVPixelBufferHeightKey,
    };
    const void *values[] = {
        (__bridge const void *)([NSNumber numberWithInt:format]),
        (__bridge const void *)([NSNumber numberWithInt:width]),
        (__bridge const void *)([NSNumber numberWithInt:height]),
    };
    
    CFDictionaryRef attribute = CFDictionaryCreate(NULL, keys, values, 3, NULL, NULL);

    OSStatus status = VTCompressionSessionCreate(NULL, width, height,
                                                 kCMVideoCodecType_HEVC,
                                                 NULL,
                                                 attribute,
                                                 NULL,
                                                 CompressSessionOnHevcEncodedCallback,
                                                 (__bridge void * _Nullable)self,
                                                 &_encoderSession);
    CFRelease(attribute);
    if (noErr != status) {
        NSLog(@"create session error:%d",status);
        return;
    }

    
    int frameRate = 30;
    int keyFrameIntervalDuration = 3;
    int keyFrameInterval = keyFrameIntervalDuration * frameRate;
    int averageBitRate = 1.2 * 1000 * 1000;
    
    status = VTSessionSetProperty(self.encoderSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main10_AutoLevel);
    status = VTSessionSetProperty(self.encoderSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    status = VTSessionSetProperty(self.encoderSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    status = VTSessionSetProperty(self.encoderSession, kVTCompressionPropertyKey_AllowTemporalCompression, kCFBooleanTrue);
    status = VTSessionSetProperty_int(self.encoderSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, keyFrameInterval);
    status = VTSessionSetProperty_int(self.encoderSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, keyFrameIntervalDuration);
    status = VTSessionSetProperty_int(self.encoderSession, kVTCompressionPropertyKey_ExpectedFrameRate, frameRate);
    status = VTSessionSetProperty_int(self.encoderSession, kVTCompressionPropertyKey_AverageBitRate, averageBitRate);
    
    
    CVAttachmentMode attachmentMode = kCVAttachmentMode_ShouldNotPropagate;
    CFTypeRef matrix = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, &attachmentMode);
    CFTypeRef colorPrimaries = CVBufferGetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, &attachmentMode);
    CFTypeRef transferFunction = CVBufferGetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, &attachmentMode);

    status = VTSessionSetProperty(self.encoderSession, kVTCompressionPropertyKey_YCbCrMatrix, matrix);
    status = VTSessionSetProperty(self.encoderSession, kVTCompressionPropertyKey_ColorPrimaries, colorPrimaries);
    status = VTSessionSetProperty(self.encoderSession, kVTCompressionPropertyKey_TransferFunction, transferFunction);
    
    status = VTCompressionSessionPrepareToEncodeFrames(self.encoderSession);
}

- (void)encodeCompress:(void *)sourceFrameRefCon status:(OSStatus) status encodeInfoFlags:(VTEncodeInfoFlags) infoFlags sampleBuffer:(CMSampleBufferRef) sampleBuffer {
    if (status != noErr) {
        NSLog(@"encode error %d", (int)status);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH265 data is not ready ");
        return;
    }
    if (infoFlags == kVTEncodeInfo_FrameDropped) {
        NSLog(@"with frame dropped");
        return;
    }

    bool isKeyframe = false;
    CFArrayRef attachments_for_sample;
    attachments_for_sample = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, 0);
    if (NULL != attachments_for_sample) {
        CFDictionaryRef attachments;
        CFBooleanRef depends_on_others;
        attachments = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments_for_sample, 0);
        depends_on_others = (CFBooleanRef)CFDictionaryGetValue(attachments, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyframe = (depends_on_others == kCFBooleanFalse);
    }
    
    if (isKeyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t vpsSetSize = 0;
        size_t vpsSetCount = 0;
        const uint8_t *vpsSet = NULL;
        OSStatus statusCodeVps = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 0, &vpsSet, &vpsSetSize, &vpsSetCount, 0);
        
        size_t spsSetSize = 0, spsSetCount = 0;
        const uint8_t *spsSet;
        OSStatus statusCodeSps = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 1, &spsSet, &spsSetSize, &spsSetCount, 0);
        
        size_t ppsSetSize,ppsSetCount;
        const uint8_t *ppsSet;
        OSStatus statusCodePps = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 2, &ppsSet, &ppsSetSize, &ppsSetCount, 0);
        
        if (statusCodeVps == noErr && statusCodeSps == noErr && statusCodePps == noErr) {
            NalMutableBuffer *nalBuffer = [[NalMutableBuffer alloc] init];
            [nalBuffer appendBytes:kNaluStartCode length:kNaluLongStartSequenceSize];
            [nalBuffer appendBytes:vpsSet length:vpsSetSize];
            [nalBuffer appendBytes:kNaluStartCode length:kNaluLongStartSequenceSize];
            [nalBuffer appendBytes:spsSet length:spsSetSize];
            [nalBuffer appendBytes:kNaluStartCode length:kNaluLongStartSequenceSize];
            [nalBuffer appendBytes:ppsSet length:ppsSetSize];
            Nal *nal = [[Nal alloc] initWithNalBuffer:nalBuffer];
            if (self.delegate) {
                [self.delegate encoder:self onEncoded:nal];
            }
        }
    }
    
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t totalLength = 0;
    size_t lengthAtOffset = 0;
    uint8_t *dataPointer = NULL;
    status = CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffset, &totalLength, (char **)&dataPointer);
    if (noErr == status) {
        size_t offset = 0;
        while (offset < lengthAtOffset - kNaluLongStartSequenceSize && totalLength > 0) {
            uint32_t length = 0;
            memcpy(&length, dataPointer + offset, kNaluLongStartSequenceSize);
            length = CFSwapInt32BigToHost(length);
            
            if (self.delegate) {
                NalMutableBuffer *nalBuffer = [[NalMutableBuffer alloc] initWithLength:length + kNaluLongStartSequenceSize];
                [nalBuffer appendBytes:kNaluStartCode length:kNaluLongStartSequenceSize];
                [nalBuffer appendBytes:dataPointer + offset + kNaluLongStartSequenceSize length:length];
                Nal *nal = [[Nal alloc] initWithNalBuffer:nalBuffer];
                [self.delegate encoder:self onEncoded:nal];
            }
            
            offset += kNaluLongStartSequenceSize + length;
            totalLength -= kNaluLongStartSequenceSize + length;
            
            if (totalLength == 0) {
                break;
            }

            if (offset == lengthAtOffset && totalLength > 0) {
                offset = 0;
                status = CMBlockBufferGetDataPointer(blockBuffer, lengthAtOffset, &lengthAtOffset, nil, (char **)&dataPointer);
            }
        }
    }
}

- (void)destroySession {
    if (_encoderSession) {
        VTCompressionSessionCompleteFrames(_encoderSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_encoderSession);
        CFRelease(_encoderSession);
        _encoderSession = nil;
    }
}

void CompressSessionOnHevcEncodedCallback(void *refCon,
                                          void *sourceFrameRefCon,
                                          OSStatus compressStatus,
                                          VTEncodeInfoFlags infoFlags,
                                          CMSampleBufferRef sampleBuf) {
    @autoreleasepool {
        VT265Encoder *vc = (__bridge VT265Encoder *)refCon;
        [vc encodeCompress:sourceFrameRefCon status:compressStatus encodeInfoFlags:infoFlags sampleBuffer:sampleBuf];
    }
}

OSStatus VTSessionSetProperty_int(VTCompressionSessionRef session, CFStringRef name, int val)
{
    CFNumberRef num = CFNumberCreate(NULL, kCFNumberIntType, &val);
    OSStatus status = VTSessionSetProperty(session, name, num);
    CFRelease(num);
    return status;
}

@end
