import Foundation

/// iCloud 私有同步（键值存储，无需自建服务器）
/// 未开启 iCloud 能力时自动降级为"不可用"，不影响本地使用。
final class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    enum Status: Equatable {
        case unavailable
        case idle
        case syncing
        case synced(Date)
        case failed(String)

        var text: String {
            switch self {
            case .unavailable: return "未开启 iCloud（本地模式）"
            case .idle: return "等待同步"
            case .syncing: return "同步中…"
            case .synced(let date):
                let f = DateFormatter()
                f.dateFormat = "M月d日 HH:mm"
                return "已同步 \u{00B7} " + f.string(from: date)
            case .failed(let msg): return "同步失败：" + msg
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastSync: Date?

    private let kv = NSUbiquitousKeyValueStore.default
    private let payloadKey = "moneymate.sync.payload"
    private let stampKey = "moneymate.sync.stamp"
    private let maxBytes = 900_000   // iCloud 键值存储单值上限约 1MB

    private struct Envelope: Codable {
        var stamp: Double
        var payload: Data
    }

    var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private init() {
        status = isAvailable ? .idle : .unavailable
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                              object: kv, queue: .main) { [weak self] note in
            guard let self else { return }
            let reason = (note.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int) ?? 0
            self.status = .idle
            if reason != NSUbiquitousKeyValueStoreInitialSyncChange {
                NotificationCenter.default.post(name: .moneyMateRemoteChanged, object: nil)
            }
        }
        kv.synchronize()
    }

    /// 本机写入（persist 时调用）
    func push(data: Data) {
        guard isAvailable else { status = .unavailable; return }
        guard data.count <= maxBytes else {
            status = .failed("账本过大（\(data.count / 1024)KB），暂不能云同步")
            return
        }
        let stamp = Date().timeIntervalSince1970
        guard let env = try? JSONEncoder().encode(Envelope(stamp: stamp, payload: data)) else { return }
        kv.set(env, forKey: payloadKey)
        update(status: .syncing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.lastSync = Date()
            self?.update(status: .synced(Date(timeIntervalSince1970: stamp)))
        }
    }

    /// 拉取云端的账本（若比本机新）
    func remotePayload() -> Data? {
        guard isAvailable else { return nil }
        guard let raw = kv.data(forKey: payloadKey),
              let env = try? JSONDecoder().decode(Envelope.self, from: raw) else { return nil }
        return env.payload
    }

    func syncNow() {
        guard isAvailable else { status = .unavailable; return }
        kv.synchronize()
        update(status: .syncing)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.lastSync = Date()
            self?.update(status: .synced(Date()))
        }
    }

    /// 统一在主线程更新状态
    private func update(status newValue: Status) {
        if Thread.isMainThread {
            status = newValue
        } else {
            DispatchQueue.main.async { [weak self] in self?.status = newValue }
        }
    }
}

extension Notification.Name {
    /// iCloud 端有新数据，主程序需要合并
    static let moneyMateRemoteChanged = Notification.Name("moneymate.remote.changed")
}
