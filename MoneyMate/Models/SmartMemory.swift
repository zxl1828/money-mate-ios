import Foundation

/// 记账模板：一键记一笔固定的账
struct TxTemplate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var category: String
    var isIncome: Bool = false

    var label: String { name + " " + MoneyFormat.text(amount) }
}

enum MoneyFormat {
    static func text(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 1000 ? 0 : 2
        let body = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "\u{00A5}" + body
    }
}

/// 商户 → 分类 记忆、模板存储（都存在 UserDefaults，不改变账本格式）
enum SmartMemory {
    private static let merchantKey = "moneymate.merchant.categories"
    private static let templateKey = "moneymate.templates.v1"
    private static let clipboardKey = "moneymate.intake.hash"

    // MARK: 商户记忆

    static func merchantMap() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: merchantKey),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    static func category(forMerchant name: String) -> String? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return merchantMap()[key]
    }

    static func remember(merchant: String, category: String) {
        let key = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, !category.isEmpty else { return }
        var map = merchantMap()
        guard map[key] != category else { return }
        map[key] = category
        if map.count > 400 {
            let trimmed = Dictionary(uniqueKeysWithValues: map.prefix(300))
            map = trimmed
        }
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: merchantKey)
        }
    }

    // MARK: 模板

    static func templates() -> [TxTemplate] {
        guard let data = UserDefaults.standard.data(forKey: templateKey),
              let list = try? JSONDecoder().decode([TxTemplate].self, from: data) else { return [] }
        return list
    }

    static func saveTemplates(_ list: [TxTemplate]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: templateKey)
        }
    }

    // MARK: 剪贴板去重

    static func isNewClipboard(_ text: String) -> Bool {
        let stamp = String(text.hashValue)
        if UserDefaults.standard.string(forKey: clipboardKey) == stamp { return false }
        UserDefaults.standard.set(stamp, forKey: clipboardKey)
        return true
    }

    static let privacyKey = "moneymate.privacy.mode"

    static var privacyMode: Bool {
        get { UserDefaults.standard.bool(forKey: privacyKey) }
        set { UserDefaults.standard.set(newValue, forKey: privacyKey) }
    }
}

/// 隐私模式开关（可观察，便于全局即时生效）
final class PrivacyState: ObservableObject {
    static let shared = PrivacyState()

    @Published var enabled: Bool {
        didSet { SmartMemory.privacyMode = enabled }
    }

    private init() {
        enabled = SmartMemory.privacyMode
    }
}
