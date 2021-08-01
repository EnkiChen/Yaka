//
//  YuvConfigController.h
//  Yaka
//
//  Created by Enki on 2019/8/31.
//  Copyright © 2019 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class FileConfigViewController;

@protocol FileConfigDelegate <NSObject>

- (void)fileConfigViewController:(FileConfigViewController*) fileConfigCtrl openDocument:(NSString*) path;

- (void)fileConfigViewController:(FileConfigViewController*) fileConfigCtrl filePath:(NSString*) filePath width:(int) widht height:(int) height formatIndex:(int) formatIndex;

@end

@interface FileConfigViewController : NSViewController

@property (weak) IBOutlet NSTextField *textFilePath;
@property (weak) IBOutlet NSTextField *textWidth;
@property (weak) IBOutlet NSTextField *textHeight;
@property (weak) IBOutlet NSComboBox *formatComboBox;
@property (weak) IBOutlet NSComboBox *sizeComboBox;

@property(nonatomic, copy) NSString *filePath;

@property(nonatomic, weak) id<FileConfigDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
