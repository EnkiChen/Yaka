//
//  FormatConvertVCtrl.m
//  Yaka
//
//  Created by Enki on 2021/10/26.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "FormatConvertVCtrl.h"
#import "DragOperationView.h"

static NSArray *kAllowedConvertFileTypes = @[@"yuv", @"h264", @"264", @"h265", @"265"];

@interface FormatConvertVCtrl ()

@property (weak) IBOutlet NSTextField *textFilePath;
@property (weak) IBOutlet NSTextField *textWidth;
@property (weak) IBOutlet NSTextField *textHeight;
@property (weak) IBOutlet NSComboBox *formatComboBox;
@property (weak) IBOutlet NSComboBox *sizeComboBox;

@property (weak) IBOutlet NSTextField *textOutputFilePath;
@property (weak) IBOutlet NSTextField *textOutputWidth;
@property (weak) IBOutlet NSTextField *textOutputHeight;
@property (weak) IBOutlet NSComboBox *formatOutputComboBox;
@property (weak) IBOutlet NSComboBox *sizeOutputComboBox;

@end

@implementation FormatConvertVCtrl

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)openDocument:(id)sender {
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canCreateDirectories = NO;
    openPanel.canChooseFiles = YES;
    openPanel.allowedFileTypes = kAllowedConvertFileTypes;
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse result) {
        if ( result == NSModalResponseOK ) {
            [self setInputFilePath:openPanel.URL];
        }
    }];
}

- (IBAction)selectSaveDic:(id)sender {
    NSSavePanel *panel = [NSSavePanel savePanel];
    [panel setCanSelectHiddenExtension:NO];
    [panel setNameFieldStringValue:@"video_360x640x30_I420_vt264_800k.yuv"];
    [panel beginSheetModalForWindow:[NSApp mainWindow] completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSString *chooseFile = [[panel URL] path];
            [self.textOutputFilePath setStringValue:chooseFile];
        }
    }];
}

- (IBAction)convertAction:(id)sender {
    
}

- (IBAction)onSizeComboboxChanged:(id)sender {
    NSComboBox *sizeBox = (NSComboBox*)sender;
    if ( sizeBox.indexOfSelectedItem != 0 ) {
        NSString *size_txt = sizeBox.objectValueOfSelectedItem;
        NSArray *size_info = [size_txt componentsSeparatedByString:@"x"];
        if ( size_info.count == 2 ) {
            if (sizeBox.tag == 0) {
                [self.textWidth setStringValue:size_info[0]];
                [self.textHeight setStringValue:size_info[1]];
            } else {
                [self.textOutputWidth setStringValue:size_info[0]];
                [self.textOutputHeight setStringValue:size_info[1]];
            }
        }
    }
}

#pragma mark - DragOperationViewDelegate
- (NSDragOperation)dragOperationView:(DragOperationView*) view draggingEntered:(NSArray<NSURL *>*) fileUrls {
    if (fileUrls.count == 1) {
        for (NSString *fileType in kAllowedConvertFileTypes) {
            if ([fileUrls.lastObject.path hasSuffix:fileType] ) {
                return NSDragOperationCopy;
            }
        }
    }
    return NSDragOperationNone;
}

- (void)dragOperationView:(DragOperationView*) view prepareForDragOperation:(NSArray<NSURL *>*) fileUrls {
    if (fileUrls.count == 1) {
        [self setInputFilePath:fileUrls.lastObject];
    }
}

- (void)setInputFilePath:(NSURL*)url {
    [self.textFilePath setStringValue:url.path];
    NSString *filePath = [url.path lowercaseString];
    NSRange range = [filePath rangeOfString:@"[1-9][0-9]*[x,X,_][0-9]*" options:NSRegularExpressionSearch];
    if (range.location != NSNotFound) {
        NSString *result = [filePath substringWithRange:range];
        range = [result rangeOfString:@"^[0-9]*" options:NSRegularExpressionSearch];
        if (range.location != NSNotFound) {
            [self.textWidth setStringValue:[result substringWithRange:range]];
        }
        range = [result rangeOfString:@"[0-9]*$" options:NSRegularExpressionSearch];
        if (range.location != NSNotFound) {
            [self.textHeight setStringValue:[result substringWithRange:range]];
        }
    }
    [self.sizeComboBox selectItemAtIndex:0];
    if ([self containsType:filePath types:@[@"i420", @"y420"]]) {
        [self.formatComboBox selectItemAtIndex:0];
        return;
    }
    if ([self containsType:filePath types:@[@"nv12", @"420f", @"420v"]]) {
        [self.formatComboBox selectItemAtIndex:1];
        return;
    }
    if ([self containsType:filePath types:@[@"p010", @"x420"]]) {
        [self.formatComboBox selectItemAtIndex:2];
        return;
    }
}

- (BOOL)containsType:(NSString*) string types:(NSArray*) types {
    for (NSString *type in types) {
        if ([string containsString:type]) {
            return YES;
        }
    }
    return NO;
}

@end
