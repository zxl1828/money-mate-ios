import Foundation
import CoreLocation

// MARK: - 币种（离线参考汇率，录入时锁定）

enum Currency: String, Codable, CaseIterable, Identifiable {
    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case jpy = "JPY"
    case hkd = "HKD"
    case gbp = "GBP"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cny: return "人民币"
        case .usd: return "美元"
        case .eur: return "欧元"
        case .jpy: return "日元"
        case .hkd: return "港币"
        case .gbp: return "英镑"
        }
    }

    var symbol: String {
        switch self {
        case .cny, .jpy: return "\u{00A5}"
        case .usd: return "$"
        case .eur: return "\u{20AC}"
        case .hkd: return "HK$"
        case .gbp: return "\u{00A3}"
        }
    }

    /// 离线参考汇率：1 单位该币种 约等于 多少人民币（录入当天锁定）
    var rateToCNY: Double {
        switch self {
        case .cny: return 1
        case .usd: return 7.18
        case .eur: return 7.82
        case .jpy: return 0.0475
        case .hkd: return 0.918
        case .gbp: return 9.12
        }
    }
}

// MARK: - 周期账单规则

enum Recurrence: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "不重复"
        case .daily: return "每天"
        case .weekly: return "每周"
        case .monthly: return "每月"
        }
    }

    var icon: String {
        switch self {
        case .none: return "minus"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        }
    }

    func advance(_ date: Date) -> Date? {
        let cal = Calendar.current
        switch self {
        case .none: return nil
        case .daily: return cal.date(byAdding: .day, value: 1, to: date)
        case .weekly: return cal.date(byAdding: .day, value: 7, to: date)
        case .monthly: return cal.date(byAdding: .month, value: 1, to: date)
        }
    }
}

// MARK: - 一笔账

struct Tx: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var amount: Double          // 有符号：> 0 收入，< 0 支出（原币种金额）
    var currency: Currency
    var rate: Double            // 录入时锁定的汇率（转人民币）
    var category: String
    var date: Date
    var merchant: String
    var note: String
    var tags: [String]
    var location: String
    var latitude: Double?       // 地点纬度（可选）
    var longitude: Double?      // 地点经度（可选）
    var recurrence: Recurrence
    var sourceID: UUID?         // 周期账单母单
    var autoPosted: Bool        // 是否为自动补录

    init(id: UUID = UUID(),
         title: String,
         amount: Double,
         currency: Currency = .cny,
         rate: Double? = nil,
         category: String,
         date: Date = Date(),
         merchant: String = "",
         note: String = "",
         tags: [String] = [],
         location: String = "",
         latitude: Double? = nil,
         longitude: Double? = nil,
         recurrence: Recurrence = .none,
         sourceID: UUID? = nil,
         autoPosted: Bool = false) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.rate = rate ?? currency.rateToCNY
        self.category = category
        self.date = date
        self.merchant = merchant
        self.note = note
        self.tags = tags
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.recurrence = recurrence
        self.sourceID = sourceID
        self.autoPosted = autoPosted
    }

    enum CodingKeys: String, CodingKey {
        case id, title, amount, currency, rate, category, date
        case merchant, note, tags, location, latitude, longitude, recurrence, sourceID, autoPosted
    }

    // 兼容旧版本存档：缺失字段一律回落默认值
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "未命名"
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        let cur = try c.decodeIfPresent(Currency.self, forKey: .currency) ?? .cny
        currency = cur
        rate = try c.decodeIfPresent(Double.self, forKey: .rate) ?? cur.rateToCNY
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "其他"
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        location = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? .none
        sourceID = try c.decodeIfPresent(UUID.self, forKey: .sourceID)
        autoPosted = try c.decodeIfPresent(Bool.self, forKey: .autoPosted) ?? false
    }

    var isIncome: Bool { amount >= 0 }
    var amountCNY: Double { amount * rate }
    var symbol: String { Tx.symbol(for: category) }

    /// 是否记录了精确坐标
    var hasCoordinate: Bool { latitude != nil && longitude != nil }

    /// 地图回看用的坐标
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 展示金额：外币会同时给出折合人民币
    var displayAmount: String {
        let sign = amount >= 0 ? "+ " : "- "
        let body = currency.symbol + " " + String(format: "%.2f", abs(amount))
        if currency == .cny { return sign + body }
        return sign + body + "  \u{2248} \u{00A5} " + String(format: "%.2f", abs(amountCNY))
    }

    var shortAmount: String {
        let sign = amount >= 0 ? "+" : "-"
        return sign + currency.symbol + String(format: "%.2f", abs(amount))
    }

    static let categories = ["餐饮", "交通", "购物", "居家", "娱乐", "医疗", "学习", "旅行", "宠物", "工资", "理财", "其他"]

    static func symbol(for category: String) -> String {
        switch category {
        case "餐饮": return "fork.knife"
        case "交通": return "tram.fill"
        case "购物": return "bag.fill"
        case "居家": return "house.fill"
        case "娱乐": return "gamecontroller.fill"
        case "医疗": return "cross.case.fill"
        case "学习": return "book.fill"
        case "旅行": return "airplane"
        case "宠物": return "pawprint.fill"
        case "工资": return "banknote.fill"
        case "理财": return "chart.line.uptrend.xyaxis"
        default: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - 图表数据点

struct DayPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let label: String
    let value: Double
}

struct CategoryTotal: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let value: Double
}

