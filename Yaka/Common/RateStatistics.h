//
//  RateStatistics.h
//  Camera
//
//  Created by Enki on 2021/8/12.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RateStatistics : NSObject

- (instancetype)initWithWindowSize:(uint64_t) windowSize;

- (void)update:(uint64_t) count now:(uint64_t) now_ms;

- (uint64_t)rate:(uint64_t) now_ms;

- (uint64_t)frameRate:(uint64_t) now_ms;

@end

NS_ASSUME_NONNULL_END
