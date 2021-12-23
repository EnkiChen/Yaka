//
//  DragOperationView.m
//  Yaka
//
//  Created by Enki on 2021/8/3.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "DragOperationView.h"

@implementation DragOperationView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeFileURL, nil]];
    }
    return self;
}
 
- (void)awakeFromNib {
    [super awakeFromNib];
    [self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeFileURL, nil]];
}

- (void)dealloc {
    [self unregisterDraggedTypes];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if ([[pasteboard types] containsObject:NSPasteboardTypeFileURL]) {
        if (pasteboard.pasteboardItems.count <= 1) {
            NSURL *fileURL = [NSURL URLFromPasteboard:pasteboard];
            return [self.delegate dragOperationView:self draggingEntered:@[fileURL]];
        } else {
            NSArray *list = [pasteboard propertyListForType:NSFilenamesPboardType];
            NSMutableArray *urlList = [NSMutableArray array];
            for (NSString *str in list) {
                [urlList addObject:[NSURL fileURLWithPath:str]];
            }
            return [self.delegate dragOperationView:self draggingEntered:urlList];
        }
    }
    return NSDragOperationNone;
}
 
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender{
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if (pasteboard.pasteboardItems.count <= 1) {
        NSURL *fileURL = [NSURL URLFromPasteboard:pasteboard];
        [self.delegate dragOperationView:self prepareForDragOperation:@[fileURL]];
    } else {
        NSArray *list = [pasteboard propertyListForType:NSFilenamesPboardType];
        NSMutableArray *urlList = [NSMutableArray array];
        for (NSString *str in list) {
            [urlList addObject:[NSURL fileURLWithPath:str]];
        }
        [self.delegate dragOperationView:self prepareForDragOperation:urlList];
    }
    return YES;
}

@end