struct MonthPoint: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let income: Double
    let expense: Double
}

struct DayGroup: Identifiable {
    var id: Date { day }
    let day: Date
    let txs: [Tx]
    let expense: Double
    let income: Double
}

// MARK: - 存档

private struct StoreSnapshot: Codable {
    var txs: [Tx] = []
    var budget: Double = 6000
    var notifyEnabled: Bool = true
    var privacyLock: Bool = false
    var hapticsEnabled: Bool = true
    var cloudSync: Bool = false
    var baseCurrency: Currency = .cny
    var budgetByCategory: [String: Double] = [:]
    var recurringEnabled: Bool = true
    var seeded: Bool = false

    enum CodingKeys: String, CodingKey {
        case txs, budget, notifyEnabled, privacyLock, hapticsEnabled, cloudSync
        case baseCurrency, budgetByCategory, recurringEnabled, seeded
    }

    init(txs: [Tx] = [],
         budget: Double = 6000,
         notifyEnabled: Bool = true,
         privacyLock: Bool = false,
         hapticsEnabled: Bool = true,
         cloudSync: Bool = false,
         baseCurrency: Currency = .cny,
         budgetByCategory: [String: Double] = [:],
         recurringEnabled: Bool = true,
         seeded: Bool = false) {
        self.txs = txs
        self.budget = budget
        self.notifyEnabled = notifyEnabled
        self.privacyLock = privacyLock
        self.hapticsEnabled = hapticsEnabled
        self.cloudSync = cloudSync
        self.baseCurrency = baseCurrency
        self.budgetByCategory = budgetByCategory
        self.recurringEnabled = recurringEnabled
        self.seeded = seeded
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        txs = try c.decodeIfPresent([Tx].self, forKey: .txs) ?? []
        budget = try c.decodeIfPresent(Double.self, forKey: .budget) ?? 6000
        notifyEnabled = try c.decodeIfPresent(Bool.self, forKey: .notifyEnabled) ?? true
        privacyLock = try c.decodeIfPresent(Bool.self, forKey: .privacyLock) ?? false
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        cloudSync = try c.decodeIfPresent(Bool.self, forKey: .cloudSync) ?? false
        baseCurrency = try c.decodeIfPresent(Currency.self, forKey: .baseCurrency) ?? .cny
        budgetByCategory = try c.decodeIfPresent([String: Double].self, forKey: .budgetByCategory) ?? [:]
        recurringEnabled = try c.decodeIfPresent(Bool.self, forKey: .recurringEnabled) ?? true
        seeded = try c.decodeIfPresent(Bool.self, forKey: .seeded) ?? false
    }
}

// MARK: - 数据仓库（所有按钮的后端逻辑）

