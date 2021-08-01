//
//  VideoFrame.m
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "VideoFrame.h"
#include "I420Buffer.h"
#include "libyuv.h"

@implementation VideoFrame {
    VideoRotation _rotation;
}

- (int)width {
    return _buffer.width;
}

- (int)height {
    return _buffer.height;
}

- (instancetype)initWithBuffer:(id<VideoFrameBuffer>)buffer
                      rotation:(VideoRotation)rotation {
    if (self = [super init]) {
        _buffer = buffer;
        _rotation = rotation;
    }
    
    return self;
}

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                           rotation:(VideoRotation)rotation {
    return [self initWithBuffer:[[CVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer]
                       rotation:rotation];
}

@end

@implementation I420Buffer {
@protected
    std::shared_ptr<YUV::I420Buffer> _i420Buffer;
}

- (instancetype)initWithWidth:(int)width height:(int)height {
    if (self = [super init]) {
        _i420Buffer = YUV::I420Buffer::Create(width, height);
    }
    
    return self;
}

- (instancetype)initWithWidth:(int)width
                       height:(int)height
                      strideY:(int)strideY
                      strideU:(int)strideU
                      strideV:(int)strideV {
    if (self = [super init]) {
        _i420Buffer = YUV::I420Buffer::Create(width, height, strideY, strideU, strideV);
    }
    
    return self;
}

- (instancetype)initWithFrameBuffer:(std::shared_ptr<YUV::I420Buffer>)i420Buffer {
    if (self = [super init]) {
        _i420Buffer = i420Buffer;
    }
    
    return self;
}

- (int)width {
    return _i420Buffer->width();
}

- (int)height {
    return _i420Buffer->height();
}

- (int)strideY {
    return _i420Buffer->StrideY();
}

- (int)strideU {
    return _i420Buffer->StrideU();
}

- (int)strideV {
    return _i420Buffer->StrideV();
}

- (int)chromaWidth {
    return (_i420Buffer->width() + 1) / 2;
}

- (int)chromaHeight {
    return (_i420Buffer->height() + 1) / 2;
}

- (const uint8_t *)dataY {
    return _i420Buffer->DataY();
}

- (const uint8_t *)dataU {
    return _i420Buffer->DataU();
}

- (const uint8_t *)dataV {
    return _i420Buffer->DataV();
}

- (id<I420Buffer>)toI420 {
    return self;
}

@end

@implementation MutableI420Buffer

- (uint8_t *)mutableDataY {
    return static_cast<YUV::I420Buffer *>(_i420Buffer.get())->DataY();
}

- (uint8_t *)mutableDataU {
    return static_cast<YUV::I420Buffer *>(_i420Buffer.get())->DataU();
}

- (uint8_t *)mutableDataV {
    return static_cast<YUV::I420Buffer *>(_i420Buffer.get())->DataV();
}

@end

@interface CVPixelBuffer ()

@property(nonatomic, strong) MutableI420Buffer* i420Buffer;

@end

@implementation CVPixelBuffer {
    int _bufferWidth;
    int _bufferHeight;
    uint8_t *cache_;
}

@synthesize pixelBuffer = _pixelBuffer;

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (self = [super init]) {
        _pixelBuffer = pixelBuffer;
        _bufferWidth = int(CVPixelBufferGetWidth(_pixelBuffer));
        _bufferHeight = int(CVPixelBufferGetHeight(_pixelBuffer));
        CVBufferRetain(_pixelBuffer);
    }
    return self;
}

- (void)dealloc {
    free(cache_);
    CVBufferRelease(_pixelBuffer);
}

- (int)width {
    return _bufferWidth;
}

- (int)height {
    return _bufferHeight;
}

