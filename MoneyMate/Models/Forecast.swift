import Foundation

// MARK: - 宏观假设（本地静态常量，用户可改，不联网）

/// 前瞻推演用的宏观参数。全部内置为本地常量，用户可在「推演参数」里手动调整。
struct MacroAssumptions: Codable, Hashable {
    /// 通胀参考（%）
    var inflation: Double = 2.0
    /// 一年期基准利率参考（%）
    var benchmarkRate: Double = 1.5
    /// 房贷利率兜底（%），手工科目没填利率时用它
    var mortgageRate: Double = 3.5
    /// 稳健投资预期年化（%）
    var investReturn: Double = 5.0
    /// 生存跑道安全线（月）
    var safeRunwayMonths: Double = 6.0
    /// 现金流安全垫（月刚性支出）
    var safeCashFloorMonths: Double = 1.0

    static let standard = MacroAssumptions()
}

// MARK: - 未来重大收支事件

struct Milestone: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    /// 名称，如「年终奖」「买车首付」
    var title: String
    /// 正数 = 流入，负数 = 流出（人民币）
    var amount: Double
    var date: Date
    /// 每年重复（保费、学费一类）
    var repeatYearly: Bool = false

    var isInflow: Bool { amount >= 0 }
}

/// 规划相关数据的本地存储（与账本快照分开存，避免动存档格式）
final class PlanningBook: ObservableObject {
    static let shared = PlanningBook()

    @Published var milestones: [Milestone] = [] {
        didSet { saveMilestones() }
    }

    @Published var macro: MacroAssumptions = .standard {
        didSet { saveMacro() }
    }

    private let milestoneKey = "moneymate.planning.milestones"
    private let macroKey = "moneymate.planning.macro"

    init() {
        if let data = UserDefaults.standard.data(forKey: milestoneKey),
           let decoded = try? JSONDecoder().decode([Milestone].self, from: data) {
            milestones = decoded.sorted { $0.date < $1.date }
        }
        if let data = UserDefaults.standard.data(forKey: macroKey),
           let decoded = try? JSONDecoder().decode(MacroAssumptions.self, from: data) {
            macro = decoded
        }
    }

    func upsert(_ item: Milestone) {
        var list = milestones
        if let idx = list.firstIndex(where: { $0.id == item.id }) {
            list[idx] = item
        } else {
            list.append(item)
        }
        milestones = list.sorted { $0.date < $1.date }
    }

    func delete(_ id: String) {
        milestones = milestones.filter { $0.id != id }
    }

    private func saveMilestones() {
        if let data = try? JSONEncoder().encode(milestones) {
            UserDefaults.standard.set(data, forKey: milestoneKey)
        }
    }

    private func saveMacro() {
        if let data = try? JSONEncoder().encode(macro) {
            UserDefaults.standard.set(data, forKey: macroKey)
        }
    }
}

// MARK: - 流动性阶梯与生存跑道

enum LiquidityTier: String, CaseIterable, Identifiable {
    case fast, buffer, fixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: return "Tier-1 极速流动性"
        case .buffer: return "Tier-2 缓冲流动性"
        case .fixed: return "Tier-3 固化资产"
        }
    }

    /// 副标题：这一层能撑几天
    var subtitle: String {
        switch self {
        case .fast: return "现金 · 活期 · 零钱 · 货币基金"
        case .buffer: return "短债基金 · 可赎回理财"
        case .fixed: return "房产净值 · 车 · 封闭定存 · 受限股权"
        }
    }

    var advice: String {
        switch self {
        case .fast: return "失业、急病时唯一能马上用的钱"
        case .buffer: return "赎回要 1~3 天，是第二道防线"
        case .fixed: return "账面有钱，急用却卖不掉，不能当跑道"
        }
    }
}

struct LiquidityLine: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var value: Double
    var detail: String = ""
}

struct LiquidityLayer: Identifiable, Hashable {
    var id: String { tier.rawValue }
    var tier: LiquidityTier
    var lines: [LiquidityLine]
    var total: Double
}

/// 刚性支出明细项
struct CategoryAmount: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var amount: Double
}

struct RunwayReport {
    var layers: [LiquidityLayer] = []
    var rigidMonthly: Double = 0
    var hardMonthly: Double = 0
    var rigidBreakdown: [CategoryAmount] = []
    var monthsCovered: Int = 3
    var safeMonths: Double = 6

    var tier1: Double { value(at: 0) }
    var tier2: Double { value(at: 1) }
    var tier3: Double { value(at: 2) }
    var totalAssets: Double { layers.reduce(0) { $0 + $1.total } }

    private func value(at index: Int) -> Double {
        guard index < layers.count else { return 0 }
        return layers[index].total
    }

