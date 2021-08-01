//
//  YuvFileDumper.h
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface YuvFileDumper : NSObject

- (instancetype)initWithPath:(NSString*) filePath;

- (void)dumpToFile:(VideoFrame *) frame;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
