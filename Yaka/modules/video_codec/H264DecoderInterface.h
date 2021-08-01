//
//  VideoDecoderInterface.h
//  Yaka
//
//  Created by Enki on 2019/8/30.
//  Copyright © 2019 Enki. All rights reserved.
//

#ifndef VideoDecoderInterface_h
#define VideoDecoderInterface_h

#import "VideoFrame.h"

@protocol H264DecoderInterface;

@protocol H264DecoderDelegate <NSObject>

- (void)decoder:(id<H264DecoderInterface>) decoder onDecoded:(VideoFrame *) frame;

@end


@protocol H264DecoderInterface <NSObject>

@property(nonatomic, weak) id<H264DecoderDelegate> delegate;

- (void)initDecoder;

- (void)decode:(Nal*) nal;

- (void)releaseDecoder;

@end

#endif /* VideoDecoderInterface_h */
