//
//  FMAnimator.m
//  FMChart
//
//  Created by Keisuke Mori on 2015/09/01.
//  Copyright © 2015 Keisuke Mori. All rights reserved.
//

#import "FMAnimator.h"
#import "NSArray+Utility.h"

@interface FMAnimator()

@end

@interface FMBlockAnimation()

@property (copy  , nonatomic) FMAnimationBlock block;
@property (assign, nonatomic) NSTimeInterval anchorTime;

@end

@implementation FMAnimator

- (instancetype)init
{
	self = [super init];
	if(self) {
		_runningAnimations = [NSOrderedSet orderedSet];
		_pendingAnimations = [NSOrderedSet orderedSet];
	}
	return self;
}

- (void)chart:(FMMetalChart *)chart willStartEncodingToBuffer:(id<MTLCommandBuffer>)buffer
{
	NSOrderedSet<id<FMAnimation>> * running;
	NSOrderedSet<id<FMAnimation>> * pending;
	const NSTimeInterval timestamp = CFAbsoluteTimeGetCurrent();
	
	@synchronized(self) {
		running = _runningAnimations;
		pending = _pendingAnimations;
	}
	
	for(id<FMAnimation> a in pending) {
		if([a animator:self shouldStartAnimating:timestamp]) {
			running = [running orderedSetByAddingObject:a];
			[self removePendingAnimation:a];
		}
	}
	
	NSOrderedSet<id<FMAnimation>> * newRunning = running;
	for(id<FMAnimation> a in running) {
		if([a animator:self animate:buffer timestamp:timestamp]) {
			newRunning = [newRunning orderedSetByRemovingObject:a];
		}
	}
	
	_runningAnimations = newRunning;
}

- (void)chart:(FMMetalChart *)chart willCommitBuffer:(id<MTLCommandBuffer>)buffer
{
	@synchronized (self) {
		if(_runningAnimations.count + _pendingAnimations.count > 0) {
			[_metalView setNeedsDisplay];
		}
	}
}

- (void)addAnimation:(id<FMAnimation>)animation
{
	@synchronized(self) {
		[animation addedToPendingQueueOfAnimator:self timestamp:CFAbsoluteTimeGetCurrent()];
		_pendingAnimations = [_pendingAnimations orderedSetByAddingObject:animation];
		FMMetalView *view = self.metalView;
		if(view) {
			[view setNeedsDisplay];
		}
	}
}

- (void)removePendingAnimation:(id<FMAnimation>)animation
{
	@synchronized(self) {
		_pendingAnimations = [_pendingAnimations orderedSetByRemovingObject:animation];
	}
}

@end

@implementation FMBlockAnimation

- (instancetype)initWithDuration:(NSTimeInterval)duration
						   delay:(NSTimeInterval)delay
						   Block:(FMAnimationBlock)block
{
	self = [super init];
	if(self) {
		self.block = block;
		_duration = MAX(0.1, duration); // progressの計算で分母になるので最低持続時間を設ける.
		_delay = MAX(0, delay);
	}
	return self;
}

- (BOOL)requestCancel { return NO; }
- (void)addedToPendingQueueOfAnimator:(FMAnimator *)animator timestamp:(CFAbsoluteTime)timestamp { _anchorTime = timestamp; }

- (BOOL)animator:(FMAnimator *)animator shouldStartAnimating:(CFAbsoluteTime)timestamp
{
	return (_anchorTime + _delay <= timestamp);
}

- (BOOL)animator:(FMAnimator *)animator animate:(id<MTLCommandBuffer>)buffer timestamp:(CFAbsoluteTime)timestamp
{
	const float progress = (float)((timestamp - (_anchorTime + _delay)) / _duration);
	_block(progress);
	return (progress >= 1.0);
}

@end






