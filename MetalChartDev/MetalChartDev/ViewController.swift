//
//  ViewController.swift
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/03.
//  Copyright © 2015年 freaks. All rights reserved.
//

import UIKit
import Metal
import MetalKit

class ViewController: UIViewController {

	@IBOutlet var metalView: MTKView!
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    @IBOutlet var pinchRecognizer: UIPinchGestureRecognizer!
	
	var chart : MetalChart = MetalChart()
	let resource : DeviceResource = DeviceResource.defaultResource()
	let asChart = true
    
	override func viewDidLoad() {
		super.viewDidLoad()
        metalView.device = resource.device
        metalView.sampleCount = 2
        let v : Double = 0.9;
        let alpha : Double = 1;
        metalView.clearColor = MTLClearColorMake(v,v,v,alpha)
        metalView.clearDepth = 0
		metalView.colorPixelFormat = MTLPixelFormat.BGRA8Unorm
        metalView.depthStencilPixelFormat = MTLPixelFormat.Depth32Float_Stencil8;
		metalView.enableSetNeedsDisplay = false
		metalView.paused = false
		metalView.preferredFramesPerSecond = 60
		
		setupChart()
		metalView.delegate = chart
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func setupChart() {
		
		if (asChart) {
			let yRange : CGFloat = CGFloat(5)
			let dimX = MCDimensionalProjection(dimensionId: 1, minValue: -1, maxValue: 1)
			let dimY = MCDimensionalProjection(dimensionId: 2, minValue: -yRange, maxValue: yRange)
			let space = MCSpatialProjection(dimensions: [dimX, dimY])
			
			let vertCapacity : UInt = 1<<9
			let vertLength = 1 << 8
			let vertOffset = 1 << 4
			let engine = LineEngine(resource: resource)
			let series = OrderedSeries(resource: resource, vertexCapacity: vertCapacity)
			let line = OrderedPolyLine(engine: engine, orderedSeries: series)
			line.setSampleAttributes()
			
			let xAxisConf = MCBlockAxisConfigurator() { (uniform, dimension, orthogonal) -> Void in
				uniform.majorTickInterval = CFloat(1<<6)
				uniform.maxMajorTicks = CUnsignedChar((1<<2) + 1)
				uniform.axisAnchorValue = 0
				uniform.tickAnchorValue = 0
			}
			
			let yAxisConf = MCBlockAxisConfigurator() { (uniform, dimension, orthogonal) -> Void in
				let l = dimension.length()
				uniform.majorTickInterval = CFloat(l / 4)
				uniform.maxMajorTicks = 5
				uniform.axisAnchorValue = CFloat(orthogonal.min)
				uniform.tickAnchorValue = 0
			}
			
			let xAxis = MCAxis(engine: engine, projection: space, dimension: 1, configuration:xAxisConf);
			let yAxis = MCAxis(engine: engine, projection: space, dimension: 2, configuration:yAxisConf);
            
            xAxis.setMinorTickCountPerMajor(4)
			
			let xUpdater = MCProjectionUpdater(target: dimX)
			xUpdater.addRestriction(MCLengthRestriction(length: CGFloat(vertLength), anchor: 1, offset:CGFloat(vertOffset)))
			xUpdater.addRestriction(MCAlternativeSourceRestriction(minValue: -1, maxValue: 1, expandMin: true, expandMax: true))
			
			chart.padding = RectPadding(left: 30, top: 60, right: 30, bottom: 60);
			
			chart.willDraw = { (mc : MetalChart) -> Void in
				line.appendSampleData((1<<0), maxVertexCount:vertCapacity) { (Float x, Float y) in
					xUpdater.addSourceValue(CGFloat(x), update: false)
				}
				xUpdater.updateTarget()
			}
			
			let lineSeries = MCLineSeries(line: line)
			chart.addSeries(lineSeries, projection: space)
			chart.addPostRenderable(yAxis)
			chart.addPostRenderable(xAxis)
			
		} else {
            chart.padding = RectPadding(left: 30, top: 30, right: 30, bottom: 30);

			let offsetX = CGFloat(0)
			let dimX = MCDimensionalProjection(dimensionId: 1, minValue: -1 + offsetX, maxValue: 1 + offsetX)
			let dimY = MCDimensionalProjection(dimensionId: 2, minValue: -1, maxValue: 1)
			let space = MCSpatialProjection(dimensions: [dimX, dimY])
			
			let engine = LineEngine(resource: resource)
			let series = OrderedSeries(resource: resource, vertexCapacity: 1<<6)
			let line = OrderedPolyLine(engine: engine, orderedSeries: series)
			line.setSampleData()
			series.info.count = 5
			line.attributes.setWidth(10)
			
			let xAxisConf = MCBlockAxisConfigurator() { (uniform, dimension, orthogonal) -> Void in
				let l = dimension.length()
				uniform.majorTickInterval = CFloat(l / 4)
				uniform.maxMajorTicks = 5
				uniform.axisAnchorValue = -0.5
				uniform.tickAnchorValue = +0.0
			}
			
			let xAxis = MCAxis(engine: engine, projection: space, dimension: 1, configuration:xAxisConf);
			
			xAxis.setMinorTickCountPerMajor(3)
			
			let lineSeries = MCLineSeries(line: line)
			chart.addSeries(lineSeries, projection: space)
			
			chart.addPostRenderable(xAxis)
		}
        chart.addToPanRecognizer(panRecognizer)
        chart.addToPinchRecognizer(pinchRecognizer)
	}
}
