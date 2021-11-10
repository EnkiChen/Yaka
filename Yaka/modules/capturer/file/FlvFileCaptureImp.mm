//
//  FlvFileCaptureImp.m
//  Yaka
//
//  Created by Enki on 2021/11/4.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "FlvFileCaptureImp.h"
#import "FileUnit.h"

namespace {
 
/* flv file format structure and definitions */

/* FLV file header */
#define FLV_SIGNATURE       "FLV"
#define FLV_VERSION         ((uint8)0x01)

#define FLV_FLAG_VIDEO      ((uint8)0x01)
#define FLV_FLAG_AUDIO      ((uint8)0x04)

#pragma pack(1)
typedef struct __flv_header {
    uint8_t         signature[3]; /* always "FLV" */
    uint8_t         version; /* should be 1 */
    uint8_t         flags;
    uint32_t        offset; /* always 9 */
} flv_header;
#pragma pack()

#define FLV_HEADER_SIZE 9u

#define flv_header_has_video(header)    ((header).flags & FLV_FLAG_VIDEO)
#define flv_header_has_audio(header)    ((header).flags & FLV_FLAG_AUDIO)
#define flv_header_get_offset(header)   (swap_uint32((header).offset))

/* FLV tag */
#define FLV_TAG_TYPE_AUDIO  ((uint8)0x08)
#define FLV_TAG_TYPE_VIDEO  ((uint8)0x09)
#define FLV_TAG_TYPE_META   ((uint8)0x12)

typedef struct __uint24 {
    uint8_t b[3];
} uint24, uint24_be, uint24_le;

#pragma pack(1)
typedef struct __flv_tag {
    uint32_t    previous_tag_length;
    uint8_t     type;
    uint24      body_length; /* in bytes, total tag size minus 11 */
    uint24      timestamp; /* milli-seconds */
    uint8       timestamp_extended; /* timestamp extension */
    uint24      stream_id; /* reserved, must be "\0\0\0" */
    /* body comes next */
} flv_tag;
#pragma pack(0)

#pragma pack(1)
typedef struct __flv_tag_video_header {
    struct {
        uint8_t    codec_id : 4;
        uint8_t    frame_type : 4;
    };
    uint8_t     avc_packet_type;
    uint24      composition_time;
} flv_video_tag_header;
#pragma pack(0)

#pragma pack(1)
typedef struct __avc_decoder_config_header {
    uint8_t     version;
    uint8_t     profile;
    uint8_t     compatibility;
    uint8_t     level;
    struct {
        uint8_t    length_size_minus_one : 2;
        uint8_t    reserved_a : 6;
    };
    struct {
        uint8_t    num_of_sps_count : 5;
        uint8_t    reserved_b : 3;
    };
} avc_decoder_config_header;
#pragma pack(0)

#define FLV_TAG_SIZE 11u

/* convert big endian 24 bits integers to native integers */
# define uint24_be_to_uint32(x) ((uint32)(((x).b[0] << 16) | \
    ((x).b[1] << 8) | (x).b[2]))
    
#define big_to_little_32(A) ((( (uint32)(A) & 0xff000000) >> 24) | \
    (( (uint32)(A) & 0x00ff0000) >> 8)   | \
    (( (uint32)(A) & 0x0000ff00) << 8)   | \
    (( (uint32)(A) & 0x000000ff) << 24))

#define flv_tag_get_body_length(tag)    (uint24_be_to_uint32((tag).body_length))
#define flv_tag_get_timestamp(tag) \
    (uint24_be_to_uint32((tag).timestamp) + ((tag).timestamp_extended << 24))
#define flv_tag_get_stream_id(tag)      (uint24_be_to_uint32((tag).stream_id))

/* audio tag */
#define FLV_AUDIO_TAG_SOUND_TYPE_MONO    0
#define FLV_AUDIO_TAG_SOUND_TYPE_STEREO  1

#define FLV_AUDIO_TAG_SOUND_SIZE_8       0
#define FLV_AUDIO_TAG_SOUND_SIZE_16      1

