//
//  H264FileDumper.h
//  Yaka
//
//  Created by Enki on 2019/11/16.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface H264FileDumper : NSObject

- (instancetype)initWithPath:(NSString*) filePath;

- (void)dumpToFile:(Nal *) nal;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
