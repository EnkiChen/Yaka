//
//  ViewController.m
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#include <iostream>
#import "MainViewController.h"
#import "FileConfigViewController.h"
#import "FormatConvertVCtrl.h"
#import "DragOperationView.h"
#import "VideoFrame.h"
#import "CameraCapture.h"
#import "DesktopCapture.h"
#import "FileCapture.h"
#import "YuvFileDumper.h"
#import "H264FileDumper.h"
#import "NalUnitSourceFileImp.h"
#import "FlvFileCaptureImp.h"
#import "Openh264Decoder.h"
#import "VT264Encoder.h"
#import "VT264Decoder.h"
#import "VT265Encoder.h"
#import "VT265Decoder.h"
#import "X264Encoder.h"
#import "OpenH264Encoder.h"
#import "H264Common.h"
#import "YuvHelper.h"
#import "RateStatistics.h"
#import "FormatConvert.h"
#import "BulletinView.h"
#import "VideoTrack.h"
#import "ColorToolbox.h"

static NSArray *kAllowedFileTypes = @[@"yuv", @"rgb", @"h264", @"264", @"h265", @"265", @"flv"];

@interface MainViewController() <VideoSourceSink, H264SourceSink, DecoderDelegate, EncoderDelegate, FileConfigDelegate, FileSourceDelegate, PalyCtrlViewDelegae, ThumbnailViewDelegate>

@property(nonatomic, assign) NSUInteger renderCount;
@property(nonatomic, strong) RateStatistics *renderFps;
@property(nonatomic, strong) NSMutableDictionary *frameBuffers;

@property(nonatomic, strong) id<DecoderInterface> decoder;
@property(nonatomic, strong) Openh264Decoder *openh264Decoder;
@property(nonatomic, strong) VT264Decoder *vt264Decoder;
@property(nonatomic, strong) VT265Decoder *vt265Decoder;

@property(nonatomic, strong) dispatch_queue_t encodeQueue;
@property(nonatomic, strong) id<EncoderInterface> encoder;
@property(nonatomic, strong) OpenH264Encoder *openh264Encoder;
@property(nonatomic, strong) X264Encoder *x264Encoder;
@property(nonatomic, strong) VT264Encoder *vt264Encoder;
@property(nonatomic, strong) VT265Encoder *vt265Encoder;
@property(nonatomic, strong) RateStatistics *encodeBitrate;
@property(nonatomic, strong) RateStatistics *encodeFps;

@property(nonatomic, strong) id<VideoSourceInterface> capture;
@property(nonatomic, strong) CameraCapture *cameraCapture;
@property(nonatomic, strong) DesktopCapture *desktopCapture;

@property(nonatomic, assign, getter=isMultiPlayMode) BOOL multiPlayMode;
@property(nonatomic, assign) NSUInteger maxTotalFrames;

@property(nonatomic, strong) id<FileSourceInterface> fileSourceCapture;
@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, strong) VideoTrack *videoTrack;
@property(nonatomic, strong) NSMutableArray<VideoTrack *>* videoTracks;

@property(nonatomic, strong) YuvFileDumper *yuvFileDumper;
@property(nonatomic, strong) H264FileDumper *h264FileDumper;
@property(nonatomic, assign) BOOL isDump;
@property(nonatomic, assign) BOOL dumpType;

@property(nonatomic, strong) NSWindowController *settingWindowCtrl;
@property(nonatomic, strong) NSWindowController *fileConfigWindowCtrl;
@property(nonatomic, strong) NSWindowController *formatConvertWindowCtrl;

@property(nonatomic, strong) BulletinView *bulletinView;

@property (weak) IBOutlet NSLayoutConstraint *thumbnailHeightConstraint;
@property (weak) IBOutlet NSLayoutConstraint *statusbarConstraint;
@property (nonatomic, assign) BOOL isDidSelectItems;

@property(nonatomic, assign) BOOL isLoop;

@property(nonatomic, assign) uint64_t lastPrintLog;
@property(nonatomic, assign) NSUInteger count;

@property(nonatomic, strong) FormatConvert *formatConvert;

@end


@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupUI];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (void)viewWillDisappear {
    [self performClose:nil];
}


#pragma mark - User UI Action
- (IBAction)openDocument:(id)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canCreateDirectories = NO;
    openPanel.canChooseFiles = YES;
    openPanel.allowedFileTypes = kAllowedFileTypes;
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            if ([openPanel.URL.path hasSuffix:@"yuv"] || [openPanel.URL.path hasSuffix:@"rgb"]) {
                [self showFileConfigPanle:openPanel.URL];
            } else {
                [self openFileWithPath:openPanel.URL fileInfo:nil];
            }
        }
    }];
}

