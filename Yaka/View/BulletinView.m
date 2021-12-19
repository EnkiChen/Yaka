//
//  BulletinView.m
//  Yaka
//
//  Created by Enki on 2021/12/16.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "BulletinView.h"

@interface BulletinView ()

@property(nonatomic, strong) NSTextField *renderFpsTextField;
@property(nonatomic, strong) NSTextField *renderCountTextField;
@property(nonatomic, strong) NSTextField *bitrateTextField;

@end

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
    NSRect frame = self.bounds;
    self.renderFpsTextField = [[NSTextField alloc] initWithFrame:frame];
    self.renderCountTextField = [[NSTextField alloc] initWithFrame:frame];
    self.bitrateTextField = [[NSTextField alloc] initWithFrame:frame];
    
    [self.renderFpsTextField setStringValue:@"渲染帧率：-"];
    [self.renderCountTextField setStringValue:@"渲染帧数：-"];
    [self.bitrateTextField setStringValue:@"编码码率：0kbps"];
    
    [self setupStyle:self.renderFpsTextField];
    [self setupStyle:self.renderCountTextField];
    [self setupStyle:self.bitrateTextField];
    
    [self addArrangedSubview:self.renderFpsTextField];
    [self addArrangedSubview:self.renderCountTextField];
    [self addArrangedSubview:self.bitrateTextField];
    
    self.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.spacing = 0;
    self.alignment = NSLayoutAttributeLeft;
}

- (void)setupStyle:(NSTextField*)textField {
    textField.editable = NO;
    textField.bordered = NO;
    textField.alignment = NSTextAlignmentLeft;
    textField.backgroundColor = [NSColor clearColor];
    textField.font = [NSFont systemFontOfSize:10.f];
}

@end
