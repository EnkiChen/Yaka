//
//  MultiPlayView.h
//  Yaka
//
//  Created by Enki on 2022/1/12.
//  Copyright © 2022 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class VideoFrame;

@interface MultiPlayView : NSStackView

@property(nonatomic, assign) NSUInteger maxPlayCount;

- (void)renderFrame:(nullable VideoFrame *)frame withIndex:(NSUInteger)index;

- (void)enableMirror:(BOOL)enableMirror withIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