final class MoneyStore: ObservableObject {
    @Published var txs: [Tx] { didSet { persist() } }
    @Published var budget: Double { didSet { persist() } }
    @Published var notifyEnabled: Bool { didSet { persist() } }
    @Published var privacyLock: Bool { didSet { persist() } }
    @Published var hapticsEnabled: Bool { didSet { persist() } }
    @Published var cloudSync: Bool { didSet { persist() } }
    @Published var baseCurrency: Currency { didSet { persist() } }
    @Published var budgetByCategory: [String: Double] { didSet { persist() } }
    @Published var recurringEnabled: Bool { didSet { persist() } }

    private static let key = "moneymate.store.v1"
    private var isLoading = false

    init() {
        let snap = MoneyStore.load()
        txs = snap.txs
        budget = snap.budget
        notifyEnabled = snap.notifyEnabled
        privacyLock = snap.privacyLock
        hapticsEnabled = snap.hapticsEnabled
        cloudSync = snap.cloudSync
        baseCurrency = snap.baseCurrency
        budgetByCategory = snap.budgetByCategory
        recurringEnabled = snap.recurringEnabled
        isLoading = true
        if !snap.seeded {
            txs = MoneyStore.sampleData()
            isLoading = false
            persist()
        } else {
            isLoading = false
            processRecurring()
        }
    }

    // MARK: 增删改

    func add(_ tx: Tx) {
        txs.insert(tx, at: 0)
    }

    func update(_ tx: Tx) {
        guard let idx = txs.firstIndex(where: { $0.id == tx.id }) else { return }
        txs[idx] = tx
    }

    func delete(_ tx: Tx) {
        txs.removeAll { $0.id == tx.id || $0.sourceID == tx.id }
    }

    func clearAll() {
        txs = []
    }

    func restoreSamples() {
        txs = MoneyStore.sampleData()
    }

    private func persist() {
        guard !isLoading else { return }
        let snap = StoreSnapshot(txs: txs,
                                 budget: budget,
                                 notifyEnabled: notifyEnabled,
                                 privacyLock: privacyLock,
                                 hapticsEnabled: hapticsEnabled,
                                 cloudSync: cloudSync,
                                 baseCurrency: baseCurrency,
                                 budgetByCategory: budgetByCategory,
                                 recurringEnabled: recurringEnabled,
                                 seeded: true)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        UserDefaults.standard.set(data, forKey: MoneyStore.key)
    }

    private static func load() -> StoreSnapshot {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snap = try? JSONDecoder().decode(StoreSnapshot.self, from: data) else {
            return StoreSnapshot()
        }
        return snap
    }

    // MARK: 备份与恢复

    func exportJSON() -> Data? {
        let snap = StoreSnapshot(txs: txs,
                                 budget: budget,
                                 notifyEnabled: notifyEnabled,
                                 privacyLock: privacyLock,
                                 hapticsEnabled: hapticsEnabled,
                                 cloudSync: cloudSync,
                                 baseCurrency: baseCurrency,
                                 budgetByCategory: budgetByCategory,
                                 recurringEnabled: recurringEnabled,
                                 seeded: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snap)
    }

    @discardableResult
    func importJSON(_ data: Data) -> Bool {
        guard let snap = try? JSONDecoder().decode(StoreSnapshot.self, from: data) else { return false }
        isLoading = true
        txs = snap.txs
        budget = snap.budget
        notifyEnabled = snap.notifyEnabled
        privacyLock = snap.privacyLock
        hapticsEnabled = snap.hapticsEnabled
        cloudSync = snap.cloudSync
        baseCurrency = snap.baseCurrency
        budgetByCategory = snap.budgetByCategory
        recurringEnabled = snap.recurringEnabled
        isLoading = false
        persist()
        return true
    }

    // MARK: 周期账单自动补录

    func processRecurring() {
        guard recurringEnabled else { return }
        let now = Date()
        var added: [Tx] = []
        for tx in txs where tx.recurrence != .none && !tx.autoPosted {
            var cursor = tx.date
            var steps = 0
            while steps < 36, let next = tx.recurrence.advance(cursor), next <= now {
                cursor = next
                let exists = txs.contains { $0.sourceID == tx.id && Calendar.current.isDate($0.date, inSameDayAs: next) }
                let pending = added.contains { $0.sourceID == tx.id && Calendar.current.isDate($0.date, inSameDayAs: next) }
                if !exists && !pending {
                    var copy = tx
                    copy.id = UUID()
                    copy.date = next
                    copy.sourceID = tx.id
                    copy.autoPosted = true
                    added.append(copy)
                }
                steps += 1
            }
        }
        if !added.isEmpty {
            isLoading = true
            txs.append(contentsOf: added)
            txs.sort { $0.date > $1.date }
            isLoading = false
            persist()
        }
    }

