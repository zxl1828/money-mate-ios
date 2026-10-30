import Foundation
import CryptoKit
import Security
import CommonCrypto

@MainActor
final class WebDAVSyncService {
    static let shared = WebDAVSyncService()
    private let keychainService = "com.moneymate.webdav"
    private let keychainAccount = "credentials"
    private let aad = Data("MoneyMate-WebDAV-v1".utf8)

    private struct Credentials: Codable {
        var url: String
        var username: String
        var password: String
        var passphrase: String = ""
        var autoSync: Bool = false
    }

    func save(url: String, username: String, password: String,
              passphrase: String = "", autoSync: Bool = false) throws {
        let data = try JSONEncoder().encode(Credentials(url: url, username: username,
            password: password, passphrase: passphrase, autoSync: autoSync))
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: keychainService,
                                   kSecAttrAccount as String: keychainAccount]
        SecItemDelete(base as CFDictionary)
        var item = base
        item[kSecValueData as String] = data
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw SyncError.keychain(status) }
    }

    func syncSaved(store: MoneyStore) async {
        guard let saved = try? load(), let credentials = try? readCredentials(),
              credentials.autoSync, credentials.passphrase.count >= 10,
              !saved.0.isEmpty else { return }
        _ = try? await sync(store: store, url: saved.0, username: saved.1,
            password: saved.2, passphrase: credentials.passphrase)
    }

    func autoSyncEnabled() -> Bool { (try? readCredentials())?.autoSync ?? false }

    func load() throws -> (String, String, String) {
        let credentials = try readCredentials()
        return (credentials.url, credentials.username, credentials.password)
    }

    private func readCredentials() throws -> Credentials {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: keychainService,
                                    kSecAttrAccount as String: keychainAccount,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let credentials = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return Credentials(url: "", username: "", password: "")
        }
        return credentials
    }

    func sync(store: MoneyStore, url: String, username: String, password: String,
              passphrase: String) async throws -> String {
        guard let target = URL(string: url), target.scheme?.lowercased() == "https",
              target.host?.isEmpty == false, passphrase.count >= 10 else { throw SyncError.configuration }
        var request = URLRequest(url: target, timeoutInterval: 30)
        let auth = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        let (remote, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 200 {
            let clear = try decrypt(remote, passphrase: passphrase)
            try merge(clear, into: store)
        } else if code != 404 {
            throw SyncError.http(code)
        }
        let payload = try sharedPackage(store)
        let encrypted = try encrypt(payload, passphrase: passphrase)
        var put = URLRequest(url: target, timeoutInterval: 30)
        put.httpMethod = "PUT"
        put.httpBody = encrypted
        put.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        put.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (_, putResponse) = try await URLSession.shared.data(for: put)
        let putCode = (putResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(putCode) else { throw SyncError.http(putCode) }
        return "已安全同步"
    }

    private func sharedPackage(_ store: MoneyStore) throws -> Data {
        let iso = ISO8601DateFormatter()
        let day = DateFormatter(); day.dateFormat = "yyyy-MM-dd"
        let time = DateFormatter(); time.dateFormat = "HH:mm"
        let accounts = store.accounts.map { account in
            ["name": account.name, "kind": account.kind.rawValue,
             "currency": account.currency.rawValue, "initial_balance": account.initialBalance,
             "card_tail": account.cardTail, "credit_limit": account.creditLimit,
             "statement_day": account.statementDay, "due_day": account.dueDay,
             "archived": account.archived ? 1 : 0, "created_at": iso.string(from: account.createdAt)] as [String: Any]
        }
        let txs = store.txs.map { tx -> [String: Any] in
            let account = store.accounts.first { $0.id == tx.accountID }
            let to = store.accounts.first { $0.id == tx.toAccountID }
            let type: String = tx.kind == .refund ? "refund" : tx.kind == .transfer ? "transfer" : tx.isIncome ? "income" : "expense"
            return ["amount": tx.amount, "currency": tx.currency.rawValue,
                    "base_amount": tx.amountCNY, "type": type, "category": tx.category,
                    "payee": tx.merchant, "tags": tx.tags.joined(separator: ","),
                    "note": tx.note, "transaction_date": day.string(from: tx.date),
                    "transaction_time": time.string(from: tx.date), "location": tx.location,
                    "is_recurring": tx.recurrence == .none ? 0 : 1,
                    "recurring_period": tx.recurrence == .monthly ? "每月" : tx.recurrence == .weekly ? "每周" : tx.recurrence == .daily ? "每日" : "",
                    "recurring_end_date": NSNull(), "dedup_hash": "", "created_at": iso.string(from: tx.date),
                    "updated_at": iso.string(from: tx.updatedAt), "member_name": tx.memberName,
                    "uid": tx.id.uuidString.replacingOccurrences(of: "-", with: "").lowercased(), "ledger": tx.ledger,
                    "refund_of_uid": tx.refundOfID?.uuidString.replacingOccurrences(of: "-", with: "").lowercased() ?? "",
                    "account_ref": account.map { "\($0.name)|\($0.kind.rawValue)" } ?? "",
                    "to_account_ref": to.map { "\($0.name)|\($0.kind.rawValue)" } ?? ""]
        }
        return try JSONSerialization.data(withJSONObject: ["accounts": accounts, "txs": txs], options: [.sortedKeys])
    }

    private func merge(_ data: Data, into store: MoneyStore) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawTxs = root["txs"] as? [[String: Any]] else { throw SyncError.invalidData }
        var accountsByRef: [String: Account] = [:]
        for account in store.accounts {
            accountsByRef["\(account.name)|\(account.kind.rawValue)"] = account
        }
        for raw in root["accounts"] as? [[String: Any]] ?? [] {
            guard let name = raw["name"] as? String, let kindRaw = raw["kind"] as? String,
                  let kind = AccountKind(rawValue: kindRaw) else { continue }
            let ref = "\(name)|\(kindRaw)"
            if accountsByRef[ref] != nil { continue }
            let account = Account(name: name, kind: kind,
                                  currency: Currency(rawValue: raw["currency"] as? String ?? "CNY") ?? .cny,
                                  initialBalance: (raw["initial_balance"] as? NSNumber)?.doubleValue ?? 0,
                                  cardTail: raw["card_tail"] as? String ?? "",
                                  creditLimit: (raw["credit_limit"] as? NSNumber)?.doubleValue ?? 0,
                                  statementDay: (raw["statement_day"] as? NSNumber)?.intValue ?? 0,
                                  dueDay: (raw["due_day"] as? NSNumber)?.intValue ?? 0,
                                  archived: (raw["archived"] as? NSNumber)?.intValue == 1)
            store.accounts.append(account)
            accountsByRef[ref] = account
        }
        let current = Dictionary(uniqueKeysWithValues: store.txs.map { ($0.id, $0) })
        var merged = current
        for raw in rawTxs {
            guard let uid = raw["uid"] as? String, let id = Self.parseUUID(uid),
                  let type = raw["type"] as? String,
                  let dateText = raw["transaction_date"] as? String,
                  let date = ISO8601DateFormatter.date(dateText) else { continue }
            let updatedAt = ISO8601DateFormatter.date(raw["updated_at"] as? String ?? "") ?? date
            if let old = merged[id], old.updatedAt >= updatedAt { continue }
            let amount = (raw["amount"] as? NSNumber)?.doubleValue ?? 0
            let base = (raw["base_amount"] as? NSNumber)?.doubleValue ?? amount
            let currency = Currency(rawValue: raw["currency"] as? String ?? "CNY") ?? .cny
            let period = raw["recurring_period"] as? String ?? ""
            let recurrence: Recurrence = period == "每月" ? .monthly : period == "每周" ? .weekly : period == "每日" ? .daily : .none
            let account = accountsByRef[raw["account_ref"] as? String ?? ""]
            let to = accountsByRef[raw["to_account_ref"] as? String ?? ""]
            let tx = Tx(id: id, title: raw["payee"] as? String ?? (raw["category"] as? String ?? "账单"),
                        amount: amount, currency: currency,
                        rate: abs(amount) > 0.000001 ? abs(base / amount) : currency.rateToCNY,
                        category: raw["category"] as? String ?? "其他", date: date,
                        merchant: raw["payee"] as? String ?? "", note: raw["note"] as? String ?? "",
                        tags: (raw["tags"] as? String ?? "").split(separator: ",").map(String.init),
                        location: raw["location"] as? String ?? "", recurrence: recurrence,
                        kind: type == "refund" ? .refund : type == "transfer" ? .transfer : type == "income" ? .income : .expense,
                        accountID: account?.id, toAccountID: to?.id, updatedAt: updatedAt,
                        memberName: raw["member_name"] as? String ?? "", ledger: raw["ledger"] as? String ?? "日常",
                        refundOfID: Self.parseUUID(raw["refund_of_uid"] as? String ?? ""))
            merged[id] = tx
        }
        store.txs = merged.values.sorted { $0.date > $1.date }
    }

    private func encrypt(_ clear: Data, passphrase: String) throws -> Data {
        let salt = Self.random(count: 16), nonceData = Self.random(count: 12)
        let key = try derive(passphrase, salt: salt)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealed = try AES.GCM.seal(clear, using: key, nonce: nonce, authenticating: aad)
        return try JSONSerialization.data(withJSONObject: ["version": 1, "kdf": "PBKDF2-HMAC-SHA256", "iterations": 310000,
            "salt": salt.base64EncodedString(), "nonce": nonceData.base64EncodedString(),
            "ciphertext": (sealed.ciphertext + sealed.tag).base64EncodedString()])
    }

    private func decrypt(_ envelope: Data, passphrase: String) throws -> Data {
        guard let box = try JSONSerialization.jsonObject(with: envelope) as? [String: Any],
              box["version"] as? Int == 1, box["kdf"] as? String == "PBKDF2-HMAC-SHA256",
              box["iterations"] as? Int == 310000,
              let saltText = box["salt"] as? String, let salt = Data(base64Encoded: saltText),
              let nonceText = box["nonce"] as? String, let nonce = Data(base64Encoded: nonceText),
              let cipher = box["ciphertext"] as? String, let bytes = Data(base64Encoded: cipher), bytes.count >= 16 else {
            throw SyncError.invalidData
        }
        let key = try derive(passphrase, salt: salt)
        let sealed = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: Data(bytes.dropLast(16)), tag: Data(bytes.suffix(16)))
        return try AES.GCM.open(sealed, using: key, authenticating: aad)
    }

    private func derive(_ phrase: String, salt: Data) throws -> SymmetricKey {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltBuffer in
            bytes.withUnsafeMutableBytes { keyBuffer in
                phrase.withCString { password in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, phrase.utf8.count,
                        saltBuffer.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 310000, keyBuffer.baseAddress!, bytes.count)
                }
            }
        }
        guard status == kCCSuccess else { throw SyncError.keyDerivation }
        return SymmetricKey(data: Data(bytes))
    }

    private static func random(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private static func parseUUID(_ value: String) -> UUID? {
        if let id = UUID(uuidString: value) { return id }
        let compact = value.replacingOccurrences(of: "-", with: "")
        guard compact.count == 32 else { return nil }
        let parts = [compact.prefix(8), compact.dropFirst(8).prefix(4), compact.dropFirst(12).prefix(4),
                     compact.dropFirst(16).prefix(4), compact.suffix(12)]
        return UUID(uuidString: parts.map { String($0) }.joined(separator: "-"))
    }

    enum SyncError: Error { case configuration, invalidData, keyDerivation, keychain(OSStatus), http(Int) }
}

private extension ISO8601DateFormatter {
    static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value) ?? {
            let date = DateFormatter(); date.locale = Locale(identifier: "en_US_POSIX"); date.dateFormat = "yyyy-MM-dd"
            return date.date(from: value)
        }()
    }
}
