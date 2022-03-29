//
//  FileCapture.m
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "FileCapture.h"
#include "I420Buffer.h"
#include "libyuv.h"
#import "PixelBufferTools.h"

namespace {

static const int kDefaultFps = 24;

void splitUVPlane16(const uint8_t* src_uv, int src_stride_uv,
                    uint8_t* dst_u, int dst_stride_u,
                    uint8_t* dst_v, int dst_stride_v,
                    int width, int height) {
    for (int i = 0; i < height / 2; i++) {
        const uint8_t *uv = src_uv + src_stride_uv * i;
        uint8_t* u = dst_u + dst_stride_u * i / 2;
        uint8_t* v = dst_v + dst_stride_v * i / 2;
        for (int i = 0; i < width / 2; i++) {
            memcpy(u, uv, 2);
            memcpy(v, uv + 2, 2);
            uv += 4;
            u += 2;
            v += 2;
        }
    }
}

void mergeUVPlane16(const uint8_t* src_u, int src_stride_u,
                    const uint8_t* src_v, int src_stride_v,
                    uint8_t* dst_uv, int dst_stride_uv,
                    int width, int height) {
    for (int i = 0; i < height / 2; i++) {
        uint8_t *uv = dst_uv + dst_stride_uv * i;
        const uint8_t* u = src_u + src_stride_u * i / 2;
        const uint8_t* v = src_v + src_stride_v * i / 2;
        for (int i = 0; i < width / 2; i++) {
            memcpy(uv, u, 2);
            memcpy(uv + 2, v, 2);
            uv += 4;
            u += 2;
            v += 2;
        }
    }
}

}

@interface FileCapture ()

@property(nonatomic, strong) MutableI420Buffer *frameBuffer;
@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;
@property(nonatomic, assign) int frameSize;
@property(nonatomic, assign) long totalByte;
@property(nonatomic, assign) NSUInteger frameIndex;
@property(nonatomic, assign) FILE *fd;
@property(atomic, assign) BOOL cancel;


@end

@implementation FileCapture

@synthesize delegate;
@synthesize isRunning;
@synthesize fileSourceDelegate;
@synthesize isPause;
@synthesize isLoop;
@synthesize frameIndex;
@synthesize fps;
@synthesize totalFrames;

- (instancetype)initWithPath:(NSString*) filePath width:(NSUInteger) width height:(NSUInteger) height pixelFormatType:(PixelFormatType) format {
    self = [super init];
    if ( self ) {
        self.filePath = filePath;
        self.cancel = YES;
        self.width = (int)width;
        self.height = (int)height;
        self.format = format;
        self.isLoop = YES;
        self.fps = kDefaultFps;
        [self openFileAndAnalysis];
    }
    return self;
}

- (void)dealloc {
    [self stop];
}


#pragma mark -
#pragma mark VideoSourceInterface

- (void)start {
    if ( !self.cancel ) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.cancel = NO;
        [self process];
    });
}

- (void)stop {
    if (!self.cancel) {
        self.cancel = YES;
        [self performSelector:@selector(closeFile) withObject:self afterDelay:0.3];
    }
}

- (BOOL)isRunning {
    return !self.cancel;
}


#pragma mark -
#pragma mark FileSourceInterface

- (BOOL)isPause {
    return self.cancel && self.fd != NULL;
}

- (NSUInteger)totalFrames {
    if (self.frameSize != 0) {
        return self.totalByte / self.frameSize;
    }
    return 0;
}

- (void)pause {
    self.cancel = YES;
}

- (void)resume {
    if (!self.isPause) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.cancel = NO;
        [self process];
    });
}

- (void)seekToFrameIndex:(NSUInteger) frameIndex {
    if ( frameIndex < self.totalFrames ) {
        long location = self.frameSize * frameIndex;
        if ( self.fd != NULL ) {
            fseek(self.fd, location, SEEK_SET);
        }
        [self outputFrame];
    }
}

- (id<NSObject>)frameWithIndex:(NSUInteger) frameIndex {
    if ( frameIndex < self.totalFrames ) {
        long location = ftell(self.fd);
        long offset = self.frameSize * frameIndex;
        fseek(self.fd, offset, SEEK_SET);
        VideoFrame *videoFrame = [self readFrame:NO];
        fseek(self.fd, location, SEEK_SET);
        return videoFrame;
    } else {
        return nil;
    }
}

#pragma mark -
#pragma mark Private Method