- (IBAction)saveDocumentAs:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setCanSelectHiddenExtension:NO];
    [panel setNameFieldStringValue:@"live_360x640x30_I420_vt264_800k.yuv"];
    [panel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSString *chooseFile = [[panel URL] path];
            if ([chooseFile hasSuffix:@".yuv"]) {
                self.yuvFileDumper = [[YuvFileDumper alloc] initWithPath:chooseFile];
                self.yuvFileDumper.isOrdered = YES;
            } else if ( [chooseFile hasSuffix:@".h264"] ) {
                self.h264FileDumper = [[H264FileDumper alloc] initWithPath:chooseFile];
            }
            NSLog(@"choose file:%@", chooseFile);
        }
    }];
}

- (IBAction)performClose:(id)sender {
    [self.capture stop];
    self.capture = nil;
    
    [self.fileSourceCapture stop];
    self.fileSourceCapture = nil;
    
    self.maxTotalFrames = 0;
    for (VideoTrack *videoTrack in self.videoTracks) {
        [videoTrack stop];
    }
    [self.videoTracks removeAllObjects];
    
    [self.h264FileDumper stop];
    self.h264FileDumper = nil;
    
    self.palyCtrlView.progressSlider.minValue = 1;
    self.palyCtrlView.progressSlider.maxValue = 1;
    [self.palyCtrlView.textMaxFrameIndex setStringValue:@"-"];
    [self.palyCtrlView.textCurFrameIndex setStringValue:@"-"];
    [self.palyCtrlView.progressSlider setIntValue:1];
    self.palyCtrlView.playState = PlayControlState_RecordStart;
    
    self.renderCount = 0;
    [self.frameBuffers removeAllObjects];
    
    [self clearRecordState];
}

- (IBAction)openPreferencesWindow:(id)sender {
    NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    self.settingWindowCtrl = [storyBoard instantiateControllerWithIdentifier:@"PreferencesWindow"];
    [self.settingWindowCtrl.window setLevel:NSFloatingWindowLevel];
    [self.settingWindowCtrl showWindow:nil];
}

- (IBAction)openCameraRecord:(id)sender {
    NSMenuItem *menuItem = sender;
    if (menuItem.state == NSControlStateValueOn) {
        return;
    }
    
    [self performClose:nil];
    
    menuItem.state = NSControlStateValueOn;
    NSArray<AVCaptureDevice *> *cameras = [CameraCapture allCameraCapture];
    AVCaptureDevice *capture = [cameras objectAtIndex:menuItem.tag];
    [self.cameraCapture setCaptureDevice:capture];
    self.capture = self.cameraCapture;
    [self.capture start];
    self.palyCtrlView.playState = PlayControlState_RecordStop;
    self.view.window.title = menuItem.title;
}

- (IBAction)openScreenRecord:(id)sender {
    NSMenuItem *menuItem = sender;
    if (menuItem.state == NSControlStateValueOn) {
        return;
    }

    [self performClose:nil];
    
    menuItem.state = NSControlStateValueOn;
    NSArray<DirectDisplay*>* allDirectDisplay = [DesktopCapture allDirectDisplay];
    self.desktopCapture.directDisplay = [allDirectDisplay objectAtIndex:menuItem.tag];
    self.capture = self.desktopCapture;
    [self.capture start];
    self.palyCtrlView.playState = PlayControlState_RecordStop;
    self.view.window.title = menuItem.title;
}

- (IBAction)colorspaceMenuAction:(id)sender {
    NSMenuItem *menuItem = sender;
    if (menuItem.state == NSControlStateValueOn) {
        menuItem.state = NSControlStateValueOff;
    } else {
        menuItem.state = NSControlStateValueOn;
    }
}

- (IBAction)thumbnailMenuAction:(id)sender {
    NSMenuItem *menuItem = sender;
    if (menuItem.state == NSControlStateValueOn) {
        menuItem.state = NSControlStateValueOff;
        self.thumbnailHeightConstraint.constant = 0;
    } else {
        menuItem.state = NSControlStateValueOn;
        self.thumbnailHeightConstraint.constant = 130;
    }
}

