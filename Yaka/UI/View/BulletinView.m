//
//  BulletinView.m
//  Yaka
//
//  Created by Enki on 2021/12/16.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "BulletinView.h"


@implementation BulletinView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self != nil) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (void)setup {
    self.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.spacing = 0;
    self.alignment = NSLayoutAttributeLeft;
    self.distribution = NSStackViewDistributionFillEqually;
}

- (void)setRowCount:(NSUInteger)rowCount {
    if (rowCount == _rowCount) {
        return;
    }
    if (_rowCount < rowCount) {
        for (; _rowCount < rowCount; _rowCount++) {
            NSTextField *textField = [[NSTextField alloc] initWithFrame:self.bounds];
            [self setupStyle:textField];
            [self addArrangedSubview:textField];
        }
    } else {
        for (; _rowCount > rowCount; _rowCount--) {
            NSView *view = [self.arrangedSubviews lastObject];
            [self removeArrangedSubview:view];
        }
    }
}

- (void)setStringValue:(NSString *)string withRow:(NSUInteger)row {
    NSTextField *textField = [self.arrangedSubviews objectAtIndex:row];
    [textField setStringValue:string];
}

- (void)setupStyle:(NSTextField*)textField {
    textField.editable = NO;
    textField.bordered = NO;
    textField.alignment = NSTextAlignmentLeft;
    textField.backgroundColor = [NSColor clearColor];
    textField.font = [NSFont systemFontOfSize:10.f];
}

@end