    /// 生存跑道（月）= Tier-1 ÷ 月均刚性支出
    var runwayMonths: Double {
        rigidMonthly <= 0 ? 99 : tier1 / rigidMonthly
    }

    /// 把 Tier-2 也算进来之后能撑多久
    var runwayWithBuffer: Double {
        rigidMonthly <= 0 ? 99 : (tier1 + tier2) / rigidMonthly
    }

    var progress: Double { min(runwayMonths / 12, 1) }

    var status: String {
        if rigidMonthly <= 0 { return "待补数据" }
        if runwayMonths < 3 { return "红灯 · 急迫" }
        if runwayMonths < safeMonths { return "黄灯 · 警戒" }
        if runwayMonths < 12 { return "安全" }
        return "充裕"
    }

    /// 0 待补 / 1 红 / 2 黄 / 3 安全 / 4 充裕
    var level: Int {
        if rigidMonthly <= 0 { return 0 }
        if runwayMonths < 3 { return 1 }
        if runwayMonths < safeMonths { return 2 }
        if runwayMonths < 12 { return 3 }
        return 4
    }

    var advice: String {
        switch level {
        case 0:
            return "还没有足够的支出记录，先记满一个月，跑道才估得准。"
        case 1:
            return "极速流动性只够撑 \(String(format: "%.1f", runwayMonths)) 个月，一旦断收入立刻见底。优先把结余搬进活期/货币基金，暂缓加杠杆和长期锁定。"
        case 2:
            return "跑道 \(String(format: "%.1f", runwayMonths)) 个月，还在警戒区。建议把安全线抬到 \(String(format: "%.0f", safeMonths)) 个月，差的部分可以每月定投货币基金补齐。"
        case 3:
            return "跑道 \(String(format: "%.1f", runwayMonths)) 个月，已经能应对常规波动。可以开始把增量资金往 Tier-2 和长期资产上放。"
        default:
            return "跑道 \(String(format: "%.1f", runwayMonths)) 个月，相当稳。注意别让钱全躺在活期被通胀啃，适度上移一部分到能生息的资产。"
        }
    }

    var tips: [String] {
        var list: [String] = []
        if totalAssets > 0, tier3 / totalAssets > 0.8 {
            list.append("固化资产占总资产 \(Int((tier3 / totalAssets) * 100))%，急用钱时卖不掉，账面富裕但跑道很短。")
        }
        if tier1 > 0, tier2 > tier1 * 2 {
            list.append("Tier-2 是 Tier-1 的两倍多：缓冲层很厚，但真出事的第一周还是要靠现金。")
        }
        if hardMonthly > 0, rigidMonthly > hardMonthly * 1.6 {
            list.append("刚性支出里有一块是可压缩的（交通/通讯），真到断收入时这部分还能砍。")
        }
        if level >= 2, runwayMonths < safeMonths + 1.5 {
            list.append("刚好压在安全线上：任何一笔大额长期支出都可能把跑道打穿，动手前先看「沙盒」推演。")
        }
        return list
    }
}

// MARK: - 标准普尔四象限

struct SpBucket: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var name: String
    var detail: String
    var target: Double
    var amount: Double
    var lines: [LiquidityLine]

    var targetLabel: String { "\(Int(target * 100))%" }
}

struct SpAllocation {
    var buckets: [SpBucket] = []
    var total: Double = 0
    var notes: [String] = []

    func percent(of key: String) -> Double {
        guard total > 0, let b = buckets.first(where: { $0.key == key }) else { return 0 }
        return b.amount / total
    }

    /// 当前占比 − 目标占比
    func deviation(of key: String) -> Double {
        guard let b = buckets.first(where: { $0.key == key }) else { return 0 }
        return percent(of: key) - b.target
    }

    /// 结构分：偏离越小越高
    var score: Int {
        guard total > 0 else { return 0 }
        let sum = buckets.reduce(0.0) { $0 + abs(deviation(of: $1.key)) }
        return max(0, min(100, Int(100 - sum * 100)))
    }

    var largest: SpBucket? {
        buckets.max { $0.amount < $1.amount }
    }

    var headline: String {
        guard total > 0, let big = largest else { return "先补上资产科目，四象限才有结构可看。" }
        return "最大一块是「\(big.name)」，占 \(Int((big.amount / total) * 100))%（基准 \(big.targetLabel)）。"
    }
}

// MARK: - 未来现金流沙盒

struct CashFlowPoint: Identifiable, Hashable {
    var id: Date { month }
    var month: Date
    var start: Double
    var inflow: Double
    var outflow: Double
    var end: Double
    var netWorth: Double

    /// 26/3 形式
    var label: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: month)
        return "\(String(format: "%02d", (comps.year ?? 2000) % 100))/\(comps.month ?? 1)"
    }

    var isNegative: Bool { end < 0 }
}