- (id<I420Buffer>)toI420 {
    
    if ( self.i420Buffer ) {
        return self.i420Buffer;
    }
    
    const OSType pixelFormat = CVPixelBufferGetPixelFormatType(_pixelBuffer);
    
    CVPixelBufferLockBaseAddress(_pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if ( pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ) {
        
        self.i420Buffer = [[MutableI420Buffer alloc] initWithWidth:self.width height:self.height];
        
        const uint8_t* srcY = static_cast<const uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(_pixelBuffer, 0));
        const size_t srcYStride = CVPixelBufferGetBytesPerRowOfPlane(_pixelBuffer, 0);
        const uint8_t* srcUV = static_cast<const uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(_pixelBuffer, 1));
        const size_t srcUVStride = CVPixelBufferGetBytesPerRowOfPlane(_pixelBuffer, 1);
        
        libyuv::NV12ToI420(srcY, int(srcYStride), srcUV, int(srcUVStride),
                           self.i420Buffer.mutableDataY, self.i420Buffer.strideY,
                           self.i420Buffer.mutableDataU, self.i420Buffer.strideU,
                           self.i420Buffer.mutableDataV, self.i420Buffer.strideV,
                           self.i420Buffer.width, self.i420Buffer.height);

    } else if ( pixelFormat == kCVPixelFormatType_420YpCbCr8Planar ) {
        
        const int stride_y = self.width;
        const int stride_u = int(CVPixelBufferGetBytesPerRowOfPlane(_pixelBuffer, 1));
        const int stride_v = int(CVPixelBufferGetBytesPerRowOfPlane(_pixelBuffer, 2));
        self.i420Buffer = [[MutableI420Buffer alloc] initWithWidth:self.width
                                                            height:self.height
                                                           strideY:stride_y
                                                           strideU:stride_u
                                                           strideV:stride_v];
        
        const uint8_t* srcY = static_cast<const uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(_pixelBuffer, 0));
        memcpy(self.i420Buffer.mutableDataY, srcY, stride_y * self.height);
        
        const uint8_t* srcU = static_cast<const uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(_pixelBuffer, 1));
        const size_t srcUHeight = CVPixelBufferGetHeightOfPlane(_pixelBuffer, 1);
        memcpy(self.i420Buffer.mutableDataU, srcU, stride_u * srcUHeight);
        
        const uint8_t* srcV = static_cast<const uint8_t*>(CVPixelBufferGetBaseAddressOfPlane(_pixelBuffer, 2));
        const size_t srcVHeight = CVPixelBufferGetHeightOfPlane(_pixelBuffer, 2);
        memcpy(self.i420Buffer.mutableDataV, srcV, stride_v * srcVHeight);

    } else if ( pixelFormat == kCVPixelFormatType_32ARGB ) {
        
        self.i420Buffer = [[MutableI420Buffer alloc] initWithWidth:self.width height:self.height];
        const uint8_t* src = (uint8_t *)CVPixelBufferGetBaseAddress(_pixelBuffer);
        int rowBytes = (int)CVPixelBufferGetBytesPerRow(_pixelBuffer);
        int width = (int)CVPixelBufferGetWidth(_pixelBuffer);
        int height = (int)CVPixelBufferGetHeight(_pixelBuffer);
        
        if (cache_ == NULL) {
            cache_ = (uint8_t*)malloc(rowBytes * height);
        }
        
        libyuv::ARGBToBGRA(src, rowBytes, cache_, rowBytes, width, height);
        libyuv::ARGBToI420(cache_, rowBytes,
                           self.i420Buffer.mutableDataY, self.i420Buffer.strideY,
                           self.i420Buffer.mutableDataU, self.i420Buffer.strideU,
                           self.i420Buffer.mutableDataV, self.i420Buffer.strideV,
                           self.i420Buffer.width, self.i420Buffer.height);

    } else if ( pixelFormat == kCVPixelFormatType_32BGRA ) {
        
        self.i420Buffer = [[MutableI420Buffer alloc] initWithWidth:self.width height:self.height];
        const uint8_t* src = (uint8_t *)CVPixelBufferGetBaseAddress(_pixelBuffer);
        int rowBytes = (int)CVPixelBufferGetBytesPerRow(_pixelBuffer);
        libyuv::ARGBToI420(src, rowBytes,
                           self.i420Buffer.mutableDataY, self.i420Buffer.strideY,
                           self.i420Buffer.mutableDataU, self.i420Buffer.strideU,
                           self.i420Buffer.mutableDataV, self.i420Buffer.strideV,
                           self.i420Buffer.width, self.i420Buffer.height);
    }
    
    CVPixelBufferUnlockBaseAddress(_pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    return self.i420Buffer;
}

@end

@interface NalBuffer ()
@property(nonatomic, strong) NSMutableData *data;
@end

@implementation NalBuffer

- (instancetype)initWithBytes:(const void*) buffer length:(int) length {
    self = [super init];
    if ( self ) {
        self.data = [[NSMutableData alloc] initWithBytes:buffer length:length];
    }
    return self;
}

- (instancetype)initWithLength:(int) length {
    self = [super init];
    if ( self ) {
        self.data = [[NSMutableData alloc] initWithLength:length];
    }
    return self;
}

- (uint8_t* )bytes {
    return (uint8_t*)self.data.mutableBytes;
}

- (NSUInteger)length {
    return self.data.length;
}

@end

@implementation NalMutableBuffer

- (void)appendBytes:(const void *)bytes length:(NSUInteger)length {
    [self.data appendBytes:bytes length:length];
}

@end

@interface Nal ()

@property(nonatomic, strong) NalBuffer *buffer;

@end

@implementation Nal

- (instancetype)initWithNalBuffer:(NalBuffer *) buffer {
    self = [super init];
    if ( self ) {
        self.buffer = buffer;
    }
    return self;
}


@end
