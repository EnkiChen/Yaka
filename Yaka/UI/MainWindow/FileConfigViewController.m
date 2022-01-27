//
//  YuvConfigController.m
//  Yaka
//
//  Created by Enki on 2019/8/31.
//  Copyright © 2019 Enki. All rights reserved.
//

#import "FileConfigViewController.h"

@interface FileConfigViewController ()

@end

@implementation FileConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [self.sizeComboBox selectItemAtIndex:0];
    [self.formatComboBox selectItemAtIndex:0];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self.textFilePath setStringValue:self.fileUrl.path];
    NSString *filePath = [self.fileUrl.path lowercaseString];
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
    if ([self containsType:filePath types:@[@"p010", @"x420", @"p010le"]]) {
        [self.formatComboBox selectItemAtIndex:2];
        return;
    }
    if ([self containsType:filePath types:@[@"i010", @"yuv420p16le", @"yuv420p10le"]]) {
        [self.formatComboBox selectItemAtIndex:3];
        return;
    }
}

- (IBAction)onSizeComboboxChanged:(id)sender {
    NSComboBox *sizeBox = (NSComboBox*)sender;
    if ( sizeBox.indexOfSelectedItem != 0 ) {
        NSString *size_txt = sizeBox.objectValueOfSelectedItem;
        NSArray *size_info = [size_txt componentsSeparatedByString:@"x"];
        if ( size_info.count == 2 ) {
            [self.textWidth setStringValue:size_info[0]];
            [self.textHeight setStringValue:size_info[1]];
        }
    }
}

- (IBAction)openDocument:(id)sender {
    if (self.delegate != nil) {
        [self.delegate fileConfigViewController:self openDocument:self.fileUrl];
    }
}

- (IBAction)closeAction:(id)sender {
    if ( self.delegate != nil ) {
        [self.delegate fileConfigViewController:self
                                       filePath:self.fileUrl
                                          width:self.textWidth.intValue
                                         height:self.textHeight.intValue
                                    formatIndex:(int)self.formatComboBox.indexOfSelectedItem];
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

@implementation OpenFileInfo

@end
