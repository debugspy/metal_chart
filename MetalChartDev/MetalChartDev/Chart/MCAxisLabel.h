//
//  MCText.h
//  MetalChartDev
//
//  Created by Keisuke Mori on 2015/09/16.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Metal/MTLTypes.h>
#import "MCAxis.h"

@protocol MTLTexture;

@class DeviceResource;
@class Engine;
@class TextureQuad;

@protocol MCAxisLabelDelegate<NSObject>

- (NSMutableAttributedString * _Nonnull)attributedStringForValue:(CGFloat)value
                                                dimension:(MCDimensionalProjection * _Nonnull)dimension
;

@end

typedef MTLRegion (^MCTextDrawConfBlock)(CGSize lineSize, CGSize bufferSize, CGRect *_Nonnull drawRect);

@interface MCTextRenderer : NSObject

@property (assign, nonatomic) CGSize size;
@property (strong, nonatomic) UIFont * _Nullable font;

- (instancetype _Nonnull)initWithBufferSize:(CGSize)size
;

- (void)drawString:(NSMutableAttributedString * _Nonnull)string
         toTexture:(id<MTLTexture> _Nonnull)texture
         confBlock:(MCTextDrawConfBlock _Nonnull)block;
;

@end

@interface MCAxisLabel : NSObject<MCAxisDecoration>

@property (readonly, nonatomic) TextureQuad * _Nonnull quad;
@property (readonly, nonatomic) id<MCAxisLabelDelegate> _Nonnull delegate;

// textをフレーム内に配置する際、内容によっては余白(場合によっては負値)が生じる。
// この余白をどう配分するかを制御するプロパティ, (0, 0)で全て右と下へ配置、(0.5,0.5)で等分に配置する.
@property (assign  , nonatomic) CGPoint textAlignment;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
                                       frameSize:(CGSize)frameSize
                                  bufferCapacity:(NSUInteger)capacity
                                   labelDelegate:(id<MCAxisLabelDelegate> _Nonnull)delegate;
;

- (void)setFont:(UIFont * _Nonnull)font;
- (void)setFrameOffset:(CGPoint)offset;
- (void)setFrameAnchorPoint:(CGPoint)point;

@end

typedef NSMutableAttributedString *_Nonnull (^MCAxisLabelDelegateBlock)(CGFloat value, MCDimensionalProjection *_Nonnull dimension);

@interface MCAxisLabelBlockDelegate : NSObject<MCAxisLabelDelegate>

- (instancetype _Nonnull)initWithBlock:(MCAxisLabelDelegateBlock _Nonnull)block;

@end
