//
//  BulletinView.h
//  Yaka
//
//  Created by Enki on 2021/12/16.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BulletinView : NSStackView

@property(nonatomic, assign) NSUInteger rowCount;

- (void)setStringValue:(NSString *)string withRow:(NSUInteger)row;

@end

NS_ASSUME_NONNULL_END
