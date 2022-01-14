//
//  MultiPlayView.m
//  Yaka
//
//  Created by Enki on 2022/1/12.
//  Copyright © 2022 Enki. All rights reserved.
//

#import "MultiPlayView.h"

@interface MultiPlayView ()

@end

@implementation MultiPlayView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self != nil) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (void)setup {
    self.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.spacing = 0;
    self.alignment = NSLayoutAttributeLeft;
}

- (void)setMaxPlayCount:(NSUInteger)maxPlayCount {
    _maxPlayCount = maxPlayCount;
}

- (void)renderFrame:(nullable VideoFrame *)frame withIndex:(NSUInteger)index {
    
}

- (void)enableMirror:(BOOL)enableMirror withIndex:(NSUInteger)index {
    
}

@end
