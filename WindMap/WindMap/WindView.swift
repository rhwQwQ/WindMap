//
//  WindView.swift
//  WindMap
//
//  Created by renhw on 2023/12/28.
//

import UIKit
import Foundation
import CoreLocation
import MAMapKit
struct Coordinate: Codable {
    var latitude: Double
    var longitude: Double
}

struct WindModel: Codable {
    // 标题
    var title: String?
    var year: Double = 0
    var month: Double = 0
    var day: Double = 0
    var hour: Double = 0
    var timesession: Double = 0
    var layer: Double = 0
    var startlon: Double = 0
    var startlat: Double = 0
    var endlon: Double = 0
    var endlat: Double = 0
    var nlon: Double = 0
    var nlat: Double = 0
    var lonsize: Double = 0
    var latsize: Double = 0
    var data: [[Double]]
    var windMin2D: Coordinate {
        return Coordinate(latitude: startlat, longitude: startlon)
    }
    
    var windMax2D: Coordinate {
        return Coordinate(latitude: endlat, longitude: endlon)
    }
}
class WindView: UIView {
    //算经纬度专用
    weak var mapView: MAMapView?
    //尾巴专用
    weak var streakView: WindMotionStreakView?
    //起始经度
    var x0: CGFloat = 0.0
    //起始纬度
    var y0: CGFloat = 0.0
    //结束经度
    var x1: CGFloat = 0.0
    //结束纬度
    var y1: CGFloat = 0.0
    //精确度
    var nlon: CGFloat = 0.0
    //精确度
    var nlat: CGFloat = 0.0
    //最大显示数量
    var partNum: Int = 0
    //列数
    var gridWidth: Int = 0
    //行数
    var gridHeight: Int = 0
    //初始宽
    var width: CGFloat = 0.0
    //初始高
    var height: CGFloat = 0.0
    //fields数组
    var windfields: [[NSValue]] = []
    //粒子数组
    var particles: [WindParticle] = []
    //定时器
    var timer: Timer?
    //暂停
    var remove: Bool = false
    //最大长度
    var maxLength: CGFloat = 10.0
    init(frame: CGRect, mapView: MAMapView, windMotionStreakView: WindMotionStreakView, tyWindDetailModel: WindModel) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.mapView = mapView
        self.streakView = windMotionStreakView
        self.x0 = tyWindDetailModel.startlon
        self.x1 = tyWindDetailModel.endlon
        self.y0 = tyWindDetailModel.startlat
        self.y1 = tyWindDetailModel.endlat
        self.nlon = tyWindDetailModel.nlon
        self.nlat = tyWindDetailModel.nlat
        self.partNum = 1000
        self.gridWidth = Int(tyWindDetailModel.lonsize)
        self.gridHeight = Int(tyWindDetailModel.latsize)
        self.width = self.frame.size.width
        self.height = self.frame.size.height
        self.getWindfields(with:tyWindDetailModel.data)
        self.getParticles()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func getWindfields(with fields: [Any]) {
        guard let arr1 = fields.first as? [NSNumber], let arr2 = fields.last as? [NSNumber] else {
            return
        }
        
        var arr: [NSValue] = []
        for i in 0..<arr1.count {
            let obj1 = arr1[i]
            let obj2 = arr2[i]
            let v = CGVector(dx: CGFloat(obj1.floatValue), dy: CGFloat(obj2.floatValue))
            maxLength = max(maxLength, length(of: v))
            arr.append(NSValue(cgVector: v))
        }
        
        var linecolumnArray: [[NSValue]] = []
        for i in 0..<gridHeight {
            var columnArray: [NSValue] = []
            for j in 0..<gridWidth {
                columnArray.append(arr[i * gridWidth + j])
            }
            linecolumnArray.append(columnArray)
        }
        
        windfields = linecolumnArray
    }
    
    func length(of v: CGVector) -> CGFloat {
        return sqrt(v.dx * v.dx + v.dy * v.dy)
    }
    
