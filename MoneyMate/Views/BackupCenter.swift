import SwiftUI

/// 自动备份 + 版本历史（存在 App 文档目录，保留最近 7 份）
enum BackupHistory {
    static var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Backups", isDirectory: true)
    }

    static func snapshot(_ data: Data, keep: Int = 7) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = folder.appendingPathComponent("MoneyMate-" + formatter.string(from: Date()) + ".json")
        try? data.write(to: url, options: .atomic)
        // 只留最近 keep 份
        let files = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let sorted = files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return a > b
        }
        for old in sorted.dropFirst(keep) {
            try? fm.removeItem(at: old)
        }
    }

    static func list() -> [URL] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return a > b
        }
    }

    static func read(_ url: URL) -> Data? {
        try? Data(contentsOf: url)
    }
}

struct BackupCenterCard: View {
    @ObservedObject var store: MoneyStore
    var toast: (String) -> Void = { _ in }
    @State private var versions: [URL] = BackupHistory.list()
    @State private var pendingRestore: URL?
    @State private var showingRestoreConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "版本历史", subtitle: "每次改动自动备份，保留最近 7 份") {
                if let data = store.exportJSON() {
                    BackupHistory.snapshot(data)
                    versions = BackupHistory.list()
                    toast("已生成一份备份")
                }
            }
            if versions.isEmpty {
                Text("还没有自动备份，改一笔账就会生成")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            } else {
                ForEach(versions.prefix(5), id: \.absoluteString) { url in
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                        Text(Self.label(url))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                        Button("恢复") {
                            pendingRestore = url
                            showingRestoreConfirmation = true
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.primary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .confirmationDialog("恢复历史备份？", isPresented: $showingRestoreConfirmation, titleVisibility: .visible) {
            if let pendingRestore {
                Button("覆盖并恢复", role: .destructive) {
                    restore(pendingRestore)
                }
            }
            Button("取消", role: .cancel) {
                pendingRestore = nil
            }
        } message: {
            Text("当前账本将被所选备份替换。取消不会更改数据。")
        }
    }

    private func restore(_ url: URL) {
        guard let data = BackupHistory.read(url) else {
            Haptics.error()
            toast("无法读取备份，当前数据未更改")
            pendingRestore = nil
            return
        }
        guard store.importJSON(data) else {
            Haptics.error()
            toast("备份内容无效，当前数据未更改")
            pendingRestore = nil
            return
        }
        Haptics.success()
        versions = BackupHistory.list()
        toast("已恢复到 " + Self.label(url))
        pendingRestore = nil
    }

    static func label(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "MoneyMate-", with: "")
    }
}
