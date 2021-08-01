//
//  EncodeTestItem.m
//  Yaka
//
//  Created by Enki on 2019/10/17.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "EncodeTestItem.h"
#import "H264Common.h"
#import "YuvFileDumper.h"

@interface EncodeTestItem ()

@property(nonatomic, copy) NSString *name;

@property(nonatomic, strong) id<H264EncoderInterface> h264Encoder;
@property(nonatomic, strong) id<H264DecoderInterface> h264Decoder;

@property(nonatomic, strong) YuvFileDumper *yuvFileDumper;

@property(nonatomic, assign) uint64_t totalBits;
@property(nonatomic, assign) uint64 idrBits;
@property(nonatomic, assign) uint32 idrCount;
@property(nonatomic, assign) uint64 idrMaxBits;
@property(nonatomic, assign) uint32 nalCount;
@property(nonatomic, assign) double totalEncodeTime;
@property(nonatomic, assign) uint32 dumpCount;


@end

@implementation EncodeTestItem

- (instancetype)initEncoder:(id<H264EncoderInterface>) encoder params:(EncoderParams *) params name:(NSString *) name {
    self = [super init];
    if ( self ) {
        self.name = name;
        
        self.h264Encoder = encoder;
        self.h264Encoder.delegate = self;
        [self.h264Encoder initEncoder];
        [self.h264Encoder reconfig:params];
        
        self.h264Decoder = [[Openh264VideoDecoder alloc] init];
        self.h264Decoder.delegate = self;
        [self.h264Decoder initDecoder];
        
        NSString *filePath = [NSString stringWithFormat:@"/Users/Enki/Desktop/M/1920x1200_%@.yuv", name];
        self.yuvFileDumper = [[YuvFileDumper alloc] initWithPath:filePath];
    }
    return self;
}

- (void)encode:(VideoFrame*) frame {
    [self.h264Encoder encode:frame];
}

- (void)stop {
    [self.yuvFileDumper stop];
    
    NSLog(@"%@ %llu : %llu : %llu ： %d : %d : %d : %.2f",
          self.name, self.totalBits,
          self.idrMaxBits / 1000, self.idrBits / (self.idrCount == 0 ? 1 : self.idrCount) / 1000, self.idrCount,
          self.nalCount, self.dumpCount, self.totalEncodeTime / 1000);
}

- (void)encoder:(id<H264EncoderInterface>) encoder onEncoded:(Nal *) nal {
    if ( nal.type == H264::kIdr ) {
        self.idrBits += nal.buffer.length * 8;
        self.idrCount++;
        if ( nal.buffer.length * 8 > self.idrMaxBits ) {
            self.idrMaxBits = nal.buffer.length * 8;
        }
    }
    
    if ( nal.type == H264::kIdr || nal.type == H264::kSlice ) {
        self.nalCount++;
        NSLog(@"encode frame %d", self.nalCount);
    }
    
    if ( self.nalCount == 550 ) {
        NSLog(@"encode frame %d", self.nalCount);
    }
    
    self.totalBits += nal.buffer.length * 8;
    self.totalEncodeTime += nal.encodeTime;
    
    [self.h264Decoder decode:nal];
}

- (void)decoder:(id<H264DecoderInterface>) decoder onDecoded:(VideoFrame *)frame {
    self.dumpCount++;
    NSLog(@"dump frame %d", self.dumpCount);
    [self.yuvFileDumper dumpToFile:frame];
}

@end
