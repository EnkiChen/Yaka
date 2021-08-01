#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import "VideoFrame.h"

NS_ASSUME_NONNULL_BEGIN
/**
 * Protocol defining ability to render VideoFrame in Metal enabled views.
 */
@protocol MTLRenderer<NSObject>

/**
 * Method to be implemented to perform actual rendering of the provided frame.
 *
 * @param frame The frame to be rendered.
 */
- (void)drawFrame:(VideoFrame *)frame;

/**
 * Sets the provided view as rendering destination if possible.
 *
 * If not possible method returns NO and callers of the method are responisble for performing
 * cleanups.
 */

#if TARGET_OS_IOS
- (BOOL)addRenderingDestination:(__kindof UIView *)view;
#else
- (BOOL)addRenderingDestination:(__kindof NSView *)view;
#endif

@end

/**
 * Implementation of MTLRenderer protocol for rendering native nv12 video frames.
 */
NS_AVAILABLE(10_11, 9_0)
@interface MTLRenderer : NSObject<MTLRenderer>
@end

NS_ASSUME_NONNULL_END
