//
//  H264SourceFileImp.h
//  Yaka
//
//  Created by Enki on 2019/8/31.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoSourceInterface.h"

NS_ASSUME_NONNULL_BEGIN

@interface NalUnitSourceFileImp : NSObject <H264FileSourceInterface>

- (instancetype)initWithPath:(NSString*) filePath;

@end

NS_ASSUME_NONNULL_END
