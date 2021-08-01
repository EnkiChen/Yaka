//
//  ViewController.m
//  Yaka
//
//  Created by Enki on 2019/2/28.
//  Copyright © 2019 Enki. All rights reserved.
//

#include <iostream>
#import "ViewController.h"
#import "FileConfigViewController.h"
#import "VideoFrame.h"
#import "CameraCapture.h"
#import "DesktopCapture.h"
#import "FileCapture.h"
#import "YuvFileDumper.h"
#import "H264FileDumper.h"
#import "H264SourceFileImp.h"
#import "Openh264VideoDecoder.h"
#import "VideoToolboxVideoDecoder.h"
#import "X264VideoEncoder.h"
#import "OpenH264VideoEncoder.h"
#import "H264Common.h"
#import "EncodeTestItem.h"
#include "YuvHelper.h"



@interface ViewController() <VideoSourceSink, H264SourceSink, H264DecoderDelegate, H264EncoderDelegate, FileConfigDelegate, FileSourceDelegate, PalyCtrlViewDelegae>

@property(nonatomic, weak) id<VideoRenderer> videoRenderer;

@property(nonatomic, strong) id<H264DecoderInterface> h264Decoder;
@property(nonatomic, strong) Openh264VideoDecoder *openh264Decoder;
@property(nonatomic, strong) VideoToolboxVideoDecoder *videoToolboxDecoder;

@property(nonatomic, strong) id<H264EncoderInterface> h264Encoder;
@property(nonatomic, strong) OpenH264VideoEncoder *openh264Encoder;
@property(nonatomic, strong) X264VideoEncoder *x264Encoder;

@property(nonatomic, strong) id<VideoSourceInterface> capture;
@property(nonatomic, strong) id<FileSourceInterface> fileSourceCapture;
@property(nonatomic, strong) CameraCapture *cameraCapture;
@property(nonatomic, strong) DesktopCapture *desktopCapture;
@property(nonatomic, strong) FileCapture *fileCapture;
@property(nonatomic, assign) NSUInteger captureType;

@property(nonatomic, strong) id<H264SourceInterface> h264Source;
@property(nonatomic, strong) H264SourceFileImp *h264FileSoucre;

@property(nonatomic, strong) YuvFileDumper *yuvFileDumper;
@property(nonatomic, strong) H264FileDumper *h264FileDumper;
@property(nonatomic, assign) BOOL isDump;
@property(nonatomic, assign) BOOL dumpType;

@property(nonatomic, strong) NSWindowController *fileConfigWindowCtrl;

@property(nonatomic, assign) BOOL isLoop;

@end


@implementation ViewController

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
    if ( self.capture.isRunning ) {
        [self.capture stop];
        [self.yuvFileDumper stop];
    }
}


#pragma mark -
#pragma mark User UI Action

- (IBAction)magicAction:(id)sender {

}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canCreateDirectories = NO;
    openPanel.canChooseFiles = YES;
    openPanel.allowedFileTypes = @[@"yuv", @"h264", @"264"];
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if ( result == NSModalResponseOK ) {
            if ( [openPanel.URL.path hasSuffix:@"yuv"] ) {
                [self showFileConfigPanle:openPanel.URL.path];
            } else {
                [self performClose:nil];
                
                self.h264FileSoucre = [[H264SourceFileImp alloc] initWithPath:openPanel.URL.path];
                self.h264Source = self.h264FileSoucre;
                self.fileSourceCapture = self.h264FileSoucre;
                
                self.h264FileSoucre.delegate = self;
                self.h264FileSoucre.fileSourceDelegate = self;
                [self.h264FileSoucre start];
                
                self.view.window.title = [openPanel.URL.path componentsSeparatedByString:@"/"].lastObject;

                self.palyCtrlView.progressSlider.minValue = 1;
                self.palyCtrlView.progressSlider.maxValue = self.h264FileSoucre.totalFrames;
                self.palyCtrlView.formatComboBox.enabled = NO;
                [self.palyCtrlView.textMaxFrameIndex setStringValue:[NSString stringWithFormat:@"%lu", (unsigned long)self.h264FileSoucre.totalFrames]];
                [self.palyCtrlView.progressSlider setIntValue:1];
                self.fileCapture.fps = self.palyCtrlView.textFps.intValue;
                self.palyCtrlView.playState = PlayControlState_Stop;
            }
        }
    }];
}

