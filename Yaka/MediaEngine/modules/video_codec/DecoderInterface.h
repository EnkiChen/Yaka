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

@protocol DecoderInterface;

@protocol DecoderDelegate <NSObject>

- (void)decoder:(id<DecoderInterface>) decoder onDecoded:(VideoFrame *) frame;

@end


@protocol DecoderInterface <NSObject>

@property(nonatomic, weak) id<DecoderDelegate> delegate;

- (void)initDecoder;

- (void)decode:(Nal*) nal;

- (void)releaseDecoder;

@end

#endif /* VideoDecoderInterface_h */
