//
//  TextureQuadBuffers.h
//  FMChart
//
//  Created by Keisuke Mori on 2015/09/16.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import "TextureQuad_common.h"
#import "Prototypes.h"

@protocol MTLBuffer;

/**
 * FMUniformRegion is a wrapper class for struct uniform_region that provides setter methods.
 */

@interface FMUniformRegion : NSObject

@property (readonly, nonatomic) id<MTLBuffer> _Nonnull buffer;
@property (readonly, nonatomic) uniform_region * _Nonnull region;

- (instancetype _Nonnull)initWithResource:(FMDeviceResource * _Nonnull)resource;

- (void)setBasePosition:(CGPoint)point;
- (void)setAnchorPoint:(CGPoint)anchor;
- (void)setIterationVector:(CGPoint)vec;
- (void)setIterationOffset:(CGFloat)offset;

// 以下2つのパラメータは他のものと解釈が（TextureQuadのシェーダ側で）
// 異なるので注意する事（変則は避けるべきなのは承知の上で、使い勝手の問題からそうしている）
//
// 具体的には、uvRegionの場合はそのままuv空間で捉えられる(offsetは実質いらない)が、
// dataRegionでは以下2つがview座標空間でのものとして解釈される.
// まともにラベル描画用に使えるシェーダとしては必須だったと言い訳しておく.

/**
 * Interpretation of size is shader-dependent.
 * uv size in texture space (for texRegion), and logical pixels otherwise (for dataRegion)
 */
- (void)setSize:(CGSize)size;

/**
 * Interpretation of positionOffset is shader-dependent.
 * uv size in texture space (for texRegion), and in view-coordinate system otherwise (for dataRegion)
 */
- (void)setPositionOffset:(CGPoint)offset;


@end