- (IBAction)statusbarAction:(id)sender {
    NSMenuItem *menuItem = sender;
    if (menuItem.state == NSControlStateValueOn) {
        menuItem.state = NSControlStateValueOff;
        self.statusbarConstraint.constant = 0;
    } else {
        menuItem.state = NSControlStateValueOn;
        self.statusbarConstraint.constant = 22;
    }
}

- (IBAction)bulletinMenuAction:(id)sender {
    NSMenuItem *menuItem = sender;
    if (menuItem.state == NSControlStateValueOn) {
        menuItem.state = NSControlStateValueOff;
    } else {
        menuItem.state = NSControlStateValueOn;
    }
    self.bulletinView.hidden = (menuItem.state == NSControlStateValueOff);
}

- (IBAction)loopStatUpdated:(id) sender {
    NSMenuItem *loopMenuItem = sender;
    if (loopMenuItem.state == NSControlStateValueOn) {
        loopMenuItem.state = NSControlStateValueOff;
        self.fileSourceCapture.isLoop = YES;
    } else {
        loopMenuItem.state = NSControlStateValueOn;
        self.fileSourceCapture.isLoop = YES;
    }
    for (VideoTrack *videoTrack in self.videoTracks) {
        videoTrack.isLoop = (loopMenuItem.state == NSControlStateValueOn);
    }
}

- (IBAction)multiPlayModeAction:(id)sender {
    NSMenuItem *menuItem = sender;
    NSUInteger index = [menuItem.menu.itemArray indexOfObject:menuItem];
    NSMenuItem *subItem = [menuItem.menu itemAtIndex:index+1];
    if (menuItem.state == NSControlStateValueOn) {
        menuItem.state = NSControlStateValueOff;
        self.multiPlayMode = NO;
        subItem.enabled = NO;
    } else {
        menuItem.state = NSControlStateValueOn;
        self.multiPlayMode = YES;
        subItem.enabled = YES;
    }
}

- (IBAction)multiFileWindowModeAction:(id)sender {
    NSMenuItem *menuItem = sender;
    if (menuItem.tag == 0) {
        menuItem.state = NSControlStateValueOn;
        [menuItem.menu itemAtIndex:1].state = NSControlStateValueOff;
    } else if (menuItem.tag == 1) {
        menuItem.state = NSControlStateValueOn;
        [menuItem.menu itemAtIndex:0].state = NSControlStateValueOff;
    }
}

- (IBAction)rotateAction:(id) sender {
    NSMenuItem *menuItem = sender;
    if ( [menuItem.identifier isEqualToString:@"rotateHorizintal"] ) {
        if (menuItem.state == NSControlStateValueOff) {
            menuItem.state = NSControlStateValueOn;
        } else {
            menuItem.state = NSControlStateValueOff;
        }
    } else if ( [menuItem.identifier isEqualToString:@"rotateVertical"] ) {
        if (menuItem.state == NSControlStateValueOff) {
            menuItem.state = NSControlStateValueOn;
        } else {
            menuItem.state = NSControlStateValueOff;
        }
    } else if ( [menuItem.identifier isEqualToString:@"rotateLeft"] ) {
        
    } else if ( [menuItem.identifier isEqualToString:@"rotateRight"] ) {
        
    }
}

- (IBAction)openConvertTool:(id)sender {
    NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    self.formatConvertWindowCtrl = [storyBoard instantiateControllerWithIdentifier:@"FormatConvert"];
    [self.formatConvertWindowCtrl.window setLevel:NSFloatingWindowLevel];
    [self.formatConvertWindowCtrl showWindow:nil];
}

- (IBAction)openBatchConvertTool:(id)sender {
    [self.formatConvert startTask];
}

- (IBAction)onRendererComboboxChanged:(id)sender {

}

- (IBAction)onDecoderComboboxChanged:(id)sender {
    NSComboBox *combobox = (NSComboBox*)sender;
    switch (combobox.indexOfSelectedItem) {
        case 0:
            self.decoder = self.openh264Decoder;
            break;
        case 1:
            self.decoder = self.vt264Decoder;
            break;
        default:
            break;
    }
}


#pragma mark - FileConfigDelegae
- (void)fileConfigViewController:(FileConfigViewController*)fileConfigCtrl openDocument:(NSURL*)path {
    [self.fileConfigWindowCtrl close];
    [self openDocument:nil];
}

