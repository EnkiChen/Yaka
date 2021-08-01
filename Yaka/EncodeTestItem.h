//
//  EncodeTestItem.h
//  Yaka
//
//  Created by Enki on 2019/10/17.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "H264EncoderInterface.h"
#import "VideoToolboxVideoDecoder.h"
#import "Openh264VideoDecoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface EncodeTestItem : NSObject <H264EncoderDelegate, H264DecoderDelegate>

- (instancetype)initEncoder:(id<H264EncoderInterface>) encoder params:(EncoderParams *) params name:(NSString *) name;

- (void)encode:(VideoFrame*) frame;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
