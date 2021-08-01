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
@property(nonatomic, strong) dispatch_queue_t dump_queue;

@end

@implementation YuvFileDumper

- (instancetype)initWithPath:(NSString*) filePath {
    self = [super init];
    if ( self != nil ) {
        self.filePath = filePath;
    }
    return self;
}

- (void)setup {
    self.fdLock = [[NSLock alloc] init];
    self.dump_queue = dispatch_queue_create("com.yaka.dump_queue", nil);
    self.fd_yuv = fopen([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (void)dumpToFile:(VideoFrame *)frame {
    if (self.dump_queue == nil ){
        [self setup];
    }
    if ( self.fd_yuv == NULL ) {
        self.fd_yuv = fopen([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], "wb");
    }
    if ( self.fd_yuv == NULL ) {
        return;
    }
    [frame.buffer toI420];
    dispatch_async(self.dump_queue, ^{
        id<I420Buffer> buffer = [frame.buffer toI420];
        uint8_t* data[3] = {(uint8_t*)buffer.dataY, (uint8_t*)buffer.dataU, (uint8_t*)buffer.dataV};
        int stride[2] = {buffer.strideY, buffer.strideU};
        [self.fdLock lock];
        if ( self.fd_yuv != nil ) {
            Write2File(self.fd_yuv, data, stride, frame.width, frame.height);
        }
        [self.fdLock unlock];
    });
}

- (void)stop {
    [self.fdLock lock];
    fclose(self.fd_yuv);
    self.fd_yuv = NULL;
    [self.fdLock unlock];
}

@end
