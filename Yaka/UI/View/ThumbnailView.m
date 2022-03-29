//
//  ThumbnailView.m
//  Yaka
//
//  Created by Enki on 2022/2/14.
//  Copyright © 2022 Enki. All rights reserved.
//

#import "ThumbnailView.h"
#import "SampleVideoRenderView.h"


@interface ThumbnailViewItem : NSCollectionViewItem

@property(nonatomic, strong)SampleVideoRenderView *renderView;

@end

@implementation ThumbnailViewItem

- (void)loadView {
    NSStackView *stackView = [[NSStackView alloc] init];
    stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    stackView.alignment = NSLayoutAttributeCenterX;
    stackView.distribution = NSStackViewDistributionFillEqually;
    stackView.spacing = 5;
    
    NSTextField *textField = [[NSTextField alloc] initWithFrame:CGRectZero];
    textField.alignment = NSTextAlignmentCenter;
    textField.editable = NO;
    textField.selectable = NO;
    textField.bordered = NO;
    textField.backgroundColor = [NSColor clearColor];
    [stackView addArrangedSubview:textField];
    
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:CGRectZero];
    imageView.image = [NSImage imageNamed:@"Thumbnail"];
    imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
//    [stackView addArrangedSubview:imageView];
    
    self.renderView = [[SampleVideoRenderView alloc] initWithFrame:CGRectZero];
    [stackView addArrangedSubview:self.renderView];
    
    self.imageView = imageView;
    self.textField = textField;
    self.view = stackView;
}

- (void)setHighlightState:(NSCollectionViewItemHighlightState)highlightState {
    if (highlightState == NSCollectionViewItemHighlightForSelection) {
        self.renderView.layer.masksToBounds = YES;
        self.renderView.layer.borderWidth = 2.f;
        self.renderView.layer.borderColor = [NSColor blueColor].CGColor;
    } else if (highlightState == NSCollectionViewItemHighlightForDeselection) {
        self.renderView.layer.masksToBounds = YES;
        self.renderView.layer.borderWidth = 0.f;
        self.renderView.layer.borderColor = [NSColor clearColor].CGColor;
    }
}

@end

@interface ThumbnailView () <NSCollectionViewDataSource, NSCollectionViewDelegate>

@end

@implementation ThumbnailView
 
- (void)awakeFromNib {
    [super awakeFromNib];
    self.dataSource = self;
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor clearColor].CGColor;
    self.allowsEmptySelection = NO;
    [self registerClass:ThumbnailViewItem.self forItemWithIdentifier:@"ThumbnailViewItem"];
}

- (void)setThumbnails:(NSMutableArray *)thumbnails {
    _thumbnails = thumbnails;
    [self reloadData];
}

- (void)selectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths scrollPosition:(NSCollectionViewScrollPosition)scrollPosition {
    for (NSIndexPath *indexPath in self.selectionIndexPaths.allObjects) {
        NSCollectionViewItem *item = [self itemAtIndexPath:indexPath];
        item.highlightState = NSCollectionViewItemHighlightForDeselection;
    }
    [super selectItemsAtIndexPaths:indexPaths scrollPosition:scrollPosition];
    NSCollectionViewItem *item = [self itemAtIndexPath:indexPaths.allObjects.firstObject];
    item.highlightState = NSCollectionViewItemHighlightForSelection;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.thumbnails.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    ThumbnailViewItem *item = [collectionView makeItemWithIdentifier:@"ThumbnailViewItem" forIndexPath:indexPath];
    if (!item) {
        item = [[ThumbnailViewItem alloc] init];
    }
    
    if ([self.selectionIndexPaths containsObject:indexPath]) {
        item.highlightState = NSCollectionViewItemHighlightForSelection;
    } else {
        item.highlightState = NSCollectionViewItemHighlightForDeselection;
    }
    
    [item.textField setStringValue:[NSString stringWithFormat:@"%ld", (long)indexPath.item + 1]];
    VideoFrame *frame = [self.thumbnails objectAtIndex:indexPath.item];
    [item.renderView renderFrame:frame];
    return item;
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    if (self.eventDelegate) {
        [self.eventDelegate thumbnailView:self didSelectItemsAtIndexPaths:indexPaths.allObjects.firstObject];
    }
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    
}

@end
