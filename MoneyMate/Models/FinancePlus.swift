import Foundation
import SwiftUI

// MARK: - 保单台账

struct InsurancePolicy: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var kind: String = InsurancePolicy.life
    var name: String = ""
    var coverage: Double = 0        // 保额
    var premium: Double = 0         // 年保费
    var payYears: Int = 0           // 缴费年限（0 = 未填）
    var cashValue: Double = 0       // 现金价值
    var holder: String = ""         // 被保人
    var note: String = ""

    static let life = "life"
    static let critical = "critical"
    static let medical = "medical"
    static let accident = "accident"
    static let annuity = "annuity"

    static let kinds: [String] = [life, critical, medical, accident, annuity]

    static func label(_ kind: String) -> String {
        switch kind {
        case life: return "寿险"
        case critical: return "重疾险"
        case medical: return "医疗险"
        case accident: return "意外险"
        case annuity: return "年金 / 养老"
        default: return "其他"
        }
    }

    static func icon(_ kind: String) -> String {
        switch kind {
        case life: return "figure.stand"
        case critical: return "heart.text.square"
        case medical: return "cross.case"
        case accident: return "bolt.heart"
        case annuity: return "calendar.badge.clock"
        default: return "doc.text"
        }
    }

    var isProtection: Bool { kind == InsurancePolicy.life || kind == InsurancePolicy.critical || kind == InsurancePolicy.medical || kind == InsurancePolicy.accident }
}

// MARK: - 税务档案

struct TaxProfile: Codable, Hashable {
    var monthlyIncome: Double = 0
    var marginalRate: Double = 0.10
    var children: Int = 0
    var childCare: Bool = true
    var elderlySupport: Bool = false
    var mortgageInterest: Bool = false
    var housingRent: Bool = false
    var rentTier: Int = 1          // 1 = 一线 1500，2 = 二线 1100，3 = 其他 800
    var continuingEducation: Bool = false
    var seriousIllness: Double = 0 // 年度自付医疗
    var pensionContributed: Double = 0
    var annualBonus: Double = 0
    var bonusBySeparateTax: Bool = true

    static let pensionLimit: Double = 12000

    static let standard = TaxProfile()
}

// MARK: - 目标

struct MoneyGoal: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var target: Double = 0
    var dueDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var saved: Double = 0
    var monthly: Double = 0
    var annualReturn: Double = 3.0
    var priority: Int = 1
    var note: String = ""
}

// MARK: - 情景

struct FinanceScenario: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String = ""
    var incomeFactor: Double = 1.0
    var lumpSum: Double = 0
    var extraMonthly: Double = 0
    var months: Int = 12
    var note: String = ""
}

// MARK: - 净资产快照

struct NetWorthSnapshot: Identifiable, Codable, Hashable {
    var id: String { month }
    var month: String        // yyyy-MM
    var assets: Double
    var liabilities: Double
    var manual: Double
    var capturedAt: Date = Date()

    var net: Double { assets - liabilities + manual }
}

// MARK: - 结果模型

struct ProtectionGap {
    var needByDemand: Double = 0
    var needByIncomeMultiple: Double = 0
    var existingCoverage: Double = 0
    var debts: Double = 0
    var rigidYearly: Double = 0
    var liquidAssets: Double = 0
    var premiumYearly: Double = 0
    var annualIncome: Double = 0
    var criticalCoverage: Double = 0
    var policies: [InsurancePolicy] = []

    /// 建议保额：两种算法取大，再打八折（避免一上来就吓人）
    var suggested: Double { max(needByDemand, needByIncomeMultiple) * 0.8 }
    var gap: Double { max(suggested - existingCoverage, 0) }
    var coverageRatio: Double { suggested <= 0 ? 1 : min(existingCoverage / suggested, 1.5) }
    var premiumRatio: Double { annualIncome <= 0 ? 0 : premiumYearly / annualIncome }
    var criticalSuggested: Double { annualIncome * 4 }
    var criticalGap: Double { max(criticalSuggested - criticalCoverage, 0) }