- (IBAction)performClose:(id)sender {
    if ( self.capture != nil ) {
        [self.capture stop];
        self.capture = nil;
    }
    
    if ( self.h264FileSoucre != nil ) {
        [self.h264FileSoucre stop];
        self.h264FileSoucre = nil;
    }
    
    if ( self.fileCapture != nil ) {
        [self.fileCapture stop];
        self.fileCapture = nil;
    }
    
    self.h264Source = nil;
    self.fileSourceCapture = nil;
    
    self.palyCtrlView.progressSlider.minValue = 1;
    self.palyCtrlView.progressSlider.maxValue = 1;
    self.palyCtrlView.formatComboBox.enabled = NO;
    [self.palyCtrlView.textMaxFrameIndex setStringValue:@"-"];
    [self.palyCtrlView.textCurFrameIndex setStringValue:@"-"];
    [self.palyCtrlView.progressSlider setIntValue:1];
    self.palyCtrlView.playState = PlayControlState_RecordStart;
    
    [self clearRecordState];
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

- (IBAction)loopStatUpdated:(id) sender {
    NSMenuItem *loopMenuItem = sender;
    if (loopMenuItem.state == NSControlStateValueOn) {
        loopMenuItem.state = NSControlStateValueOff;
        self.fileCapture.isLoop = NO;
    } else {
        loopMenuItem.state = NSControlStateValueOn;
        self.fileCapture.isLoop = YES;
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

- (IBAction)dumpAction:(id)sender {
    NSButton *btn = sender;
    if ( self.isDump ) {
        [self.yuvFileDumper stop];
        self.yuvFileDumper = nil;
        [self.h264FileDumper stop];
        self.h264FileDumper = nil;
        [btn setTitle:@"开始存储"];
        self.isDump = NO;
        return;
    }
    
    NSString *dumpPath = @"";
    if ( [dumpPath hasSuffix:@".yuv"] ) {
        self.yuvFileDumper = [[YuvFileDumper alloc] initWithPath:dumpPath];
    } else if ( [dumpPath hasSuffix:@".h264"] ) {
        self.h264FileDumper = [[H264FileDumper alloc] initWithPath:dumpPath];
    }
    
    if ( self.yuvFileDumper != nil || self.h264FileDumper != nil ) {
        [btn setTitle:@"停止存储"];
        self.isDump = YES;
    }
}

- (IBAction)onRendererComboboxChanged:(id)sender {
    NSComboBox *combobox = (NSComboBox*)sender;
    id<VideoRenderer> renderView = self.videoRenderer;
    switch (combobox.indexOfSelectedItem) {
        case 0:
            self.videoRenderer = self.glVideoView;
            break;
        case 1:
            self.videoRenderer = self.metalRenderView;
            break;
        case 2:
            self.videoRenderer = self.sampleRenderView;
            break;
        default:
            break;
    }
    if ( renderView != self.videoRenderer ) {
        ((NSView*)self.videoRenderer).hidden = NO;
        ((NSView*)renderView).hidden = YES;
    }
}

- (IBAction)onDecoderComboboxChanged:(id)sender {
    NSComboBox *combobox = (NSComboBox*)sender;
    switch (combobox.indexOfSelectedItem) {
        case 0:
            self.h264Decoder = self.openh264Decoder;
            break;
        case 1:
            self.h264Decoder = self.videoToolboxDecoder;
            break;
        default:
            break;
    }
}


#pragma mark -
#pragma mark FileConfigDelegae

- (void)fileConfigViewController:(FileConfigViewController*) fileConfigCtrl openDocument:(NSString*) path {
    [self.fileConfigWindowCtrl close];
    [self openDocument:nil];
}

- (void)fileConfigViewController:(FileConfigViewController*) fileConfigCtrl filePath:(NSString*) filePath width:(int) widht height:(int) height formatIndex:(int) formatIndex {
    if ( filePath.length == 0 || widht == 0 || height == 0 ) {
        [self showMessage:@"提示" message:@"参数信息错误！" window:self.fileConfigWindowCtrl.window];
        return;
    }

    [self performClose:nil];

    self.view.window.title = [filePath componentsSeparatedByString:@"/"].lastObject;
    
    PixelFormatType format = formatIndex == 0 ? kPixelFormatType_I420 : kPixelFormatType_NV12;
    self.fileCapture = [[FileCapture alloc] initWithPath:filePath width:widht height:height pixelFormatType:format];
    self.fileSourceCapture = self.fileCapture;
    self.capture = self.fileCapture;
    self.fileCapture.delegate = self;
    self.fileCapture.fileSourceDelegate = self;
    self.fileCapture.isLoop = self.isLoop;
    [self.fileCapture start];
    
    self.palyCtrlView.progressSlider.minValue = 1;
    self.palyCtrlView.progressSlider.maxValue = self.fileCapture.totalFrames;
    self.palyCtrlView.formatComboBox.enabled = YES;
    [self.palyCtrlView.formatComboBox selectItemAtIndex:formatIndex];
    [self.palyCtrlView.textMaxFrameIndex setStringValue:[NSString stringWithFormat:@"%lu", (unsigned long)self.fileCapture.totalFrames]];
    [self.palyCtrlView.progressSlider setIntValue:1];
    self.fileCapture.fps = self.palyCtrlView.textFps.intValue;
    self.palyCtrlView.playState = PlayControlState_Stop;

    [self.fileConfigWindowCtrl close];
}


#pragma mark -
#pragma mark h264 capture Action

- (void)h264Source:(id<H264SourceInterface>) source onEncodedImage:(Nal *)nal {
    [self.h264Decoder decode:nal];
}


#pragma mark -
#pragma mark VideoSourceInterface Action

- (void)captureSource:(id<VideoSourceInterface>) source onFrame:(VideoFrame *)frame {
    [self renderFrame:frame];
}


#pragma mark -
#pragma mark h264 Encode Action

- (void)encoder:(id<H264EncoderInterface>) encoder onEncoded:(Nal *) nal {
    if ( self.h264FileDumper != nil ) {
        [self.h264FileDumper dumpToFile:nal];
    }
}

#pragma mark -
#pragma mark h264 decode Action
- (void)decoder:(id<H264DecoderInterface>) decoder onDecoded:(VideoFrame *)frame {
    [self renderFrame:frame];
}


#pragma mark -
#pragma mark FileSourceInterface Action
- (void)fileSource:(id<FileSourceInterface>) fileSource progressUpdated:(NSUInteger) index {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.palyCtrlView.progressSlider setIntValue:(int)index + 1];
        [self.palyCtrlView.textCurFrameIndex setStringValue:[NSString stringWithFormat:@"%lu", (unsigned long)index + 1]];
    });
}