struct CashProjection {
    var points: [CashFlowPoint] = []
    var startCash: Double = 0
    var monthlySurplus: Double = 0
    var safeFloor: Double = 0
    var months: Int = 24

    var minBalance: Double { points.map(\.end).min() ?? startCash }
    var endBalance: Double { points.last?.end ?? startCash }
    var endNetWorth: Double { points.last?.netWorth ?? startCash }
    var ok: Bool { firstAlertIndex == nil }

    var firstAlertIndex: Int? {
        points.firstIndex { $0.end < safeFloor }
    }

    var alerts: [CashFlowPoint] {
        points.filter { $0.end < safeFloor }
    }

    var verdict: String {
        if points.isEmpty { return "还没有足够的数据推演。" }
        if let idx = firstAlertIndex {
            let p = points[idx]
            return "第 \(idx + 1) 个月（\(p.label)）现金流会掉到 \(money(p.end))，低于安全线 \(money(safeFloor))。建议提前 3 个月准备 \(money(max(safeFloor - p.end, 0))) 的储备。"
        }
        let lowest = points.min { $0.end < $1.end }
        if let lowest {
            return "未来 \(months) 个月最低点是 \(lowest.label) 的 \(money(lowest.end))，始终高于安全线，节奏可以照现在的来。"
        }
        return "未来 \(months) 个月都在安全线以上。"
    }
}

// MARK: - 提前还贷 vs 投资理财

struct CompassResult {
    var balance: Double = 0
    var rate: Double = 0
    var termMonths: Int = 0
    var idleCash: Double = 0
    var expectedReturn: Double = 0
    var equalInstallment: Bool = true

    var monthlyPayment: Double = 0
    var interestSaving: Double = 0
    var freedMonthly: Double = 0
    var payoffMonths: Int = 0

    var investFinal: Double = 0
    var investGain: Double = 0
    var investMonthlyOutlay: Double = 0

    /// 预期收益 − 房贷利率（个百分点）
    var spread: Double { expectedReturn - rate }

    /// 0~100，>50 偏向投资
    var investScore: Int {
        let base = 50 + max(-1, min(1, spread / 2)) * 35
        let penalty = 0.15 * 20 // 流动性折损
        return max(0, min(100, Int(base - penalty)))
    }

    var investWins: Bool { investScore >= 50 }

    var winner: String { investWins ? "拿去投资更划算" : "提前还贷更划算" }

    var advice: String {
        if investScore >= 50, spread >= 1.5 {
            return "利差有 \(String(format: "%.1f", spread)) 个百分点，复利站在投资这边。前提是这笔钱真能拿住 5 年以上，且投资标的不加杠杆。"
        }
        if investScore >= 50 {
            return "两边差不多（利差 \(String(format: "%.1f", spread)) 个百分点），投资收益还不确定，还贷是确定收益。想要睡得踏实就还贷，想要弹性就留一半现金。"
        }
        return "利差是负的（比房贷利率低 \(String(format: "%.1f", abs(spread))) 个百分点），稳赚的利息比贷款还便宜，优先提前还贷。注意还进去的钱取不出来，先确认跑道 ≥ 6 个月。"
    }
}

// MARK: - 负债

struct DebtItem: Identifiable, Hashable {
    var id: String
    var name: String
    var balance: Double
    var rate: Double
    var minPayment: Double
    var source: String      // manual / account
    var accountID: UUID?
    var termMonths: Int
    var equalInstallment: Bool = true

    /// 只按最低还款时还要还多少个月
    var estimatedMonths: Int {
        guard balance > 0, minPayment > 0 else { return 0 }
        let r = rate / 100 / 12
        if r <= 0 { return Int((balance / minPayment).rounded(.up)) }
        let ratio = balance * r / minPayment
        if ratio >= 1 { return 600 }
        return min(600, Int((-log(1 - ratio) / log(1 + r)).rounded(.up)))
    }
}

struct AvalancheStep: Identifiable, Hashable {
    var id: Int { order }
    var order: Int
    var name: String
    var rate: Double
    var balance: Double
    var months: Int
    var interest: Double
    var monthlyPayment: Double
}

struct AvalanchePlan {
    var steps: [AvalancheStep] = []
    var baselineInterest: Double = 0
    var plannedInterest: Double = 0
    var baselineMonths: Int = 0
    var plannedMonths: Int = 0
    var extraMonthly: Double = 0

    var savedInterest: Double { max(baselineInterest - plannedInterest, 0) }
    var savedMonths: Int { max(baselineMonths - plannedMonths, 0) }