    /// 0 = 没有数据，1 很危险，2 缺口大，3 基本够，4 充足
    var level: Int {
        if annualIncome <= 0 && policies.isEmpty { return 0 }
        if existingCoverage <= 0 { return 1 }
        if coverageRatio < 0.4 { return 1 }
        if coverageRatio < 0.7 { return 2 }
        if coverageRatio < 1.0 { return 3 }
        return 4
    }

    var status: String {
        switch level {
        case 0: return "待登记"
        case 1: return "保障明显不足"
        case 2: return "缺口偏大"
        case 3: return "基本够用"
        default: return "保障充足"
        }
    }
}

struct TaxCheckLine: Identifiable {
    var id: String { name }
    var name: String
    var detail: String
    var yearlyDeduction: Double
    var saving: Double
    var claimed: Bool
}

struct TaxReport {
    var lines: [TaxCheckLine] = []
    var totalSaving: Double = 0
    var pensionSaving: Double = 0
    var missingSaving: Double = 0
    var bonusTip: String = ""
    var bonusBest: Double = 0
    var bonusDiff: Double = 0
    var rate: Double = 0.10
}

struct GoalPlan: Identifiable {
    var id: String { goal.id }
    var goal: MoneyGoal
    var monthsLeft: Int
    var requiredMonthly: Double
    var projected: Double
    var probability: Double     // 0~1
    var progress: Double        // 已存 / 目标

    var onTrack: Bool { projected >= goal.target }
    var gap: Double { max(goal.target - projected, 0) }
}

struct ScenarioOutcome: Identifiable {
    var id: String { scenario.id }
    var scenario: FinanceScenario
    var lowestCash: Double
    var breakMonth: Int         // 0 = 没破线
    var endCash: Double
    var safeFloor: Double

    var ok: Bool { breakMonth == 0 }
}

struct AttributionReport {
    var month: String = ""
    var netNow: Double = 0
    var netBefore: Double = 0
    var saving: Double = 0
    var investment: Double = 0
    var repayment: Double = 0
    var revalue: Double = 0
    var income: Double = 0
    var expense: Double = 0

    var delta: Double { netNow - netBefore }
}

// MARK: - 本地存档

final class FinanceBook: ObservableObject {
    static let shared = FinanceBook()

    @Published var policies: [InsurancePolicy] {
        didSet { save(policies, key: "moneymate.finance.policies") }
    }
    @Published var tax: TaxProfile {
        didSet { if let data = try? JSONEncoder().encode(tax) { UserDefaults.standard.set(data, forKey: "moneymate.finance.tax") } }
    }
    @Published var goals: [MoneyGoal] {
        didSet { save(goals, key: "moneymate.finance.goals") }
    }
    @Published var scenarios: [FinanceScenario] {
        didSet { save(scenarios, key: "moneymate.finance.scenarios") }
    }
    @Published var snapshots: [NetWorthSnapshot] {
        didSet { save(snapshots, key: "moneymate.finance.snapshots") }
    }

