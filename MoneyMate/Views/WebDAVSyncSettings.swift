import SwiftUI

/// 私有 WebDAV 加密同步配置：服务器地址 / 端口 / 路径 / 账号 / 密码 / 主加密口令
struct WebDAVSyncSettings: View {
    @ObservedObject var store: MoneyStore
    var toast: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var host = ""
    @State private var port = "443"
    @State private var path = "/MoneyMate/moneymate.enc"
    @State private var username = ""
    @State private var password = ""
    @State private var passphrase = ""
    @State private var syncing = false
    @State private var autoSync = false
    @State private var result: String?
    @State private var savedHint: String?

    private var composedURL: String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host.trimmingCharacters(in: .whitespaces)
        if let value = Int(port.trimmingCharacters(in: .whitespaces)), value > 0, value != 443 {
            components.port = value
        }
        var tail = path.trimmingCharacters(in: .whitespaces)
        if tail.isEmpty { tail = "/MoneyMate/moneymate.enc" }
        if !tail.hasPrefix("/") { tail = "/" + tail }
        components.path = tail
        return components.string ?? ""
    }

    private var canSubmit: Bool {
        !host.isEmpty && !username.isEmpty && passphrase.count >= 10 && !syncing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("WebDAV 服务器") {
                    TextField("服务器地址，例如 dav.jianguoyun.com", text: $host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("端口（默认 443）", text: $port)
                        .keyboardType(.numberPad)
                    TextField("文件路径，例如 /MoneyMate/moneymate.enc", text: $path)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(composedURL.isEmpty ? "填好地址后自动拼出完整地址" : composedURL)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section("账号") {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $password)
                }

                Section("端到端加密") {
                    SecureField("主加密口令（至少 10 位，两端必须一致）", text: $passphrase)
                    Toggle("回到前台时自动同步", isOn: $autoSync)
                    Text("账本在本机用 PBKDF2-HMAC-SHA256 + AES-256-GCM 加密后再上传，服务器上只有密文。开启自动同步后主口令保存在 Keychain；不开启则每次都要重新输入，不会落盘。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task { await runSync() }
                    } label: {
                        HStack(spacing: 8) {
                            if syncing { ProgressView().controlSize(.small) }
                            Label(syncing ? "正在加密并同步…" : "保存并立即同步",
                                  systemImage: "arrow.triangle.2.circlepath.icloud")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)

                    Button {
                        saveOnly()
                    } label: {
                        Label("只保存配置（下次再说）", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(syncing || host.isEmpty)

                    if let savedHint {
                        Text(savedHint)
                            .font(.caption2)
                            .foregroundStyle(Palette.mint)
                    }
                }
            }
            .navigationTitle("WebDAV 同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { loadCredentials() }
            .alert("同步结果", isPresented: Binding(get: { result != nil },
                                                set: { if !$0 { result = nil } })) {
                Button("好", role: .cancel) { result = nil }
            } message: {
                Text(result ?? "")
            }
        }
    }

    private func loadCredentials() {
        guard let saved = try? WebDAVSyncService.shared.load() else { return }
        username = saved.1
        password = saved.2
        autoSync = WebDAVSyncService.shared.autoSyncEnabled()
        if let components = URLComponents(string: saved.0) {
            host = components.host ?? ""
            port = components.port.map(String.init) ?? "443"
            path = components.path.isEmpty ? "/MoneyMate/moneymate.enc" : components.path
        }
    }

    private func saveOnly() {
        do {
            try WebDAVSyncService.shared.save(url: composedURL, username: username,
                password: password, passphrase: autoSync ? passphrase : "", autoSync: autoSync)
            savedHint = "配置已保存到 Keychain（\(composedURL)）"
        } catch {
            result = "保存失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func runSync() async {
        syncing = true
        defer { syncing = false }
        do {
            try WebDAVSyncService.shared.save(url: composedURL, username: username,
                password: password, passphrase: autoSync ? passphrase : "", autoSync: autoSync)
            let message = try await WebDAVSyncService.shared.sync(store: store, url: composedURL,
                username: username, password: password, passphrase: passphrase)
            passphrase = ""
            result = "\(message)\n服务器：\(composedURL)"
        } catch let error as WebDAVSyncService.SyncError {
            result = "同步失败：\(describe(error))"
        } catch {
            result = "同步失败：\(error.localizedDescription)"
        }
    }

    private func describe(_ error: WebDAVSyncService.SyncError) -> String {
        switch error {
        case .configuration: return "配置不完整（地址需 https、口令至少 10 位）"
        case .invalidData: return "云端文件不是本 App 的加密包"
        case .keyDerivation: return "主口令错误，或两端口令不一致"
        case .keychain(let status): return "Keychain 写入失败（\(status)）"
        case .http(let code): return "服务器返回 HTTP \(code)"
        }
    }
}
