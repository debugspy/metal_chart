//
//  Series.h
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/11.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Buffers.h"

@interface OrderedSeries : NSObject

@property (readonly, nonatomic) VertexBuffer * _Nonnull vertices;
@property (readonly, nonatomic) UniformSeriesInfo * _Nonnull info;

- (_Null_unspecified instancetype)initWithResource:(DeviceResource * _Nonnull)resource
									vertexCapacity:(NSUInteger)vertCapacity;

@end

@interface IndexedSeries : NSObject

@property (readonly, nonatomic) VertexBuffer * _Nonnull vertices;
@property (readonly, nonatomic) IndexBuffer * _Nonnull indices;
@property (readonly, nonatomic) UniformSeriesInfo * _Nonnull info;

- (_Null_unspecified instancetype)initWithResource:(DeviceResource * _Nonnull)resource
									vertexCapacity:(NSUInteger)vertCapacity
									 indexCapacity:(NSUInteger)idxCapacity
;


@end
