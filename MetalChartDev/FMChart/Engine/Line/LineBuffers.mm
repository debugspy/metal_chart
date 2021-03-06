//
//  LineBuffers.m
//  FMChart
//
//  Created by Keisuke Mori on 2015/08/25.
//  Copyright © 2015 Keisuke Mori. All rights reserved.
//

#import "LineBuffers.h"
#import "Buffers.h"
#import "UIColor+Utility.h"

@implementation FMUniformLineAttributes

- (instancetype)initWithResource:(FMDeviceResource *)resource
{
	self = [super initWithResource:resource size:sizeof(uniform_line_attr)];
	return self;
}

- (uniform_line_attr *)attributes
{
	return ((uniform_line_attr *)([self.buffer contents]) + self.index);
}

- (void)setWidth:(float)width
{
	[self attributes]->width = (float)width;
}

- (void)setColorVec:(vector_float4)color
{
	[self attributes]->color = color;
}

- (void)setDashLineLength:(float)length
{
	self.attributes->length_repeat = length;
}

- (void)setDashSpaceLength:(float)length
{
	self.attributes->length_space = length;
}

- (void)setDashLineAnchor:(float)anchor
{
	self.attributes->repeat_anchor_line = anchor;
}

- (void)setDashRepeatAnchor:(float)anchor
{
	self.attributes->repeat_anchor_dash = anchor;
}

@end



@implementation FMUniformLineAttributesArray

- (instancetype)initWithResource:(FMDeviceResource *)resource capacity:(NSUInteger)capacity
{
	auto ptr = std::make_shared<MTLObjectBuffer<uniform_line_attr>>(resource.device, capacity);
	self = [super initWithBuffer:std::static_pointer_cast<MTLObjectBufferBase>(ptr)];
	return self;
}

+ (Class)attributesClass { return [FMUniformLineAttributes class]; }

@end




@implementation FMUniformLineConf

- (id)initWithResource:(FMDeviceResource *)resource
{
	self = [super init];
	if(self) {
		_buffer = [resource.device newBufferWithLength:sizeof(uniform_line_conf) options:MTLResourceCPUCacheModeWriteCombined];
		self.conf->alpha = 1;
	}
	return self;
}

- (uniform_line_conf *)conf
{
	return (uniform_line_conf *)([self.buffer contents]);
}

- (void)setAlpha:(float)alpha
{
	[self conf]->alpha = MIN(1.0f, MAX(0, alpha));
}

- (void)setModifyAlphaOnEdge:(BOOL)modify
{
	[self conf]->modify_alpha_on_edge = (modify ? 1 : 0);
}

- (void)setEnableOverlay:(BOOL)enableOverlay
{
	_enableOverlay = enableOverlay;
	[self setModifyAlphaOnEdge:enableOverlay];
}

- (void)setDepthValue:(float)depth
{
	_depthValue = depth;
	[self conf]->depth = depth;
}

@end





@implementation FMUniformAxisAttributes

- (instancetype)initWithAttributes:(uniform_axis_attributes *)attr
{
	self = [super init];
	if(self) {
		_attributes = attr;
		_attributes->length_mod = vector2((float)-1, (float)1);
	}
	return self;
}

- (void)setWidth:(float)width { _attributes->width = width; }

- (void)setLineLength:(float)length { _attributes->line_length = length; }

- (void)setColorVec:(vector_float4)color
{
	_attributes->color = color;
}

- (void)setLengthModifierStart:(float)start end:(float)end
{
	_attributes->length_mod = vector2(start, end);
}

- (void)setLengthModifierStart:(float)start
{
	_attributes->length_mod[0] = start;
}

- (void)setLengthModifierEnd:(float)end
{
	_attributes->length_mod[1] = end;
}

@end

@implementation FMUniformAxisConfiguration

static const float _ndc_anchor_invalid = 8;

- (instancetype)initWithResource:(FMDeviceResource *)resource
{
	self = [super init];
	if(self) {
		id<MTLDevice> device = resource.device;
		_buffer = [device newBufferWithLength:sizeof(uniform_axis_configuration) options:MTLResourceOptionCPUCacheModeWriteCombined];
	}
	return self;
}

- (uniform_axis_configuration *)configuration {
	return (uniform_axis_configuration *)[_buffer contents];
}

- (void)setAxisAnchorDataValue:(float)value
{
	if(_axisAnchorDataValue != value) {
		_axisAnchorDataValue = value;
		self.configuration->axis_anchor_value_data = value;
	}
	self.axisAnchorNDCValue = _ndc_anchor_invalid;
}

- (void)setAxisAnchorNDCValue:(float)value
{
	if(_axisAnchorNDCValue != value) {
		_axisAnchorNDCValue = value;
		self.configuration->axis_anchor_value_ndc = value;
	}
}

- (void)setTickAnchorValue:(float)value
{
	if( _tickAnchorValue != value ) {
		_tickAnchorValue = value;
		_majorTickValueModified = YES;
		self.configuration->tick_anchor_value = value;
	}
}

- (void)setMajorTickInterval:(float)interval
{
	if( _majorTickInterval != interval ) {
		_majorTickInterval = interval;
		_majorTickValueModified = YES;
		self.configuration->tick_interval_major = interval;
#ifdef DEBUG
		NSAssert(interval > 0, @"interval should be positive (may work in some cases, but there's no guarantee)");
#endif
	}
}

- (void)setDimensionIndex:(uint8_t)index
{
	if( _dimensionIndex != index ) {
		_dimensionIndex = index;
		self.configuration->dimIndex = index;
	}
}

- (void)setMinorTicksPerMajor:(uint8_t)count {
	_minorTicksPerMajor = count;
	self.configuration->minor_ticks_per_major = count;
}

