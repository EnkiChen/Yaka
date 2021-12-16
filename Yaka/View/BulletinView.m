//
//  BulletinView.m
//  Yaka
//
//  Created by Enki on 2021/12/16.
//  Copyright © 2021 Enki. All rights reserved.
//

#import "BulletinView.h"

@interface BulletinView ()

@property(nonatomic, strong) NSTextField *renderFps;
@property(nonatomic, strong) NSTextField *renderCount;

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
    self.renderFps = [[NSTextField alloc] initWithFrame:frame];
    self.renderCount = [[NSTextField alloc] initWithFrame:frame];
    
    [self.renderFps setStringValue:@"渲染帧率：-"];
    [self.renderCount setStringValue:@"渲染帧数：-"];
    
    [self setupStyle:self.renderFps];
    [self setupStyle:self.renderCount];
    
    [self addArrangedSubview:self.renderFps];
    [self addArrangedSubview:self.renderCount];
    
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