- (void)fileSource:(id<FileSourceInterface>) fileSource fileDidEnd:(NSUInteger) totalFrame {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.palyCtrlView.playState = PlayControlState_Play;
    });
}


#pragma mark -
#pragma mark PalyCtrlView Action

- (void)palyCtrlView:(PalyCtrlView*) palyCtrlView formatUpdated:(NSInteger) indexOfSelectedItem {
    
}

- (void)palyCtrlView:(PalyCtrlView*) palyCtrlView fpsUpdated:(int) fps {
    self.fileSourceCapture.fps = fps;
}

- (void)palyCtrlView:(PalyCtrlView*) palyCtrlView playStatusUpdated:(CtrlType) ctrlType {
    if (ctrlType == CtrlType_RecordStart) {
        NSMenu *cameraMenu = [[[NSApp menu] itemAtIndex:1].submenu itemAtIndex:0].submenu;
        for (int i = 0; i < cameraMenu.numberOfItems; i++) {
            NSMenuItem *menuItem = [cameraMenu itemAtIndex:i];
            if (menuItem.enabled) {
                [self openCameraRecord:menuItem];
            }
        }
        return;
    } else if (ctrlType == CtrlType_RecordStop) {
        [self.capture stop];
        self.palyCtrlView.playState = PlayControlState_RecordStart;
        [self clearRecordState];
        return;
    }
    
    if (self.fileSourceCapture != nil) {
        if (ctrlType == CtrlType_Play) {
            if (self.fileSourceCapture.isPause) {
                self.palyCtrlView.playState = PlayControlState_Stop;
                [self.fileSourceCapture resume];
            }
        } else if (ctrlType == CtrlType_Pause) {
            if (!self.fileSourceCapture.isPause) {
                self.palyCtrlView.playState = PlayControlState_Play;
                [self.fileSourceCapture pause];
            }
        } else if (ctrlType == CtrlType_Rewind ) {
            NSUInteger frameIndex = self.fileSourceCapture.frameIndex;
            if (frameIndex != 0) {
                [self.fileSourceCapture seekToFrameIndex:frameIndex - 1];
            }
        } else if (ctrlType == CtrlType_FastForward ) {
            NSUInteger totalFrames = self.fileSourceCapture.totalFrames;
            NSUInteger frameIndex = self.fileSourceCapture.frameIndex;
            if (totalFrames > 0 && frameIndex < totalFrames - 1) {
                [self.fileSourceCapture seekToFrameIndex:frameIndex + 1];
            }
        } else if (ctrlType == CtrlType_SkipToStart) {
            NSUInteger frameIndex = self.fileSourceCapture.frameIndex;
            if (frameIndex != 0) {
                [self.fileSourceCapture seekToFrameIndex:0];
            }
        } else if (ctrlType == CtrlType_SkipToEnd) {
            NSUInteger totalFrames = self.fileSourceCapture.totalFrames;
            if (totalFrames > 0) {
                [self.fileSourceCapture seekToFrameIndex:totalFrames - 1];
            }
        }
    }
}

