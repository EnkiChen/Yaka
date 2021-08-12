//
//  H264EncoderInterface.h
//  Yaka
//
//  Created by Enki on 2019/10/9.
//  Copyright © 2019 Enki. All rights reserved.
//

#ifndef H264EncoderInterface_h
#define H264EncoderInterface_h

#import "VideoFrame.h"

@protocol EncoderInterface;

@interface EncoderParams : NSObject

@property(nonatomic, assign) int maxQp;
@property(nonatomic, assign) int minQp;
@property(nonatomic, assign) int targetBitrateBps;
@property(nonatomic, assign) int maxBitrateBps;
@property(nonatomic, assign) int maxFramerate;
@property(nonatomic, assign) int gopSize;

@end

@protocol EncoderDelegate <NSObject>

- (void)encoder:(id<EncoderInterface>) encoder onEncoded:(Nal *) nal;

@end


@protocol EncoderInterface <NSObject>

@property(nonatomic, weak) id<EncoderDelegate> delegate;

- (void)initEncoder;

- (void)reconfig:(EncoderParams *) params;

- (void)encode:(VideoFrame*) frame;

- (void)releaseEncoder;

@end

#endif /* H264EncoderInterface_h */
