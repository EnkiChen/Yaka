//
//  FormatConvert.m
//  Yaka
//
//  Created by Enki on 2021/11/9.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "FormatConvert.h"
#import "YuvFileDumper.h"
#import "NalUnitSourceFileImp.h"
#import "FlvFileCaptureImp.h"
#import "VT264Decoder.h"
#import "VT265Decoder.h"

@interface FormatConvert () <VideoSourceSink, H264SourceSink, DecoderDelegate, FileSourceDelegate>

@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, copy) NSString *outputFilePath;

@property(nonatomic, strong) YuvFileDumper *yuvFileDumper;

@property(nonatomic, strong) id<H264FileSourceInterface> nalUnitFileSource;
@property(nonatomic, strong) NalUnitSourceFileImp *naluFileSoucre;
@property(nonatomic, strong) FlvFileCaptureImp *flvFileCaptureImp;

@property(nonatomic, strong) VT264Decoder *vt264Decoder;
@property(nonatomic, strong) VT265Decoder *vt265Decoder;

@property(nonatomic, copy) NSDictionary *files;
@property(nonatomic, assign) NSUInteger index;

@end

@implementation FormatConvert

- (instancetype)initWithFiles:(NSDictionary*)files {
    self = [super init];
    if (self) {
        self.files = files;
        self.index = 0;
    }
    return self;
}

- (void)startTask {
    [self stop];
    if (self.index < self.files.count) {
        NSArray *keys = self.files.allKeys;
        self.filePath = keys[self.index];
        self.outputFilePath = self.files[self.filePath];
        [self start];
        self.index++;
    }
}

- (void)start {
    NSLog(@"start convert %@", self.filePath);
    if ([self.filePath hasSuffix:@"h264"] || [self.filePath hasSuffix:@"264"] || [self.filePath hasSuffix:@"h265"] || [self.filePath hasSuffix:@"265"]) {
        self.naluFileSoucre = [[NalUnitSourceFileImp alloc] initWithPath:self.filePath];
        self.nalUnitFileSource = self.naluFileSoucre;
    } else if ([self.filePath hasSuffix:@"flv"]) {
        self.flvFileCaptureImp = [[FlvFileCaptureImp alloc] initWithPath:self.filePath];
        self.nalUnitFileSource = self.flvFileCaptureImp;
    }
    
    self.yuvFileDumper = [[YuvFileDumper alloc] initWithPath:self.outputFilePath];
    self.nalUnitFileSource.isLoop = NO;
    self.nalUnitFileSource.fps = 240;
    self.nalUnitFileSource.delegate = self;
    self.nalUnitFileSource.fileSourceDelegate = self;
    
    [self.nalUnitFileSource start];
}

- (void)stop {
    [self.nalUnitFileSource stop];
    [self.vt264Decoder releaseDecoder];
    self.vt264Decoder = nil;
    [self.vt265Decoder releaseDecoder];
    self.vt265Decoder = nil;
    [self.naluFileSoucre stop];
    self.naluFileSoucre = nil;
    [self.flvFileCaptureImp stop];
    self.flvFileCaptureImp = nil;
    [self.yuvFileDumper stop];
    self.yuvFileDumper = nil;
    [NSThread sleepForTimeInterval:0.5];
}

#pragma mark - FileSourceDelegate
- (void)fileSource:(id<FileSourceInterface>)fileSource progressUpdated:(NSUInteger)index {
    NSLog(@"convert %@ convert %lu/%lu.", self.filePath, (unsigned long)index + 1, (unsigned long)fileSource.totalFrames);
}

- (void)fileSource:(id<FileSourceInterface>)fileSource fileDidEnd:(NSUInteger)totalFrame {
    NSLog(@"%@ convert done.", self.filePath);
    [self performSelectorOnMainThread:@selector(startTask) withObject:self waitUntilDone:NO];
}

#pragma mark - VideoSourceSink
- (void)captureSource:(id<VideoSourceInterface>)source onFrame:(VideoFrame *)frame {
    
}

#pragma mark - H264SourceSink
- (void)h264Source:(id<H264SourceInterface>)source onEncodedImage:(Nal *)nal {
    if ([self.filePath hasSuffix:@"h264"] || [self.filePath hasSuffix:@"264"] || [self.filePath hasSuffix:@"flv"]) {
        [self.vt264Decoder decode:nal];
    } else if ([self.filePath hasSuffix:@"h265"] || [self.filePath hasSuffix:@"265"]) {
        [self.vt265Decoder decode:nal];
    }
}

#pragma mark - DecoderDelegate
- (void)decoder:(id<DecoderInterface>)decoder onDecoded:(VideoFrame *)frame {
    [self.yuvFileDumper dumpToFile:frame];
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