- (void)setMaxMajorTicks:(uint8_t)count {
	_maxMajorTicks = count;
	self.configuration->max_major_ticks = count;
}

- (BOOL)checkIfMajorTickValueModified:(BOOL (^)(FMUniformAxisConfiguration *))ifModified
{
	const BOOL isModified = _majorTickValueModified;
	if(isModified) {
		_majorTickValueModified = ! ifModified(self);
	}
	return isModified;
}

- (float)axisAnchorValueWithProjection:(FMUniformProjectionCartesian2D *)projection
{
	if(_axisAnchorNDCValue != _ndc_anchor_invalid) {
		const BOOL isx = (_dimensionIndex == 0); // これは軸の方向、必要なのは直交する方向の位置.
		const CGSize scale = projection.valueScale;
		const CGPoint offset = projection.valueOffset; // offsetは描画時のそれで符合反転している事に注意.
		return (isx) ? (scale.height * _axisAnchorNDCValue) - offset.y : (scale.width * _axisAnchorNDCValue) - offset.x;
	}
	return _axisAnchorDataValue;
}

@end



@implementation FMUniformGridAttributes

- (instancetype)initWithResource:(FMDeviceResource *)resource
{
	self = [super init];
	if(self) {
		_buffer = [resource.device newBufferWithLength:sizeof(uniform_grid_attributes) options:MTLResourceOptionCPUCacheModeWriteCombined];
	}
	return self;
}

- (uniform_grid_attributes *)attributes { return (uniform_grid_attributes *)[_buffer contents]; }

- (void)setWidth:(float)width
{
	self.attributes->width = width;
}

- (void)setColorVec:(vector_float4)color
{
	self.attributes->color = color;
}

- (void)setDashLineLength:(float)length
{
	self.attributes->length_repeat = length;
}

- (void)setDashSpaceLength:(float)length
{
	self.attributes->length_space = length;
}

- (void)setDashLineAnchor:(float)anchor
{
	self.attributes->repeat_anchor_line = anchor;
}

- (void)setDashRepeatAnchor:(float)anchor
{
	self.attributes->repeat_anchor_dash = anchor;
}

@end




@implementation FMUniformGridConfiguration

- (instancetype)initWithResource:(FMDeviceResource *)resource
{
	self = [super init];
	if(self) {
		_buffer = [resource.device newBufferWithLength:sizeof(uniform_grid_configuration) options:MTLResourceOptionCPUCacheModeWriteCombined];
	}
	return self;
}

- (uniform_grid_configuration *)conf { return (uniform_grid_configuration *)[_buffer contents]; }

- (void)setAnchorValue:(float)anchorValue
{
	if(_anchorValue != anchorValue) {
		_anchorValue = anchorValue;
		self.conf->anchor_value = anchorValue;
	}
}

- (void)setInterval:(float)interval
{
	if(_interval != interval) {
		_interval = interval;
		self.conf->interval = interval;
	}
}

- (void)setDimensionIndex:(uint8_t)dimensionIndex
{
	_dimensionIndex = dimensionIndex;
	self.conf->dimIndex = dimensionIndex;
}

- (void)setDepthValue:(float)depth
{
	self.conf->depth = depth;
}


@end



@implementation FMUniformLineAreaAttributes

- (instancetype)initWithResource:(FMDeviceResource *)resource
{
	self = [super initWithResource:resource size:sizeof(uniform_line_area_attr)];
	return self;
}

- (uniform_line_area_attr *)attributes
{
	return ((uniform_line_area_attr *)([self.buffer contents]) + self.index);
}

- (void)setGradientStartColor:(vector_float4)colorStart
				startPosition:(CGPoint)posStart
					 endColor:(vector_float4)colorEnd
				  endPosition:(CGPoint)posEnd
				   toPositive:(BOOL)positive
{
	gradient_conf* g = self.attributes->grads + (positive ? 0 : 1);
	g->color_start = colorStart;
	g->color_end = colorEnd;
	g->pos_start = VectFromPoint(posStart);
	g->pos_end = VectFromPoint(posEnd);
}

- (void)setSolidColor:(vector_float4)color
{
	gradient_conf* g = self.attributes->grads;
	g->color_start = color;
	g->color_end = color;
	g->pos_start = vector2(.0f, .0f);
	g->pos_end = vector2(.0f, .1f);
}

@end




@implementation FMUniformLineAreaConfiguration

- (instancetype)initWithResource:(FMDeviceResource *)resource
{
	self = [super init];
	if(self) {
		_buffer = [resource.device newBufferWithLength:sizeof(uniform_line_area_conf) options:MTLResourceOptionCPUCacheModeWriteCombined];
		[self setOpacity:1];
		[self setAnchorPoint:CGPointMake(0, -1) inDataSpace:NO];
		[self setDirection:CGPointMake(1, 0)];
		[self setColorPositionInDateSpace:NO];
	}
	return self;
}

- (uniform_line_area_conf *)conf { return (uniform_line_area_conf *)[_buffer contents]; }

- (void)setAnchorPoint:(CGPoint)anchor inDataSpace:(BOOL)inDataSpace
{
	self.conf->anchor = VectFromPoint(anchor);
	self.conf->anchor_data = inDataSpace;
}

- (void)setDirection:(CGPoint)direction
{
	self.conf->direction = vector2((float)direction.x, (float)direction.y);
}

- (void)setColorPositionInDateSpace:(BOOL)inDataSpace
{
	self.conf->grad_pos_data = inDataSpace;
}

- (void)setDepthValue:(float)depth
{
	self.conf->depth = depth;
}

- (void)setOpacity:(float)opacity
{
	self.conf->opacity = opacity;
}

@end



