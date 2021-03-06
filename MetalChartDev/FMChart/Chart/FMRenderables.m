//
//  FMRenderables.m
//  FMChart
//
//  Created by Keisuke Mori on 2015/08/11.
//  Copyright © 2015 Keisuke Mori. All rights reserved.
//

#import "FMRenderables.h"
#import "DeviceResource.h"
#import "Engine.h"
#import "Buffers.h"
#import "Series.h"
#import "Lines.h"
#import "Rects.h"
#import "Points.h"
#import "LineBuffers.h"
#import "RectBuffers.h"
#import "FMAxis.h"
#import "LineBuffers.h"


@implementation FMBlockRenderable

- (instancetype)initWithBlock:(FMRenderBlock)block
{
	self = [super init];
	if(self) {
		_block = block;
	}
	return self;
}

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder chart:(FMMetalChart *)chart
{
	_block(encoder, chart);
}

@end


@interface FMLineSeries()

@end

@implementation FMLineSeries

- (instancetype)initWithLine:(FMLinePrimitive *)line
				  projection:(FMProjectionCartesian2D *)projection
{
	self = [super init];
	if(self) {
		_line = line;
		_projection = projection;
	}
	return self;
}

- (id<FMSeries>)series { return [_line series]; }

- (FMUniformLineConf *)conf { return _line.configuration; }

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
			 chart:(FMMetalChart * _Nonnull)chart
{
	FMUniformProjectionCartesian2D *projection = _projection.projection;
	if(projection) {
		[_line encodeWith:encoder projection:projection];
	}
}

- (CGFloat)requestDepthRangeFrom:(CGFloat)min objects:(NSArray * _Nonnull)objects
{
	for(id obj in objects) {
		if([obj isKindOfClass:[FMPlotArea class]]) {
			return 0;
		}
	}
	[self.conf setDepthValue:min+0.05];
	return 0.1;
}

- (CGFloat)allocateRangeInPlotArea:(FMPlotArea *)area minValue:(CGFloat)min
{
	[self.conf setDepthValue:min+0.05];
	return 0.1;
}

+ (instancetype)orderedSeriesWithCapacity:(NSUInteger)capacity
								   engine:(FMEngine *)engine
							   projection:(FMProjectionCartesian2D *)projection
{
	FMOrderedSeries *series = [[FMOrderedSeries alloc] initWithResource:engine.resource
													 vertexCapacity:capacity];
	FMOrderedPolyLinePrimitive *line = [[FMOrderedPolyLinePrimitive alloc] initWithEngine:engine
																		orderedSeries:series
																		   attributes:nil];
	return [[self alloc] initWithLine:line projection:projection];
}

@end



@interface FMLineAreaSeries ()

@property (nonatomic) CGFloat minDepth;

@end
@implementation FMLineAreaSeries

- (instancetype)initWithLineArea:(FMOrderedPolyLineAreaPrimitive *)lineArea projection:(FMProjectionCartesian2D *)projection
{
	self = [super init];
	if(self) {
		_lineArea = lineArea;
		_projection = projection;
	}
	return self;
}

- (id<FMSeries>)series { return [_lineArea series]; }

- (FMUniformLineAreaConfiguration *)conf { return _lineArea.configuration; }

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
			 chart:(FMMetalChart * _Nonnull)chart
{
	FMUniformProjectionCartesian2D *projection = _projection.projection;
	if(projection) {
		if(self.line) {
			[self.conf setDepthValue:self.line.conf.depthValue];
		} else {
			[self.conf setDepthValue:self.minDepth];
		}
		[_lineArea encodeWith:encoder projection:projection];
	}
}

- (CGFloat)requestDepthRangeFrom:(CGFloat)min objects:(NSArray *)objects
{
	_minDepth = min;
	return 0.01;
}

@end




@implementation FMBarSeries

- (instancetype)initWithBar:(FMBarPrimitive *)bar
				 projection:(FMProjectionCartesian2D *)projection
{
	self = [super init];
	if(self) {
		_bar = bar;
		_projection = projection;
	}
	return self;
}

- (CGFloat)requestDepthRangeFrom:(CGFloat)min objects:(NSArray * _Nonnull)objects
{
	for(id obj in objects) {
		if([obj isKindOfClass:[FMPlotArea class]]) {
			return 0;
		}
	}
	[self.conf setDepthValue:min+0.05];
	return 0.1;
}

- (CGFloat)allocateRangeInPlotArea:(FMPlotArea *)area minValue:(CGFloat)min
{
	[self.conf setDepthValue:min+0.05];
	return 0.1;
}

- (FMUniformBarConfiguration *)conf { return _bar.conf; }

- (id<FMSeries>)series { return [_bar series]; }

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
			 chart:(FMMetalChart * _Nonnull)chart
{
	FMUniformProjectionCartesian2D *projection = _projection.projection;
	if(projection) {
		[_bar encodeWith:encoder projection:projection];
	}
}

+ (instancetype)orderedSeriesWithCapacity:(NSUInteger)capacity
								   engine:(FMEngine *)engine
							   projection:(FMProjectionCartesian2D *)projection
{
	FMOrderedSeries *series = [[FMOrderedSeries alloc] initWithResource:engine.resource
														 vertexCapacity:capacity];
	FMOrderedBarPrimitive *bar = [[FMOrderedBarPrimitive alloc] initWithEngine:engine
																		series:series
																 configuration:nil
																	attributes:nil];
	
	return [[self alloc] initWithBar:bar projection:projection];
}


@end



@implementation FMPointSeries

