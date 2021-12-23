//
//  FileCapture.h
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoSourceInterface.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PixelFormatType) {
    kPixelFormatType_420_I420 = 0,  // 8bit  YYYY UU VV
    kPixelFormatType_420_YV12,      // 8bit  YYYY VV UU
    kPixelFormatType_420_I010,      // 10bit YYYY UU VV
    kPixelFormatType_420_NV12,      // 8bit  YYYY UVUV
    kPixelFormatType_420_NV21,      // 8bit  YYYY VUVU
    kPixelFormatType_420_P010,      // 10bit YYYY UVUV
    kPixelFormatType_422_I422,      // 8bit  YYYY UU VV
    kPixelFormatType_422_YV16,      // 8bit  YYYY VV UU
    kPixelFormatType_422_NV16,      // 8bit  YYYY UVUV
    kPixelFormatType_422_NV61,      // 8bit  YYYY VUVU
    kPixelFormatType_422_YUVY,      // 8bit  YUVY YUVY YUVY
    kPixelFormatType_422_VYUY,      // 8bit  VYUY VYUY VYUY
    kPixelFormatType_422_UYVY,      // 8bit  UYVY UYVY UYVY
    kPixelFormatType_444_I444,      // 8bit  YYYY UUUU VVVV
    kPixelFormatType_444_YV24,      // 8bit  YYYY VVVV UUUU
    kPixelFormatType_444_NV24,      // 8bit  YYYY UVUVUVUVUV
    kPixelFormatType_444_NV42,      // 8bit  YYYY VUVUVUVUVU
    kPixelFormatType_444_YUV,       // 8bit  YUV YUV YUV YUV
};

@interface FileCapture : NSObject <ImageFileSourceInterface>

@property(nonatomic, assign) PixelFormatType format;

- (instancetype)initWithPath:(NSString*) filePath width:(NSUInteger) width height:(NSUInteger) height pixelFormatType:(PixelFormatType) format;

@end

NS_ASSUME_NONNULL_END