    var headline: String {
        guard let first = steps.first else { return "没有负债，雪崩法无用武之地。" }
        if savedInterest < 1 {
            return "额外还 \(money(extraMonthly))/月 的效果有限，先把这 \(money(extraMonthly)) 存成应急金更实在。"
        }
        return "先把钱砸向「\(first.name)」（年化 \(String(format: "%.1f", first.rate))%），能提前 \(savedMonths) 个月清完，少付 \(money(savedInterest)) 利息。"
    }
}

struct StressScenario: Identifiable, Hashable {
    var id: String { label }
    var label: String
    var incomeFactor: Double
    var rateShock: Double
    var monthlyIncome: Double
    var monthlyDebt: Double
    var surplus: Double
    var monthsToDefault: Double
    var dsr: Double

    var survives: Bool { monthsToDefault >= 99 }
    var stable: Bool { surplus >= 0 }
}

struct StressReport {
    var monthlyIncome: Double = 0
    var monthlyDebt: Double = 0
    var dsr: Double = 0
    var tier1: Double = 0
    var hardMonthly: Double = 0
    var scenarios: [StressScenario] = []

    var dsrStatus: String {
        if monthlyIncome <= 0 { return "待补数据" }
        if dsr <= 0.35 { return "健康" }
        if dsr <= 0.40 { return "接近警戒" }
        if dsr <= 0.50 { return "偏重" }
        return "高危"
    }
}

// MARK: - 引擎（纯本地、无网络、毫秒级）

enum PlanningEngine {
    static let rigidCategories: Set<String> = ["居住", "餐饮", "交通", "通讯", "医疗"]
    static let optionalCategories: Set<String> = ["购物", "娱乐", "学习", "人情", "宠物"]

    private static var cal: Calendar { Calendar.current }

    // MARK: 支出基线

    struct RigidExpense {
        var monthly: Double = 0
        var hard: Double = 0
        var breakdown: [CategoryAmount] = []
        var months: Int = 3
    }

    /// 近 N 个月刚性必要支出（剔除可选/冲动消费）
    static func rigidExpense(_ txs: [Tx], months: Int = 3, end: Date = Date()) -> RigidExpense {
        let anchor = cal.startOfDay(for: end)
        guard let start = cal.date(byAdding: .month, value: -months, to: anchor) else {
            return RigidExpense()
        }
        let window = txs.filter { $0.kind == .expense && $0.date > start && $0.date <= endOfDay(anchor) }
        var rigid = 0.0
        var hard = 0.0
        var map: [String: Double] = [:]
        for tx in window {
            let value = abs(tx.amountCNY)
            let root = tx.category
            guard rigidCategories.contains(root) else { continue }
            rigid += value
            map[root, default: 0] += value
            if root == "居住" || root == "餐饮" || root == "医疗" { hard += value }
        }
        var divisor = months
        if let earliest = window.map({ $0.date }).min() {
            let span = (cal.dateComponents([.month], from: cal.startOfDay(for: earliest), to: anchor).month ?? months) + 1
            if span >= 1, span < months { divisor = span }
        }
        let breakdown = map
            .map { CategoryAmount(name: $0.key, amount: $0.value / Double(max(divisor, 1))) }
            .sorted { $0.amount > $1.amount }
        return RigidExpense(
            monthly: rigid / Double(max(divisor, 1)),
            hard: hard / Double(max(divisor, 1)),
            breakdown: breakdown,
            months: divisor
        )
    }

    static func averageIncome(_ txs: [Tx], months: Int = 3, end: Date = Date()) -> Double {
        average(txs, months: months, end: end, income: true)
    }

    static func averageExpense(_ txs: [Tx], months: Int = 3, end: Date = Date()) -> Double {
        average(txs, months: months, end: end, income: false)
    }

    private static func average(_ txs: [Tx], months: Int, end: Date, income: Bool) -> Double {
        let anchor = cal.startOfDay(for: end)
        guard let start = cal.date(byAdding: .month, value: -months, to: anchor) else { return 0 }
        let window = txs.filter { $0.date > start && $0.date <= endOfDay(anchor) }
        let total = window.reduce(0.0) { sum, tx in
            if income { return tx.kind == .income ? sum + abs(tx.amountCNY) : sum }
            return tx.kind == .expense ? sum + abs(tx.amountCNY) : sum
        }
        return total / Double(max(months, 1))
    }

    static func defaultMonthlySurplus(_ txs: [Tx]) -> Double {
        averageIncome(txs) - averageExpense(txs)
    }

    private static func endOfDay(_ day: Date) -> Date {
        cal.date(byAdding: DateComponents(day: 1, second: -1), to: cal.startOfDay(for: day)) ?? day
    }

    // MARK: 分层 / 象限归属

    private static func matches(_ name: String, _ words: [String]) -> Bool {
        words.contains { name.contains($0) }
    }