#define FLV_AUDIO_TAG_SOUND_RATE_5_5     0
#define FLV_AUDIO_TAG_SOUND_RATE_11      1
#define FLV_AUDIO_TAG_SOUND_RATE_22      2
#define FLV_AUDIO_TAG_SOUND_RATE_44      3

#define FLV_AUDIO_TAG_SOUND_FORMAT_LINEAR_PCM          0
#define FLV_AUDIO_TAG_SOUND_FORMAT_ADPCM               1
#define FLV_AUDIO_TAG_SOUND_FORMAT_MP3                 2
#define FLV_AUDIO_TAG_SOUND_FORMAT_LINEAR_PCM_LE       3
#define FLV_AUDIO_TAG_SOUND_FORMAT_NELLYMOSER_16_MONO  4
#define FLV_AUDIO_TAG_SOUND_FORMAT_NELLYMOSER_8_MONO   5
#define FLV_AUDIO_TAG_SOUND_FORMAT_NELLYMOSER          6
#define FLV_AUDIO_TAG_SOUND_FORMAT_G711_A              7
#define FLV_AUDIO_TAG_SOUND_FORMAT_G711_MU             8
#define FLV_AUDIO_TAG_SOUND_FORMAT_RESERVED            9
#define FLV_AUDIO_TAG_SOUND_FORMAT_AAC                 10
#define FLV_AUDIO_TAG_SOUND_FORMAT_SPEEX               11
#define FLV_AUDIO_TAG_SOUND_FORMAT_MP3_8               14
#define FLV_AUDIO_TAG_SOUND_FORMAT_DEVICE_SPECIFIC     15

typedef uint8_t flv_audio_tag;

#define flv_audio_tag_sound_type(tag)   (((tag) & 0x01) >> 0)
#define flv_audio_tag_sound_size(tag)   (((tag) & 0x02) >> 1)
#define flv_audio_tag_sound_rate(tag)   (((tag) & 0x0C) >> 2)
#define flv_audio_tag_sound_format(tag) (((tag) & 0xF0) >> 4)

/* video tag */
#define FLV_VIDEO_TAG_CODEC_JPEG            1
#define FLV_VIDEO_TAG_CODEC_SORENSEN_H263   2
#define FLV_VIDEO_TAG_CODEC_SCREEN_VIDEO    3
#define FLV_VIDEO_TAG_CODEC_ON2_VP6         4
#define FLV_VIDEO_TAG_CODEC_ON2_VP6_ALPHA   5
#define FLV_VIDEO_TAG_CODEC_SCREEN_VIDEO_V2 6
#define FLV_VIDEO_TAG_CODEC_AVC             7
#define FLV_VIDEO_TAG_CODEC_HEVC            0x0C
#define FLV_VIDEO_TAG_CODEC_VP8             x0D

#define FLV_VIDEO_TAG_FRAME_TYPE_KEYFRAME               1
#define FLV_VIDEO_TAG_FRAME_TYPE_INTERFRAME             2
#define FLV_VIDEO_TAG_FRAME_TYPE_DISPOSABLE_INTERFRAME  3
#define FLV_VIDEO_TAG_FRAME_TYPE_GENERATED_KEYFRAME     4
#define FLV_VIDEO_TAG_FRAME_TYPE_COMMAND_FRAME          5

typedef uint8_t flv_video_tag;

#define flv_video_tag_codec_id(tag)     (((tag) & 0x0F) >> 0)
#define flv_video_tag_frame_type(tag)   (((tag) & 0xF0) >> 4)

/* AVC packet types */
typedef uint8_t flv_avc_packet_type;

#define FLV_AVC_PACKET_TYPE_SEQUENCE_HEADER 0
#define FLV_AVC_PACKET_TYPE_NALU            1
#define FLV_AVC_PACKET_TYPE_SEQUENCE_END    2

/* AAC packet types */
typedef uint8_t flv_aac_packet_type;

#define FLV_AAC_PACKET_TYPE_SEQUENCE_HEADER 0
#define FLV_AAC_PACKET_TYPE_RAW             1

static const int kDefaultFps = 24;

};

@interface FlvVideoTagUnit : FileUnit

@property(nonatomic, assign) uint8_t tagType;
@property(nonatomic, assign) uint32_t timestamp;
@property(nonatomic, assign) uint32_t streamId;

