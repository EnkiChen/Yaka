//
//  Openh264VideoDecoder.m
//  Yaka
//
//  Created by Enki on 2019/8/30.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "Openh264VideoDecoder.h"
#include <stdio.h>
#include <iostream>
#import "codec_api.h"
#import "codec_app_def.h"
#import "codec_def.h"
#import "codec_ver.h"

@interface Openh264VideoDecoder ()

@property(nonatomic, strong) dispatch_queue_t decoder_queue;
@property(nonatomic, assign) ISVCDecoder* decoder;

@end


@implementation Openh264VideoDecoder

@synthesize delegate;

- (instancetype)init {
    self = [super init];
    if ( self ) {
        
    }
    return self;
}

- (void)dealloc {
    [self releaseDecoder];
}

- (void)initDecoder {
    if ( WelsCreateDecoder(&_decoder) != 0 ) {
        NSLog(@"create openh264 decoder fail.");
    }
    
    SDecodingParam decParam = {0};
    decParam.bParseOnly = false;
    decParam.uiTargetDqLayer = UINT8_MAX;
    decParam.eEcActiveIdc = ERROR_CON_SLICE_COPY;
    decParam.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_DEFAULT;
    
    _decoder->Initialize(&decParam);
    
    if ( self.decoder_queue == nil ) {
        self.decoder_queue = dispatch_queue_create("com.yaka.decoder_queue", nil);
    }
}

- (void)releaseDecoder {
    if ( _decoder != nullptr ) {
        _decoder->Uninitialize();
        WelsDestroyDecoder(_decoder);
    }
}

- (void)decode:(Nal*) nal {
    dispatch_async(self.decoder_queue, ^{
        [self decodeFrame:nal.buffer.bytes length:nal.buffer.length];
    });
}

- (void)decodeFrame:(const unsigned char*) src length:(NSUInteger) length {
    if ( _decoder == nil ) {
        NSLog(@"uninitialized openh264 decoder.");
        return;
    }
    uint8_t* data[3] = {nullptr};
    SBufferInfo bufInfo;
    memset (data, 0, sizeof (data));
    memset (&bufInfo, 0, sizeof(bufInfo));
    DECODING_STATE rv = _decoder->DecodeFrameNoDelay(src, (int)length, data, &bufInfo);
    
    if ( rv != dsErrorFree) {
        NSLog(@"decode frame fail error code %d", rv);
        return;
    }

    if (bufInfo.iBufferStatus == 1) {
        VideoFrame *frame = [self yuvVideoFrame:data bufferInfo:bufInfo];
        if ( self.delegate != nil ) {
            [self.delegate decoder:self onDecoded:frame];
        }
    } else {
         [self flushFrame];
    }
}

- (void)flushFrame {
    int32_t num_of_frames_in_buffer = 0;
    uint8_t* data[3] = {nullptr};
    SBufferInfo bufInfo;
    memset (data, 0, sizeof (data));
    memset (&bufInfo, 0, sizeof(bufInfo));
    _decoder->GetOption(DECODER_OPTION_NUM_OF_FRAMES_REMAINING_IN_BUFFER, &num_of_frames_in_buffer);
    for (int32_t i = 0; i < num_of_frames_in_buffer; ++i) {
        DECODING_STATE rv = _decoder->FlushFrame(data, &bufInfo);
        if (rv == dsErrorFree && bufInfo.iBufferStatus == 1 && self.delegate != nil) {
            VideoFrame *frame = [self yuvVideoFrame:data bufferInfo:bufInfo];
            [self.delegate decoder:self onDecoded:frame];
        }
    }
}

- (VideoFrame*)yuvVideoFrame:(uint8_t**) data bufferInfo:(SBufferInfo &) bufInfo {
    int iWidth = bufInfo.UsrData.sSystemBuffer.iWidth;
    int iHeight = bufInfo.UsrData.sSystemBuffer.iHeight;
    MutableI420Buffer *i420Buffer = [[MutableI420Buffer alloc] initWithWidth:iWidth height:iHeight];
    
    int i = 0;
    unsigned char* pSrc = NULL;
    unsigned char* pDst = NULL;
    
    pDst = i420Buffer.mutableDataY;
    pSrc = data[0];
    for (i = 0; i < iHeight; i++) {
        memcpy(pDst, pSrc, iWidth);
        pSrc += bufInfo.UsrData.sSystemBuffer.iStride[0];
        pDst += iWidth;
    }
    
    iHeight = iHeight / 2;
    iWidth = iWidth / 2;
    pDst = i420Buffer.mutableDataU;
    pSrc = data[1];
    for (i = 0; i < iHeight; i++) {
        memcpy(pDst, pSrc, iWidth);
        pSrc += bufInfo.UsrData.sSystemBuffer.iStride[1];
        pDst += iWidth;
    }
    
    pDst = i420Buffer.mutableDataV;
    pSrc = data[2];
    for (i = 0; i < iHeight; i++) {
        memcpy(pDst, pSrc, iWidth);
        pSrc += bufInfo.UsrData.sSystemBuffer.iStride[1];
        pDst += iWidth;
    }
    
    return [[VideoFrame alloc] initWithBuffer:i420Buffer rotation:VideoRotation_0];
}




@end