- (BOOL)openFileAndAnalysis {
    if (self.fd != NULL) {
        fclose(self.fd);
        self.fd = NULL;
    }
    self.fd = fopen([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    if (self.fd == NULL) {
        return NO;
    }
    if (self.format == kPixelFormatType_420_P010 ||
        self.format == kPixelFormatType_420_I010) {
        self.frameSize = self.width * self.height * 3;
    } else {
        self.frameSize = self.width * self.height * 3 / 2;
    }
    fseek(self.fd, 0, SEEK_END);
    self.totalByte = ftell(self.fd);
    fseek(self.fd, 0, SEEK_SET);
    self.frameBuffer = [[MutableI420Buffer alloc] initWithWidth:(int)self.width
                                                         height:(int)self.height];
    return YES;
}

- (void)process {
    long remainder = self.totalByte - ftell(self.fd);
    if (remainder < self.frameSize) {
        self.frameIndex = 0;
        fseek(self.fd, 0, SEEK_SET);
    }
    VideoFrame *videoFrame = nil;
    do {
        @autoreleasepool {
            videoFrame = [self outputFrame];
        }
        usleep(1000.0 / (self.fps == 0 ? kDefaultFps : self.fps) * 1000);
    } while (videoFrame != nil && !self.cancel);
    self.cancel = YES;
    remainder = self.totalByte - ftell(self.fd);
    if (remainder < self.frameSize) {
        if (self.fileSourceDelegate != nil) {
            [self.fileSourceDelegate fileSource:self fileDidEnd:self.totalFrames];
        }
    }
}

- (void)closeFile {
    if (self.fd != NULL) {
        fclose(self.fd);
        self.fd = NULL;
    }
}

- (VideoFrame*)outputFrame {
    self.frameIndex = (ftell(self.fd) / self.frameSize);
    VideoFrame *videoFrame = [self readFrame:self.isLoop];
    if (videoFrame != nil) {
        if (self.delegate) {
            [self.delegate captureSource:self onFrame:videoFrame];
        }
        if (self.fileSourceDelegate != nil) {
            [self.fileSourceDelegate fileSource:self progressUpdated:self.frameIndex];
        }
    } else {
        self.frameIndex -= 1;
    }
    return videoFrame;
}

- (VideoFrame*)readFrame:(BOOL) isLoop {
    VideoFrame *videoFrame = nil;
    do {
        if (self.format == kPixelFormatType_420_I420) {
            videoFrame = [self readI420Frame];
        } else if (self.format == kPixelFormatType_420_NV12) {
            videoFrame = [self readNV12Frame];
        } else if (self.format == kPixelFormatType_420_P010) {
            videoFrame = [self readP010Frame];
        } else if (self.format == kPixelFormatType_420_I010) {
            videoFrame = [self readI010Frame];
        }
        if (videoFrame == nil && isLoop) {
            fseek(self.fd, 0, SEEK_SET);
            continue;
        } else {
            break;
        }
    } while (true);
    return videoFrame;
}

- (VideoFrame*)readI420Frame {
    CVPixelBufferRef pixelBuffer = [PixelBufferTools createPixelBufferWithSize:CGSizeMake(self.width, self.height)
                                                                   pixelFormat:kCVPixelFormatType_420YpCbCr8Planar];
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    for (int i = 0; i < 3; i++) {
        uint8_t* src = (uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i);
        int stride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i);
        int width = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
        int height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
        for ( int j = 0; j < height; j++ ) {
            int read_size = [self fread:src + stride * j length:width fd:self.fd];
            if (read_size != width) {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
                CVPixelBufferRelease(pixelBuffer);
                return nil;
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:pixelBuffer rotation:VideoRotation_0];
    CVPixelBufferRelease(pixelBuffer);
    return videoFrame;
}

- (VideoFrame*)readNV12Frame {
    CVPixelBufferRef pixelBuffer = [PixelBufferTools createPixelBufferWithSize:CGSizeMake(self.width, self.height)
                                                                   pixelFormat:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    unsigned char *src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
    int srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    int srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    int srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    for (int i = 0; i < srcHeight; i++) {
        int read_size = [self fread:src + srcStride * i length:srcWidth fd:self.fd];
        if (read_size != srcWidth) {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
            CVPixelBufferRelease(pixelBuffer);
            return nil;
        }
    }
    src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
    srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1) * 2;
    srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    for (int i = 0; i < srcHeight; i++) {
        int read_size = [self fread:src + srcStride * i length:srcWidth fd:self.fd];
        if (read_size != srcWidth) {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
            CVPixelBufferRelease(pixelBuffer);
            return nil;
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:pixelBuffer rotation:VideoRotation_0];
    CVPixelBufferRelease(pixelBuffer);
    return videoFrame;
}

- (VideoFrame*)readP010Frame {
    CVPixelBufferRef pixelBuffer = [PixelBufferTools createPixelBufferWithSize:CGSizeMake(self.width, self.height)
                                                                   pixelFormat:kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange];
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    unsigned char *src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
    int srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    int srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) * 2;
    int srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    for (int i = 0; i < srcHeight; i++) {
        int read_size = [self fread:src + srcStride * i length:srcWidth fd:self.fd];
        if (read_size != srcWidth) {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
            CVPixelBufferRelease(pixelBuffer);
            return nil;
        }
    }
    src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
    srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1) * 4;
    srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    for (int i = 0; i < srcHeight; i++) {
        int read_size = [self fread:src + srcStride * i length:srcWidth fd:self.fd];
        if (read_size != srcWidth) {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
            CVPixelBufferRelease(pixelBuffer);
            return nil;
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);

    CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG, kCVAttachmentMode_ShouldPropagate);
    
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:pixelBuffer rotation:VideoRotation_0];
    CVPixelBufferRelease(pixelBuffer);
    return videoFrame;
}

- (VideoFrame*)readI010Frame {
    I010Buffer *frameBuffer = [[I010Buffer alloc] initWithWidth:self.width
                                                         height:self.height];
    for (int i = 0; i < frameBuffer.height; i++) {
        int read_size = [self fread:(uint8_t *)frameBuffer.dataY + frameBuffer.strideY * i
                             length:frameBuffer.width * 2
                                 fd:self.fd];
        if (read_size != frameBuffer.width * 2) {
            return nil;
        }
    }
    for (int i = 0; i < frameBuffer.chromaHeight / 2; i++) {
        int read_size = [self fread:(uint8_t *)frameBuffer.dataU + frameBuffer.strideU * i
                             length:frameBuffer.width * 2
                                 fd:self.fd];
        if (read_size != frameBuffer.width * 2) {
            return nil;
        }
    }
    for (int i = 0; i < frameBuffer.chromaHeight / 2; i++) {
        int read_size = [self fread:(uint8_t *)frameBuffer.dataV + frameBuffer.strideV * i
                             length:frameBuffer.width * 2
                                 fd:self.fd];
        if (read_size != frameBuffer.width * 2) {
            return nil;
        }
    }
    CVPixelBufferRef pixelBuffer = [self convertToP010:frameBuffer];
    if (pixelBuffer == nil) {
        return nil;
    }
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:pixelBuffer rotation:VideoRotation_0];
    CVPixelBufferRelease(pixelBuffer);
    return videoFrame;
}

