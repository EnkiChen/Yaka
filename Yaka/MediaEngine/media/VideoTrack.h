//
//  VideoTrack.h
//  Yaka
//
//  Created by Enki on 2021/12/29.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoSourceInterface.h"
#import "FileCapture.h"

NS_ASSUME_NONNULL_BEGIN

@interface VideoTrack : NSObject <FileSourceInterface, VideoSourceInterface>

- (instancetype)initWithRawFile:(NSString *)filePath
                          width:(NSInteger)width
                         height:(NSInteger)height
                    pixelFormat:(PixelFormatType)format;

- (instancetype)initWithNalFile:(NSString *)filePath;

- (instancetype)initWithFlvFile:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