    private init() {
        let d = UserDefaults.standard
        policies = FinanceBook.load([InsurancePolicy].self, key: "moneymate.finance.policies") ?? []
        tax = d.data(forKey: "moneymate.finance.tax").flatMap { try? JSONDecoder().decode(TaxProfile.self, from: $0) } ?? .standard
        goals = FinanceBook.load([MoneyGoal].self, key: "moneymate.finance.goals") ?? []
        let saved = FinanceBook.load([FinanceScenario].self, key: "moneymate.finance.scenarios") ?? []
        scenarios = saved.isEmpty ? FinanceEngine.presetScenarios() : saved
        snapshots = FinanceBook.load([NetWorthSnapshot].self, key: "moneymate.finance.snapshots") ?? []
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func upsertPolicy(_ item: InsurancePolicy) {
        var next = policies
        if let i = next.firstIndex(where: { $0.id == item.id }) { next[i] = item } else { next.append(item) }
        policies = next
    }

    func deletePolicy(_ id: String) { policies = policies.filter { $0.id != id } }

    func upsertGoal(_ item: MoneyGoal) {
        var next = goals
        if let i = next.firstIndex(where: { $0.id == item.id }) { next[i] = item } else { next.append(item) }
        next.sort { $0.priority < $1.priority }
        goals = next
    }

    func deleteGoal(_ id: String) { goals = goals.filter { $0.id != id } }

    func upsertScenario(_ item: FinanceScenario) {
        var next = scenarios
        if let i = next.firstIndex(where: { $0.id == item.id }) { next[i] = item } else { next.append(item) }
        scenarios = next
    }

    func deleteScenario(_ id: String) { scenarios = scenarios.filter { $0.id != id } }

    var latestSnapshot: NetWorthSnapshot? { snapshots.last }
    var previousSnapshot: NetWorthSnapshot? { snapshots.count >= 2 ? snapshots[snapshots.count - 2] : nil }

    /// 记录本月快照（同月覆盖，最多 36 条）
    func captureSnapshot(assets: Double, liabilities: Double, manual: Double, at date: Date = Date()) {
        let key = FinanceEngine.monthKey(date)
        var next = snapshots.filter { $0.month != key }
        next.append(NetWorthSnapshot(month: key, assets: assets, liabilities: liabilities, manual: manual, capturedAt: Date()))
        next.sort { $0.month < $1.month }
        if next.count > 36 { next = Array(next.suffix(36)) }
        snapshots = next
    }
}

// MARK: - 固定种子随机数（结果可复现）

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - 引擎

enum FinanceEngine {
    static let rigidRoots: Set<String> = ["居住", "餐饮", "交通", "通讯", "医疗"]
    static let optionalRoots: Set<String> = ["购物", "娱乐", "学习", "人情", "宠物"]

    static func monthKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    static func rootOf(_ category: String) -> String {
        let roots = ["餐饮", "交通", "购物", "居住", "娱乐", "医疗", "学习", "人情", "通讯", "宠物", "工资", "理财", "其他收入"]
        for root in roots where category.hasPrefix(root) { return root }
        if category.contains("房贷") || category.contains("房租") || category.contains("物业") { return "居住" }
        if category.contains("外卖") || category.contains("午餐") { return "餐饮" }
        return "其他"
    }

    /// 近 N 个月月均支出（按大类）
    static func monthlyAverage(_ txs: [Tx], root: String?, months: Int = 3, type: TxKind = .expense, end: Date = Date()) -> Double {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -months, to: end) else { return 0 }
        let scoped = txs.filter { $0.kind == type && $0.date > start && $0.date <= end }
        guard !scoped.isEmpty else { return 0 }
        let total = scoped.reduce(0.0) { sum, tx in
            if let root, rootOf(tx.category) != root { return sum }
            return sum + abs(tx.amountCNY)
        }
        let span = min(months, max(1, monthSpan(of: scoped)))
        return total / Double(span)
    }

    static func monthSpan(of txs: [Tx]) -> Int {
        guard let first = txs.map({ $0.date }).min(), let last = txs.map({ $0.date }).max() else { return 1 }
        let cal = Calendar.current
        let months = cal.dateComponents([.month], from: first, to: last).month ?? 0
        return months + 1
    }

    static func rigidMonthly(_ txs: [Tx], months: Int = 3, end: Date = Date()) -> Double {
        rigidRoots.reduce(0) { $0 + monthlyAverage(txs, root: $1, months: months, end: end) }
    }

    static func incomeMonthly(_ txs: [Tx], months: Int = 3) -> Double {
        monthlyAverage(txs, root: nil, months: months, type: .income)
    }

    // MARK: 保障

