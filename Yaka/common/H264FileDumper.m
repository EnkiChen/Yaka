//
//  H264FileDumper.m
//  Yaka
//
//  Created by Enki on 2019/11/16.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "H264FileDumper.h"

@interface H264FileDumper ()

@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, assign) FILE *fd;
@property(nonatomic, strong) NSLock *fdLock;

@end

@implementation H264FileDumper

- (instancetype)initWithPath:(NSString*) filePath {
    self = [super init];
    if ( self != nil ) {
        self.filePath = filePath;
        self.fd = fopen([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], "wb");
        self.fdLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dumpToFile:(Nal *) nal {
    [self.fdLock lock];
    if ( self.fd != nil ) {
        fwrite(nal.buffer.bytes, 1, nal.buffer.length, self.fd);
    }
    [self.fdLock unlock];
}

- (void)stop {
    [self.fdLock lock];
    fclose(self.fd);
    self.fd = nil;
    [self.fdLock unlock];
}

@end
