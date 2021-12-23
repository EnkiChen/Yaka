//
//  FormatConvert.m
//  Yaka
//
//  Created by Enki on 2021/11/9.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "FormatConvert.h"
#import "YuvFileDumper.h"
#import "FileCapture.h"
#import "NalUnitSourceFileImp.h"
#import "FlvFileCaptureImp.h"
#import "VT264Decoder.h"
#import "VT265Decoder.h"
#include "YuvHelper.h"

@interface FormatConvert () <VideoSourceSink, H264SourceSink, DecoderDelegate, FileSourceDelegate>

@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, copy) NSString *outputFilePath;

@property(nonatomic, strong) YuvFileDumper *yuvFileDumper;

@property(nonatomic, strong) FileCapture *fileCapture;
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
    [self dowmska];
}

- (void)scaleFrame {
    NSArray* numbers = @[@"A", @"B", @"E", @"G"];
    NSArray* resolutions = @[@"368x640x10"];
    NSArray* bitrates = @[@"200", @"400"];
    for (NSString *num in numbers) {
        for (NSString *resl in resolutions) {
            for (NSString *br in bitrates) {
                NSString *inputFile = [NSString stringWithFormat:@"/Users/enki/Desktop/盲测视频/%@/%@_%@_I420_vt264_%@k.yuv", num, num, resl, br];
                NSString *outputFile = [NSString stringWithFormat:@"/Users/enki/Desktop/盲测视频/%@/%@_720x1280x10_I420_%@_UP_vt264_%@k.yuv", num, num, resl, br];
                scaleYUV([inputFile cStringUsingEncoding:NSUTF8StringEncoding], 368, 640, [outputFile cStringUsingEncoding:NSUTF8StringEncoding], 720, 1280);
            }
        }
    }
}

- (void)flvToYuv {
    NSArray* numbers = @[@"A", @"B", @"E", @"G"];
    NSArray* resolutions = @[@"240x432x15"];
    NSArray* bitrates = @[@"600", @"800"];
    NSMutableDictionary *filePaths = [[NSMutableDictionary alloc] init];
    for (NSString *num in numbers) {
        for (NSString *resl in resolutions) {
            for (NSString *br in bitrates) {
                NSString *inputFile = [NSString stringWithFormat:@"/Users/enki/Desktop/盲测视频/%@/%@_%@_vt264_%@k.flv", num, num, resl, br];
                NSString *outputFile = [NSString stringWithFormat:@"/Users/enki/Desktop/盲测视频/%@/%@_%@_I420_vt264_%@k.yuv", num, num, resl, br];
                [filePaths setValue:outputFile forKey:inputFile];
            }
        }
    }
    self.files = filePaths;
    [self startConvert];
}

- (void)dowmska {
    NSArray* numbers = @[@"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H"];
    NSMutableDictionary *filePaths = [[NSMutableDictionary alloc] init];
    for (NSString *num in numbers) {
        NSString *inputFile = [NSString stringWithFormat:@"/Users/enki/Desktop/盲测视频/video/%@_720x1280x30_I420.yuv", num];
        NSString *outputFile = [NSString stringWithFormat:@"/Users/enki/Desktop/盲测视频/video/%@_720x1280x5_I420.yuv", num];
        [filePaths setValue:outputFile forKey:inputFile];
    }
    self.files = filePaths;
    [self startConvert];
}

- (void)startConvert {
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
    } else if ([self.filePath hasSuffix:@"yuv"]) {
        int width = 0;
        int height = 0;
        NSString *filePath = [self.filePath lowercaseString];
        NSRange range = [filePath rangeOfString:@"[1-9][0-9]*[x,X,_][0-9]*" options:NSRegularExpressionSearch];
        if (range.location != NSNotFound) {
            NSString *result = [filePath substringWithRange:range];
            range = [result rangeOfString:@"^[0-9]*" options:NSRegularExpressionSearch];
            if (range.location != NSNotFound) {
                width = [[result substringWithRange:range] intValue];
            }
            range = [result rangeOfString:@"[0-9]*$" options:NSRegularExpressionSearch];
            if (range.location != NSNotFound) {
                height = [[result substringWithRange:range] intValue];
            }
        }
        self.fileCapture = [[FileCapture alloc] initWithPath:self.filePath width:width height:height pixelFormatType:kPixelFormatType_420_I420];
        self.fileCapture.delegate = self;
        self.fileCapture.fileSourceDelegate = self;
        self.fileCapture.fps = 240;
        self.fileCapture.isLoop = NO;
    }
    
    self.yuvFileDumper = [[YuvFileDumper alloc] initWithPath:self.outputFilePath];
    self.yuvFileDumper.isOrdered = YES;
    self.nalUnitFileSource.isLoop = NO;
    self.nalUnitFileSource.fps = 240;
    self.nalUnitFileSource.delegate = self;
    self.nalUnitFileSource.fileSourceDelegate = self;
    
    [self.nalUnitFileSource start];
    [self.fileCapture start];
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
    [self.yuvFileDumper dumpToFile:frame];
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
