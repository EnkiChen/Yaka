//
//  YuvFileDumper.m
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "YuvFileDumper.h"

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

@interface YuvFileDumper ()

@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, assign) FILE *fd_yuv;
@property(nonatomic, strong) NSLock *fdLock;

@property(nonatomic, assign) NSUInteger index;

@end

@implementation YuvFileDumper

- (instancetype)initWithPath:(NSString*)filePath {
    self = [super init];
    if ( self != nil ) {
        self.filePath = filePath;
        self.index = 0;
        self.startIndex = 0;
        self.total = -1;
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

- (void)stop {
    [self.fdLock lock];
    self.index = 0;
    self.startIndex = 0;
    self.total = -1;
    fclose(self.fd_yuv);
    self.fd_yuv = NULL;
    [self.fdLock unlock];
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
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

@end