    private static let fixedWords = ["定期", "封闭", "定开", "受限", "股权", "房产", "厂房", "车位"]
    private static let fastWords = ["货币", "余额宝", "零钱", "活期", "现金"]
    private static let bufferWords = ["短债", "债基", "理财", "逆回购", "应急", "稳健"]

    static func tier(of account: Account) -> LiquidityTier {
        if account.kind.isLiability { return .fixed }
        if matches(account.name, fixedWords) { return .fixed }
        switch account.kind {
        case .cash, .debit, .wallet:
            return .fast
        case .investment:
            if matches(account.name, fastWords) { return .fast }
            if matches(account.name, bufferWords) { return .buffer }
            return .buffer
        case .receivable:
            return .buffer
        default:
            return .buffer
        }
    }

    static func tier(of item: ManualItem) -> LiquidityTier {
        if item.isLiability { return .fixed }
        if matches(item.name, fastWords) { return .fast }
        if matches(item.name, bufferWords) { return .buffer }
        return .fixed
    }

    static func buildRunway(
        accounts: [Account],
        balances: [UUID: Double],
        items: [ManualItem],
        txs: [Tx],
        macro: MacroAssumptions,
        rigidOverride: Double? = nil
    ) -> RunwayReport {
        let rigid = rigidExpense(txs)
        var lines: [LiquidityTier: [LiquidityLine]] = [:]
        for account in accounts where !account.archived {
            guard !account.kind.isLiability else { continue }
            let value = balances[account.id] ?? account.initialBalance
            guard value > 0 else { continue }
            let tier = tier(of: account)
            lines[tier, default: []].append(
                LiquidityLine(name: account.displayName, value: value, detail: account.kind.title)
            )
        }
        for item in items where !item.isLiability {
            guard item.value > 0 else { continue }
            let tier = tier(of: item)
            lines[tier, default: []].append(
                LiquidityLine(name: item.name, value: item.value, detail: item.kind.label)
            )
        }
        let layers: [LiquidityLayer] = LiquidityTier.allCases.map { tier in
            let list = (lines[tier] ?? []).sorted { $0.value > $1.value }
            return LiquidityLayer(tier: tier, lines: list, total: list.reduce(0) { $0 + $1.value })
        }
        return RunwayReport(
            layers: layers,
            rigidMonthly: rigidOverride ?? rigid.monthly,
            hardMonthly: rigid.hard,
            rigidBreakdown: rigid.breakdown,
            monthsCovered: rigid.months,
            safeMonths: macro.safeRunwayMonths
        )
    }

    static let spTargets: [(key: String, name: String, detail: String, target: Double)] = [
        ("spend", "要花的钱", "3~6 个月日常开支，放活期/货币基金", 0.10),
        ("protect", "保命的钱", "重疾/医疗/寿险与应急缓冲，专款专用", 0.20),
        ("grow", "生钱的钱", "股票、基金、黄金、高波动资产", 0.30),
        ("safe", "保本升值的钱", "国债、大额存单、养老金、房产净值", 0.40)
    ]

    static func bucket(of account: Account) -> String {
        if account.kind.isLiability { return "safe" }
        if matches(account.name, ["股", "基金", "黄金", "ETF", "币", "权益"]) { return "grow" }
        if matches(account.name, ["债", "存", "理财", "稳", "货基"]) { return "safe" }
        switch account.kind {
        case .cash, .debit, .wallet: return "spend"
        case .investment: return "grow"
        case .receivable: return "protect"
        default: return "spend"
        }
    }

    static func bucket(of item: ManualItem) -> String {
        if item.isLiability { return "safe" }
        if matches(item.name, ["股", "基金", "黄金", "ETF", "币", "权益"]) { return "grow" }
        if matches(item.name, ["债", "存", "理财", "稳", "货基", "公积金", "年金", "房产", "房"]) { return "safe" }
        if matches(item.name, fastWords) { return "spend" }
        if matches(item.name, bufferWords) { return "protect" }
        return "safe"
    }

