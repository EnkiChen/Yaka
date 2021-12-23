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

@property(nonatomic, assign) NSUInteger startIndex;
@property(nonatomic, assign) NSInteger total;
@property(nonatomic, assign) BOOL isOrdered;

- (instancetype)initWithPath:(NSString*)filePath;

- (void)dumpToFile:(VideoFrame *)frame;

- (void)flush;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
