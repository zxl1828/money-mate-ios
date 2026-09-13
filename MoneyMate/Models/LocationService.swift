import Foundation
import CoreLocation
import MapKit

// MARK: - 地点服务（CoreLocation + CLGeocoder，纯系统 API）

/// 定位 / 反查地址。
/// 全部使用系统回调式 API（主线程回调），避免并发 Sendable 问题。
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    /// 是否已拿到定位权限
    @Published var authorized = false
    /// 正在取定位
    @Published var busy = false
    /// 反查出来的地址文本
    @Published var address = ""
    /// 最近一次坐标
    @Published var coordinate: CLLocationCoordinate2D?
    /// 失败提示
    @Published var errorText: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorized = LocationService.isAuthorized(manager.authorizationStatus)
    }

    static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    // MARK: 对外接口

    /// 请求一次当前定位（首次会弹权限）
    func requestCurrent() {
        busy = true
        errorText = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            busy = false
            errorText = "定位权限已关闭，可在「设置 - 隐私与安全性 - 定位服务」里打开"
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorized = LocationService.isAuthorized(status)
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if busy { manager.requestLocation() }
        case .denied, .restricted:
            busy = false
            errorText = "定位权限被拒绝，可以手动输入地址，或在地图上选点"
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let text = placemarks?.first.map(LocationService.format)
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                if let text, !text.isEmpty { self.address = text }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        busy = false
        errorText = "定位失败：" + error.localizedDescription
    }

    // MARK: 工具

    /// 坐标 -> 中文地址（地图选点时用）
    static func address(for coordinate: CLLocationCoordinate2D,
                        completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            let text = placemarks?.first.map(LocationService.format)
            DispatchQueue.main.async { completion(text) }
        }
    }

    /// 把 CLPlacemark 拼成一行中文地址
    static func format(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        func add(_ value: String?) {
            guard let value else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !parts.contains(trimmed) else { return }
            parts.append(trimmed)
        }
        add(placemark.name)
        add(placemark.subLocality)
        add(placemark.locality)
        add(placemark.administrativeArea)
        return parts.joined(separator: " · ")
    }
}
