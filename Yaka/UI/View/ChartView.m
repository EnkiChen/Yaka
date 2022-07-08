//
//  ChartView.m
//  Yaka
//
//  Created by Enki on 2022/7/6.
//  Copyright © 2022 Enki. All rights reserved.
//

#import "ChartView.h"

@interface ChartView ()

@property (nonatomic, strong) NSBezierPath *path;

@end

@implementation ChartView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.path = [NSBezierPath bezierPath];
        self.path.lineCapStyle = NSLineCapStyleRound;
        self.path.lineJoinStyle = NSLineJoinStyleRound;
        self.path.lineWidth = 1.f;
        [self.path moveToPoint:CGPointMake(3, 3)];
        [self.path lineToPoint:CGPointMake(10, 5)];
        [self.path lineToPoint:CGPointMake(40, 54)];
        [self.path lineToPoint:CGPointMake(70, 34)];
        [self.path lineToPoint:CGPointMake(120, 20)];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor redColor] setStroke];
    [self.path stroke];
}

@end