    static func buildProtectionGap(policies: [InsurancePolicy], debts: Double, liquidAssets: Double, txs: [Tx]) -> ProtectionGap {
        var gap = ProtectionGap()
        gap.policies = policies
        gap.debts = debts
        gap.liquidAssets = liquidAssets
        gap.rigidYearly = rigidMonthly(txs) * 12
        gap.annualIncome = incomeMonthly(txs) * 12
        gap.premiumYearly = policies.reduce(0) { $0 + $1.premium }
        gap.existingCoverage = policies.filter { $0.kind == InsurancePolicy.life }.reduce(0) { $0 + $1.coverage }
        gap.criticalCoverage = policies.filter { $0.kind == InsurancePolicy.critical }.reduce(0) { $0 + $1.coverage }
        gap.needByDemand = max(debts + gap.rigidYearly * 5 - liquidAssets, 0)
        gap.needByIncomeMultiple = gap.annualIncome * 8
        return gap
    }

    // MARK: 税务

    static func bonusSeparateTax(_ bonus: Double) -> Double {
        guard bonus > 0 else { return 0 }
        let monthly = bonus / 12
        let steps: [(limit: Double, rate: Double, quick: Double)] = [
            (3000, 0.03, 0), (12000, 0.10, 210), (25000, 0.20, 1410), (35000, 0.25, 2660),
            (55000, 0.30, 4410), (80000, 0.35, 7160), (Double.greatestFiniteMagnitude, 0.45, 15160)
        ]
        for step in steps where monthly <= step.limit {
            return max(bonus * step.rate - step.quick, 0)
        }
        return 0
    }

    static func bonusMergedTax(_ bonus: Double, marginalRate: Double) -> Double {
        max(bonus * marginalRate, 0)
    }

    static func buildTaxReport(_ p: TaxProfile) -> TaxReport {
        var report = TaxReport()
        report.rate = p.marginalRate
        let rate = p.marginalRate
        var lines: [TaxCheckLine] = []

        let childDeduction = Double(p.children) * 24000
        lines.append(TaxCheckLine(name: "子女教育", detail: "每个子女每月 2000 元", yearlyDeduction: childDeduction, saving: childDeduction * rate, claimed: p.children > 0))
        if p.childCare && p.children > 0 {
            lines.append(TaxCheckLine(name: "3 岁以下照护", detail: "每月 2000 元 / 每孩", yearlyDeduction: 24000, saving: 24000 * rate, claimed: true))
        }
        if p.elderlySupport {
            lines.append(TaxCheckLine(name: "赡养老人", detail: "独生子女每月 3000 元", yearlyDeduction: 36000, saving: 36000 * rate, claimed: true))
        }
        if p.mortgageInterest {
            lines.append(TaxCheckLine(name: "住房贷款利息", detail: "首套房贷每月 1000 元", yearlyDeduction: 12000, saving: 12000 * rate, claimed: true))
        }
        if p.housingRent {
            let monthly: Double = p.rentTier == 1 ? 1500 : (p.rentTier == 2 ? 1100 : 800)
            lines.append(TaxCheckLine(name: "住房租金", detail: "每月 \(Int(monthly)) 元（与房贷利息二选一）", yearlyDeduction: monthly * 12, saving: monthly * 12 * rate, claimed: true))
        }
        if p.continuingEducation {
            lines.append(TaxCheckLine(name: "继续教育", detail: "学历教育每月 400 元", yearlyDeduction: 4800, saving: 4800 * rate, claimed: true))
        }
        if p.seriousIllness > 15000 {
            let deductible = min(p.seriousIllness - 15000, 80000)
            lines.append(TaxCheckLine(name: "大病医疗", detail: "自付超 1.5 万部分，限额 8 万", yearlyDeduction: deductible, saving: deductible * rate, claimed: true))
        }
        let pension = min(p.pensionContributed, TaxProfile.pensionLimit)
        lines.append(TaxCheckLine(name: "个人养老金", detail: "每年上限 12000 元，领取时按 3% 单独计税", yearlyDeduction: pension, saving: pension * (rate - 0.03), claimed: pension > 0))

        report.lines = lines
        report.totalSaving = lines.reduce(0) { $0 + $1.saving }
        report.pensionSaving = pension * (rate - 0.03)
        report.missingSaving = lines.filter { !$0.claimed }.reduce(0) { $0 + $1.yearlyDeduction * rate }

        if p.annualBonus > 0 {
            let separate = bonusSeparateTax(p.annualBonus)
            let merged = bonusMergedTax(p.annualBonus, marginalRate: rate)
            report.bonusBest = min(separate, merged)
            report.bonusDiff = abs(separate - merged)
            report.bonusTip = separate < merged
                ? "年终奖单独计税更划算，能少交约 \(money(report.bonusDiff))"
                : "年终奖并入综合所得更划算，能少交约 \(money(report.bonusDiff))"
        }
        return report
    }

