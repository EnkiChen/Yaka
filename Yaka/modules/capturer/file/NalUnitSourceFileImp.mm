//
//  H264SourceFileImp.m
//  Yaka
//
//  Created by Enki on 2019/8/31.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "NalUnitSourceFileImp.h"

namespace  {

static const int kBufferSize = 2 * 1024 * 1024;
static const int kDefaultFps = 24;
    
enum NaluType {
    kSlice = 1,
    kIdr = 5,
    kSei = 6,
    kSps = 7,
    kPps = 8,
    
    kEndOfSequence = 10,
    kEndOfStream = 11,
    kFiller = 12,
    kStapA = 24,
    kFuA = 28
};


NaluType naluType(uint8_t code)
{
    return NaluType(code & 0x1F);
}

bool isNalu(unsigned char *buffer)
{
    return buffer[0] == 0x00 && buffer[1] == 0x00 && buffer[2] == 0x00 && buffer[3] == 0x01;
}

int findNalu(unsigned char *buffer, int length)
{
    for ( int i = 0; i < length - 4; i++ ) {
        if ( isNalu(buffer + i) ) {
            return i;
        }
    }
    return -1;
}

int readData(unsigned char* buffer, int length, FILE *fd) {
    size_t read_size = 0;
    size_t total_size = 0;
    do {
        read_size = fread(buffer + total_size, 1, length - total_size, fd);
        total_size += read_size;
    } while ( read_size != 0 && total_size != length );
    return int(total_size);
}
    
}

@interface FileNalUnit : NSObject

@property (nonatomic, assign) long offset;
@property (nonatomic, assign) long length;
@property (nonatomic, assign) NaluType type;

@end

@implementation FileNalUnit

- (instancetype)initWithOffset:(long) offset length:(long) length type:(NaluType) type {
    self = [super init];
    if ( self ) {
        self.offset = offset;
        self.length = length;
        self.type = type;
    }
    return self;
}

@end

@interface NalUnitSourceFileImp ()

@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, assign) NSUInteger width;
@property(nonatomic, assign) NSUInteger height;
@property(nonatomic, assign) FILE *fd;
@property(nonatomic, assign) uint8_t* buffer;
@property(nonatomic, strong) NSMutableArray *nalUnits;
@property(nonatomic, assign) NSUInteger index;
@property(nonatomic, assign) NSUInteger frameIndex;
@property(atomic, assign) BOOL cancel;

@end

@implementation NalUnitSourceFileImp

@synthesize delegate;

@synthesize fileSourceDelegate;
@synthesize isPause;
@synthesize isLoop;
@synthesize fps;
@synthesize frameIndex;
@synthesize totalFrames;


- (instancetype)initWithPath:(NSString*) filePath {
    self = [super init];
    if ( self ) {
        self.filePath = filePath;
        self.cancel = YES;
        self.isLoop = YES;
        self.fps = kDefaultFps;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}


#pragma mark -
#pragma mark VideoSourceInterface

- (void)start {
    if ( !self.cancel ) {
        return;
    }
    [self openFileAndAnalysis];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.cancel = NO;
        [self process];
    });
}

- (void)stop {
    if (!self.cancel) {
        self.cancel = YES;
        [self performSelector:@selector(closeFile) withObject:self afterDelay:0.3];
    }
}

-(BOOL)isRunning {
    return !self.cancel;
}


#pragma mark -
#pragma mark VideoSourceInterface

- (BOOL)isPause {
    return self.cancel && self.fd != NULL;
}

- (NSUInteger)totalFrames {
    return self.nalUnits.count;
}

- (void)pause {
    self.cancel = YES;
}

- (void)resume {
    if (!self.isPause) {
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.cancel = NO;
        [self process];
    });
}

- (void)seekToFrameIndex:(NSUInteger) frameIndex {
    if (frameIndex != self.index && frameIndex !=0) {
        return;
    }
    if ( frameIndex < self.nalUnits.count ) {
        self.index = frameIndex;
        [self outputFrame];
    }
}

