//
//  SampleRenderView.h
//  Yaka
//
//  Created by Enki on 2019/3/4.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VideoFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface SampleVideoRenderView : NSView <VideoRenderer>

@property(nonatomic, nullable) CGColorRef backgroundColor;

@end

NS_ASSUME_NONNULL_END
