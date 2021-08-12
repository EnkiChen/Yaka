//
//  OpenH264Encoder.m
//  Yaka
//
//  Created by Enki on 2019/10/9.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "OpenH264Encoder.h"
#include <chrono>
#import "codec_api.h"
#import "codec_app_def.h"
#import "codec_def.h"
#import "codec_ver.h"
#import "H264Common.h"

static const int kDefaultMaxQp = 36;
static const int kDefaultMinQp = 23;
static const int kTargetBitrateBps = 2 * 1000 * 1000;
static const int kMaxBitrateBps = 3 * 1000 * 1000;
static const int kMaxFramerate = 15;
static const int kGopSize = 300;

@interface OpenH264Encoder ()

@property(nonatomic, assign) ISVCEncoder* encoder;

@property(nonatomic, assign) int maxQp;
@property(nonatomic, assign) int minQp;
@property(nonatomic, assign) int targetBitrateBps;
@property(nonatomic, assign) int maxBitrateBps;
@property(nonatomic, assign) int maxFramerate;
@property(nonatomic, assign) int gopSize;

@end

@implementation OpenH264Encoder

@synthesize delegate;

- (void)dealloc {
    [self releaseEncoder];
}

- (void)initEncoder {
    self.maxQp = kDefaultMaxQp;
    self.minQp = kDefaultMinQp;
    self.targetBitrateBps = kTargetBitrateBps;
    self.maxBitrateBps = kMaxBitrateBps;
    self.maxFramerate = kMaxFramerate;
    self.gopSize = kGopSize;
}

- (void)reconfig:(EncoderParams *) params {
    [self releaseEncoder];
    self.maxQp = params.maxQp;
    self.minQp = params.minQp;
    self.targetBitrateBps = params.targetBitrateBps;
    self.maxBitrateBps = params.maxBitrateBps;
    self.maxFramerate = params.maxFramerate;
    self.gopSize = params.gopSize;
}

- (void)encode:(VideoFrame*) frame {
    if ( frame == nullptr || frame.width == 0 || frame.height == 0 ) {
        return;
    }
    
    if ( _encoder == nullptr ) {
        _encoder = [self createEncoder:frame.width height:frame.height];
    }
    
    id<I420Buffer> buffer = [frame.buffer toI420];
    
    SSourcePicture picture;
    memset(&picture, 0, sizeof(SSourcePicture));
    picture.iPicWidth = frame.width;
    picture.iPicHeight = frame.height;
    picture.iColorFormat = EVideoFormatType::videoFormatI420;
    picture.uiTimeStamp = 0;
    picture.iStride[0] = buffer.strideY;
    picture.iStride[1] = buffer.strideU;
    picture.iStride[2] = buffer.strideV;
    picture.pData[0] = const_cast<uint8_t*>(buffer.dataY);
    picture.pData[1] = const_cast<uint8_t*>(buffer.dataU);
    picture.pData[2] = const_cast<uint8_t*>(buffer.dataV);
    
    SFrameBSInfo info;
    memset(&info, 0, sizeof(SFrameBSInfo));
    
    auto start = std::chrono::steady_clock::now();
    int enc_ret = _encoder->EncodeFrame(&picture, &info);
    auto now = std::chrono::steady_clock::now();
    double consume = std::chrono::duration<double, std::milli>(now-start).count();
    
    if (enc_ret != 0) {
        NSLog(@"openh264 encoder fail.");
        return;
    }
    
    size_t required_size = 0;
    for (int layer = 0; layer < info.iLayerNum; ++layer) {
        const SLayerBSInfo& layerInfo = info.sLayerInfo[layer];
        int nal_index = 0;
        for (int nal = 0; nal < layerInfo.iNalCount; ++nal) {
            required_size += layerInfo.pNalLengthInByte[nal];
            NalMutableBuffer *buffer = [[NalMutableBuffer alloc] initWithBytes:layerInfo.pBsBuf + nal_index
                                                                        length:layerInfo.pNalLengthInByte[nal]];

            Nal *nal_obj = [[Nal alloc] initWithNalBuffer:buffer];
            nal_obj.encodeTime = consume;
            nal_obj.type = H264::naluType(buffer.bytes[H264::kNaluLongStartSequenceSize]);

            if ( self.delegate ) {
                [self.delegate encoder:self onEncoded:nal_obj];
            }
            nal_index += layerInfo.pNalLengthInByte[nal];
        }
    }
}

