//
//  FileUnit.h
//  Yaka
//
//  Created by Enki on 2021/11/8.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileUnit : NSObject

@property (nonatomic, assign) long offset;
@property (nonatomic, assign) long length;

- (instancetype)initWithOffset:(long)offset length:(long)length;

@end

NS_ASSUME_NONNULL_END