    static func buildAllocation(accounts: [Account], balances: [UUID: Double], items: [ManualItem]) -> SpAllocation {
        var totals: [String: Double] = [:]
        var lines: [String: [LiquidityLine]] = [:]
        var debts: [LiquidityLine] = []

        for account in accounts where !account.archived {
            let value = balances[account.id] ?? account.initialBalance
            if account.kind.isLiability {
                if value < 0 {
                    debts.append(LiquidityLine(name: account.displayName, value: -value, detail: "信用卡/欠款"))
                }
                continue
            }
            guard value > 0 else { continue }
            let key = bucket(of: account)
            totals[key, default: 0] += value
            lines[key, default: []].append(
                LiquidityLine(name: account.displayName, value: value, detail: account.kind.title)
            )
        }
        for item in items {
            if item.isLiability {
                if item.value > 0 {
                    debts.append(LiquidityLine(name: item.name, value: item.value, detail: item.kind.label))
                }
                continue
            }
            guard item.value > 0 else { continue }
            let key = bucket(of: item)
            totals[key, default: 0] += item.value
            lines[key, default: []].append(
                LiquidityLine(name: item.name, value: item.value, detail: item.kind.label)
            )
        }

        var total = totals.values.reduce(0, +)
        // 负债从「保本升值的钱」等比扣减，不足再扣生钱的钱、要花的钱
        var remainingDebt = debts.reduce(0) { $0 + $1.value }
        for key in ["safe", "grow", "spend"] {
            guard remainingDebt > 0 else { break }
            let available = totals[key] ?? 0
            guard available > 0 else { continue }
            let cut = min(available, remainingDebt)
            totals[key] = available - cut
            remainingDebt -= cut
            lines[key, default: []].append(
                LiquidityLine(name: "已扣负债", value: -cut, detail: "负债优先从本象限扣减")
            )
        }
        if remainingDebt > 0 {
            total = 0
        }
        total = totals.values.reduce(0, +)

        let buckets = spTargets.map { target -> SpBucket in
            let amount = totals[target.key] ?? 0
            return SpBucket(
                key: target.key,
                name: target.name,
                detail: target.detail,
                target: target.target,
                amount: amount,
                lines: (lines[target.key] ?? []).sorted { $0.value > $1.value }
            )
        }
        var notes: [String] = []
        if total > 0 {
            for bucket in buckets {
                let share = bucket.amount / total
                let diff = share - bucket.target
                if diff > 0.05 {
                    notes.append("「\(bucket.name)」占 \(Int(share * 100))%，比基准高 \(Int(diff * 100)) 个百分点。新增结余先别往这里放。")
                } else if diff < -0.05 {
                    notes.append("「\(bucket.name)」占 \(Int(share * 100))%，比基准低 \(Int(-diff * 100)) 个百分点。后续结余可以优先补这一块。")
                }
            }
        }
        if notes.isEmpty {
            notes.append("四块结构都在目标 ±5 个百分点内，保持现在的定投节奏即可，不必为了凑比例卖出。")
        }
        return SpAllocation(buckets: buckets, total: total, notes: notes)
    }

    // MARK: 现金流沙盒

    static func projectCashFlow(
        currentCash: Double,
        monthlySurplus: Double,
        milestones: [Milestone],
        months: Int,
        safeFloor: Double,
        netWorth: Double,
        investedAssets: Double,
        macro: MacroAssumptions,
        from date: Date = Date()
    ) -> CashProjection {
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
        let monthlyReturn = macro.investReturn / 100 / 12
        var cash = currentCash
        var equity = investedAssets
        var points: [CashFlowPoint] = []
        for index in 1...max(months, 1) {
            guard let monthDate = cal.date(byAdding: .month, value: index, to: startOfMonth) else { break }
            var inflow = 0.0
            var outflow = 0.0
            for milestone in milestones {
                let sameMonth = cal.isDate(milestone.date, equalTo: monthDate, toGranularity: .month)
                let sameMonthOfYear = cal.component(.month, from: milestone.date) == cal.component(.month, from: monthDate)
                    && milestone.repeatYearly
                    && milestone.date < monthDate
                guard sameMonth || sameMonthOfYear else { continue }
                if milestone.amount >= 0 { inflow += milestone.amount } else { outflow += -milestone.amount }
            }
            let start = cash
            equity *= (1 + monthlyReturn)
            cash += monthlySurplus + inflow - outflow
            points.append(
                CashFlowPoint(
                    month: monthDate,
                    start: start,
                    inflow: inflow,
                    outflow: outflow,
                    end: cash,
                    netWorth: cash + equity
                )
            )
        }
        return CashProjection(
            points: points,
            startCash: currentCash,
            monthlySurplus: monthlySurplus,
            safeFloor: safeFloor,
            months: max(months, 1)
        )
    }

    // MARK: 贷款数学

    static func monthlyPayment(principal: Double, annualRate: Double, months: Int, equalInstallment: Bool = true) -> Double {
        guard principal > 0, months > 0 else { return 0 }
        let r = annualRate / 100 / 12
        if r <= 0 { return principal / Double(months) }
        if equalInstallment {
            let factor = pow(1 + r, Double(months))
            return principal * r * factor / (factor - 1)
        }
        return principal / Double(months) + principal * r
    }

    static func totalInterest(principal: Double, annualRate: Double, months: Int, equalInstallment: Bool = true) -> Double {
        guard principal > 0, months > 0 else { return 0 }
        let r = annualRate / 100 / 12
        let pay = monthlyPayment(principal: principal, annualRate: annualRate, months: months, equalInstallment: equalInstallment)
        if equalInstallment { return pay * Double(months) - principal }
        return principal * r * Double(months + 1) / 2
    }

