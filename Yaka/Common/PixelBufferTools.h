//
//  PixelBufferTool.h
//  Yaka
//
//  Created by Enki on 2021/7/23.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PixelBufferTools : NSObject

+ (void)writeToFile:(CVPixelBufferRef)pixelBuffer fd:(FILE*)fd;

+ (CGImagePropertyOrientation)getOrientation:(CMSampleBufferRef) sampleBuffer;

+ (CMSampleBufferRef)createSampleBufferWithPixelBuffer:(CVPixelBufferRef)pixelBuffer;

+ (CMSampleBufferRef)createSampleBufferWithPixelBuffer:(CVPixelBufferRef)pixelBuffer from:(CMSampleBufferRef)sampleBuffer;

+ (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size pixelFormat:(OSType)format;

+ (CVPixelBufferRef)createPixelBufferWithSize:(CGSize)size from:(CVPixelBufferRef)src;

+ (CVPixelBufferRef)copyPixelBuffer:(CVPixelBufferRef)pixelBuffer;

+ (CVPixelBufferRef)createAndRotatePixelBuffer:(CVPixelBufferRef)pixelBuffer rotationConstant:(uint8_t)rotationConstant;

+ (CVPixelBufferRef)createAndscalePixelBuffer:(CVPixelBufferRef)srcPixelBuffer scaleSize:(CGSize)size;

+ (CVPixelBufferRef)scaleCropPixelBuffer:(CVPixelBufferRef)src cropSize:(CGSize)size;

+ (CVPixelBufferRef)convertTo32BGRA:(CVPixelBufferRef)pixelBuffer;

+ (CVPixelBufferRef)mirrorPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
