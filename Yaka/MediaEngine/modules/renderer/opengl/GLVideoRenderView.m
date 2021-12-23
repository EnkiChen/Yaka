//
//  NSGLVideoView.m
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <CoreVideo/CVDisplayLink.h>
#import <OpenGL/gl3.h>

#import "GLVideoRenderView.h"
#import "DefaultShader.h"
#import "I420TextureCache.h"

@interface GLVideoRenderView ()

@property(atomic, strong) VideoFrame *videoFrame;

@property(atomic, strong) id<VideoViewShading> shader;
@property(atomic, strong) I420TextureCache *i420TextureCache;

@property(atomic, assign) NSRect glViewBounds;
@property(atomic, assign) CGSize lastVideoFrameSize;
@property(atomic, assign) bool reshaped;

@property(atomic, assign) bool enableMirror;
@property(atomic, assign) CGFloat backingScale;

- (void)drawFrame;

@end

static CVReturn OnDisplayLinkFired(CVDisplayLinkRef displayLink,
                                   const CVTimeStamp *now,
                                   const CVTimeStamp *outputTime,
                                   CVOptionFlags flagsIn,
                                   CVOptionFlags *flagsOut,
                                   void *displayLinkContext) {
    @autoreleasepool {
        GLVideoRenderView *view = (__bridge GLVideoRenderView *)displayLinkContext;
        @synchronized (view) {
            [view drawFrame];
        }
    }
    return kCVReturnSuccess;
}

@implementation GLVideoRenderView {
    CVDisplayLinkRef _displayLink;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    self.wantsBestResolutionOpenGLSurface = YES;
    self.backingScale = [self window].backingScaleFactor;
    self.lastVideoFrameSize = CGSizeZero;
    self.reshaped = false;
    self.enableMirror = false;
}

- (void)dealloc {
    [self teardownDisplayLink];
}

- (void)drawRect:(NSRect)dirtyRect {
    @autoreleasepool{
        @synchronized (self) {
            [self drawFrame];
        }
    }
}

- (void)renderFrame:(nullable VideoFrame *)frame {
    self.videoFrame = frame;
}

- (void)enableMirror:(BOOL) enableMirror {
    self.enableMirror = enableMirror == YES;
    [self.shader enableMirror:enableMirror];
}

- (void)drawFrame {

    VideoFrame *frame = self.videoFrame;
    if ( !frame ) {
        return;
    }
    
    // This method may be called from CVDisplayLink callback which isn't on the
    // main thread so we have to lock the GL context before drawing.
    NSOpenGLContext *context = [self openGLContext];
    if (!context) {
        return;
    }
    
    CGLLockContext([context CGLContextObj]);
    [self ensureGLContext];
    glClear(GL_COLOR_BUFFER_BIT);
    
    if (self.reshaped || (self.lastVideoFrameSize.width != frame.width) || (self.lastVideoFrameSize.height != frame.height))
    {
        self.reshaped = false;
        self.lastVideoFrameSize = CGSizeMake(frame.width, frame.height);
        
        int viewWidth = self.glViewBounds.size.width;
        int viewHeight = self.glViewBounds.size.height;
        if (frame.width * self.glViewBounds.size.height < frame.height * self.glViewBounds.size.width)
        {
            viewHeight = self.glViewBounds.size.height;
            viewWidth = self.glViewBounds.size.height * frame.width / frame.height;
        }
        else if(frame.width * self.glViewBounds.size.height > frame.height * self.glViewBounds.size.width)
        {
            viewHeight = self.glViewBounds.size.width * frame.height / frame.width;
            viewWidth = self.glViewBounds.size.width;
        }
        
        GLint viewPortX = (self.glViewBounds.size.width - viewWidth) * self.backingScale / 2;
        GLint viewPortY = (self.glViewBounds.size.height - viewHeight) * self.backingScale / 2;
        GLsizei viewPortWidth = viewWidth * self.backingScale;
        GLsizei viewPortHeight = viewHeight * self.backingScale;
        glViewport(viewPortX, viewPortY, viewPortWidth, viewPortHeight);
    }
    
    if (!self.i420TextureCache) {
        self.i420TextureCache = [[I420TextureCache alloc] initWithContext:context];
    }
    
    I420TextureCache *textureCache = self.i420TextureCache;
    if (textureCache) {
        [textureCache uploadFrameToTextures:frame];
        [_shader applyShadingForFrameWithWidth:frame.width
                                        height:frame.height
                                      rotation:frame.rotation
                                        yPlane:textureCache.yTexture
                                        uPlane:textureCache.uTexture
                                        vPlane:textureCache.vTexture];
        [context flushBuffer];
    }
    CGLUnlockContext([context CGLContextObj]);
}

- (void)reshape {
    [super reshape];
    self.glViewBounds = self.bounds;
    self.backingScale = [self window].backingScaleFactor;
    self.reshaped = true;
}

- (void)lockFocus {
    NSOpenGLContext *context = [self openGLContext];
    [super lockFocus];
    if ([context view] != self) {
        [context setView:self];
    }
    [context makeCurrentContext];
}

- (void)recreateContext {
#if !TARGET_OS_IPHONE
    if ([self openGLContext] != nil) {
        GLint major = 0, minor = 0;
        glGetIntegerv(GL_MAJOR_VERSION, &major);
        glGetIntegerv(GL_MINOR_VERSION, &minor);
        if (major > 3 || (major == 3 && minor >= 2)) {
            return;
        }
    }
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFADoubleBuffer,    // 可选地，可以使用双缓冲
        NSOpenGLPFAOpenGLProfile,   // Must specify the 3.2 Core Profile to use OpenGL 3.2
        NSOpenGLProfileVersion3_2Core,
        0
    };
    
    NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    
    if (!pf) {
        NSLog(@"No OpenGL pixel format");
    }
    
    NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
    
    [self setPixelFormat:pf];
    [self setOpenGLContext:context];
    self.shader = [[DefaultShader alloc] init];
    [self.shader enableMirror:self.enableMirror];
#endif
}

- (void)prepareOpenGL {
    [self recreateContext];
    [super prepareOpenGL];
    [self ensureGLContext];
    glDisable(GL_DITHER);
    [self setupDisplayLink];
}

- (void)clearGLContext {
    [self ensureGLContext];
    self.i420TextureCache = nil;
    [super clearGLContext];
}

- (void)ensureGLContext {
    NSOpenGLContext* context = [self openGLContext];
    NSAssert(context, @"context shouldn't be nil");
    if ([NSOpenGLContext currentContext] != context) {
        [context makeCurrentContext];
    }
}

- (void)setupDisplayLink {
    if (_displayLink) {
        return;
    }
    // Synchronize buffer swaps with vertical refresh rate.
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    // Create display link.
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink,
                                   &OnDisplayLinkFired,
                                   (__bridge void *)self);
    // Set the display link for the current renderer.
    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cglContext, cglPixelFormat);
    CVDisplayLinkStart(_displayLink);
}

- (void)teardownDisplayLink {
    if (!_displayLink) {
        return;
    }
    CVDisplayLinkStop(_displayLink);
    CVDisplayLinkRelease(_displayLink);
    @synchronized (self) {
        _displayLink = NULL;
    }
}

@end
