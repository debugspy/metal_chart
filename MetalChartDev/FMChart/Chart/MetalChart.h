//
//  MetalChart.h
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/09.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "chart_common.h"
#import "Engine_common.h"

MTLPixelFormat determineDepthPixelFormat();

/*
 * このヘッダファイル内で宣言されたクラスは代替の利かないコアなコンポーネントの「全て」である.
 * その目的と興味はプロットエリアにおける座標変換のみに絞られている.
 * 軸・メモリ・レンジの制御・UI操作フィードバックなどはデフォルト実装を提供しているが、すべて独自定義クラスで代替可能.
 * 描画エンジンもFMRenderableを通して利用しているため、これらも独自定義可能である.
 * もちろんコード量と煩雑さはそこそこなのでオススメはできない.
 */

@class UniformProjectionCartesian2D;
@class MetalChart;


/*
 * Renderable/AttachmentがDepthTestを必要とする場合、このプロトコルを実装する. 
 * 複数のドローコールが発行される関係上、Depthバッファの値の取りうる範囲（領域ではない）のうち、
 * どの範囲をどれが使用するかを把握していないと描画上の不整合を起こすため. 強制力は無い.
 * clientが使用可能な値は, 戻り値 R を用いて (minDepth < v <= minDepth + |R|) を満たすvである.
 * Rの絶対値を取るのは、R < 0 の場合はclearDepthよりも小さい値をデプスバッファに書き込む事を意味し、
 * かつdepthテストでは負値を使えないようなので逆にclearDepthを上げる事で対処するためのものである.
 * ちなみに、この「掘り下げる」のはプロット領域を角丸にしつつ、そこでマスクをするなどの機能で使う.
 *
 * MetalChartの想定は、MTKView の clearDepthの値が0となっている事, depthが浮動小数点である事である.
 * また, 少なくともデフォルト実装では depthTestはMTLCompareFunctionGreaterを使う.
 *
 * また、当然ではあるがハンドリングされるのは
 * [MetalChart (add/remove)(Series/PreRenderable/PostRenderable):]
 * の引数に渡されたオブジェクトだけである.
 */
@protocol FMDepthClient <NSObject>

- (CGFloat)requestDepthRangeFrom:(CGFloat)min
                         objects:(NSArray * _Nonnull)objects;

@end



@protocol FMRenderable<NSObject>

- (void)encodeWith:(id<MTLRenderCommandEncoder> _Nonnull)encoder
			 chart:(MetalChart * _Nonnull)chart
;

@end



@protocol FMAttachment <NSObject>

- (void)encodeWith:(id<MTLRenderCommandEncoder> _Nonnull)encoder
             chart:(MetalChart * _Nonnull)chart
              view:(MetalView * _Nonnull)view
;

@end


@protocol FMCommandBufferHook <NSObject>

- (void)chart:(MetalChart * _Nonnull)chart willStartEncodingToBuffer:(id<MTLCommandBuffer> _Nonnull)buffer;
- (void)chart:(MetalChart * _Nonnull)chart willCommitBuffer:(id<MTLCommandBuffer> _Nonnull)buffer;

@end


@protocol FMProjection <NSObject>

- (void)writeToBuffer;

- (void)configure:(MetalView * _Nonnull)view padding:(RectPadding)padding;

@end

@interface FMDimensionalProjection : NSObject

@property (readonly, nonatomic) NSInteger dimensionId;
@property (assign  , nonatomic) CGFloat     min;
@property (assign  , nonatomic) CGFloat     max;
@property (readonly, nonatomic) CGFloat     mid;
@property (readonly, nonatomic) CGFloat     length;
@property (copy    , nonatomic) void (^ _Nullable willUpdate)(CGFloat * _Nullable newMin, CGFloat * _Nullable newMax);

- (instancetype _Nonnull)initWithDimensionId:(NSInteger)dimId
									minValue:(CGFloat)min
									maxValue:(CGFloat)max
NS_DESIGNATED_INITIALIZER;

- (instancetype _Nonnull)init UNAVAILABLE_ATTRIBUTE;

- (void)setMin:(CGFloat)min max:(CGFloat)max;

// 画面上での位置が重なるような値を算出する.
- (CGFloat)convertValue:(CGFloat)value
					 to:(FMDimensionalProjection * _Nonnull)to
;

@end

@interface FMProjectionCartesian2D : NSObject<FMProjection>

@property (readonly, nonatomic) FMDimensionalProjection * _Nonnull dimX;
@property (readonly, nonatomic) FMDimensionalProjection * _Nonnull dimY;
@property (readonly, nonatomic) UniformProjectionCartesian2D * _Nonnull projection;
@property (readonly, nonatomic) NSArray<FMDimensionalProjection *> * _Nonnull dimensions;

- (instancetype _Nonnull)initWithDimensionX:(FMDimensionalProjection * _Nonnull)x
										  Y:(FMDimensionalProjection * _Nonnull)y
NS_DESIGNATED_INITIALIZER;

- (instancetype _Nonnull)init UNAVAILABLE_ATTRIBUTE;

- (FMDimensionalProjection * _Nullable)dimensionWithId:(NSInteger)dimensionId;

- (BOOL)matchesDimensionIds:(NSArray<NSNumber*> * _Nonnull)ids;

@end


@interface MetalChart : NSObject<MetalViewDelegate>

@property (copy   , nonatomic) void (^ _Nullable willDraw)(MetalChart * _Nonnull);
@property (copy   , nonatomic) void (^ _Nullable didDraw)(MetalChart * _Nonnull);
@property (strong , nonatomic) id<FMCommandBufferHook> _Nullable bufferHook;
@property (assign , nonatomic) RectPadding padding;
@property (readonly, nonatomic) CGFloat clearDepth;

- (instancetype _Nonnull)init NS_DESIGNATED_INITIALIZER;

// 以下でArrayごと追加するメソッドは、単純にクライアントコードをシンプルにするためだけのものであって、
// 最適化などはしていないので注意.

// また、すでに追加されているものを再度追加しようとした場合、あるいは追加されていないものを除こうとした場合、
// そのメソッドは何もしない. 他の条件が不正な呼び出しもそれに準ずる.

- (void)addSeries:(id<FMRenderable> _Nonnull)series;
- (void)addSeriesArray:(NSArray<id<FMRenderable>> *_Nonnull)series;
- (void)removeSeries:(id<FMRenderable> _Nonnull)series;

- (void)addProjection:(id<FMProjection> _Nonnull)projection;
- (void)addProjections:(NSArray<id<FMProjection>> *_Nonnull)projections;
- (void)removeProjection:(id<FMProjection> _Nonnull)projection;

- (void)addPreRenderable:(id<FMAttachment> _Nonnull)object;
- (void)insertPreRenderable:(id<FMAttachment> _Nonnull)object atIndex:(NSUInteger)index;
- (void)addPreRenderables:(NSArray<id<FMAttachment>> * _Nonnull)array;
- (void)removePreRenderable:(id<FMAttachment> _Nonnull)object;

- (void)addPostRenderable:(id<FMAttachment> _Nonnull)object;
- (void)addPostRenderables:(NSArray<id<FMAttachment>> * _Nonnull)array;
- (void)removePostRenderable:(id<FMAttachment> _Nonnull)object;

- (void)removeAll;

- (NSArray<id<FMRenderable>> * _Nonnull)series;

- (NSSet<id<FMProjection>> * _Nonnull)projectionSet;

@end



