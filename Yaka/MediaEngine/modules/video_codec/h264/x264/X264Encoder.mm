//
//  X264Encoder.m
//  Yaka
//
//  Created by Enki on 2019/10/9.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "X264Encoder.h"
#include <chrono>
#import "x264.h"
#import "H264Common.h"

static const int kDefaultMaxQp = 51;
static const int kDefaultMinQp = 23;
static const int kDefaultQpStep = 2;
static const int kTargetBitrateBps = 1 * 1000 * 1000;
static const int kMaxBitrateBps = 1 * 1000 * 1000;
static const int kMaxFramerate = 30;
static const int kGopSize = 300;
static const char *kProfile = "high";
static const char *kPreset = "superfast";
static const char *kTune = "grain+zerolatency";

static const uint8_t start_code[4] = { 0, 0, 0, 1 };

@interface X264Encoder ()

@property(nonatomic, assign) x264_t* encoder;

@property(nonatomic, assign) int maxQp;
@property(nonatomic, assign) int minQp;
@property(nonatomic, assign) int qpStep;
@property(nonatomic, assign) int targetBitrateBps;
@property(nonatomic, assign) int maxBitrateBps;
@property(nonatomic, assign) int maxFramerate;
@property(nonatomic, assign) int gopSize;

@end


@implementation X264Encoder

@synthesize delegate;

- (void)dealloc {
    [self releaseEncoder];
}

- (void)initEncoder {
    self.maxQp = kDefaultMaxQp;
    self.minQp = kDefaultMinQp;
    self.qpStep = kDefaultQpStep;
    self.targetBitrateBps = kTargetBitrateBps;
    self.maxBitrateBps = kMaxBitrateBps;
    self.maxFramerate = kMaxFramerate;
    self.gopSize = kGopSize;
}

- (void)reconfig:(EncoderParams *) params {
    [self releaseEncoder];
    self.maxQp = params.maxQp;
    self.minQp = params.minQp;
    self.qpStep = kDefaultQpStep;
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
    
    x264_picture_t picture_t;
    x264_picture_init(&picture_t);
    picture_t.img.i_csp = X264_CSP_I420;
    picture_t.img.i_plane = 3;
    picture_t.i_type = X264_TYPE_AUTO;
    picture_t.img.i_plane = 3;
    picture_t.img.plane[0] = const_cast<uint8_t*>(buffer.dataY);
    picture_t.img.plane[1] = const_cast<uint8_t*>(buffer.dataU);
    picture_t.img.plane[2] = const_cast<uint8_t*>(buffer.dataV);
    picture_t.img.plane[3] = 0;
    picture_t.img.i_stride[0] = buffer.strideY;
    picture_t.img.i_stride[1] = buffer.strideU;
    picture_t.img.i_stride[2] = buffer.strideV;
    
    x264_picture_t pic_out;
    x264_nal_t *nal;
    int i_nal = 0;
    
    auto start = std::chrono::steady_clock::now();
    int enc_ret = x264_encoder_encode(_encoder, &nal, &i_nal, &picture_t, &pic_out);
    auto now = std::chrono::steady_clock::now();
    double consume = std::chrono::duration<double, std::milli>(now-start).count();

    if (enc_ret <= 0) {
        NSLog(@"x264 encoder failed.");
        return;
    }

    for ( int index = 0 ; index < i_nal; index++) {
        NalMutableBuffer *buffer = [[NalMutableBuffer alloc] initWithBytes:start_code
                                                                    length:sizeof(start_code)/sizeof(start_code[0])];
        [buffer appendBytes:nal[index].p_payload + 4 length:nal[index].i_payload - 4];
        Nal *nalObj = [[Nal alloc] initWithNalBuffer:buffer];
        nalObj.encodeTime = consume;
        nalObj.type = nal[index].i_type;
        
        if ( self.delegate ) {
            [self.delegate encoder:self onEncoded:nalObj];
        }
    }
}

- (void)releaseEncoder {
    if ( _encoder != nullptr ) {
        x264_encoder_close(_encoder);
        _encoder = nullptr;
    }
}

- (x264_t*)createEncoder:(int) width height:(int) height {
    x264_t* encoder = nullptr;
    x264_param_t encoder_params;
    
    x264_param_default_preset(&encoder_params, kPreset, kTune);
    x264_param_apply_profile(&encoder_params, kProfile);
    
    encoder_params.b_annexb = 0;
    encoder_params.i_threads = 1;
    encoder_params.i_csp = X264_CSP_I420;
    encoder_params.i_width = width;
    encoder_params.i_height = height;
    encoder_params.i_fps_num = self.maxFramerate;
    encoder_params.i_fps_den = 1;
    encoder_params.i_bframe_adaptive = X264_B_ADAPT_NONE;
    encoder_params.i_keyint_max = self.gopSize;
    
    // Rate Control mode
    encoder_params.rc.i_rc_method = X264_RC_ABR;
    encoder_params.rc.f_rate_tolerance = 1.0;
    encoder_params.rc.i_bitrate = self.targetBitrateBps / 1000;
    encoder_params.rc.i_vbv_max_bitrate = self.maxBitrateBps / 1000;
    encoder_params.rc.i_vbv_buffer_size = self.maxBitrateBps / 1000;
    encoder_params.rc.f_vbv_buffer_init = 0.5;
    encoder_params.rc.i_qp_min = self.minQp;
    encoder_params.rc.i_qp_max = self.maxQp;
    encoder_params.rc.i_qp_step = self.qpStep;
    encoder_params.rc.f_rf_constant = self.minQp;
    encoder_params.rc.f_rf_constant_max = self.maxQp;
    
    //使用加权预测后 webrtc 不能解析，所以禁用加权预测
    encoder_params.analyse.i_weighted_pred = 0;
    
    // Create encoder.
    encoder = x264_encoder_open(&encoder_params);
    
    if ( encoder == nullptr ) {
        NSLog(@"create x264 encoder fail.");
    }
    return encoder;
}

@end
