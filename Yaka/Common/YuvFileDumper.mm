//
//  YuvFileDumper.m
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "YuvFileDumper.h"

namespace {

void Write2File(FILE* pFp, uint8_t* pData[3], int iStride[2], int iWidth, int iHeight) {
    int i = 0;
    unsigned char* pPtr = NULL;
    
    pPtr = pData[0];
    for (i = 0; i < iHeight; i++) {
        fwrite (pPtr, 1, iWidth, pFp);
        pPtr += iStride[0];
    }
    
    iHeight = (iHeight + 1) / 2;
    iWidth = (iWidth + 1) / 2;
    pPtr = pData[1];
    for (i = 0; i < iHeight; i++) {
        fwrite (pPtr, 1, iWidth, pFp);
        pPtr += iStride[1];
    }
    
    pPtr = pData[2];
    for (i = 0; i < iHeight; i++) {
        fwrite (pPtr, 1, iWidth, pFp);
        pPtr += iStride[1];
    }
    
    fflush(pFp);
}

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

}

@interface YuvFileDumper ()

@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, assign) FILE *fd_yuv;
@property(nonatomic, strong) NSLock *fdLock;

@property(nonatomic, assign) NSUInteger index;

@property(nonatomic, strong) NSMutableArray<VideoFrame*> *frameOrderedList;

@end

@implementation YuvFileDumper

- (instancetype)initWithPath:(NSString*)filePath {
    self = [super init];
    if ( self != nil ) {
        self.filePath = filePath;
        self.index = 0;
        self.startIndex = 0;
        self.total = -1;
        self.isOrdered = NO;
        self.frameOrderedList = [[NSMutableArray alloc] initWithCapacity:3];
    }
    return self;
}

- (void)setup {
    if (self.fdLock == nil) {
        self.fdLock = [[NSLock alloc] init];
    }
    
    self.fd_yuv = fopen([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (void)dumpToFile:(VideoFrame *)frame {
    if (!self.isOrdered) {
        [self dumpFrame:frame];
        return;
    }
    
    frame = [self pushFrameToOrderedlist:frame];
    if (frame == nil) {
        return;
    }
    [self dumpFrame:frame];
}

- (void)flush {
    while (self.frameOrderedList.count != 0) {
        [self dumpFrame:self.frameOrderedList.firstObject];
        [self.frameOrderedList removeObjectAtIndex:0];
    }
    fflush(self.fd_yuv);
}

- (void)stop {
    [self flush];
    [self.fdLock lock];
    self.index = 0;
    self.startIndex = 0;
    self.total = -1;
    fclose(self.fd_yuv);
    self.fd_yuv = NULL;
    [self.fdLock unlock];
}

- (void)dumpFrame:(VideoFrame *)frame {
    if ( self.fd_yuv == NULL ) {
        [self setup];
    }
    
    if ( self.fd_yuv == NULL ) {
        return;
    }
    
    if (self.index++ < self.startIndex) {
        return;
    }
    
    if (self.total != -1 && self.index - self.startIndex > self.total) {
        return;
    }
    
    [self.fdLock lock];
    if ([frame.buffer isKindOfClass:CVPixelBuffer.class]) {
        CVPixelBuffer *pixelBuffer = (CVPixelBuffer*)frame.buffer;
        const OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer.pixelBuffer);
        if (format == kCVPixelFormatType_420YpCbCr8Planar) {
            [self writeToFile:pixelBuffer.pixelBuffer fd:self.fd_yuv];
            [self.fdLock unlock];
            return;
        } else if (format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange) {
            [self writeI010ToFile:pixelBuffer.pixelBuffer fd:self.fd_yuv];
            [self.fdLock unlock];
            return;
        }
    }
    id<I420Buffer> buffer = [frame.buffer toI420];
    uint8_t* data[3] = {(uint8_t*)buffer.dataY, (uint8_t*)buffer.dataU, (uint8_t*)buffer.dataV};
    int stride[2] = {buffer.strideY, buffer.strideU};
    if ( self.fd_yuv != nil ) {
        Write2File(self.fd_yuv, data, stride, frame.width, frame.height);
    }
    [self.fdLock unlock];
}

- (VideoFrame*)pushFrameToOrderedlist:(VideoFrame*)frame {
    NSUInteger index = 0;
    for (; index < self.frameOrderedList.count; index++) {
        if (CMTimeCompare(frame.presentationTimeStamp, self.frameOrderedList[index].presentationTimeStamp) == -1) {
            break;
        }
    }
    
    [self.frameOrderedList insertObject:frame atIndex:index];
    
    if (self.frameOrderedList.count < 4) {
        return nil;
    } else {
        frame = self.frameOrderedList.firstObject;
        [self.frameOrderedList removeObjectAtIndex:0];
        return frame;
    }
}

- (void)writeToFile:(CVPixelBufferRef)pixelBuffer fd:(FILE*)fd {
    const OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        int factor = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ? 2 : 1;
        int planeCount = (int)CVPixelBufferGetPlaneCount(pixelBuffer);
        for (int i = 0; i < planeCount; i++) {
            const uint8_t* src = (const uint8_t*)(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i));
            const size_t srcStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i);
            const size_t srcWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
            const size_t srcHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
            size_t size = (i == 0) ? srcWidth * factor : srcWidth * ((planeCount == 2) ? 2 : 1) * factor;
            for (int i = 0; i < srcHeight; i++) {
                fwrite(src + srcStride * i, 1, size, fd);
                fflush(fd);
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (void)writeI010ToFile:(CVPixelBufferRef)pixelBuffer fd:(FILE*)fd {
    const OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange == format) {
        I010Buffer *i010buffer = [self convertToI010:pixelBuffer];
        for (int i = 0; i < i010buffer.height; i++) {
            fwrite(i010buffer.dataY + i010buffer.strideY * i, 1, i010buffer.width * 2, fd);
            fflush(fd);
        }
        for (int i = 0; i < i010buffer.height / 4; i++) {
            fwrite(i010buffer.dataU + i010buffer.strideU * i, 1, i010buffer.width * 2, fd);
            fflush(fd);
        }
        for (int i = 0; i < i010buffer.height / 4; i++) {
            fwrite(i010buffer.dataV + i010buffer.strideV * i, 1, i010buffer.width * 2, fd);
            fflush(fd);
        }
    }
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