@property(nonatomic, assign) uint8_t codecId;
@property(nonatomic, assign) uint8_t frameType;
@property(nonatomic, assign) uint8_t avcPacketType;
@property(nonatomic, assign) int32_t compositionTime;

@end

@implementation FlvVideoTagUnit

@end


@interface FlvFileCaptureImp()

@property(nonatomic, assign) NSString *filePath;
@property(nonatomic, assign) FILE *fd;
@property(nonatomic, assign) flv_header flvHeader;

@property(nonatomic, strong) NSMutableArray<FlvVideoTagUnit*> *videoTags;
@property(nonatomic, assign) NSUInteger index;
@property(nonatomic, assign) NSUInteger frameIndex;

@property(atomic, assign) BOOL cancel;

@end

@implementation FlvFileCaptureImp

@synthesize delegate;

@synthesize fileSourceDelegate;
@synthesize isPause;
@synthesize isLoop;
@synthesize fps;
@synthesize frameIndex;
@synthesize totalFrames;

- (instancetype)initWithPath:(NSString*)filePath {
    self = [super init];
    if (self) {
        self.filePath = filePath;
        
        self.cancel = YES;
        self.isLoop = NO;
        self.fps = kDefaultFps;
    }
    return self;
}


#pragma mark - VideoSourceInterface

