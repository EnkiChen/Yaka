//
//  FileUnit.m
//  Yaka
//
//  Created by Enki on 2021/11/8.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "FileUnit.h"

@implementation FileUnit

- (instancetype)init {
    self = [super init];
    if ( self ) {
        self.offset = 0;
        self.length = 0;
    }
    return self;
}

- (instancetype)initWithOffset:(long)offset length:(long)length {
    self = [super init];
    if ( self ) {
        self.offset = offset;
        self.length = length;
    }
    return self;
}

@end