- (void)fileConfigViewController:(FileConfigViewController*)fileConfigCtrl filePath:(NSURL*)fileUrl width:(int)widht height:(int)height formatIndex:(int)formatIndex {
    if (![fileUrl.path hasSuffix:@".yuv"] && [fileUrl.path hasSuffix:@".rgb"]) {
        [self showMessage:@"提示" message:@"请选择正确的文件格式！" window:self.fileConfigWindowCtrl.window];
        return;
    }
    if (fileUrl.path.length == 0 || widht == 0 || height == 0) {
        [self showMessage:@"提示" message:@"参数信息错误！" window:self.fileConfigWindowCtrl.window];
        return;
    }
    NSDictionary *fileInfo = @{
        @"width" : @(widht),
        @"height" : @(height),
        @"formatIndex" : @(formatIndex)
    };
    [self openFileWithPath:fileUrl fileInfo:fileInfo];
    [self.fileConfigWindowCtrl close];
}


#pragma mark - h264 capture Action
- (void)h264Source:(id<H264SourceInterface>) source onEncodedImage:(Nal *)nal {
    if (nal.nalType == NalType_H264) {
        [self.vt264Decoder decode:nal];
    } else if (nal.nalType == NalType_HEVC) {
        [self.vt265Decoder decode:nal];
    }
}


#pragma mark - VideoSourceInterface Action
- (void)captureSource:(id<VideoSourceInterface>) source onFrame:(VideoFrame *)frame {
   if ([self.videoTracks containsObject:(VideoTrack *)source]) {
       NSUInteger index = [self.videoTracks indexOfObject:(VideoTrack *)source];
       [self renderFrame:frame withIndex:index];
   } else {
       [self renderFrame:frame];
   }

    // dispatch_async(self.encodeQueue, ^{
    //     [self.openh264Encoder encode:frame];
    //     uint64_t now_ms = [[NSDate date] timeIntervalSince1970] * 1000;
    //     [self.encodeFps update:1 now:now_ms];
    // });
}

#pragma mark - h264 Encode Action
- (void)encoder:(id<EncoderInterface>) encoder onEncoded:(Nal *) nal {
    if ( self.h264FileDumper != nil ) {
        [self.h264FileDumper dumpToFile:nal];
    }
    uint64_t now_ms = [[NSDate date] timeIntervalSince1970] * 1000;
    [self.encodeBitrate update:nal.buffer.length * 8 now:now_ms];
    
    if (now_ms - self.lastPrintLog >= 1000) {
        NSLog(@"encode %llufps output %llukbps", [self.encodeFps rate:now_ms], [self.encodeBitrate rate:now_ms] / 1000);
        self.lastPrintLog = now_ms;
    }
    [self.vt264Decoder decode:nal];
}

#pragma mark - h264 decode Action
- (void)decoder:(id<DecoderInterface>) decoder onDecoded:(VideoFrame *)frame {
    [self renderFrame:frame];
}

#pragma mark - ThumbnailViewDelegate
- (void)thumbnailView:(ThumbnailView *)thumbnailView didSelectItemsAtIndexPaths:(NSIndexPath *)indexPath {
    for (VideoTrack *videoTrack in self.videoTracks) {
        if (indexPath.item <= videoTrack.totalFrames && indexPath.item > 0) {
            self.isDidSelectItems = YES;
            [videoTrack seekToFrameIndex:indexPath.item];
        }
    }
}


#pragma mark - FileSourceInterface Action
- (void)fileSource:(id<FileSourceInterface>) fileSource progressUpdated:(NSUInteger) index {
    if ([self.videoTracks containsObject:(VideoTrack *)fileSource]) {
        NSUInteger trackIndex = [self.videoTracks indexOfObject:(VideoTrack *)fileSource];
        NSMutableArray *frames = [self.frameBuffers objectForKey:@(trackIndex)];
        // todo:播放到最后一帧时，缓存的帧，应该要渲染出来，而不是丢弃
        if (index + 1 == fileSource.totalFrames) {
            [frames removeAllObjects];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.palyCtrlView.isDragging) {
            [self.palyCtrlView.progressSlider setIntValue:(int)index + 1];
        }
        [self.palyCtrlView.textCurFrameIndex setStringValue:[NSString stringWithFormat:@"%lu", (unsigned long)index + 1]];

        if (self.thumbnailView.thumbnails.count > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
            NSCollectionViewScrollPosition position = NSCollectionViewScrollPositionCenteredHorizontally;
            if (self.isDidSelectItems) {
                position = NSCollectionViewScrollPositionNone;
            }
            [self.thumbnailView selectItemsAtIndexPaths:[NSSet setWithObject:indexPath] scrollPosition:position];
            self.isDidSelectItems = NO;
        }
    });
}

