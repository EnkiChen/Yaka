//
//  FormatConvert.h
//  Yaka
//
//  Created by Enki on 2021/11/9.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FormatConvert : NSObject

- (instancetype)initWithFiles:(NSDictionary*)files;

- (void)startTask;

@end

NS_ASSUME_NONNULL_END
