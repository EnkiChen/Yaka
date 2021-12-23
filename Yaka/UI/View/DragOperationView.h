//
//  DragOperationView.h
//  Yaka
//
//  Created by Enki on 2021/8/3.
//  Copyright © 2021 Enki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DragOperationView;

@protocol DragOperationViewDelegate <NSObject>
 
- (NSDragOperation)dragOperationView:(DragOperationView*) view draggingEntered:(NSArray<NSURL *>*) fileUrls;

- (void)dragOperationView:(DragOperationView*) view prepareForDragOperation:(NSArray<NSURL *>*) fileUrls;
 
@end


@interface DragOperationView : NSView

@property (weak, nonatomic) IBOutlet id<DragOperationViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