    func getParticles() {
        particles.removeAll()
        
        let mainScreenBounds = UIScreen.main.bounds
        
        if frame.origin.x >= mainScreenBounds.size.width || frame.origin.x + frame.size.width <= 0 || frame.origin.y >= mainScreenBounds.size.height || frame.origin.y + frame.size.height <= 0 {
            // 上下左右都超出了屏幕
        } else {
            if frame.size.width < width {
                partNum = 1000
            } else {
                partNum = Int(1000 * frame.size.width * frame.size.height / (width * height))
            }
            
            partNum = min(partNum, 1500)
            
            for _ in 0..<partNum {
                let particle = WindParticle()
                particle.maxLength = maxLength
                particles.append(particle)
            }
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if timer == nil {
            timer = WeakTargetTimer.scheduledTimer(withTimeInterval: 1/60.0, target: self, selector: #selector(timeFired), userInfo: nil, repeats: true)
        }
    }
    
    @objc func timeFired() {
        guard particles.count > 0 else {
            return
        }
        
        DispatchQueue.main.async {
            for (index, obj) in self.particles.enumerated() {
                self.updateCenter(particle: obj)
                if index == self.particles.count - 1 {
                    self.setNeedsDisplay()
                }
            }
        }
    }
    // 更新
    func updateCenter(particle: WindParticle) {
        particle.age -= 1
        if particle.age <= 0 {
            let startCenter = randomParticleCenter()
            let startMapPoint = mapPointFromViewPoint(point: startCenter)
            let startVect = vectorWithPoint(point: startMapPoint)
            particle.reset(center: startCenter, age: randomAge(), xv: startVect.dx, yv: startVect.dy)
        } else {
            let updateCenter = CGPoint(x: particle.center.x + particle.xv, y: particle.center.y - particle.yv)
            let updateMapPoint = mapPointFromViewPoint(point: updateCenter)
            let disRect = bounds
            let disMapRect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
            if !disRect.contains(updateCenter) || !disMapRect.contains(updateMapPoint) {
                let startCenter = randomParticleCenter()
                let startMapPoint = mapPointFromViewPoint(point: startCenter)
                let startVect = vectorWithPoint(point: startMapPoint)
                particle.reset(center: startCenter, age: randomAge(), xv: startVect.dx, yv: startVect.dy)
            } else {
                let updateVect = vectorWithPoint(point: updateMapPoint)
                particle.update(center: updateCenter, xv: updateVect.dx, yv: updateVect.dy)
            }
        }
    }
    
    // 在自身范围内随机生成一个点，要保证它在经纬度内并且在屏幕上
    func randomParticleCenter() -> CGPoint {
        var randomPoint: CGPoint
        repeat {
            let a = CGFloat(drand48())
            let b = CGFloat(drand48())
            let x = a * bounds.size.width
            let y = b * bounds.size.height
            randomPoint = CGPoint(x: x, y: y)
        } while !UIScreen.main.bounds.contains(randomPoint)
        
        return randomPoint
    }
    // 获取该点在地图上的经纬度
    func mapPointFromViewPoint(point: CGPoint) -> CGPoint {
        let mapPoint = convert(point, to: mapView)
        let coor = mapView?.convert(mapPoint, toCoordinateFrom: mapView)
        return CGPoint(x: coor?.longitude ?? 0, y: coor?.latitude ?? 0)
    }
    
    // 线性插值
    func vectorWithPoint(point: CGPoint) -> CGVector {
        let i = (point.x - self.x0) / self.nlon
        let j = (point.y - self.y0) / self.nlat
        let fi = Int(floor(i)) // 上一列
        let ci = fi + 1 // 下一列
        let fj = Int(floor(j)) // 上一行
        let cj = fj + 1 // 下一行
        
        if fi < 0 || ci < 0 || fj < 0 || cj < 0 || fi >= self.gridWidth - 1 || fj >= self.gridHeight - 1 {
            return CGVector(dx: 0, dy: 0)
        }
        
        let lineArr1 = self.windfields[fj] 
        let value1 = lineArr1[fi]
        let vect1 = value1.cgVectorValue
        let value2 = lineArr1[ci]
        let vect2 = value2.cgVectorValue
        
        let lineArr2 = self.windfields[cj]
        let value3 = lineArr2[fi]
        let vect3 = value3.cgVectorValue
        let value4 = lineArr2[ci]
        let vect4 = value4.cgVectorValue
        
        let x = i - CGFloat(fi)
        let y = j - CGFloat(fj)
        
        let vx = vect1.dx * (1 - x) * (1 - y) + vect2.dx * x * (1 - y) + vect3.dx * (1 - x) * y + vect4.dx * x * y
        let vy = vect1.dy * (1 - x) * (1 - y) + vect2.dy * x * (1 - y) + vect3.dy * (1 - x) * y + vect4.dy * x * y
        
        return CGVector(dx: vx, dy: vy)
    }
    
    func randomAge() -> Int {
        return 50 + Int(arc4random_uniform(150))
    }
    
    // 绘图
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        if remove {
            context?.clear(bounds)
            remove = false
        } else {
            streakView?.addLayer(layer: layer)
            context?.clear(bounds)
            var showCount = 0
            for i in 0..<partNum {
                let particle = particles[i]
                if showCount >= partNum {
                    break
                }
                if !particle.isShow {
                    particle.age = 0
                    continue
                }
                if particle.age > 0 {
                    showCount += 1
                    context?.saveGState()
                    let temp_alpha: CGFloat = 50.0
                    var alpha = CGFloat(particle.age) / temp_alpha
                    if CGFloat(particle.initAge - particle.age) <= temp_alpha {
                        alpha = CGFloat(particle.initAge - particle.age) / temp_alpha
                    }
                    context?.setAlpha(alpha)
                    if particle.oldCenter.x != -1 {
                        context?.setStrokeColor(UIColor.white.cgColor)
                        context?.setLineWidth(1.5)
                        let newPoint = CGPoint(x: particle.center.x, y: particle.center.y)
                        let oldPoint = CGPoint(x: particle.oldCenter.x, y: particle.oldCenter.y)
                        context?.move(to: newPoint)
                        context?.addLine(to: oldPoint)
                        context?.strokePath()
                    }
                    context?.restoreGState()
                }
            }
        }
    }
    
    // 停止
    func windStop() {
        timer?.fireDate = .distantFuture
        streakView?.removeLayers()
        remove = true
        setNeedsDisplay()
        getParticles()
        isHidden = true
    }
    
    // 开始
    func windRestart() {
        timer?.fireDate = .distantPast
        isHidden = false
    }
    
    // 释放
    func windRemoveTime() {
        timer?.invalidate()
        timer = nil
    }
}

class WindParticle: NSObject {
    var vScale: CGFloat = 4.0 // 速度比例
    var age: Int = 0 // 生命
    var initAge: Int = 0 // 初始生命
    var isShow: Bool {
        get{
            let t = sqrt(self.xv * self.xv + self.yv * self.yv)
            if t <= 0.01 { // 过滤风速太小的点
                return false
            }
            return true
        }
    } // 是否显示
    var xv: CGFloat = 0 // x 方向速度
    var yv: CGFloat = 0 // y 方向速度
    var center: CGPoint = .zero // 中心点
    var oldCenter: CGPoint = CGPoint(x: -1, y: -1) // 旧的中心点
    var maxLength: CGFloat = 0 // 最大长度
    var gradientColor: UIColor? // 渐变色
    var colorHue: CGFloat = 0 // 颜色色调
    