    static func mortgageCompass(
        balance: Double,
        rate: Double,
        termMonths: Int,
        equalInstallment: Bool,
        idleCash: Double,
        expectedReturn: Double
    ) -> CompassResult {
        let months = max(termMonths, 1)
        let cash = min(max(idleCash, 0), max(balance, 0))
        let oldPay = monthlyPayment(principal: balance, annualRate: rate, months: months, equalInstallment: equalInstallment)
        let remaining = max(balance - cash, 0)
        let newPay = monthlyPayment(principal: remaining, annualRate: rate, months: months, equalInstallment: equalInstallment)
        let interestSaving = max(
            totalInterest(principal: balance, annualRate: rate, months: months, equalInstallment: equalInstallment)
                - totalInterest(principal: remaining, annualRate: rate, months: months, equalInstallment: equalInstallment),
            0
        )
        let freed = max(oldPay - newPay, 0)
        let r = expectedReturn / 100 / 12
        let factor = r <= 0 ? 1 : pow(1 + r, Double(months))
        let lump = cash * factor
        let dca = r <= 0 ? freed * Double(months) : freed * (factor - 1) / r
        let final = lump + dca
        let contributed = cash + freed * Double(months)
        return CompassResult(
            balance: balance,
            rate: rate,
            termMonths: months,
            idleCash: idleCash,
            expectedReturn: expectedReturn,
            equalInstallment: equalInstallment,
            monthlyPayment: oldPay,
            interestSaving: interestSaving,
            freedMonthly: freed,
            payoffMonths: months,
            investFinal: final,
            investGain: final - contributed,
            investMonthlyOutlay: freed
        )
    }

    // MARK: 负债雪崩 / 压力测试

    static func debts(accounts: [Account], balances: [UUID: Double], items: [ManualItem], macro: MacroAssumptions) -> [DebtItem] {
        var list: [DebtItem] = []
        for account in accounts where !account.archived {
            guard account.kind == .credit else { continue }
            let value = balances[account.id] ?? account.initialBalance
            let used = max(-value, 0)
            guard used > 1 else { continue }
            list.append(
                DebtItem(
                    id: account.id.uuidString,
                    name: account.displayName,
                    balance: used,
                    rate: 18.25,
                    minPayment: max(used * 0.1, 50),
                    source: "account",
                    accountID: account.id,
                    termMonths: 12,
                    equalInstallment: true
                )
            )
        }
        for item in items where item.isLiability {
            guard item.value > 1 else { continue }
            var rate = item.rate ?? 0
            if rate <= 0 {
                switch item.kind {
                case .mortgage: rate = macro.mortgageRate
                case .carLoan: rate = macro.mortgageRate + 1.5
                case .consumerLoan: rate = 12.0
                default: rate = 6.0
                }
            }
            var months = item.termMonths ?? 0
            if months <= 0 { months = 60 }
            let pay = monthlyPayment(
                principal: item.value,
                annualRate: rate,
                months: months,
                equalInstallment: item.equalInstallment ?? true
            )
            list.append(
                DebtItem(
                    id: item.id,
                    name: item.name,
                    balance: item.value,
                    rate: rate,
                    minPayment: max(pay, item.value * 0.005),
                    source: "manual",
                    accountID: nil,
                    termMonths: months,
                    equalInstallment: item.equalInstallment ?? true
                )
            )
        }
        return list.sorted { $0.rate > $1.rate }
    }

