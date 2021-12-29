//
//  VideoTrack.m
//  Yaka
//
//  Created by Enki on 2021/12/29.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "VideoTrack.h"

#import "VideoFrame.h"
#import "FileCapture.h"
#import "NalUnitSourceFileImp.h"
#import "FlvFileCaptureImp.h"

#import "Openh264Decoder.h"
#import "VT264Decoder.h"
#import "VT265Decoder.h"

@interface VideoTrack () <VideoSourceSink, H264SourceSink, DecoderDelegate>

@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, strong) id<FileSourceInterface> fileSource;
@property(nonatomic, strong) FileCapture *fileCapture;
@property(nonatomic, strong) NalUnitSourceFileImp *naluFileSoucre;
@property(nonatomic, strong) FlvFileCaptureImp *flvFileCaptureImp;

@property (nonatomic, assign) PixelFormatType pixelFormat;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;

@property(nonatomic, strong) id<DecoderInterface> decoder;
@property(nonatomic, strong) Openh264Decoder *openh264Decoder;
@property(nonatomic, strong) VT264Decoder *vt264Decoder;
@property(nonatomic, strong) VT265Decoder *vt265Decoder;

@end

@implementation VideoTrack

@synthesize delegate;
@synthesize isRunning;
@synthesize fileSourceDelegate;
@synthesize isPause;
@synthesize isLoop;
@synthesize frameIndex;
@synthesize fps;
@synthesize totalFrames;

- (instancetype)initWithRawFile:(NSString *)filePath
                          width:(NSInteger)width
                         height:(NSInteger)height
                    pixelFormat:(PixelFormatType)format {
    self = [super init];
    if (self) {
        self.width = width;
        self.height = height;
        self.pixelFormat = format;
        self.filePath = filePath;
        self.fileCapture = [[FileCapture alloc] initWithPath:filePath
                                                       width:width
                                                      height:height
                                             pixelFormatType:format];
        self.fileCapture.delegate = self;
        self.fileSource = self.fileCapture;
    }
    return self;
}

- (instancetype)initWithNalFile:(NSString *)filePath {
    self = [super init];
    if (self) {
        self.filePath = filePath;
        self.naluFileSoucre = [[NalUnitSourceFileImp alloc] initWithPath:filePath];
        self.naluFileSoucre.delegate = self;
        self.fileSource = self.naluFileSoucre;
    }
    return self;
}

- (instancetype)initWithFlvFile:(NSString *)filePath {
    self = [super init];
    if (self) {
        self.filePath = filePath;
        self.flvFileCaptureImp = [[FlvFileCaptureImp alloc] initWithPath:filePath];
        self.flvFileCaptureImp.delegate = self;
        self.fileSource = self.flvFileCaptureImp;
    }
    return self;
}

- (void)start {
    [self.fileSource start];
}

- (void)stop {
    [self.fileSource stop];
}

- (void)pause {
    [self.fileSource pause];
}

- (void)resume {
    [self.fileSource resume];
}

- (void)seekToFrameIndex:(NSUInteger)frameIndex {
    [self.fileSource seekToFrameIndex:frameIndex];
}

- (id<NSObject>)frameWithIndex:(NSUInteger)frameIndex {
    return [self.fileSource frameWithIndex:fraction];
}

#pragma mark - video source action
- (void)captureSource:(id<VideoSourceInterface>)source onFrame:(VideoFrame *)frame {
    [self.delegate captureSource:self onFrame:frame];
}

#pragma mark - h264 source action
- (void)h264Source:(id<H264SourceInterface>)source onEncodedImage:(Nal *)nal {
    if (nal.nalType == NalType_H264) {
        [self.vt264Decoder decode:nal];
    } else if (nal.nalType == NalType_HEVC) {
        [self.vt265Decoder decode:nal];
    }
}

#pragma mark - h264 decode action
- (void)decoder:(id<DecoderInterface>)decoder onDecoded:(VideoFrame *)frame {
    [self.delegate captureSource:self onFrame:frame];
}

#pragma mark - set&get action
- (BOOL)isPause {
    return self.fileSource.isPause;
}

- (void)setIsLoop:(BOOL)isLoop {
    self.fileSource.isLoop = isLoop;
}

- (BOOL)isLoop {
    return self.fileSource.isLoop;
}

- (void)setFps:(NSUInteger)fps {
    self.fileSource.fps = fps;
}

- (NSUInteger)fps {
    return self.fileSource.fps;
}

- (NSUInteger)frameIndex {
    return self.fileSource.frameIndex;
}

- (NSUInteger)totalFrames {
    return self.fileSource.totalFrames;
}

- (void)setFileSourceDelegate:(id<FileSourceDelegate>)fileSourceDelegate {
    self.fileSource.fileSourceDelegate = fileSourceDelegate;
}

- (Openh264Decoder*)openh264Decoder {
    if ( _openh264Decoder == nil ) {
        _openh264Decoder = [[Openh264Decoder alloc] init];
        _openh264Decoder.delegate = self;
        [_openh264Decoder initDecoder];
    }
    return _openh264Decoder;
}

- (VT264Decoder*)vt264Decoder {
    if ( _vt264Decoder == nil ) {
        _vt264Decoder = [[VT264Decoder alloc] init];
        _vt264Decoder.delegate = self;
        [_vt264Decoder initDecoder];
    }
    return _vt264Decoder;
}

- (VT265Decoder*)vt265Decoder {
    if (_vt265Decoder == nil) {
        _vt265Decoder = [[VT265Decoder alloc] init];
        _vt265Decoder.delegate = self;
        [_vt265Decoder initDecoder];
    }
    return _vt265Decoder;
}

@end
