//
//  VideoCapture.h
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "VideoSourceInterface.h"

NS_ASSUME_NONNULL_BEGIN

@interface CameraCapture : NSObject <VideoSourceInterface>

@property(nonatomic, strong) AVCaptureDevice* captureDevice;

+ (NSArray<AVCaptureDevice *> *)allCameraCapture;

- (void)addPreview:(AVCaptureVideoPreviewLayer*) previewLayer;

- (void)removePreview:(AVCaptureVideoPreviewLayer*) previewLayer;

@end

NS_ASSUME_NONNULL_END
