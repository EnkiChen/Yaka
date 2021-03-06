/*
 *  Copyright 2017 The Web project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE

#import "VideoFrame.h"

// Check if metal is supported in Web.
// NOTE: Currently arm64 == Metal.
#if defined(__aarch64__)
#define _SUPPORTS_METAL
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * MTLVideoView is thin wrapper around MTKView.
 *
 * It has id<VideoRenderer> property that renders video frames in the view's
 * bounds using Metal.
 * NOTE: always check if metal is available on the running device via
 * _SUPPORTS_METAL macro before initializing this class.
 */
NS_CLASS_AVAILABLE_IOS(9)

@interface MTLVideoView : UIView <VideoRenderer>

@end

NS_ASSUME_NONNULL_END

#endif
