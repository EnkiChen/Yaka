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

@property(nonatomic, strong, readonly) NSTextField *renderFps;
@property(nonatomic, strong, readonly) NSTextField *renderCount;

@end

NS_ASSUME_NONNULL_END
