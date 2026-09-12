import Foundation

// MARK: - 一笔账

struct Tx: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var amount: Double          // > 0 收入，< 0 支出
    var category: String
    var date: Date = Date()

    var isIncome: Bool { amount >= 0 }
    var symbol: String { Tx.symbol(for: category) }

    static let categories = ["餐饮", "交通", "购物", "居家", "娱乐", "工资", "其他"]

    static func symbol(for category: String) -> String {
        switch category {
        case "餐饮": return "fork.knife"
        case "交通": return "tram.fill"
        case "购物": return "bag.fill"
        case "居家": return "house.fill"
        case "娱乐": return "gamecontroller.fill"
        case "工资": return "banknote.fill"
        default: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - 持久化快照

private struct StoreSnapshot: Codable {
    var txs: [Tx] = []
    var budget: Double = 6000
    var notifyEnabled: Bool = true
    var privacyLock: Bool = false
    var hapticsEnabled: Bool = true
    var cloudSync: Bool = false
    var seeded: Bool = false
}

// MARK: - 数据仓库（所有按钮的后端逻辑）

final class MoneyStore: ObservableObject {
    @Published var txs: [Tx] { didSet { persist() } }
    @Published var budget: Double { didSet { persist() } }
    @Published var notifyEnabled: Bool { didSet { persist() } }
    @Published var privacyLock: Bool { didSet { persist() } }
    @Published var hapticsEnabled: Bool { didSet { persist() } }
    @Published var cloudSync: Bool { didSet { persist() } }

    private static let key = "moneymate.store.v1"

    init() {
        var snap = MoneyStore.load()
        if !snap.seeded {
            snap.txs = MoneyStore.sampleData()
            snap.seeded = true
        }
        txs = snap.txs
        budget = snap.budget
        notifyEnabled = snap.notifyEnabled
        privacyLock = snap.privacyLock
        hapticsEnabled = snap.hapticsEnabled
        cloudSync = snap.cloudSync
        if !MoneyStore.hasPersisted() { persist() }
    }

    // MARK: 读写

    func add(_ tx: Tx) {
        txs.insert(tx, at: 0)
    }

    func delete(_ tx: Tx) {
        txs.removeAll { $0.id == tx.id }
    }

    func clearAll() {
        txs = []
    }

    func restoreSamples() {
        txs = MoneyStore.sampleData()
    }

    private func persist() {
        let snap = StoreSnapshot(txs: txs,
                                 budget: budget,
                                 notifyEnabled: notifyEnabled,
                                 privacyLock: privacyLock,
                                 hapticsEnabled: hapticsEnabled,
                                 cloudSync: cloudSync,
                                 seeded: true)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        UserDefaults.standard.set(data, forKey: MoneyStore.key)
    }

    private static func hasPersisted() -> Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    private static func load() -> StoreSnapshot {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(StoreSnapshot.self, from: data) else {
            return StoreSnapshot()
        }
        return snap
    }

    // MARK: 统计

    var monthTxs: [Tx] {
        let cal = Calendar.current
        return txs.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    var todayTxs: [Tx] {
        let cal = Calendar.current
        return txs.filter { cal.isDateInToday($0.date) }
    }

    var income: Double { monthTxs.filter { $0.isIncome }.reduce(0) { $0 + $1.amount } }
    var expense: Double { monthTxs.filter { !$0.isIncome }.reduce(0) { $0 - $1.amount } }
    var balance: Double { income - expense }

    var budgetLeft: Double { max(budget - expense, 0) }
    var budgetProgress: Double { budget <= 0 ? 0 : min(expense / budget, 1) }

    /// 近 7 日支出
    func last7Days() -> [(label: String, value: Double)] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        var result: [(String, Double)] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let total = txs.filter { !$0.isIncome && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 - $1.amount }
            result.append((formatter.string(from: day), total))
        }
        return result
    }

    /// 本月支出分类
    func categoryTotals() -> [(label: String, value: Double)] {
        var bucket: [String: Double] = [:]
        for tx in monthTxs where !tx.isIncome {
            bucket[tx.category, default: 0] += -tx.amount
        }
        return bucket.map { (label: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }

    // MARK: 金额格式化

    func money(_ value: Double) -> String {
        let text = MoneyStore.decimalFormatter.string(from: NSNumber(value: abs(value))) ?? "0.00"
        return (value < 0 ? "- \u{00A5} " : "\u{00A5} ") + text
    }

    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: 示例数据

    static func sampleData() -> [Tx] {
        [Tx(title: "星巴克", amount: -32, category: "餐饮"),
         Tx(title: "地铁", amount: -6, category: "交通"),
         Tx(title: "工资", amount: 12000, category: "工资"),
         Tx(title: "超市采购", amount: -186.5, category: "购物")]
    }
}