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

+ (CGImagePropertyOrientation)getOrientation:(CMSampleBufferRef) sampleBuffer;

+ (CVPixelBufferRef)createPixelBufferWithSize:(CGSize) size pixelFormat:(OSType) format;

+ (CVPixelBufferRef)copyPixelBuffer:(CVPixelBufferRef) pixelBuffer;

+ (CVPixelBufferRef)createAndRotatePixelBuffer:(CVPixelBufferRef) pixelBuffer rotationConstant:(uint8_t) rotationConstant;

+ (CVPixelBufferRef)createAndscalePixelBuffer:(CVPixelBufferRef)srcPixelBuffer ScaleSize:(CGSize) size;

+ (CVPixelBufferRef)convertTo32BGRA:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