    static func avalanche(_ debts: [DebtItem], extraMonthly: Double) -> AvalanchePlan {
        guard !debts.isEmpty else { return AvalanchePlan(extraMonthly: extraMonthly) }
        let order = debts.sorted { $0.rate > $1.rate }

        func simulate(extra: Double) -> (interest: Double, months: Int, perDebt: [String: (Double, Int)]) {
            var remaining = order.map { $0.balance }
            var totalInterest = 0.0
            var months = 0
            var paid: [String: Double] = [:]
            var monthsUsed: [String: Int] = [:]
            while remaining.contains(where: { $0 > 1 }), months < 600 {
                months += 1
                var spare = extra
                for i in order.indices where remaining[i] > 1 {
                    let monthlyRate = order[i].rate / 100 / 12
                    let interest = remaining[i] * monthlyRate
                    totalInterest += interest
                    let payment = min(order[i].minPayment, remaining[i] + interest)
                    remaining[i] = max(remaining[i] + interest - payment, 0)
                    paid[order[i].id, default: 0] += payment
                    monthsUsed[order[i].id] = months
                    // 月供里的富余（快还完时）回流到 spare
                    spare += max(order[i].minPayment - payment, 0)
                }
                for i in order.indices where remaining[i] > 1 {
                    guard spare > 0 else { break }
                    let pay = min(spare, remaining[i])
                    remaining[i] -= pay
                    spare -= pay
                    paid[order[i].id, default: 0] += pay
                    monthsUsed[order[i].id] = months
                }
            }
            let perDebt = Dictionary(uniqueKeysWithValues: order.map {
                ($0.id, (paid[$0.id] ?? 0, monthsUsed[$0.id] ?? months))
            })
            return (totalInterest, months, perDebt)
        }

        let baseline = simulate(extra: 0)
        let planned = simulate(extra: max(extraMonthly, 0))
        let steps = order.enumerated().map { index, debt -> AvalancheStep in
            let info = planned.perDebt[debt.id] ?? (0, 0)
            let months = info.1 > 0 ? info.1 : debt.estimatedMonths
            let interest = max(info.0 - debt.balance, 0) * 0.35
            return AvalancheStep(
                order: index + 1,
                name: debt.name,
                rate: debt.rate,
                balance: debt.balance,
                months: months,
                interest: interest,
                monthlyPayment: debt.minPayment
            )
        }
        return AvalanchePlan(
            steps: steps,
            baselineInterest: baseline.interest,
            plannedInterest: planned.interest,
            baselineMonths: baseline.months,
            plannedMonths: planned.months,
            extraMonthly: max(extraMonthly, 0)
        )
    }

    static func scenario(
        label: String,
        monthlyIncome: Double,
        factor: Double,
        rateShock: Double,
        debts: [DebtItem],
        tier1: Double,
        rigidMonthly: Double,
        rigidOverride: Double? = nil
    ) -> StressScenario {
        var debt = 0.0
        for item in debts {
            if item.source == "account" {
                debt += item.minPayment * (1 + rateShock / 10)
            } else {
                debt += monthlyPayment(
                    principal: item.balance,
                    annualRate: item.rate + rateShock,
                    months: max(item.termMonths, 1),
                    equalInstallment: item.equalInstallment
                )
            }
        }
        let income = monthlyIncome * factor
        let rigid = rigidOverride ?? rigidMonthly
        let surplus = income - rigid - debt
        let monthsToDefault = surplus >= 0 ? 99 : max(0, min(99, tier1 / -surplus))
        return StressScenario(
            label: label,
            incomeFactor: factor,
            rateShock: rateShock,
            monthlyIncome: income,
            monthlyDebt: debt,
            surplus: surplus,
            monthsToDefault: monthsToDefault,
            dsr: income > 0 ? debt / income : 0
        )
    }

    static func stressTest(
        monthlyIncome: Double,
        debts: [DebtItem],
        tier1: Double,
        rigidMonthly: Double,
        factor: Double,
        rateShock: Double
    ) -> StressReport {
        let base = scenario(
            label: "基准", monthlyIncome: monthlyIncome, factor: 1, rateShock: 0,
            debts: debts, tier1: tier1, rigidMonthly: rigidMonthly
        )
        let list: [StressScenario] = [
            base,
            scenario(label: "收入 -20%", monthlyIncome: monthlyIncome, factor: 0.8, rateShock: 0,
                     debts: debts, tier1: tier1, rigidMonthly: rigidMonthly),
            scenario(label: "收入 -50%", monthlyIncome: monthlyIncome, factor: 0.5, rateShock: 0,
                     debts: debts, tier1: tier1, rigidMonthly: rigidMonthly),
            scenario(label: "降薪 20% + 利率 +1%", monthlyIncome: monthlyIncome, factor: 0.8, rateShock: 1,
                     debts: debts, tier1: tier1, rigidMonthly: rigidMonthly),
            scenario(label: "失业断收入", monthlyIncome: monthlyIncome, factor: 0, rateShock: 0,
                     debts: debts, tier1: tier1, rigidMonthly: rigidMonthly)
        ]
        return StressReport(
            monthlyIncome: monthlyIncome,
            monthlyDebt: base.monthlyDebt,
            dsr: base.dsr,
            tier1: tier1,
            hardMonthly: rigidMonthly,
            scenarios: list
        )
    }

    static func investedAssets(of allocation: SpAllocation) -> Double {
        allocation.buckets
            .filter { $0.key == "grow" || $0.key == "safe" }
            .reduce(0) { $0 + $1.amount }
    }
}

// MARK: - 小工具

/// 全局简写：把金额写成 ¥1.2 万
func money(_ value: Double) -> String {
    let sign = value < 0 ? "-" : ""
    let v = abs(value)
    if v >= 100_000_000 { return sign + "¥" + String(format: "%.2f", v / 100_000_000) + "亿" }
    if v >= 10_000 { return sign + "¥" + String(format: "%.1f", v / 10_000) + "万" }
    return sign + "¥" + String(format: "%.0f", v)
}
