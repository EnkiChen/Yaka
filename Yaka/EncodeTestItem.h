//
//  EncodeTestItem.h
//  Yaka
//
//  Created by Enki on 2019/10/17.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EncoderInterface.h"
#import "VT264Decoder.h"
#import "Openh264Decoder.h"

NS_ASSUME_NONNULL_BEGIN

@interface EncodeTestItem : NSObject <EncoderDelegate, DecoderDelegate>

- (instancetype)initEncoder:(id<EncoderInterface>) encoder params:(EncoderParams *) params name:(NSString *) name;

- (void)encode:(VideoFrame*) frame;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