#pragma mark -
#pragma mark Private Method

- (void)showFileConfigPanle:(NSString*) filePath {
    NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    self.fileConfigWindowCtrl = [storyBoard instantiateControllerWithIdentifier:@"FileConfigPanel"];
    [self.fileConfigWindowCtrl.window setLevel:NSFloatingWindowLevel];
    FileConfigViewController *fileConfigVC = (FileConfigViewController*)[self.fileConfigWindowCtrl contentViewController];
    fileConfigVC.delegate = self;
    fileConfigVC.filePath = filePath;
    [self.fileConfigWindowCtrl showWindow:nil];
}

- (void)renderFrame:(VideoFrame *)frame {
    [self.videoRenderer renderFrame:frame];
    if ( self.yuvFileDumper != nil ) {
        [self.yuvFileDumper dumpToFile:frame];
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
    self.captureType = 0;
    self.videoRenderer = self.sampleRenderView;
    self.h264Decoder = self.openh264Decoder;
    self.h264Encoder = self.openh264Encoder;
    self.palyCtrlView.delegate = self;
    [self updateRecordMenu];
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


#pragma mark -
#pragma mark get&set

- (BOOL)isLoop {
    NSMenuItem *loopMenuItem = [[[NSApp menu] itemAtIndex:4].submenu itemAtIndex:7];
    if (loopMenuItem) {
        return loopMenuItem.state == NSControlStateValueOn;
    }
    return NO;
}

- (void)setIsLoop:(BOOL)isLoop {
    NSMenuItem *loopMenuItem = [[[NSApp menu] itemAtIndex:4].submenu itemAtIndex:7];
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

- (Openh264VideoDecoder*)openh264Decoder {
    if ( _openh264Decoder == nil ) {
        _openh264Decoder = [[Openh264VideoDecoder alloc] init];
        _openh264Decoder.delegate = self;
        [_openh264Decoder initDecoder];
    }
    return _openh264Decoder;
}

- (VideoToolboxVideoDecoder*)videoToolboxDecoder {
    if ( _videoToolboxDecoder == nil ) {
        _videoToolboxDecoder = [[VideoToolboxVideoDecoder alloc] init];
        _videoToolboxDecoder.delegate = self;
        [_videoToolboxDecoder initDecoder];
    }
    return _videoToolboxDecoder;
}

-(OpenH264VideoEncoder*)openh264Encoder {
    if ( _openh264Encoder == nil ) {
        _openh264Encoder = [[OpenH264VideoEncoder alloc] init];
        _openh264Encoder.delegate = self;
        [_openh264Encoder initEncoder];
    }
    return _openh264Encoder;
}

- (X264VideoEncoder*)x264Encoder {
    if ( _x264Encoder == nil ) {
        _x264Encoder = [[X264VideoEncoder alloc] init];
        _x264Encoder.delegate = self;
        [_x264Encoder initEncoder];
    }
    return _x264Encoder;
}

@end
