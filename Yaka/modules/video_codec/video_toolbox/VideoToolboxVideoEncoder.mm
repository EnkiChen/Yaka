//
//  VideoToolboxVideoEncoder.m
//  Yaka
//
//  Created by Enki on 2019/10/10.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "VideoToolboxVideoEncoder.h"
#import "H264Common.h"

@implementation VideoToolboxVideoEncoder

@synthesize delegate;

-(void)dealloc {
    [self releaseEncoder];
}

- (void)initEncoder {
    
}

- (void)reconfig:(EncoderParams *) params {
    
}

- (void)encode:(VideoFrame*) frame {
    
}

- (void)releaseEncoder {
    
}

@end