    // MARK: 目标

    static func monthsBetween(_ from: Date, _ to: Date) -> Int {
        let months = Calendar.current.dateComponents([.month], from: from, to: to).month ?? 0
        return max(months, 0)
    }

    /// 等额月供（PMT）
    static func requiredMonthly(target: Double, saved: Double, months: Int, annualReturn: Double) -> Double {
        let remain = max(target - saved, 0)
        guard months > 0 else { return remain }
        let r = annualReturn / 100 / 12
        if r <= 0 { return remain / Double(months) }
        let f = pow(1 + r, Double(months))
        return remain * r * f / (f - 1)
    }

    static func projectedValue(saved: Double, monthly: Double, months: Int, annualReturn: Double) -> Double {
        let r = annualReturn / 100 / 12
        var value = saved
        for _ in 0..<max(months, 0) {
            value = value * (1 + r) + monthly
        }
        return value
    }

    /// 固定种子蒙特卡洛：每月结余有波动时达标概率
    static func successProbability(goal: MoneyGoal, months: Int, surplus: Double, volatility: Double) -> Double {
        guard months > 0 else { return goal.saved >= goal.target ? 1 : 0 }
        let monthlyNeed = requiredMonthly(target: goal.target, saved: goal.saved, months: months, annualReturn: goal.annualReturn)
        let monthly = max(goal.monthly, min(surplus, monthlyNeed * 1.4))
        var rng = SeededGenerator(seed: 20261113 &+ UInt64(abs(goal.id.hashValue % 100000)))
        var hits = 0
        let rounds = 400
        for _ in 0..<rounds {
            var value = goal.saved
            for _ in 0..<months {
                let shock = Double.random(in: -volatility...volatility, using: &rng)
                value = value * (1 + goal.annualReturn / 100 / 12) + monthly * (1 + shock)
            }
            if value >= goal.target { hits += 1 }
        }
        return Double(hits) / Double(rounds)
    }