- (void)fileSource:(id<FileSourceInterface>) fileSource fileDidEnd:(NSUInteger) totalFrame {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.palyCtrlView.playState = PlayControlState_Play;
    });
}


#pragma mark - PalyCtrlView Action
- (void)palyCtrlView:(PalyCtrlView*)palyCtrlView progressUpdated:(NSInteger)index {
    for (VideoTrack *videoTrack in self.videoTracks) {
        if (index <= videoTrack.totalFrames && index > 0) {
            [videoTrack seekToFrameIndex:index - 1];
        }
    }
}

- (void)palyCtrlView:(PalyCtrlView*) palyCtrlView fpsUpdated:(int) fps {
    self.fileSourceCapture.fps = fps;
    for (VideoTrack *videoTrack in self.videoTracks) {
        videoTrack.fps = fps;
    }
}

- (void)palyCtrlView:(PalyCtrlView*) palyCtrlView playStatusUpdated:(CtrlType) ctrlType {
    if (ctrlType == CtrlType_RecordStart) {
        NSMenu *cameraMenu = [[[NSApp menu] itemAtIndex:1].submenu itemAtIndex:0].submenu;
        for (int i = 0; i < cameraMenu.numberOfItems; i++) {
            NSMenuItem *menuItem = [cameraMenu itemAtIndex:i];
            if (menuItem.enabled) {
                [self openCameraRecord:menuItem];
                return;
            }
        }
        return;
    } else if (ctrlType == CtrlType_RecordStop) {
        [self.capture stop];
        self.palyCtrlView.playState = PlayControlState_RecordStart;
        [self clearRecordState];
        return;
    }
    
    if (self.videoTracks.count != 0) {
        if (ctrlType == CtrlType_Play) {
            self.palyCtrlView.playState = PlayControlState_Stop;
            for (VideoTrack *videoTrack in self.videoTracks) {
                if (videoTrack.isPause) {
                    [videoTrack resume];
                } else {
                    [videoTrack start];
                }
            }
        } else if (ctrlType == CtrlType_Pause) {
            self.palyCtrlView.playState = PlayControlState_Play;
            for (VideoTrack *videoTrack in self.videoTracks) {
                if (!videoTrack.isPause) {
                    [videoTrack pause];
                }
            }
        } else if (ctrlType == CtrlType_Rewind) {
            for (VideoTrack *videoTrack in self.videoTracks) {
                NSUInteger frameIndex = videoTrack.frameIndex;
                if (frameIndex != 0) {
                    [videoTrack seekToFrameIndex:frameIndex - 1];
                }
            }
        } else if (ctrlType == CtrlType_FastForward) {
            for (VideoTrack *videoTrack in self.videoTracks) {
                NSUInteger totalFrames = videoTrack.totalFrames;
                NSUInteger frameIndex = videoTrack.frameIndex;
                if (totalFrames > 0 && frameIndex < totalFrames - 1) {
                    [videoTrack seekToFrameIndex:frameIndex + 1];
                }
            }
        } else if (ctrlType == CtrlType_SkipToStart) {
            for (VideoTrack *videoTrack in self.videoTracks) {
                NSUInteger frameIndex = videoTrack.frameIndex;
                if (frameIndex != 0) {
                    [videoTrack seekToFrameIndex:0];
                }
            }
        } else if (ctrlType == CtrlType_SkipToEnd) {
            for (VideoTrack *videoTrack in self.videoTracks) {
                NSUInteger totalFrames = videoTrack.totalFrames;
                if (totalFrames > 0) {
                    [videoTrack seekToFrameIndex:totalFrames - 1];
                }
            }
        }
    }
}


#pragma mark - DragOperationViewDelegate
- (NSDragOperation)dragOperationView:(DragOperationView*) view draggingEntered:(NSArray<NSURL *>*) fileUrls {
    if (fileUrls.count == 1) {
        for (NSString *fileType in kAllowedFileTypes) {
            if ([fileUrls.lastObject.path hasSuffix:fileType] ) {
                return NSDragOperationCopy;
            }
        }
    }
    return NSDragOperationNone;
}

- (void)dragOperationView:(DragOperationView*) view prepareForDragOperation:(NSArray<NSURL *>*) fileUrls {
    if (fileUrls.count == 1) {
        if ([fileUrls.lastObject.path hasSuffix:@"yuv"]) {
            [self showFileConfigPanle:fileUrls.lastObject];
        } else {
            [self openFileWithPath:fileUrls.lastObject fileInfo:nil];
        }
    }
}


