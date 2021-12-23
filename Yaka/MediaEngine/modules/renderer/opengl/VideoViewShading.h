#import <Foundation/Foundation.h>
#import "OpenGLDefines.h"
#import "VideoFrame.h"

NS_ASSUME_NONNULL_BEGIN

@protocol VideoViewShading <NSObject>

- (void)enableMirror:(BOOL) enableMirror;

- (void)applyShadingForFrameWithWidth:(int)width
                               height:(int)height
                             rotation:(VideoRotation)rotation
                               yPlane:(GLuint)yPlane
                               uPlane:(GLuint)uPlane
                               vPlane:(GLuint)vPlane;

- (void)applyShadingForFrameWithWidth:(int)width
                               height:(int)height
                             rotation:(VideoRotation)rotation
                               yPlane:(GLuint)yPlane
                              uvPlane:(GLuint)uvPlane;

@end

NS_ASSUME_NONNULL_END
