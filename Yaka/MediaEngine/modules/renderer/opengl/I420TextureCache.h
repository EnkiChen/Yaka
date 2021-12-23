#import "OpenGLDefines.h"
#import "VideoFrame.h"

@interface I420TextureCache : NSObject

@property(nonatomic, readonly) GLuint yTexture;
@property(nonatomic, readonly) GLuint uTexture;
@property(nonatomic, readonly) GLuint vTexture;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithContext:(GlContextType *)context NS_DESIGNATED_INITIALIZER;

- (void)uploadFrameToTextures:(VideoFrame *)frame;

@end