#pragma mark - Private Method
- (void)openFileWithPath:(NSURL*)filePath fileInfo:(NSDictionary *)fileInfo {
    self.filePath = [filePath.path lowercaseString];
    self.view.window.title = [filePath.path componentsSeparatedByString:@"/"].lastObject;

    if (!self.multiPlayMode) {
        [self performClose:nil];
    }
    
    if ([filePath.path hasSuffix:@"yuv"] || [filePath.path hasSuffix:@"rgb"]) {
        int width = [fileInfo[@"width"] intValue];
        int height = [fileInfo[@"height"] intValue];
        int formatIndex = [fileInfo[@"formatIndex"] intValue];
        PixelFormatType formats[] = {
            kPixelFormatType_420_I420,
            kPixelFormatType_420_NV12,
            kPixelFormatType_420_P010,
            kPixelFormatType_420_I010,
            kPixelFormatType_32BGRA
        };
        PixelFormatType format = formats[formatIndex];
        self.videoTrack = [[VideoTrack alloc] initWithRawFile:filePath.path width:width height:height pixelFormat:format];
    } else if ([filePath.path hasSuffix:@"h264"] || [filePath.path hasSuffix:@"264"]
               || [filePath.path hasSuffix:@"h265"] || [filePath.path hasSuffix:@"265"] ) {
        self.videoTrack = [[VideoTrack alloc] initWithNalFile:filePath.path];
    } else if ([filePath.path hasSuffix:@"flv"]) {
        self.videoTrack = [[VideoTrack alloc] initWithFlvFile:filePath.path];
    }
    
    [self.videoTracks addObject:self.videoTrack];
    self.multiPlayView.maxPlayCount = self.videoTracks.count;
    
    self.fileSourceCapture = self.videoTrack;
    self.videoTrack.delegate = self;
    self.videoTrack.fileSourceDelegate = self;
    self.videoTrack.isLoop = self.isLoop;
    self.videoTrack.fps = self.palyCtrlView.textFps.intValue;
    
    if (self.videoTrack.totalFrames > self.maxTotalFrames) {
        self.maxTotalFrames = self.videoTrack.totalFrames;
    }
    
//    NSMutableArray *frames = [[NSMutableArray alloc] initWithCapacity:self.videoTrack.totalFrames];
//    for (int i = 0; i < self.videoTrack.totalFrames; i++) {
//        VideoFrame *frame = [self.videoTrack frameWithIndex:i];
//        if (frame != nil) {
//            [frames addObject:frame];
//        }
//    }
//    self.thumbnailView.thumbnails = frames;
    
    self.palyCtrlView.progressSlider.minValue = 1;
    self.palyCtrlView.progressSlider.maxValue = self.maxTotalFrames;
    [self.palyCtrlView.textMaxFrameIndex setStringValue:[NSString stringWithFormat:@"%lu", (unsigned long)self.maxTotalFrames]];
    [self.palyCtrlView.progressSlider setIntValue:1];
    self.palyCtrlView.playState = PlayControlState_Play;
    
    for (VideoTrack *videoTrack in self.videoTracks) {
        [videoTrack pause];
        [videoTrack seekToFrameIndex:0];
    }
    [self.frameBuffers removeAllObjects];
}

- (void)showFileConfigPanle:(NSURL*)fileUrl {
    NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    self.fileConfigWindowCtrl = [storyBoard instantiateControllerWithIdentifier:@"FileConfigPanel"];
    [self.fileConfigWindowCtrl.window setLevel:NSFloatingWindowLevel];
    FileConfigViewController *fileConfigVC = (FileConfigViewController*)[self.fileConfigWindowCtrl contentViewController];
    fileConfigVC.delegate = self;
    fileConfigVC.fileUrl = fileUrl;
    [self.fileConfigWindowCtrl showWindow:nil];
}

- (void)renderFrame:(VideoFrame *)frame {
    [self renderFrame:frame withIndex:0];
}

