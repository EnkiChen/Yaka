//
//  RateStatistics.m
//  Camera
//
//  Created by Enki on 2021/8/12.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "RateStatistics.h"

@interface Bucket : NSObject

@property(nonatomic, assign) uint64_t count;
@property(nonatomic, assign) uint64_t timestamp;

@end

@implementation Bucket

@end

@interface RateStatistics ()

@property(nonatomic, assign) uint64_t windowSize;
@property(nonatomic, strong) NSMutableArray *buckets;
@property(nonatomic, strong) NSLock *bucketsLock;

@end

@implementation RateStatistics

- (instancetype)initWithWindowSize:(uint64_t) windowSize {
    self = [super init];
    if (self) {
        self.buckets = [[NSMutableArray alloc] initWithCapacity:512];
        self.bucketsLock = [[NSLock alloc] init];
        self.windowSize = windowSize;
    }
    return self;
}

- (void)update:(uint64_t) count now:(uint64_t) now_ms {
    [self.bucketsLock lock];
    [self eraseOld:now_ms];
    Bucket *bucket = nil;
    for (Bucket *b in self.buckets) {
        if (b.timestamp == now_ms) {
            bucket = b;
        }
    }
    if (bucket == nil) {
        bucket = [[Bucket alloc] init];
        bucket.count = count;
        bucket.timestamp = now_ms;
        [self.buckets addObject:bucket];
    } else {
        bucket.count += count;
    }
    [self.bucketsLock unlock];
}

- (uint64_t)rate:(uint64_t) now_ms {
    [self.bucketsLock lock];
    [self eraseOld:now_ms];
    uint64_t bitrate = 0;
    for (Bucket *bucket in self.buckets) {
        bitrate += bucket.count;
    }
    [self.bucketsLock unlock];
    return bitrate;
}

- (uint64_t)frameRate:(uint64_t) now_ms {
    [self.bucketsLock lock];
    [self eraseOld:now_ms];
    uint64_t framerate = self.buckets.count;
    [self.bucketsLock unlock];
    return framerate;
}

- (void)eraseOld:(int64_t) now_ms {
    while (self.buckets.count > 0) {
        Bucket *bucket = self.buckets.firstObject;
        if (now_ms - bucket.timestamp > self.windowSize) {
            [self.buckets removeObject:bucket];
        } else {
            break;
        }
    }
}

@end
