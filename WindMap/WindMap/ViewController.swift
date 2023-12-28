//
//  ViewController.swift
//  WindMap
//
//  Created by renhw on 2023/12/28.
//

import UIKit
import MAMapKit
class ViewController: UIViewController, MAMapViewDelegate {
    // 地图
    lazy var mapView: MAMapView = {
        let mapView = MAMapView(frame: UIScreen.main.bounds)
        mapView.delegate = self
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.isRotateEnabled = false
        mapView.isRotateCameraEnabled = false
        mapView.zoomLevel = 3
        mapView.maxZoomLevel = 10
        mapView.minZoomLevel = 3
        mapView.mapType = .satellite
        mapView.customizeUserLocationAccuracyCircleRepresentation = true
        return mapView
    }()
    
    // 风场图
    var windView: WindView?
    
    // 流星尾巴
    var streakView: WindMotionStreakView?
    
    // 数据
    var windModel: WindModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configUI()
        configData()
    }
    
    func configUI(){
        AMapServices.shared().enableHTTPS = true
        AMapServices.shared().apiKey = "10dffc4912e47276e4f16351620a7916"
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        
        view.addSubview(mapView)
        
        let button = UIButton(frame: CGRect(x: 10, y: 200, width: 50, height: 50))
        button.backgroundColor = .red
        button.addTarget(self, action: #selector(buttonClick(_:)), for: .touchUpInside)
        view.addSubview(button)
    }
    
    func configData(){
        guard let path = Bundle.main.path(forResource: "wind", ofType: "json"),
              let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {return}
        do {
            let decoder = JSONDecoder()
            windModel = try decoder.decode(WindModel.self, from: jsonData)
        } catch {
            // 解析失败
            print("解析失败：\(error)")
        }
    }
    @objc func buttonClick(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        if sender.isSelected {
            guard let windModel = windModel else { return }
            let point1 = mapView.convert(CLLocationCoordinate2D(latitude: windModel.startlat, longitude: windModel.startlon), toPointTo: view)
            let point2 = mapView.convert(CLLocationCoordinate2D(latitude: windModel.endlat, longitude: windModel.endlon), toPointTo: view)
            streakView = WindMotionStreakView(frame: CGRect(x: point1.x, y: point2.y, width: abs(point2.x - point1.x), height: abs(point2.y - point1.y)))
            view.insertSubview(streakView!, aboveSubview: mapView)
            windView = WindView(frame: streakView!.frame, mapView: mapView, windMotionStreakView: streakView!, tyWindDetailModel: windModel)
            view.insertSubview(windView!, aboveSubview: streakView!)
        } else {
            streakView?.removeFromSuperview()
            streakView = nil
            windView?.windRemoveTime()
            windView?.removeFromSuperview()
            windView = nil
        }
    }
    
    func mapView(_ mapView: MAMapView, mapWillMoveByUser wasUserAction: Bool) {
        guard let _ = windModel else { return }
        if wasUserAction {
            windView?.windStop()
        }
    }
    
    func mapView(_ mapView: MAMapView, mapDidMoveByUser wasUserAction: Bool) {
        guard let _ = windModel else { return }
        if wasUserAction {
            changeFrame()
            windView?.windRestart()
        }
    }
    
    func mapView(_ mapView: MAMapView, mapWillZoomByUser wasUserAction: Bool) {
        guard let _ = windModel else { return }
        if wasUserAction {
            windView?.windStop()
        }
    }
    
    func mapView(_ mapView: MAMapView, mapDidZoomByUser wasUserAction: Bool) {
        guard let _ = windModel else { return }
        if wasUserAction {
            changeFrame()
            windView?.windRestart()
        }
    }
}
extension ViewController{
    func changeFrame() {
        guard let windModel = windModel else { return }
        // 调整风场面积 具体情况参考 IMG_1322
        var point1 = mapView.convert(CLLocationCoordinate2D(latitude: windModel.startlat, longitude: windModel.startlon), toPointTo: view)
        var point2 = mapView.convert(CLLocationCoordinate2D(latitude: windModel.endlat, longitude: windModel.endlon), toPointTo: view)
        let width = abs(point2.x - point1.x)
        let height = abs(point2.y - point1.y)
        // 有效宽 有效高
        var effectWidth: CGFloat = 0.0
        var effectHeight: CGFloat = 0.0
        if point1.x >= UIScreen.main.bounds.size.width || point1.x + width <= 0 || point2.y >= UIScreen.main.bounds.size.height || point2.y + height <= 0 { // 超出界面
            effectWidth = 100.0
            effectHeight = 100.0
        } else {
            if point1.x < 0 && point1.x + width < UIScreen.main.bounds.size.width { // 左边出屏幕 右边未出屏幕
                effectWidth = point1.x + width
                point1.x = 0 // x坐标
                if point2.y < 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面出屏幕 下面未出屏幕
                    effectHeight = point2.y + height
                    point2.y = 0 // y坐标
                } else if point2.y > 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面未出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height - point2.y
                } else if point2.y > 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面未出屏幕 下面未出屏幕
                    effectHeight = height
                } else if point2.y < 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height
                    point2.y = 0 // y坐标
                }
            } else if point1.x > 0 && point1.x + width > UIScreen.main.bounds.size.width { // 左边未出屏幕 右边出屏幕
                effectWidth = UIScreen.main.bounds.size.width - point1.x
                if point2.y < 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面出屏幕 下面未出屏幕
                    effectHeight = point2.y + height
                    point2.y = 0 // y坐标
                } else if point2.y > 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面未出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height - point2.y
                } else if point2.y > 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面未出屏幕 下面未出屏幕
                    effectHeight = height
                } else if point2.y < 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height
                    point2.y = 0 // y坐标
                }
            } else if point1.x > 0 && point1.x + width < UIScreen.main.bounds.size.width { // 左边未出屏幕 右边未出屏幕
                effectWidth = width
                if point2.y < 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面出屏幕 下面未出屏幕
                    effectHeight = point2.y + height
                    point2.y = 0 // y坐标
                } else if point2.y > 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面未出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height - point2.y
                } else if point2.y > 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面未出屏幕 下面未出屏幕
                    effectHeight = height
                } else if point2.y < 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height
                    point2.y = 0 // y坐标
                }
            } else if point1.x < 0 && point1.x + width > UIScreen.main.bounds.size.width { // 左边出屏幕 右边出屏幕
                effectWidth = UIScreen.main.bounds.size.width
                point1.x = 0 // x坐标
                if point2.y < 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面出屏幕 下面未出屏幕
                    effectHeight = point2.y + height
                    point2.y = 0 // y坐标
                } else if point2.y > 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面未出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height - point2.y
                } else if point2.y > 0 && point2.y + height < UIScreen.main.bounds.size.height { // 上面未出屏幕 下面未出屏幕
                    effectHeight = height
                } else if point2.y < 0 && point2.y + height > UIScreen.main.bounds.size.height { // 上面出屏幕 下面出屏幕
                    effectHeight = UIScreen.main.bounds.size.height
                    point2.y = 0 // y坐标
                }
            }
        }
        streakView?.frame = CGRect(x: point1.x, y: point2.y, width: effectWidth, height: effectHeight)
        windView?.frame = CGRect(x: point1.x, y: point2.y, width: effectWidth, height: effectHeight)
    }
}