- (void)renderFrame:(VideoFrame *)frame withIndex:(NSUInteger)index {
    uint64_t now_ms = [[NSDate date] timeIntervalSince1970] * 1000;
    [self.renderFps update:1 now:now_ms];
    self.renderCount++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.bulletinView setStringValue:[NSString stringWithFormat:@"渲染分辨率：%dx%d", frame.width, frame.height] withRow:0];
        [self.bulletinView setStringValue:[NSString stringWithFormat:@"渲染帧率：%llu", [self.renderFps rate:now_ms]] withRow:1];
        [self.bulletinView setStringValue:[NSString stringWithFormat:@"渲染帧数：%lu", (unsigned long)self.renderCount] withRow:2];
        [self.bulletinView setStringValue:[NSString stringWithFormat:@"编码码率：%llukbps", [self.encodeBitrate rate:now_ms] / 1000] withRow:3];
    });

    if ( self.yuvFileDumper != nil ) {
        [self.yuvFileDumper dumpToFile:frame];
    }

    frame = [self pushFrameToOrderedlist:frame withIndex:index];
    if (frame != nil) {
        [self.multiPlayView renderFrame:frame withIndex:index];
    }
}

- (VideoFrame*)pushFrameToOrderedlist:(VideoFrame*)frame withIndex:(NSUInteger)index {
    if (CMTIME_IS_INVALID(frame.presentationTimeStamp)) {
        return frame;
    }
    
    NSMutableArray<VideoFrame*> *frames = [self.frameBuffers objectForKey:@(index)];
    if (frames == nil) {
        frames = [[NSMutableArray alloc] init];
        [self.frameBuffers setObject:frames forKey:@(index)];
    }
    
    index = 0;
    for (; index < frames.count; index++) {
        if (CMTimeCompare(frame.presentationTimeStamp, frames[index].presentationTimeStamp) == -1) {
            break;
        }
    }
    
    [frames insertObject:frame atIndex:index];
    
    if (frames.count < 4) {
        return nil;
    } else {
        frame = frames.firstObject;
        [frames removeObjectAtIndex:0];
        return frame;
    }
}

- (void)showMessage:(NSString *) title message:(NSString *) msg window:(NSWindow*) window {
    NSAlert *alert = [NSAlert new];
    [alert addButtonWithTitle:@"确定"];
    [alert setMessageText:title];
    [alert setInformativeText:msg];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert beginSheetModalForWindow:window completionHandler:nil];
}

- (void)setupUI {
    self.videoTracks = [[NSMutableArray alloc] initWithCapacity:5];
    self.decoder = self.openh264Decoder;
    self.encoder = self.openh264Encoder;
    self.palyCtrlView.delegate = self;
    [self updateRecordMenu];
    [self setupBulletinView];
    self.thumbnailHeightConstraint.constant = 0;
    self.thumbnailView.eventDelegate = self;
}

- (void)setupBulletinView {
    int rowCount = 4;
    self.bulletinView = [[BulletinView alloc] initWithFrame:CGRectMake(10, 10, 300, rowCount * 15)];
    self.bulletinView.rowCount = rowCount;
    [self.multiPlayView.superview addSubview:self.bulletinView];
}

- (void)updateRecordMenu {
    NSMenuItem *srMenu = [[[NSApp menu] itemAtIndex:1].submenu itemAtIndex:1];
    NSArray<DirectDisplay*>* allDirectDisplay = [DesktopCapture allDirectDisplay];
    int index = 0;
    for (DirectDisplay* display in allDirectDisplay) {
        NSString *title = [NSString stringWithFormat:@"屏幕 %d (%dx%d)", index + 1, (int)display.bounds.size.width, (int)display.bounds.size.height];
        NSMenuItem *mentItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(openScreenRecord:) keyEquivalent:@""];
        mentItem.tag = index++;
        [srMenu.submenu addItem:mentItem];
    }
    
    NSMenuItem *crMenu = [[[NSApp menu] itemAtIndex:1].submenu itemAtIndex:0];
    NSArray<AVCaptureDevice *> *allCamera = [CameraCapture allCameraCapture];
    for (int i = 0; i < allCamera.count; i++) {
        AVCaptureDevice *capture = [allCamera objectAtIndex:i];
        NSMenuItem *mentItem = [[NSMenuItem alloc] initWithTitle:capture.localizedName action:@selector(openCameraRecord:) keyEquivalent:@""];
        mentItem.tag = i;
        mentItem.enabled = !capture.isSuspended;
        [crMenu.submenu addItem:mentItem];
    }
}

- (void)clearRecordState {
    NSMenuItem *srMenu = [[[NSApp menu] itemAtIndex:1].submenu itemAtIndex:0];
    for (NSMenuItem *menuItem in srMenu.submenu.itemArray) {
        menuItem.state = NSControlStateValueOff;
    }
    
    NSMenuItem *crMenu = [[[NSApp menu] itemAtIndex:1].submenu itemAtIndex:1];
    for (NSMenuItem *menuItem in crMenu.submenu.itemArray) {
        menuItem.state = NSControlStateValueOff;
    }
}


