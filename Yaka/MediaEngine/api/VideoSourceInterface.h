//
//  VideoSourceInterface.h
//  Yaka
//
//  Created by Enki on 2019/8/13.
//  Copyright © 2019 Enki. All rights reserved.
//

#ifndef VideoCapture_h
#define VideoCapture_h

#import "VideoFrame.h"

@protocol H264SourceInterface;
@protocol VideoSourceInterface;
@protocol FileSourceInterface;

@protocol FileSourceDelegate <NSObject>

- (void)fileSource:(id<FileSourceInterface>) fileSource progressUpdated:(NSUInteger) index;
- (void)fileSource:(id<FileSourceInterface>) fileSource fileDidEnd:(NSUInteger) totalFrame;

@end

@protocol FileSourceInterface <NSObject>

@property(nonatomic, weak) id<FileSourceDelegate> fileSourceDelegate;
@property(nonatomic, assign) BOOL isPause;
@property(nonatomic, assign) BOOL isLoop;
@property(nonatomic, assign) NSUInteger fps;
@property(nonatomic, assign, readonly) NSUInteger frameIndex;
@property(nonatomic, assign, readonly) NSUInteger totalFrames;

- (void)pause;

- (void)resume;

- (void)seekToFrameIndex:(NSUInteger) frameIndex;

- (id<NSObject>)frameWithIndex:(NSUInteger) frameIndex;

@end

@protocol VideoSourceSink <NSObject>

- (void)captureSource:(id<VideoSourceInterface>) source onFrame:(VideoFrame *)frame;

@end

@protocol VideoSourceInterface <NSObject>

@property(nonatomic, weak) id<VideoSourceSink> delegate;
@property(nonatomic, assign, readonly) BOOL isRunning;

- (void)start;

- (void)stop;

@end

@protocol ImageFileSourceInterface <VideoSourceInterface, FileSourceInterface>

@end

@protocol H264SourceSink <NSObject>

- (void)h264Source:(id<H264SourceInterface>) source onEncodedImage:(Nal *)encodedImage;

@end

@protocol H264SourceInterface <NSObject>

@property(nonatomic, weak) id<H264SourceSink> delegate;
@property(nonatomic, assign, readonly) BOOL isRunning;

- (void)start;

- (void)stop;

@end

@protocol H264FileSourceInterface <H264SourceInterface, FileSourceInterface>

@end

#endif /* VideoCapture_h */
