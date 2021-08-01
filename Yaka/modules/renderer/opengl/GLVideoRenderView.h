//
//  NSGLVideoView.h
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VideoFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface GLVideoRenderView : NSOpenGLView <VideoRenderer>

@end

NS_ASSUME_NONNULL_END
