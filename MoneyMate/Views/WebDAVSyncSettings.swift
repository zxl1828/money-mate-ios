import SwiftUI

struct WebDAVSyncSettings: View {
    @ObservedObject var store: MoneyStore
    var toast: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var passphrase = ""
    @State private var syncing = false
    @State private var autoSync = false

    var body: some View {
        NavigationStack {
            Form {
                Section("WebDAV 目标") {
                    TextField("完整文件地址（HTTPS）", text: $url)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("账号", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("WebDAV 密码", text: $password)
                }
                Section("端到端加密") {
                    SecureField("独立主加密口令（至少 10 位）", text: $passphrase)
                    Toggle("回到前台时自动同步", isOn: $autoSync)
                    Text("账本在本机使用 PBKDF2-HMAC-SHA256 与 AES-256-GCM 加密。服务器只保存密文，主口令不会保存。两端使用同一口令。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button {
                        Task { await syncNow() }
                    } label: {
                        HStack {
                            if syncing { ProgressView() }
                            Label("保存并立即同步", systemImage: "arrow.triangle.2.circlepath.icloud")
                        }.frame(maxWidth: .infinity)
                    }
                    .disabled(syncing || url.isEmpty || passphrase.count < 10)
                }
            }
            .navigationTitle("WebDAV 同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task { loadCredentials() }
        }
    }

    private func loadCredentials() {
        if let saved = try? WebDAVSyncService.shared.load() {
            url = saved.0; username = saved.1; password = saved.2
            autoSync = WebDAVSyncService.shared.autoSyncEnabled()
        }
    }

    @MainActor private func syncNow() async {
        syncing = true
        defer { syncing = false }
        do {
            try WebDAVSyncService.shared.save(url: url, username: username, password: password,
                passphrase: autoSync ? passphrase : "", autoSync: autoSync)
            let result = try await WebDAVSyncService.shared.sync(store: store, url: url,
                username: username, password: password, passphrase: passphrase)
            passphrase = ""
            toast(result)
        } catch {
            toast("同步失败：\(error.localizedDescription)")
        }
    }
}