    override init() {
        super.init()
        self.vScale = 4.0
        self.oldCenter = CGPoint(x: -1, y: -1)
    }
    
    func reset(center: CGPoint, age: Int, xv: CGFloat, yv: CGFloat) {
        self.age = age
        self.initAge = age
        self.update(center: center, xv: xv, yv: yv)
        self.oldCenter = CGPoint(x: -1, y: -1)
    }
    
    func update(center: CGPoint, xv: CGFloat, yv: CGFloat) {
        self.oldCenter = self.center
        self.center = center
        self.setVelocity(x: xv, y: yv)
    }
    
    func setVelocity(x: CGFloat, y: CGFloat) {
        self.xv = x / self.vScale
        self.yv = y / self.vScale
        // 此处可能需要根据需求添加颜色计算逻辑
    }
}


class WindMotionStreakView: UIView {
    var imgLayers: [CALayer] = [] // 图层数组
    let LIMIT = 15 // 层次，越多尾巴越长
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = false
        self.imgLayers = [CALayer](repeating: CALayer(), count: LIMIT)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 添加图层
    func addLayer(layer: CALayer) {
        if self.imgLayers.count == LIMIT {
            let layer = self.imgLayers.last!
            layer.removeFromSuperlayer()
            self.imgLayers.removeLast()
        }
        let newLayer = CALayer()
        newLayer.frame = self.bounds
        newLayer.contents = layer.contents
        newLayer.actions = ["opacity": NSNull()] // 取消动画
        self.layer.addSublayer(newLayer)
        self.imgLayers.insert(newLayer, at: 0)
        for i in (0..<self.imgLayers.count).reversed() {
            let layer = self.imgLayers[i]
            layer.opacity = 1
            layer.opacity = layer.opacity - Float(1/LIMIT)
        }
    }
    
    // 移除所有图层
    func removeLayers() {
        for layer in self.imgLayers {
            layer.removeFromSuperlayer()
        }
        self.imgLayers.removeAll()
    }
}
///计时器
class WeakTargetTimer: NSObject {
    weak var aTarget: AnyObject?
    var aSelector: Selector?
    
    class func scheduledTimer(withTimeInterval ti: TimeInterval, target aTarget: AnyObject, selector aSelector: Selector, userInfo: Any?, repeats yesOrNo: Bool) -> Timer {
        let object = WeakTargetTimer()
        object.aTarget = aTarget
        object.aSelector = aSelector
        
        return Timer.scheduledTimer(timeInterval: ti, target: object, selector: #selector(object.fire(_:)), userInfo: userInfo, repeats: yesOrNo)
    }
    
    @objc func fire(_ timer: Timer) {
        if let target = aTarget, let selector = aSelector {
            _ = target.perform(selector, with: timer.userInfo)
        }
    }
}
