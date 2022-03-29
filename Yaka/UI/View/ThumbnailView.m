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

@end

@interface ThumbnailView () <NSCollectionViewDataSource>

@end

@implementation ThumbnailView
 
- (void)awakeFromNib {
    [super awakeFromNib];
    self.dataSource = self;
    self.wantsLayer = YES;
    self.layer.backgroundColor = [NSColor clearColor].CGColor;
    [self registerClass:ThumbnailViewItem.self forItemWithIdentifier:@"ThumbnailViewItem"];
}

- (void)setThumbnails:(NSMutableArray *)thumbnails {
    _thumbnails = thumbnails;
    [self reloadData];
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.thumbnails.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    ThumbnailViewItem *item = [collectionView makeItemWithIdentifier:@"ThumbnailViewItem" forIndexPath:indexPath];
    if (!item) {
        item = [[ThumbnailViewItem alloc] init];
    }
    [item.textField setStringValue:[NSString stringWithFormat:@"%ld", (long)indexPath.item + 1]];
    VideoFrame *frame = [self.thumbnails objectAtIndex:indexPath.item];
    [item.renderView renderFrame:frame];
    return item;
}

@end
