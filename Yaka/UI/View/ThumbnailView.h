//
//  ThumbnailView.h
//  Yaka
//
//  Created by Enki on 2022/2/14.
//  Copyright © 2022 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ThumbnailView;

@protocol ThumbnailViewDelegate <NSObject>

- (void)thumbnailView:(ThumbnailView *)thumbnailView didSelectItemsAtIndexPaths:(NSIndexPath *)indexPath;

@end

@interface ThumbnailView : NSCollectionView

@property (nullable, weak) id<ThumbnailViewDelegate> eventDelegate;

@property (nonatomic, strong) NSMutableArray *thumbnails;

@end

NS_ASSUME_NONNULL_END