    static func surplusVolatility(_ txs: [Tx], months: Int = 3) -> Double {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -months, to: Date()) else { return 0.2 }
        var byMonth: [String: (income: Double, expense: Double)] = [:]
        for tx in txs where tx.date > start {
            let key = monthKey(tx.date)
            var slot = byMonth[key] ?? (0, 0)
            if tx.kind == .income { slot.income += abs(tx.amountCNY) } else if tx.kind == .expense { slot.expense += abs(tx.amountCNY) }
            byMonth[key] = slot
        }
        let surpluses = byMonth.values.map { $0.income - $0.expense }
        guard surpluses.count >= 2 else { return 0.2 }
        let mean = surpluses.reduce(0, +) / Double(surpluses.count)
        guard mean != 0 else { return 0.2 }
        let variance = surpluses.reduce(0) { $0 + pow($1 - mean, 2) } / Double(surpluses.count)
        return min(sqrt(variance) / abs(mean), 0.8)
    }

    static func buildGoals(_ goals: [MoneyGoal], monthlySurplus: Double, volatility: Double) -> [GoalPlan] {
        goals.map { goal in
            let months = monthsBetween(Date(), goal.dueDate)
            let need = requiredMonthly(target: goal.target, saved: goal.saved, months: max(months, 1), annualReturn: goal.annualReturn)
            let monthly = max(goal.monthly, need)
            let projected = projectedValue(saved: goal.saved, monthly: min(monthly, max(monthlySurplus, 0)), months: max(months, 1), annualReturn: goal.annualReturn)
            let probability = successProbability(goal: goal, months: max(months, 1), surplus: monthlySurplus, volatility: volatility)
            return GoalPlan(
                goal: goal,
                monthsLeft: months,
                requiredMonthly: need,
                projected: projected,
                probability: probability,
                progress: goal.target <= 0 ? 0 : min(goal.saved / goal.target, 1)
            )
        }
    }

    // MARK: 情景

    static func presetScenarios() -> [FinanceScenario] {
        [
            FinanceScenario(name: "失业 6 个月", incomeFactor: 0, lumpSum: 0, extraMonthly: 0, months: 6, note: "完全断收入，看现金能撑多久"),
            FinanceScenario(name: "收入腰斩 12 个月", incomeFactor: 0.5, lumpSum: 0, extraMonthly: 0, months: 12, note: "半年内只拿一半工资"),
            FinanceScenario(name: "一场大病 15 万", incomeFactor: 1.0, lumpSum: 150000, extraMonthly: 0, months: 12, note: "医保外自付一次性支出"),
            FinanceScenario(name: "买房首付 60 万 + 月供 6000", incomeFactor: 1.0, lumpSum: 600000, extraMonthly: 6000, months: 24, note: "两年内的现金流压力测试"),
            FinanceScenario(name: "生二孩", incomeFactor: 1.0, lumpSum: 30000, extraMonthly: 3000, months: 36, note: "每月多 3000 元育儿开支"),
        ]
    }

    static func runScenario(_ scenario: FinanceScenario, currentCash: Double, monthlyIncome: Double, monthlyExpense: Double, safeFloor: Double) -> ScenarioOutcome {
        var cash = currentCash
        var lowest = cash
        var breakMonth = 0
        for month in 1...max(scenario.months, 1) {
            var flow = monthlyIncome * scenario.incomeFactor - monthlyExpense - scenario.extraMonthly
            if month == 1 { flow -= scenario.lumpSum }
            cash += flow
            lowest = min(lowest, cash)
            if cash < safeFloor && breakMonth == 0 { breakMonth = month }
        }
        return ScenarioOutcome(scenario: scenario, lowestCash: lowest, breakMonth: breakMonth, endCash: cash, safeFloor: safeFloor)
    }

    // MARK: 归因

    static func buildAttribution(txs: [Tx], now: NetWorthSnapshot?, before: NetWorthSnapshot?) -> AttributionReport {
        var report = AttributionReport()
        report.month = now?.month ?? monthKey(Date())
        report.netNow = now?.net ?? 0
        report.netBefore = before?.net ?? report.netNow
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(from: DateComponents(year: cal.component(.year, from: Date()), month: cal.component(.month, from: Date()), day: 1)) ?? Date())
        var saving = 0.0
        var repay = 0.0
        var borrow = 0.0
        var assetIn = 0.0
        var assetOut = 0.0
        for tx in txs where tx.date >= start {
            let value = abs(tx.amountCNY)
            switch tx.kind {
            case .income: saving += value; report.income += value
            case .expense: saving -= value; report.expense += value
            default: break
            }
            if let nature = EntryNature.byKey(tx.nature) {
                switch nature {
                case .repay: repay += value
                case .borrow: borrow += value
                case .assetIn: assetIn += value
                case .assetOut: assetOut += value
                default: break
                }
            }
        }
        report.saving = saving
        report.repayment = repay - borrow
        let known = saving + report.repayment
        report.revalue = (report.netNow - report.netBefore) - known
        report.investment = assetOut - assetIn + report.revalue
        return report
    }
}