- (id<NSObject>)frameWithIndex:(NSUInteger) frameIndex {
    return nil;
}


#pragma mark -
#pragma mark Private Method

- (BOOL)openFileAndAnalysis {
    self.fd = fopen([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    self.buffer = new uint8_t[kBufferSize];
    self.nalUnits = [[NSMutableArray alloc] init];
    [self fileAnalysis];
    return YES;
}

- (void)closeFile {
    if (self.fd != NULL) {
        fclose(self.fd);
        self.fd = NULL;
    }
    if (self.buffer != NULL) {
        delete self.buffer;
        self.buffer = NULL;
    }
}

- (void)fileAnalysis {
    int remaining = 0;
    int read_size = 0;
    long offset = 0;
    do {
        int pare_index = 0;
        offset = ftell(self.fd) - remaining;
        read_size = readData(self.buffer + remaining, kBufferSize - remaining, self.fd);
        int buffer_length = remaining + read_size;
        remaining = 0;
        while ( pare_index < buffer_length )
        {
            int startIndex = findNalu(self.buffer + pare_index, buffer_length - pare_index);
            if ( startIndex == -1 ) {
                break;
            }
            int length = findNalu(self.buffer + pare_index + startIndex + 4, buffer_length - pare_index - startIndex - 4);
            if ( length == -1 && read_size != 0 ) {
                remaining = buffer_length - pare_index;
                memcpy(self.buffer, self.buffer + pare_index, remaining);
                break;
            }
            length = (length == -1) ? (buffer_length - pare_index - 4) : length;
            long fileOffset = offset + pare_index + startIndex;
            NaluType type = naluType(*(self.buffer + pare_index + 4));
            FileNalUnit *naluint = [[FileNalUnit alloc] initWithOffset:fileOffset length:length + 4 type:type];
            [self.nalUnits addObject:naluint];
            pare_index += length + 4;
        }
    } while ( read_size != 0 );
    fseek(self.fd, 0, SEEK_SET);
}

- (void)process {
    if (self.index >= self.nalUnits.count) {
        self.index = 0;
    }
    BOOL isOutput = YES;
    do {
        isOutput = [self outputFrame];
        usleep(1000.0 / (self.fps == 0 ? kDefaultFps : self.fps) * 1000);
    } while (isOutput && !self.cancel);
    self.cancel = YES;
    if (self.index == self.nalUnits.count) {
        if (self.fileSourceDelegate != nil) {
            [self.fileSourceDelegate fileSource:self fileDidEnd:self.nalUnits.count];
        }
    }
}

- (BOOL)outputFrame {
    self.frameIndex = self.index;
    Nal *nal = [self readFrame:self.isLoop];
    if (nal != nil) {
        if (self.delegate) {
            [self.delegate h264Source:self onEncodedImage:nal];
        }
        if (self.fileSourceDelegate != nil) {
            [self.fileSourceDelegate fileSource:self progressUpdated:self.frameIndex];
        }
        return YES;
    } else {
        self.frameIndex -= 1;
    }
    return NO;
}

- (Nal*)readFrame:(BOOL) isLoop {
    FileNalUnit *fileNalUnint;
    if (self.index < self.nalUnits.count) {
        fileNalUnint = [self.nalUnits objectAtIndex:self.index++];
    } else if ( self.index == self.nalUnits.count && isLoop) {
        self.index = 0;
        fileNalUnint = [self.nalUnits objectAtIndex:self.index++];
    } else  {
        return nil;
    }
    
    fseek(self.fd, fileNalUnint.offset, SEEK_SET);
    NalBuffer *nalBuffer = [[NalBuffer alloc] initWithLength:(int)fileNalUnint.length];
    int size = readData(nalBuffer.bytes, (int)fileNalUnint.length, self.fd);
    if (size == fileNalUnint.length) {
        return [[Nal alloc] initWithNalBuffer:nalBuffer];
    }
    self.index--;
    return nil;
}

@end
