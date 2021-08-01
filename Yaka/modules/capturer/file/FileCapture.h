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
    kPixelFormatType_I420 = 0,
    kPixelFormatType_NV12 = 1,
};

@interface FileCapture : NSObject <ImageFileSourceInterface>

@property(nonatomic, assign) PixelFormatType format;

- (instancetype)initWithPath:(NSString*) filePath width:(NSUInteger) width height:(NSUInteger) height pixelFormatType:(PixelFormatType) format;

@end

NS_ASSUME_NONNULL_END
