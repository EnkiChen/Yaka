//
//  VideoFrame.h
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VideoRotation) {
    VideoRotation_0 = 0,
    VideoRotation_90 = 90,
    VideoRotation_180 = 180,
    VideoRotation_270 = 270,
};

@class VideoFrame;
@protocol I420Buffer;

@protocol VideoRenderer <NSObject>

- (void)renderFrame:(nullable VideoFrame *)frame;

- (void)enableMirror:(BOOL) enableMirror;

@end

// VideoFrameBuffer is an ObjectiveC version of web::VideoFrameBuffer.
@protocol VideoFrameBuffer <NSObject>

@property(nonatomic, readonly) int width;
@property(nonatomic, readonly) int height;

- (id<I420Buffer>)toI420;

@end

/** Protocol for VideoFrameBuffers containing YUV planar data. */
@protocol YUVPlanarBuffer <VideoFrameBuffer>

@property(nonatomic, readonly) int chromaWidth;
@property(nonatomic, readonly) int chromaHeight;
@property(nonatomic, readonly) const uint8_t *dataY;
@property(nonatomic, readonly) const uint8_t *dataU;
@property(nonatomic, readonly) const uint8_t *dataV;
@property(nonatomic, readonly) int strideY;
@property(nonatomic, readonly) int strideU;
@property(nonatomic, readonly) int strideV;

- (instancetype)initWithWidth:(int)width height:(int)height;
- (instancetype)initWithWidth:(int)width
                       height:(int)height
                      strideY:(int)strideY
                      strideU:(int)strideU
                      strideV:(int)strideV;

@end

/** Extension of the YUV planar data buffer with mutable data access */
@protocol MutableYUVPlanarBuffer <YUVPlanarBuffer>

@property(nonatomic, readonly) uint8_t *mutableDataY;
@property(nonatomic, readonly) uint8_t *mutableDataU;
@property(nonatomic, readonly) uint8_t *mutableDataV;

@end

/** Protocol for YUVPlanarBuffers containing I420 data */
@protocol I420Buffer <YUVPlanarBuffer>
@end

/** Extension of the I420 buffer with mutable data access */
@protocol MutableI420Buffer <I420Buffer, MutableYUVPlanarBuffer>
@end

/** VideoFrameBuffer containing a CVPixelBufferRef */
@interface CVPixelBuffer : NSObject <VideoFrameBuffer>

@property(nonatomic, readonly) CVPixelBufferRef pixelBuffer;

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef) pixelBuffer;

@end

/** I420Buffer implements the I420Buffer protocol */
@interface I420Buffer : NSObject <I420Buffer>
@end

/** Mutable version of I420Buffer */
@interface MutableI420Buffer : I420Buffer <MutableI420Buffer>
@end

@interface VideoFrame : NSObject

@property(nonatomic, readonly) int width;
@property(nonatomic, readonly) int height;

@property(nonatomic, readonly) VideoRotation rotation;

@property(nonatomic, assign) CMTime pts;

@property(nonatomic, readonly) id<VideoFrameBuffer> buffer;


- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithBuffer:(id<VideoFrameBuffer>)frameBuffer
                      rotation:(VideoRotation)rotation;

- (instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                           rotation:(VideoRotation)rotation;

@end

@interface NalBuffer : NSObject

@property(readonly) uint8_t* bytes;
@property(readonly) NSUInteger length;

- (instancetype)initWithBytes:(const void*) buffer length:(int) length;

- (instancetype)initWithLength:(int) length;

@end

@interface NalMutableBuffer : NalBuffer

- (void)appendBytes:(const void *)bytes length:(NSUInteger)length;

@end

@interface Nal : NSObject

@property(nonatomic, readonly) NalBuffer *buffer;

@property(nonatomic, assign) double encodeTime;
@property(nonatomic, assign) int type;

- (instancetype)initWithNalBuffer:(NalBuffer *) buffer;

@end

NS_ASSUME_NONNULL_END
