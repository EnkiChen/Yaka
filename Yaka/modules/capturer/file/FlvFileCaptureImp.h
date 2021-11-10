//
//  FlvFileCaptureImp.h
//  Yaka
//
//  Created by Enki on 2021/11/4.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoSourceInterface.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlvFileCaptureImp : NSObject <H264FileSourceInterface>

- (instancetype)initWithPath:(NSString*)filePath;

@end

NS_ASSUME_NONNULL_END