    var recurringRules: [Tx] {
        txs.filter { $0.recurrence != .none && $0.sourceID == nil }
    }

    // MARK: 区间筛选

    var monthTxs: [Tx] {
        let cal = Calendar.current
        return txs.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    var todayTxs: [Tx] {
        let cal = Calendar.current
        return txs.filter { cal.isDateInToday($0.date) }
    }

    func txs(in days: Int) -> [Tx] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) else { return [] }
        return txs.filter { $0.date >= start }
    }

    var yearTxs: [Tx] {
        let cal = Calendar.current
        return txs.filter { cal.isDate($0.date, equalTo: Date(), toGranularity: .year) }
    }

    // MARK: 汇总

    var income: Double { monthTxs.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCNY } }
    var expense: Double { monthTxs.filter { !$0.isIncome }.reduce(0) { $0 - $1.amountCNY } }
    var balance: Double { income - expense }

    var budgetLeft: Double { max(budget - expense, 0) }
    var budgetProgress: Double { budget <= 0 ? 0 : max(min(expense / budget, 1), 0) }
    var budgetRatio: Double { budget <= 0 ? 0 : expense / budget }

    var dailyAverage: Double {
        let cal = Calendar.current
        let day = cal.component(.day, from: Date())
        return day > 0 ? expense / Double(day) : 0
    }

    var biggestExpense: Tx? {
        monthTxs.filter { !$0.isIncome }.min { $0.amountCNY < $1.amountCNY }
    }

    var activeDays: Int {
        let cal = Calendar.current
        let days = Set(monthTxs.map { cal.startOfDay(for: $0.date) })
        return days.count
    }

    /// 环比：本月支出 vs 上月同期
    var monthOverMonth: Double? {
        let cal = Calendar.current
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return nil }
        let day = cal.component(.day, from: Date())
        let prev = txs.filter { tx in
            guard !tx.isIncome, cal.isDate(tx.date, equalTo: lastMonth, toGranularity: .month) else { return false }
            return cal.component(.day, from: tx.date) <= day
        }.reduce(0) { $0 - $1.amountCNY }
        guard prev > 0 else { return nil }
        return (expense - prev) / prev
    }

    /// 智能预算建议：近 30 日日均支出 推算整月，再留 8% 余量
    func budgetSuggestion() -> Double {
        let recent = txs(in: 30).filter { !$0.isIncome }
        guard !recent.isEmpty else { return budget }
        let calendar = Calendar.current
        let earliest = recent.map(\.date).min() ?? Date()
        let span = max(calendar.dateComponents([.day], from: earliest, to: Date()).day ?? 0, 1) + 1
        let avg = recent.reduce(0) { $0 - $1.amountCNY } / Double(span)
        let days = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        let raw = avg * Double(days) * 1.08
        return max((raw / 100).rounded() * 100, 500)
    }

    func categoryBudget(_ category: String) -> Double {
        budgetByCategory[category] ?? 0
    }

    func categorySpent(_ category: String) -> Double {
        monthTxs.filter { !$0.isIncome && $0.category == category }.reduce(0) { $0 - $1.amountCNY }
    }

    /// 预算吃紧的排行（已用 / 预算）
    var overBudgetCategories: [CategoryTotal] {
        budgetByCategory.compactMap { key, limit in
            guard limit > 0 else { return nil }
            let used = categorySpent(key)
            guard used > limit * 0.8 else { return nil }
            return CategoryTotal(label: key, value: used / limit)
        }
        .sorted { $0.value > $1.value }
    }

    // MARK: 图表序列

    func daySeries(_ days: Int) -> [DayPoint] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = days > 10 ? "M/d" : "E"
        var points: [DayPoint] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let total = txs.filter { !$0.isIncome && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 - $1.amountCNY }
            points.append(DayPoint(date: cal.startOfDay(for: day), label: formatter.string(from: day), value: total))
        }
        return points
    }

    func last7Days() -> [DayPoint] { daySeries(7) }

    func categoryTotals(days: Int = 0) -> [CategoryTotal] {
        let source = days > 0 ? txs(in: days) : monthTxs
        var bucket: [String: Double] = [:]
        for tx in source where !tx.isIncome {
            bucket[tx.category, default: 0] += -tx.amountCNY
        }
        return bucket.map { CategoryTotal(label: $0.key, value: $0.value) }
            .sorted { $0.value > $1.value }
    }

    func monthlySeries(months: Int = 6) -> [MonthPoint] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        var points: [MonthPoint] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let month = cal.date(byAdding: .month, value: -offset, to: Date()) else { continue }
            let list = txs.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            let inc = list.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCNY }
            let exp = list.filter { !$0.isIncome }.reduce(0) { $0 - $1.amountCNY }
            points.append(MonthPoint(label: formatter.string(from: month), income: inc, expense: exp))
        }
        return points
    }

    func groupedByDay(_ list: [Tx]) -> [DayGroup] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: list) { cal.startOfDay(for: $0.date) }
        return groups.map { day, items in
            let sorted = items.sorted { $0.date > $1.date }
            let exp = sorted.filter { !$0.isIncome }.reduce(0) { $0 - $1.amountCNY }
            let inc = sorted.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCNY }
            return DayGroup(day: day, txs: sorted, expense: exp, income: inc)
        }
        .sorted { $0.day > $1.day }
    }

    // MARK: 搜索筛选

    func filter(query: String, category: String?, month: Date?, onlyRecurring: Bool = false) -> [Tx] {
        let cal = Calendar.current
        let keyword = query.trimmingCharacters(in: .whitespaces)
        return txs.filter { tx in
            if let category, tx.category != category { return false }
            if let month, !cal.isDate(tx.date, equalTo: month, toGranularity: .month) { return false }
            if onlyRecurring && tx.recurrence == .none { return false }
            guard !keyword.isEmpty else { return true }
            let haystack = [tx.title, tx.merchant, tx.note, tx.location, tx.category, tx.tags.joined(separator: " ")]
                .joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(keyword)
        }
        .sorted { $0.date > $1.date }
    }

    var usedTags: [String] {
        Array(Set(txs.flatMap(\.tags))).sorted()
    }

    // MARK: 金额格式化

    func money(_ value: Double) -> String {
        let text = MoneyStore.decimalFormatter.string(from: NSNumber(value: abs(value))) ?? "0.00"
        return (value < 0 ? "- \u{00A5} " : "\u{00A5} ") + text
    }

    func compact(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 10000 {
            return sign + String(format: "%.1f", absValue / 10000) + "\u{4E07}"
        }
        return sign + String(format: "%.0f", absValue)
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
        let cal = Calendar.current
        func day(_ back: Int) -> Date {
            cal.date(byAdding: .day, value: -back, to: Date()) ?? Date()
        }
        return [
            Tx(title: "星巴克", amount: -32, category: "餐饮", date: day(0), merchant: "星巴克臻选", tags: ["咖啡"], location: "国贸店"),
            Tx(title: "地铁通勤", amount: -6, category: "交通", date: day(0), tags: ["通勤"]),
            Tx(title: "工资", amount: 12000, category: "工资", date: day(2), merchant: "公司", recurrence: .monthly),
            Tx(title: "超市采购", amount: -186.5, category: "购物", date: day(2), merchant: "盒马", tags: ["生活"]),
            Tx(title: "房租", amount: -2600, category: "居家", date: day(5), merchant: "房东", recurrence: .monthly),
            Tx(title: "电影票", amount: -88, category: "娱乐", date: day(1), tags: ["周末"]),
            Tx(title: "健身房", amount: -299, category: "娱乐", date: day(3), tags: ["健康"]),
            Tx(title: "感冒药", amount: -46.8, category: "医疗", date: day(4), merchant: "京东健康"),
            Tx(title: "设计课", amount: -199, category: "学习", date: day(6), tags: ["课程"]),
            Tx(title: "基金定投", amount: 320, category: "理财", date: day(7), merchant: "券商")
        ]
    }
}