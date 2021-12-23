#if TARGET_OS_IPHONE

#import "MTLVideoView.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#import "VideoFrame.h"

#import "MTLI420Renderer.h"
#import "MTLNV12Renderer.h"

// To avoid unreconized symbol linker errors, we're taking advantage of the objc runtime.
// Linking errors occur when compiling for architectures that don't support Metal.
#define MTKViewClass NSClassFromString(@"MTKView")
#define MTLNV12RendererClass NSClassFromString(@"MTLNV12Renderer")
#define MTLI420RendererClass NSClassFromString(@"MTLI420Renderer")

@interface MTLVideoView () <MTKViewDelegate>
@property(nonatomic, strong) MTLI420Renderer *rendererI420;
@property(nonatomic, strong) MTLNV12Renderer *rendererNV12;
@property(nonatomic, strong) MTKView *metalView;
@property(atomic, strong) VideoFrame *videoFrame;
@end

@implementation MTLVideoView

@synthesize rendererI420 = _rendererI420;
@synthesize rendererNV12 = _rendererNV12;
@synthesize metalView = _metalView;
@synthesize videoFrame = _videoFrame;

- (instancetype)initWithFrame:(CGRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self configure];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aCoder {
    self = [super initWithCoder:aCoder];
    if (self) {
        [self configure];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self configure];
}

#pragma mark - Private

+ (BOOL)isMetalAvailable {
#if defined(_SUPPORTS_METAL)
    return YES;
#else
    return NO;
#endif
}

+ (MTKView *)createMetalView:(CGRect)frame {
    MTKView *view = [[MTKViewClass alloc] initWithFrame:frame];
    return view;
}

+ (MTLNV12Renderer *)createNV12Renderer {
    return [[MTLNV12RendererClass alloc] init];
}

+ (MTLI420Renderer *)createI420Renderer {
    return [[MTLI420RendererClass alloc] init];
}

- (void)configure {
    NSAssert([MTLVideoView isMetalAvailable], @"Metal not availiable on this device");
    
    _metalView = [MTLVideoView createMetalView:self.bounds];
    [self configureMetalView];
}

- (void)configureMetalView {
    if (_metalView) {
        _metalView.delegate = self;
        [self addSubview:_metalView];
        _metalView.contentMode = UIViewContentModeScaleAspectFit;
        _metalView.translatesAutoresizingMaskIntoConstraints = NO;
        UILayoutGuide *margins = self.layoutMarginsGuide;
        [_metalView.topAnchor constraintEqualToAnchor:margins.topAnchor].active = YES;
        [_metalView.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor].active = YES;
        [_metalView.leftAnchor constraintEqualToAnchor:margins.leftAnchor].active = YES;
        [_metalView.rightAnchor constraintEqualToAnchor:margins.rightAnchor].active = YES;
    }
}

#pragma mark - MTKViewDelegate methods

- (void)drawInMTKView:(nonnull MTKView *)view {
    NSAssert(view == self.metalView, @"Receiving draw callbacks from foreign instance.");
    if (!self.videoFrame) {
        return;
    }
    
    id<MTLRenderer> renderer = nil;
    if ([self.videoFrame.buffer isKindOfClass:[CVPixelBuffer class]]) {
        if (!self.rendererNV12) {
            self.rendererNV12 = [MTLVideoView createNV12Renderer];
            if (![self.rendererNV12 addRenderingDestination:self.metalView]) {
                self.rendererNV12 = nil;
                NSLog(@"Failed to create NV12 renderer");
            }
        }
        renderer = self.rendererNV12;
    } else {
        if (!self.rendererI420) {
            self.rendererI420 = [MTLVideoView createI420Renderer];
            if (![self.rendererI420 addRenderingDestination:self.metalView]) {
                self.rendererI420 = nil;
                NSLog(@"Failed to create I420 renderer");
            }
        }
        renderer = self.rendererI420;
    }
    
    [renderer drawFrame:self.videoFrame];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

#pragma mark - VideoRenderer

- (void)setSize:(CGSize)size {
    self.metalView.drawableSize = size;
}

- (void)renderFrame:(nullable VideoFrame *)frame {
    if (frame == nil) {
        NSLog(@"Incoming frame is nil. Exiting render callback.");
        return;
    }
    self.videoFrame = frame;
}

@end

#endif

