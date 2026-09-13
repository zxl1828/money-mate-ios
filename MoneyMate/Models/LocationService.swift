import Foundation
import CoreLocation
import MapKit

// MARK: - 地点服务（CoreLocation 定位 + MapKit 反查地址，纯系统 API）

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
        LocationService.reverse(location) { [weak self] text in
            guard let self else { return }
            self.busy = false
            if let text, !text.isEmpty { self.address = text }
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
        reverse(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                completion: completion)
    }

    /// 坐标 -> 一行地址（iOS 26 的 MKReverseGeocodingRequest，回调在主线程）
    static func reverse(_ location: CLLocation,
                        completion: @escaping (String?) -> Void) {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            completion(nil)
            return
        }
        request.getMapItems { items, _ in
            completion(items?.first.map(LocationService.format))
        }
    }

    /// 把 MKMapItem 拼成一行中文地址
    static func format(_ item: MKMapItem) -> String {
        let text = item.addressRepresentations?
            .fullAddress(includingRegion: false, singleLine: true)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, !text.isEmpty { return text }
        return item.name ?? ""
    }
}
