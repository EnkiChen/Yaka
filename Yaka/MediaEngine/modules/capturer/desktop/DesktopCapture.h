//
//  DesktopCapture.h
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VideoSourceInterface.h"

NS_ASSUME_NONNULL_BEGIN

@interface DirectDisplay : NSObject

@property (nonatomic, assign) CGDirectDisplayID displayId;
@property (nonatomic, assign) NSRect bounds;

@end

@interface DesktopCapture : NSObject <VideoSourceInterface>

@property(nonatomic, strong) DirectDisplay *directDisplay;

+ (NSArray<DirectDisplay*>*)allDirectDisplay;

@end

NS_ASSUME_NONNULL_END
