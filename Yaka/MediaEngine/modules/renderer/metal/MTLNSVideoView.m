#import "MTLNSVideoView.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#import "VideoFrame.h"
#import "MTLI420Renderer.h"

@interface MTLNSVideoView ()<MTKViewDelegate>

@property(nonatomic) id<MTLRenderer> renderer;
@property(nonatomic, strong) MTKView *metalView;
@property(atomic, strong) VideoFrame *videoFrame;

@end

@implementation MTLNSVideoView {
    id<MTLRenderer> _renderer;
}

@synthesize renderer = _renderer;
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

#pragma mark - Private

+ (BOOL)isMetalAvailable {
    return [MTLCopyAllDevices() count] > 0;
}

- (void)configure {
    if ([[self class] isMetalAvailable]) {
        _metalView = [[MTKView alloc] initWithFrame:self.bounds];
        [self addSubview:_metalView];
        _metalView.layerContentsPlacement = NSViewLayerContentsPlacementScaleProportionallyToFit;
        _metalView.translatesAutoresizingMaskIntoConstraints = NO;
        _metalView.framebufferOnly = YES;
        _metalView.delegate = self;
        
        _renderer = [[MTLI420Renderer alloc] init];
        if (![(MTLI420Renderer *)_renderer addRenderingDestination:_metalView]) {
            _renderer = nil;
        };
    }
}

- (void)updateConstraints {
    NSDictionary *views = NSDictionaryOfVariableBindings(_metalView);
    
    NSArray *constraintsHorizontal =
    [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_metalView]-0-|"
                                            options:0
                                            metrics:nil
                                              views:views];
    [self addConstraints:constraintsHorizontal];
    
    NSArray *constraintsVertical =
    [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_metalView]-0-|"
                                            options:0
                                            metrics:nil
                                              views:views];
    [self addConstraints:constraintsVertical];
    [super updateConstraints];
}

#pragma mark - MTKViewDelegate methods
- (void)drawInMTKView:(nonnull MTKView *)view {
    if (self.videoFrame == nil) {
        return;
    }
    if (view == self.metalView) {
        [_renderer drawFrame:self.videoFrame];
    }
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

#pragma mark - VideoRenderer

- (void)setSize:(CGSize)size {
    _metalView.drawableSize = size;
    [_metalView draw];
}

- (void)renderFrame:(nullable VideoFrame *)frame {
    if (frame == nil) {
        return;
    }
    self.videoFrame = frame;
}

- (void)enableMirror:(BOOL) enableMirror {
    
}

@end