- (int)fread:(void*)buffer length:(int)length fd:(FILE *)fd {
    size_t read_size = 0;
    size_t total_size = 0;
    do {
        read_size = fread((int8_t*)buffer + total_size, 1, length - total_size, fd);
        total_size += read_size;
    } while ( read_size != 0 && total_size != length );
    return (int)total_size;
}

- (CVPixelBufferRef)convertToP010:(I010Buffer *)buffer {
    CVPixelBufferRef pixelBuffer = [PixelBufferTools createPixelBufferWithSize:CGSizeMake(buffer.width, buffer.height)
                                                                   pixelFormat:kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange];
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    uint8_t *dst = (uint8_t *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
    int dstStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    int dstWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    int dstHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    for (int i = 0; i < dstHeight; i++) {
        memcpy(dst + dstStride * i, buffer.dataY + buffer.strideV * i, dstWidth * 2);
    }
    
    dst = (uint8_t *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
    dstStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    mergeUVPlane16(buffer.dataU, buffer.strideU, buffer.dataV, buffer.strideV, dst, dstStride, buffer.width, buffer.height);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG, kCVAttachmentMode_ShouldPropagate);

    return pixelBuffer;
}

- (I010Buffer *)convertToI010:(CVPixelBufferRef)pixelBuffer {
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (format != kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange) {
        return nil;
    }
    
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    
    I010Buffer *frameBuffer = [[I010Buffer alloc] initWithWidth:width height:height];
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    uint8_t *src = (uint8_t *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
    int srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    int srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) * 2;
    int srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    for (int i = 0; i < srcHeight; i++) {
        memcpy((void *)(frameBuffer.dataY + frameBuffer.strideY * i), src + srcStride * i, srcWidth);
    }
    
    src = (uint8_t *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
    srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
    splitUVPlane16((uint8_t *)src, srcStride,
                   (uint8_t *)frameBuffer.dataU, frameBuffer.strideU,
                   (uint8_t *)frameBuffer.dataV, frameBuffer.strideV,
                   width, height);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    return frameBuffer;
}

@end
