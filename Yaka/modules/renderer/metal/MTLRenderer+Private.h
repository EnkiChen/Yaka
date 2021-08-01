#import <Metal/Metal.h>
#import "MTLRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface MTLRenderer (Private)

- (nullable id<MTLDevice>)currentMetalDevice;

- (NSString *)shaderSource;

- (BOOL)setupTexturesForFrame:(nonnull VideoFrame *)frame;

- (void)uploadTexturesToRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;

@end

NS_ASSUME_NONNULL_END
