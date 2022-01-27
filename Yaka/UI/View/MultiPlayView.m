//
//  MultiPlayView.m
//  Yaka
//
//  Created by Enki on 2022/1/12.
//  Copyright © 2022 Enki. All rights reserved.
//

#import "MultiPlayView.h"
#import "SampleVideoRenderView.h"

@interface MultiPlayView ()

@property (nonatomic, strong) NSMutableArray<SampleVideoRenderView *>* renderViews;

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
    self.renderViews = [[NSMutableArray alloc] initWithCapacity:5];
    self.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.alignment = NSLayoutAttributeCenterY;
    self.distribution = NSStackViewDistributionFillEqually;
    self.spacing = 0;
    self.maxPlayCount = 1;
}

- (void)setMaxPlayCount:(NSUInteger)maxPlayCount {
    if (_maxPlayCount == maxPlayCount) {
        return;
    }
    if (_maxPlayCount < maxPlayCount) {
        for (; _maxPlayCount < maxPlayCount; _maxPlayCount++) {
            SampleVideoRenderView *renderView = [[SampleVideoRenderView alloc] initWithFrame:self.bounds];
            [self setupStyle:renderView];
            [self addArrangedSubview:renderView];
            [self.renderViews addObject:renderView];
        }
    } else {
        for (; _maxPlayCount > maxPlayCount; _maxPlayCount--) {
            SampleVideoRenderView *renderView = [self.arrangedSubviews lastObject];
            [self removeArrangedSubview:renderView];
            [self.renderViews removeObject:renderView];
        }
    }
}

- (void)renderFrame:(nullable VideoFrame *)frame {
    [self renderFrame:frame withIndex:0];
}

- (void)renderFrame:(nullable VideoFrame *)frame withIndex:(NSUInteger)index {
    if (index >= self.renderViews.count) {
        return;
    }
    SampleVideoRenderView *renderView = [self.renderViews objectAtIndex:index];
    [renderView renderFrame:frame];
}

- (void)enableMirror:(BOOL)enableMirror withIndex:(NSUInteger)index {
    if (index >= self.renderViews.count) {
        return;
    }
    SampleVideoRenderView *renderView = [self.renderViews objectAtIndex:index];
    [renderView enableMirror:enableMirror];
}

- (void)setupStyle:(SampleVideoRenderView *)renderView {
    
}

@end
