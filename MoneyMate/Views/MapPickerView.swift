import SwiftUI
import MapKit
import CoreLocation

// MARK: - 地址搜索建议（MKLocalSearchCompleter，主线程回调）

final class AddressSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                results = []
            } else {
                completer.queryFragment = text
            }
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = Array(completer.results.prefix(5))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}

// MARK: - 地图选点

/// 拖动地图 -> 屏幕中心图钉 -> 反查地址。左上角搜索框可直接搜门店。
struct MapPickerView: View {
    var initialCoordinate: CLLocationCoordinate2D?
    var initialAddress: String = ""
    var onPick: (String, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var search = AddressSearchModel()
    @StateObject private var locator = LocationService()

    @State private var camera: MapCameraPosition
    @State private var picked: CLLocationCoordinate2D?
    @State private var address: String
    @State private var hint = "拖动地图，把图钉对准这笔账发生的位置"
    @State private var resolving = false
    @State private var requestToken = ""
    @State private var lastResolved: CLLocationCoordinate2D?

    private static let fallbackCenter = CLLocationCoordinate2D(latitude: 39.9087, longitude: 116.3975)

    init(initialCoordinate: CLLocationCoordinate2D?,
         initialAddress: String = "",
         onPick: @escaping (String, Double, Double) -> Void) {
        self.initialCoordinate = initialCoordinate
        self.initialAddress = initialAddress
        self.onPick = onPick
        let start = initialCoordinate ?? MapPickerView.fallbackCenter
        let distance: CLLocationDistance = initialCoordinate == nil ? 12000 : 800
        _camera = State(initialValue: .camera(MapCamera(centerCoordinate: start, distance: distance)))
        _picked = State(initialValue: start)
        _address = State(initialValue: initialAddress)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapLayer
                panel
            }
            .navigationTitle("在地图上选点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") { confirm() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            if let initial = initialCoordinate {
                resolve(initial)
            } else {
                locateMe()
            }
        }
        .onChange(of: locator.address) { _, newValue in
            guard let coordinate = locator.coordinate, !newValue.isEmpty else { return }
            move(to: coordinate)
            address = newValue
            hint = "已用当前定位，可继续拖动微调"
        }
        .onChange(of: locator.errorText) { _, newValue in
            if let newValue { hint = newValue }
        }
    }

    // MARK: 地图

    private var mapLayer: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) { }
            .mapControls { MapCompass() }
            .onMapCameraChange(frequency: .onEnd) { context in
                let center = context.camera.centerCoordinate
                picked = center
                resolve(center)
            }
            .overlay { centerPin }
    }

    private var centerPin: some View {
        VStack(spacing: -6) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white, Palette.primary)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9))
                .foregroundStyle(Palette.primary)
        }
        .offset(y: -22)
        .shadow(color: .black.opacity(0.20), radius: 8, y: 4)
        .allowsHitTesting(false)
    }

    // MARK: 底部面板

    private var panel: some View {
        VStack(spacing: 12) {
            searchField
            if !search.results.isEmpty { suggestions }
            infoRow
        }
        .padding(16)
        .glassPanel(Radius.card, strong: true)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.primary)
            TextField("搜索地点，例如 星巴克 国贸", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.ink)
                .submitLabel(.search)
            if !search.query.isEmpty {
                Button {
                    search.query = ""
                    search.results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.ink.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .innerTile(Radius.chip, opacity: 0.10)
    }

    private var suggestions: some View {
        VStack(spacing: 0) {
            ForEach(Array(search.results.enumerated()), id: \.offset) { index, item in
                Button {
                    select(item)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.primary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.ink.opacity(0.55))
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index != search.results.count - 1 {
                    Rectangle().fill(Palette.ink.opacity(0.08)).frame(height: 1)
                }
            }
        }
    }

    private var infoRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(address.isEmpty ? (resolving ? "正在识别这个位置…" : "还没选到具体地址") : address)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button {
                locateMe()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Palette.hero, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 动作

    private func locateMe() {
        hint = "正在获取当前定位…"
        locator.requestCurrent()
    }

    private func move(to coordinate: CLLocationCoordinate2D) {
        camera = .camera(MapCamera(centerCoordinate: coordinate, distance: 800))
        picked = coordinate
        lastResolved = coordinate
    }

    private func resolve(_ coordinate: CLLocationCoordinate2D) {
        if let last = lastResolved {
            let a = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let b = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if a.distance(from: b) < 15 { return }
        }
        lastResolved = coordinate
        resolving = true
        let token = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
        requestToken = token
        LocationService.address(for: coordinate) { text in
            guard requestToken == token else { return }
            resolving = false
            if let text, !text.isEmpty {
                address = text
            } else {
                address = token
            }
        }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        let text = completion.subtitle.isEmpty ? completion.title : completion.title + " " + completion.subtitle
        hint = "正在定位搜索结果…"
        CLGeocoder().geocodeAddressString(text) { placemarks, _ in
            guard let coordinate = placemarks?.first?.location?.coordinate else {
                hint = "没能定位这个搜索结果，试试直接拖动地图"
                return
            }
            move(to: coordinate)
            address = text
            hint = "已定位到搜索结果，可继续拖动微调"
            search.query = ""
            search.results = []
        }
    }

    private func confirm() {
        let coordinate = picked ?? MapPickerView.fallbackCenter
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = text.isEmpty ? String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude) : text
        onPick(name, coordinate.latitude, coordinate.longitude)
        dismiss()
    }
}
