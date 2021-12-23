#import <Cocoa/Cocoa.h>
#import "VideoFrame.h"

NS_AVAILABLE_MAC(10.11)
@interface MTLNSVideoView : NSView<VideoRenderer>

+ (BOOL)isMetalAvailable;

@end