#pragma mark - getter&setter
- (BOOL)isLoop {
    NSMenuItem *loopMenuItem = [[[NSApp menu] itemAtIndex:3].submenu itemAtIndex:7];
    if (loopMenuItem) {
        return loopMenuItem.state == NSControlStateValueOn;
    }
    return NO;
}

- (void)setIsLoop:(BOOL)isLoop {
    NSMenuItem *loopMenuItem = [[[NSApp menu] itemAtIndex:3].submenu itemAtIndex:7];
    if (isLoop) {
        loopMenuItem.state = NSControlStateValueOn;
    } else {
        loopMenuItem.state = NSControlStateValueOff;
    }
}

- (CameraCapture*)cameraCapture {
    if ( _cameraCapture == nil ) {
        _cameraCapture = [[CameraCapture alloc] init];
        _cameraCapture.delegate = self;
    }
    return _cameraCapture;
}

-(DesktopCapture*)desktopCapture {
    if ( _desktopCapture == nil ) {
        _desktopCapture = [[DesktopCapture alloc] init];
        _desktopCapture.delegate = self;
    }
    return _desktopCapture;
}

- (Openh264Decoder*)openh264Decoder {
    if ( _openh264Decoder == nil ) {
        _openh264Decoder = [[Openh264Decoder alloc] init];
        _openh264Decoder.delegate = self;
        [_openh264Decoder initDecoder];
    }
    return _openh264Decoder;
}

- (VT264Decoder*)vt264Decoder {
    if ( _vt264Decoder == nil ) {
        _vt264Decoder = [[VT264Decoder alloc] init];
        _vt264Decoder.delegate = self;
        [_vt264Decoder initDecoder];
    }
    return _vt264Decoder;
}

- (dispatch_queue_t)encodeQueue {
    if (_encodeQueue == nil) {
        _encodeQueue = dispatch_queue_create("com.enkichen.yaka.encode_queue", DISPATCH_QUEUE_SERIAL);
    }
    return _encodeQueue;
}

- (VT264Encoder*)vt264Encoder {
    if (_vt264Encoder == nil) {
        _vt264Encoder = [[VT264Encoder alloc] init];
        _vt264Encoder.delegate = self;
        [_vt264Encoder initEncoder];
    }
    return _vt264Encoder;
}

-(OpenH264Encoder*)openh264Encoder {
    if ( _openh264Encoder == nil ) {
        _openh264Encoder = [[OpenH264Encoder alloc] init];
        _openh264Encoder.delegate = self;
        [_openh264Encoder initEncoder];
    }
    return _openh264Encoder;
}

- (X264Encoder*)x264Encoder {
    if ( _x264Encoder == nil ) {
        _x264Encoder = [[X264Encoder alloc] init];
        _x264Encoder.delegate = self;
        [_x264Encoder initEncoder];
    }
    return _x264Encoder;
}

- (VT265Decoder*)vt265Decoder {
    if (_vt265Decoder == nil) {
        _vt265Decoder = [[VT265Decoder alloc] init];
        _vt265Decoder.delegate = self;
        [_vt265Decoder initDecoder];
    }
    return _vt265Decoder;
}

- (VT265Encoder*)vt265Encoder {
    if (_vt265Encoder == nil) {
        _vt265Encoder = [[VT265Encoder alloc] init];
        _vt265Encoder.delegate = self;
        [_vt265Encoder initEncoder];
    }
    return _vt265Encoder;
}

- (RateStatistics*)encodeBitrate {
    if (_encodeBitrate == nil) {
        _encodeBitrate = [[RateStatistics alloc] initWithWindowSize:1000];
    }
    return _encodeBitrate;
}

- (RateStatistics*)encodeFps {
    if (_encodeFps == nil) {
        _encodeFps = [[RateStatistics alloc] initWithWindowSize:1000];
    }
    return _encodeFps;
}

- (RateStatistics*)renderFps {
    if (_renderFps == nil) {
        _renderFps = [[RateStatistics alloc] initWithWindowSize:1000];
    }
    return _renderFps;
}

- (NSMutableDictionary*)frameBuffers {
    if (_frameBuffers == nil) {
        _frameBuffers = [[NSMutableDictionary alloc] init];
    }
    return _frameBuffers;
}

- (FormatConvert*)formatConvert {
    if (_formatConvert == nil) {
        _formatConvert = [[FormatConvert alloc] init];
    }
    return _formatConvert;
}

@end