- (instancetype)initWithPoint:(FMPointPrimitive *)point
				   projection:(FMProjectionCartesian2D *)projection
{
	self = [super init];
	if(self) {
		_point = point;
		_projection = projection;
	}
	return self;
}

- (id<FMSeries>)series { return [_point series]; }

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
			 chart:(FMMetalChart * _Nonnull)chart
{
	FMUniformProjectionCartesian2D *projection = _projection.projection;
	if(projection) {
		[_point encodeWith:encoder projection:projection];
	}
}

+ (instancetype)orderedSeriesWithCapacity:(NSUInteger)capacity
								   engine:(FMEngine *)engine
							   projection:(FMProjectionCartesian2D *)projection
{
	FMOrderedSeries *series = [[FMOrderedSeries alloc] initWithResource:engine.resource
													 vertexCapacity:capacity];
	FMOrderedPointPrimitive *point = [[FMOrderedPointPrimitive alloc] initWithEngine:engine
																		  series:series
																	  attributes:nil];
	
	return [[self alloc] initWithPoint:point projection:projection];
}

@end




@implementation FMPlotArea

- (instancetype)initWithPlotRect:(FMPlotRectPrimitive *)rect
{
	self = [super init];
	if(self) {
		FMDeviceResource *res = rect.engine.resource;
		_projection = [[FMUniformProjectionCartesian2D alloc] initWithResource:res];
		_rect = rect;
	}
	return self;
}

- (FMUniformPlotRectAttributes *)attributes { return _rect.attributes; }

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
			 chart:(FMMetalChart *)chart
			  view:(FMMetalView *)view
{
	[_projection setPhysicalSize:view.bounds.size];
	[_projection setPadding:chart.padding];
	
	[_rect encodeWith:encoder projection:_projection];
}

- (CGFloat)requestDepthRangeFrom:(CGFloat)min objects:(NSArray * _Nonnull)objects
{
	CGFloat currentValue = 0.1;
	for(id obj in objects) {
		if([obj conformsToProtocol:@protocol(FMPlotAreaClient)]) {
			CGFloat v = [(id<FMPlotAreaClient>)obj allocateRangeInPlotArea:self minValue:(min+currentValue)];
			currentValue += fabs(v);
		}
	}
	[self.attributes setDepthValue:min];
	return -currentValue;
}

+ (instancetype)rectWithEngine:(FMEngine *)engine
{
	FMPlotRectPrimitive *rect = [[FMPlotRectPrimitive alloc] initWithEngine:engine];
	return [[self alloc] initWithPlotRect:rect];
}

@end

@interface FMGridLine()

@property (readonly, nonatomic) FMDimensionalProjection *dimension;

@end

@implementation FMGridLine

- (instancetype)initWithGridLine:(FMGridLinePrimitive *)gridLine
					  Projection:(FMProjectionCartesian2D *)projection
					   dimension:(NSInteger)dimensionId
{
	self = [super init];
	if(self) {
		_gridLine = gridLine;
		_projection = projection;
		_dimension = [projection dimensionWithId:dimensionId];
		
		if(_dimension == nil) {
			abort();
		}
		
		const NSUInteger dimIndex = [projection.dimensions indexOfObject:_dimension];
		[_gridLine.configuration setDimensionIndex:dimIndex];
	}
	return self;
}

- (FMUniformGridAttributes *)attributes {
	return self.gridLine.attributes;
}

- (FMUniformGridConfiguration*)configuration {
	return self.gridLine.configuration;
}

- (void)prepare:(FMMetalChart *)chart view:(FMMetalView *)view
{
	FMUniformAxisConfiguration *conf = _axis.axis.configuration;
	FMUniformGridConfiguration *lineConf = _gridLine.configuration;
	if(conf) {
		const NSInteger minFreq = conf.minorTicksPerMajor;
		const BOOL minor = _sticksToMinorTicks;
		lineConf.anchorValue = conf.tickAnchorValue;
		lineConf.interval = (minFreq > 0 && minor) ? conf.majorTickInterval / minFreq : conf.majorTickInterval;
	}
}

- (NSArray<id<FMDependentAttachment>> *)dependencies
{
	id<FMAxis> axis = _axis;
	return (axis) ? @[axis] : nil;
}

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
			 chart:(FMMetalChart *)chart
			  view:(FMMetalView *)view
{
	FMUniformGridConfiguration *conf = _gridLine.configuration;
	const CGFloat len = _dimension.max - _dimension.min;
	const CGFloat interval = conf.interval;
	const NSUInteger maxCount = (interval > 0) ? floor(len/conf.interval) + 1 : 0;
	[_gridLine encodeWith:encoder projection:_projection.projection maxCount:maxCount];
}

- (CGFloat)requestDepthRangeFrom:(CGFloat)min objects:(NSArray * _Nonnull)objects
{
	for(id obj in objects) {
		if([obj isKindOfClass:[FMPlotArea class]]) {
			return 0;
		}
	}
	[self.configuration setDepthValue:min+0.05];
	return 0.1;
}

- (CGFloat)allocateRangeInPlotArea:(FMPlotArea *)area minValue:(CGFloat)min
{
	[self.configuration setDepthValue:min+0.05];
	return 0.1;
}

+ (instancetype)gridLineWithEngine:(FMEngine *)engine
						projection:(FMProjectionCartesian2D *)projection
						 dimension:(NSInteger)dimensionId
{
	FMGridLinePrimitive *line = [[FMGridLinePrimitive alloc] initWithEngine:engine];
	return [[self alloc] initWithGridLine:line Projection:projection dimension:dimensionId];
}

@end