- (void)start {
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

#pragma mark - VideoSourceInterface

- (BOOL)isPause {
    return self.cancel && self.fd != NULL;
}

- (NSUInteger)totalFrames {
    return self.videoTags.count;
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
    if ( frameIndex < self.videoTags.count ) {
        self.index = frameIndex;
        [self outputFrame];
    }
}

- (id<NSObject>)frameWithIndex:(NSUInteger) frameIndex {
    return nil;
}

#pragma mark - Private Method

- (BOOL)openFileAndAnalysis {
    if (self.fd != NULL) {
        fclose(self.fd);
        self.fd = NULL;
    }
    self.fd = fopen([self.filePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    if (self.fd == NULL) {
        return NO;
    }
    self.videoTags = [[NSMutableArray alloc] init];
    [self fileAnalysis];
    return YES;
}

- (void)closeFile {
    if (self.fd != NULL) {
        fclose(self.fd);
        self.fd = NULL;
    }
}

- (BOOL)fileAnalysis {
    if ([self fread:&_flvHeader length:sizeof(flv_header) fd:self.fd] != sizeof(flv_header)) {
        return NO;
    }
    
    if (self.flvHeader.signature[0] != 'F' || _flvHeader.signature[1] != 'L' || _flvHeader.signature[2] != 'V') {
        return NO;
    }

    _flvHeader.offset = CFSwapInt32BigToHost(self.flvHeader.offset);
    
    if (self.flvHeader.offset != FLV_HEADER_SIZE) {
        return NO;
    }
    
    if (!flv_header_has_video(self.flvHeader)) {
        return NO;
    }
    
    BOOL isHasNextTag = YES;
    BOOL isFirstTag = YES;
    do {
        flv_tag flvTag;
        memset(&flvTag, 0, sizeof(flv_tag));
        
        if ([self fread:&flvTag length:sizeof(flv_tag) fd:self.fd] != sizeof(flv_tag)) {
            break;
        }
        
        if (isFirstTag && flvTag.previous_tag_length != 0) {
            break;
        }

        flvTag.previous_tag_length = CFSwapInt32BigToHost(flvTag.previous_tag_length);
        uint32_t length  = flv_tag_get_body_length(flvTag);

        if (flvTag.type == FLV_TAG_TYPE_VIDEO) {
            flv_video_tag_header video_tag_header;
            if ([self fread:&video_tag_header length:sizeof(flv_video_tag_header) fd:self.fd] != sizeof(flv_video_tag_header)) {
                break;
            }
            length -= sizeof(flv_video_tag_header);

            if (video_tag_header.codec_id == FLV_VIDEO_TAG_CODEC_AVC) {
                if (video_tag_header.avc_packet_type == FLV_AVC_PACKET_TYPE_SEQUENCE_HEADER) {
                    avc_decoder_config_header avc_header;
                    if ([self fread:&avc_header length:sizeof(avc_decoder_config_header) fd:self.fd] != sizeof(avc_decoder_config_header)) {
                        break;
                    }
                    length -= sizeof(avc_decoder_config_header);
                    
                    for (int i = 0; i < avc_header.num_of_sps_count; i++) {
                        uint16_t sps_length;
                        if ([self fread:&sps_length length:sizeof(sps_length) fd:self.fd] != sizeof(sps_length)) {
                            break;
                        }
                        length -= sizeof(sps_length);
                        
                        sps_length = CFSwapInt16BigToHost(sps_length);
                        FlvVideoTagUnit *videoTagUnit = [[FlvVideoTagUnit alloc] initWithOffset:ftell(self.fd) length:sps_length];
                        videoTagUnit.tagType = flvTag.type;
                        videoTagUnit.timestamp = flv_tag_get_timestamp(flvTag);
                        videoTagUnit.streamId = flv_tag_get_stream_id(flvTag);
                        videoTagUnit.codecId = video_tag_header.codec_id;
                        videoTagUnit.frameType = video_tag_header.frame_type;
                        videoTagUnit.avcPacketType = video_tag_header.avc_packet_type;
                        videoTagUnit.compositionTime = uint24_be_to_uint32(video_tag_header.composition_time);
                        [self.videoTags addObject:videoTagUnit];
                        
                        fseek(self.fd, sps_length, SEEK_CUR);
                        length -= sps_length;
                    }
                    
                    uint8_t num_of_pps_count = 0;
                    if ([self fread:&num_of_pps_count length:1 fd:self.fd] != 1) {
                        break;
                    }
                    length -= 1;
                    
                    for (int i = 0; i < num_of_pps_count; i++) {
                        uint16_t pps_length;
                        if ([self fread:&pps_length length:sizeof(pps_length) fd:self.fd] != sizeof(pps_length)) {
                            break;
                        }
                        length -= sizeof(pps_length);
                        
                        pps_length = CFSwapInt16BigToHost(pps_length);
                        FlvVideoTagUnit *videoTagUnit = [[FlvVideoTagUnit alloc] initWithOffset:ftell(self.fd) length:pps_length];
                        videoTagUnit.tagType = flvTag.type;
                        videoTagUnit.timestamp = flv_tag_get_timestamp(flvTag);
                        videoTagUnit.streamId = flv_tag_get_stream_id(flvTag);
                        videoTagUnit.codecId = video_tag_header.codec_id;
                        videoTagUnit.frameType = video_tag_header.frame_type;
                        videoTagUnit.avcPacketType = video_tag_header.avc_packet_type;
                        videoTagUnit.compositionTime = uint24_be_to_uint32(video_tag_header.composition_time);
                        [self.videoTags addObject:videoTagUnit];
                        
                        fseek(self.fd, pps_length, SEEK_CUR);
                        length -= pps_length;
                    }
                } else if (video_tag_header.avc_packet_type == FLV_AVC_PACKET_TYPE_NALU) {
                    
                    FlvVideoTagUnit *videoTagUnit = [[FlvVideoTagUnit alloc] initWithOffset:ftell(self.fd) + 4 length:length - 4];
                    videoTagUnit.tagType = flvTag.type;
                    videoTagUnit.timestamp = flv_tag_get_timestamp(flvTag);
                    videoTagUnit.streamId = flv_tag_get_stream_id(flvTag);
                    videoTagUnit.codecId = video_tag_header.codec_id;
                    videoTagUnit.frameType = video_tag_header.frame_type;
                    videoTagUnit.avcPacketType = video_tag_header.avc_packet_type;
                    videoTagUnit.compositionTime = uint24_be_to_uint32(video_tag_header.composition_time);
                    [self.videoTags addObject:videoTagUnit];
                    
                    fseek(self.fd, length, SEEK_CUR);
                    length -= length;
                }

                fseek(self.fd, length, SEEK_CUR);
                
            } else if (video_tag_header.codec_id == FLV_VIDEO_TAG_CODEC_HEVC) {
                uint32_t heve_length = 0;
                if ([self fread:&heve_length length:sizeof(heve_length) fd:self.fd] != sizeof(heve_length)) {
                    break;
                }
                length -= sizeof(heve_length);
                
                FlvVideoTagUnit *videoTagUnit = [[FlvVideoTagUnit alloc] initWithOffset:ftell(self.fd) length:heve_length];
                videoTagUnit.tagType = flvTag.type;
                videoTagUnit.timestamp = flv_tag_get_timestamp(flvTag);
                videoTagUnit.streamId = flv_tag_get_stream_id(flvTag);
                videoTagUnit.codecId = video_tag_header.codec_id;
                videoTagUnit.frameType = video_tag_header.frame_type;
                videoTagUnit.avcPacketType = video_tag_header.avc_packet_type;
                videoTagUnit.compositionTime = uint24_be_to_uint32(video_tag_header.composition_time);
                [self.videoTags addObject:videoTagUnit];
                
                fseek(self.fd, heve_length, SEEK_CUR);
                length -= heve_length;
                
                videoTagUnit = [[FlvVideoTagUnit alloc] initWithOffset:ftell(self.fd) length:length];
                videoTagUnit.tagType = flvTag.type;
                videoTagUnit.timestamp = flv_tag_get_timestamp(flvTag);
                videoTagUnit.streamId = flv_tag_get_stream_id(flvTag);
                videoTagUnit.codecId = video_tag_header.codec_id;
                videoTagUnit.frameType = video_tag_header.frame_type;
                videoTagUnit.avcPacketType = video_tag_header.avc_packet_type;
                videoTagUnit.compositionTime = uint24_be_to_uint32(video_tag_header.composition_time);
                [self.videoTags addObject:videoTagUnit];
                fseek(self.fd, length, SEEK_CUR);

            } else {
                fseek(self.fd, length, SEEK_CUR);
            }
        } else {
            fseek(self.fd, length, SEEK_CUR);
        }

        isFirstTag = NO;
    } while (isHasNextTag);
    
    return YES;
}

- (void)process {
    if (self.index >= self.videoTags.count) {
        self.index = 0;
    }
    BOOL isOutput = YES;
    do {
        isOutput = [self outputFrame];
        usleep(1000.0 / (self.fps == 0 ? kDefaultFps : self.fps) * 1000);
    } while (isOutput && !self.cancel);
    self.cancel = YES;
    if (self.index == self.videoTags.count) {
        if (self.fileSourceDelegate != nil) {
            [self.fileSourceDelegate fileSource:self fileDidEnd:self.videoTags.count];
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
    FlvVideoTagUnit *videoTagUnint;
    if (self.index < self.videoTags.count) {
        videoTagUnint = [self.videoTags objectAtIndex:self.index++];
    } else if ( self.index == self.videoTags.count && isLoop) {
        self.index = 0;
        videoTagUnint = [self.videoTags objectAtIndex:self.index++];
    } else  {
        return nil;
    }
    
    fseek(self.fd, videoTagUnint.offset, SEEK_SET);
    NalBuffer *nalBuffer = [[NalBuffer alloc] initWithLength:(int)videoTagUnint.length + 4];
    nalBuffer.bytes[0] = 0x00;
    nalBuffer.bytes[1] = 0x00;
    nalBuffer.bytes[2] = 0x00;
    nalBuffer.bytes[3] = 0x01;
    int size = [self fread:nalBuffer.bytes + 4 length:(int)videoTagUnint.length fd:self.fd];
    if (size == videoTagUnint.length) {
        Nal *nal = [[Nal alloc] initWithNalBuffer:nalBuffer];
        nal.decodeTimeStamp = CMTimeMake(videoTagUnint.timestamp, 1);
        nal.presentationTimeStamp = CMTimeMake(videoTagUnint.timestamp + videoTagUnint.compositionTime, 1);
        nal.duration = kCMTimeInvalid;
        return nal;
    }
    self.index--;
    return nil;
}

- (int)fread:(void*)buffer length:(int)length fd:(FILE *)fd {
    size_t read_size = 0;
    size_t total_size = 0;
    do {
        read_size = fread((int8_t*)buffer + total_size, 1, length - total_size, fd);
        total_size += read_size;
    } while ( read_size != 0 && total_size != length );
    return (int)total_size;
}

@end