- (void)releaseEncoder {
    if ( _encoder != nullptr ) {
        _encoder->Uninitialize();
        WelsDestroySVCEncoder(_encoder);
    }
}

- (ISVCEncoder*)createEncoder:(int) width height:(int) height {
    SEncParamExt encoder_params;
    ISVCEncoder* encoder;
    
    if (WelsCreateSVCEncoder(&encoder) != 0) {
        NSLog(@"create openh264 fail.");
        return nullptr;
    }
    
    int trace_level = WELS_LOG_QUIET;
    encoder->SetOption(ENCODER_OPTION_TRACE_LEVEL, &trace_level);
    
    encoder->GetDefaultParams(&encoder_params);
    
    encoder_params.iUsageType = SCREEN_CONTENT_REAL_TIME;
    encoder_params.iPicWidth = width;
    encoder_params.iPicHeight = height;
    encoder_params.iTargetBitrate = self.targetBitrateBps;
    encoder_params.iMaxBitrate = self.maxBitrateBps;
    
    encoder_params.iEntropyCodingModeFlag = 0;
    
    encoder_params.iTemporalLayerNum = 3;
    encoder_params.iRCMode = RC_QUALITY_MODE;
    encoder_params.iMaxQp = self.maxQp;
    encoder_params.iMinQp = self.minQp;
    
    //encoder_params.bSimulcastAVC = true;
    encoder_params.fMaxFrameRate = self.maxFramerate;
    encoder_params.bEnableDenoise = false;
    
    // The following parameters are extension parameters (they're in SEncParamExt,
    // not in SEncParamBase).
    encoder_params.bEnableFrameSkip = false;
    
    // |uiIntraPeriod|    - multiple of GOP size
    // |keyFrameInterval| - number of frames
    encoder_params.uiIntraPeriod = self.gopSize;
    encoder_params.uiMaxNalSize = 0;
    
    // Threading model: use auto.
    //  0: auto (dynamic imp. internal encoder)
    //  1: single thread (default value)
    // >1: number of threads
    encoder_params.iMultipleThreadIdc = 1;
    
    // The base spatial layer 0 is the only one we use.
    encoder_params.sSpatialLayers[0].iVideoWidth = encoder_params.iPicWidth;
    encoder_params.sSpatialLayers[0].iVideoHeight = encoder_params.iPicHeight;
    encoder_params.sSpatialLayers[0].fFrameRate = encoder_params.fMaxFrameRate;
    encoder_params.sSpatialLayers[0].iSpatialBitrate = encoder_params.iTargetBitrate;
    encoder_params.sSpatialLayers[0].iMaxSpatialBitrate = encoder_params.iMaxBitrate;
    encoder_params.sSpatialLayers[0].uiProfileIdc = PRO_BASELINE;
    encoder_params.sSpatialLayers[0].sSliceArgument.uiSliceNum = 1;
    encoder_params.sSpatialLayers[0].sSliceArgument.uiSliceMode = SM_FIXEDSLCNUM_SLICE;
    
    if (encoder->InitializeExt(&encoder_params) != 0) {
        NSLog(@"init openh264 fail.");
        return nullptr;
    }
    
    int video_format = EVideoFormatType::videoFormatI420;
    encoder->SetOption(ENCODER_OPTION_DATAFORMAT, &video_format);
    
    SProfileInfo profile;
    profile.iLayer = 0;
    profile.uiProfileIdc = PRO_BASELINE;
    encoder->SetOption(ENCODER_OPTION_PROFILE, &profile);
    
    SLevelInfo level;
    level.iLayer = 0;
    level.uiLevelIdc = LEVEL_4_1;
    encoder->SetOption(ENCODER_OPTION_LEVEL, &level);
    
    return encoder;
}

@end
