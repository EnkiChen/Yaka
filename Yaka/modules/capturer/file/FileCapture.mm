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

static const int kDefaultFps = 24;


size_t read_data(unsigned char* buffer, int lenght, FILE *fd) {
    size_t read_size = 0;
    size_t total_size = 0;
    do {
        read_size = fread(buffer + total_size, 1, lenght - total_size, fd);
        total_size += read_size;
    } while ( read_size != 0 && total_size != lenght );
    return (int)total_size;
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
    [self openFileAndAnalysis];
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
        [self seekToFrameIndex:frameIndex];
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
    if (self.format == kPixelFormatType_420_P010) {
        self.frameSize = self.width * self.height * 3;
    } else {
        self.frameSize = self.width * self.height * 3 / 2;
    }
    fseek(self.fd, 0, SEEK_END);
    self.totalByte = ftell(self.fd);
    fseek(self.fd, 0, SEEK_SET);
    self.frameBuffer = [[MutableI420Buffer alloc] initWithWidth:(int)self.width height:(int)self.height];
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
        videoFrame = [self outputFrame];
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
    if (self.format == kPixelFormatType_420_I420) {
        return [self readI420Frame:isLoop];
    } else if (self.format == kPixelFormatType_420_NV12) {
        return [self readNV12Frame:isLoop];
    } else if (self.format == kPixelFormatType_420_P010) {
        return [self readP010Frame:isLoop];
    }
    return nil;
}

- (VideoFrame*)readI420Frame:(BOOL) isLoop {
    size_t read_size = (int)read_data(self.frameBuffer.mutableDataY, self.frameSize, self.fd);
    if (read_size != self.frameSize) {
        if (isLoop) {
            fseek(self.fd, 0, SEEK_SET);
            read_size = read_data(self.frameBuffer.mutableDataY, self.frameSize, self.fd);
        } else {
            return nil;
        }
    }
    return [[VideoFrame alloc] initWithBuffer:self.frameBuffer rotation:VideoRotation_0];
}

- (VideoFrame*)readNV12Frame:(BOOL) isLoop {
    
    CVPixelBufferRef pixelBuffer = [PixelBufferTools createPixelBufferWithSize:CGSizeMake(self.width, self.height)
                                                                   pixelFormat:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    BOOL isContinue = NO;
    BOOL isOk = NO;
    do {
        isOk = YES;
        isContinue = NO;
        unsigned char *src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
        int srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        int srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        int srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        for (int i = 0; i < srcHeight; i++) {
            size_t read_size = read_data(src + srcStride * i, srcWidth, self.fd);
            if (read_size != srcWidth) {
                if (isLoop) {
                    fseek(self.fd, 0, SEEK_SET);
                    isContinue = YES;
                }
                isOk = NO;
                break;
            }
        }

        src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
        srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
        srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1) * 2;
        srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        for (int i = 0; i < srcHeight; i++) {
            size_t read_size = read_data(src + srcStride * i, srcWidth, self.fd);
            if (read_size != srcWidth) {
                if (isLoop) {
                    fseek(self.fd, 0, SEEK_SET);
                    isContinue = YES;
                }
                isOk = NO;
                break;
            }
        }
    } while (isContinue);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    
    if ( !isOk ) {
        CVPixelBufferRelease(pixelBuffer);
        return nil;
    }

    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:pixelBuffer rotation:VideoRotation_0];
    
    CVPixelBufferRelease(pixelBuffer);
    return videoFrame;
}

- (VideoFrame*)readP010Frame:(BOOL) isLoop  {
    CVPixelBufferRef pixelBuffer = [PixelBufferTools createPixelBufferWithSize:CGSizeMake(self.width, self.height)
                                                                   pixelFormat:kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange];
    CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
    BOOL isContinue = NO;
    BOOL isOk = NO;
    do {
        isOk = YES;
        isContinue = NO;
        unsigned char *src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0));
        int srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        int srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) * 2;
        int srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        for (int i = 0; i < srcHeight; i++) {
            size_t read_size = read_data(src + srcStride * i, srcWidth, self.fd);
            if (read_size != srcWidth) {
                if (isLoop) {
                    fseek(self.fd, 0, SEEK_SET);
                    isContinue = YES;
                }
                isOk = NO;
                break;
            }
        }
        
        src = (unsigned char *)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1));
        srcStride = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
        srcWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1) * 4;
        srcHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        for (int i = 0; i < srcHeight; i++) {
            size_t read_size = read_data(src + srcStride * i, srcWidth, self.fd);
            if (read_size != srcWidth) {
                if (isLoop) {
                    fseek(self.fd, 0, SEEK_SET);
                    isContinue = YES;
                }
                isOk = NO;
                break;
            }
        }
    } while (isContinue);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
    
    if ( !isOk ) {
        CVPixelBufferRelease(pixelBuffer);
        return nil;
    }

    CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020, kCVAttachmentMode_ShouldPropagate);
    CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG, kCVAttachmentMode_ShouldPropagate);
    
    VideoFrame *videoFrame = [[VideoFrame alloc] initWithPixelBuffer:pixelBuffer rotation:VideoRotation_0];
    CVPixelBufferRelease(pixelBuffer);

    return videoFrame;
}

@end
