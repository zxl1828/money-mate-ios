import Foundation

// MARK: - 会计科目（这笔钱到底算支出，还是只是资产/负债换形态）

/// 8 个科目：损益类 2 个、资产类 4 个、负债类 2 个。
/// 记账时按关键词自动判定（`AccountingClassifier`），用户可随时手动改。
enum EntryNature: String, Codable, CaseIterable, Identifiable {
    case expense      // 支出（损益）
    case income       // 收入（损益）
    case assetIn      // 买入资产 / 转入投资
    case assetOut     // 卖出资产 / 赎回
    case borrow       // 借入
    case repay        // 还本金
    case lend         // 借出 / 垫付
    case collect      // 收回借款

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        case .assetIn: return "买入资产"
        case .assetOut: return "卖出资产"
        case .borrow: return "借入"
        case .repay: return "还本金"
        case .lend: return "借出"
        case .collect: return "收回借款"
        }
    }

    var side: String {
        switch self {
        case .expense, .income: return "损益"
        case .assetIn, .assetOut, .lend, .collect: return "资产"
        case .borrow, .repay: return "负债"
        }
    }

    /// +1 = 钱进来，-1 = 钱出去
    var flow: Int {
        switch self {
        case .expense, .assetIn, .repay, .lend: return -1
        case .income, .assetOut, .borrow, .collect: return 1
        }
    }

    /// 是否进收入支出表（只有损益类进）
    var inStatement: Bool {
        switch self {
        case .expense, .income: return true
        default: return false
        }
    }

    var detail: String {
        switch self {
        case .expense: return "吃喝购物、房租水电这类真正花掉的钱"
        case .income: return "工资、奖金、分红这类真正赚到的钱"
        case .assetIn: return "买基金股票黄金、存定期，钱只是换了个形态"
        case .assetOut: return "赎回卖出，钱从资产变回现金"
        case .borrow: return "花呗白条、信用卡分期、向人借钱，借来的钱不是收入"
        case .repay: return "还信用卡、还房贷车贷的本金部分"
        case .lend: return "借给朋友的、替人垫付的钱，是应收款"
        case .collect: return "别人还你的钱，不是收入"
        }
    }

    /// 对应的流水方向，用于回填 Tx.kind
    var txKind: TxKind { flow > 0 ? .income : .expense }

    static func byKey(_ key: String?) -> EntryNature? {
        guard let key, !key.isEmpty else { return nil }
        return EntryNature(rawValue: key)
    }

    static var outflow: [EntryNature] { allCases.filter { $0.flow < 0 } }
    static var inflow: [EntryNature] { allCases.filter { $0.flow > 0 } }
}

// MARK: - 自动判定结果

struct NatureGuess {
    var nature: EntryNature
    var confidence: Double
    var reason: String
    var hint: String

    /// 把握不足，界面上应该提示用户确认一下
    var uncertain: Bool {
        confidence < NatureGuess.lowConfidenceFloor && !hint.isEmpty
    }

    static let lowConfidenceFloor: Double = 0.6
}

// MARK: - 分类器

enum AccountingClassifier {
    static let repayWords = ["还款", "还贷", "偿还", "还信用卡", "还花呗", "还借呗", "还白条", "还房贷",
                             "还车贷", "还借款", "还钱", "还债", "结清欠款", "提前还款"]
    static let lendWords = ["借出", "借给", "出借", "垫付", "代付", "借款给", "先帮", "帮垫"]
    static let assetInWords = ["买基金", "买股票", "买黄金", "买理财", "买债券", "买币", "买入", "申购",
                               "认购", "存定期", "定期存款", "定投", "转入理财", "转入证券", "转入基金",
                               "购买理财", "购买基金", "购汇", "换汇存入"]
    static let borrowWords = ["借款", "借入", "借钱", "贷款", "取现", "套现", "预支", "周转", "借呗",
                              "花呗", "白条", "分期到账", "信用卡取现"]
    static let collectWords = ["收回", "还我", "还款给我", "还钱给我", "归还", "退回借款", "收到还款"]
    static let assetOutWords = ["卖出", "赎回", "变现", "转让", "卖基金", "卖股票", "卖黄金", "二手卖出",
                                "闲鱼", "出售"]

    /// 自动判定（不考虑用户已手动指定的科目）
    static func guess(kind: TxKind, category: String = "", payee: String = "",
                      note: String = "", accountKind: AccountKind? = nil) -> NatureGuess {
        if kind == .transfer {
            return NatureGuess(nature: .assetIn, confidence: 1,
                               reason: "账户之间转账，只换存放位置", hint: "")
        }
        if kind == .refund {
            return NatureGuess(nature: .expense, confidence: 1,
                               reason: "退款会冲减原支出", hint: "")
        }
        let text = [payee, note, category].joined(separator: " ")

        func hit(_ words: [String]) -> String? { words.first { text.contains($0) } }

        if let w = hit(repayWords) {
            return NatureGuess(nature: .repay, confidence: 0.93,
                               reason: "「\(w)」是还本金，不算支出", hint: "")
        }
        if let w = hit(collectWords) {
            return NatureGuess(nature: .collect, confidence: 0.9,
                               reason: "「\(w)」是收回借出的钱，不是收入", hint: "")
        }
        if let w = hit(lendWords) {
            return NatureGuess(nature: .lend, confidence: 0.9,
                               reason: "「\(w)」是借出/垫付，会变成应收款", hint: "")
        }
        if let w = hit(borrowWords) {
            return NatureGuess(nature: .borrow, confidence: 0.88,
                               reason: "「\(w)」是借入，借来的钱不算收入", hint: "")
        }
        if let w = hit(assetInWords) {
            return NatureGuess(nature: .assetIn, confidence: 0.9,
                               reason: "「\(w)」是把现金换成资产", hint: "")
        }
        if let w = hit(assetOutWords) {
            return NatureGuess(nature: .assetOut, confidence: 0.9,
                               reason: "「\(w)」是资产变现，不算收入", hint: "")
        }
        if accountKind == .credit && kind == .expense {
            return NatureGuess(nature: .expense, confidence: 0.85,
                               reason: "信用卡消费，形成短期负债但仍属支出", hint: "")
        }
        if accountKind == .investment && kind == .expense {
            return NatureGuess(nature: .assetIn, confidence: 0.85,
                               reason: "从投资账户出账，多半是买入资产", hint: "")
        }
        if accountKind == .receivable && kind == .expense {
            return NatureGuess(nature: .lend, confidence: 0.8,
                               reason: "从借出账户出账，属于借出", hint: "")
        }
        if accountKind == .payable && kind == .income {
            return NatureGuess(nature: .borrow, confidence: 0.8,
                               reason: "进到借入账户，属于借入", hint: "")
        }
        let incomeCategories = ["工资", "理财", "其他收入", "奖金", "分红", "利息", "报销"]
        if incomeCategories.contains(where: { category.contains($0) }) {
            return NatureGuess(nature: kind == .income ? .income : .expense, confidence: 0.7,
                               reason: "分类是「\(category)」", hint: "")
        }
        if kind == .income {
            return NatureGuess(nature: .income, confidence: 0.55,
                               reason: "没看出特殊性质，先按收入记",
                               hint: "如果这是借来的钱或收回的欠款，改一下科目，收支表才准")
        }
        return NatureGuess(nature: .expense, confidence: 0.6,
                           reason: "没有借款/投资关键词，按日常支出记",
                           hint: "如果这是还款、买基金或借钱给人，点一下科目改掉")
    }

    /// 手动指定的科目优先，其次自动判断
    static func effectiveNature(kind: TxKind, nature: String = "", category: String = "",
                                payee: String = "", note: String = "",
                                accountKind: AccountKind? = nil) -> EntryNature {
        if let manual = EntryNature.byKey(nature) { return manual }
        return guess(kind: kind, category: category, payee: payee,
                     note: note, accountKind: accountKind).nature
    }
}

// MARK: - 手工科目（房产、车、房贷、网贷…）

enum ManualItemKind: String, Codable, CaseIterable, Identifiable {
    case house, car, valuables, providentFund, business, otherAsset
    case mortgage, carLoan, consumerLoan, otherLiability

    var id: String { rawValue }

    var label: String {
        switch self {
        case .house: return "房产"
        case .car: return "车辆"
        case .valuables: return "贵重物品"
        case .providentFund: return "公积金 / 年金"
        case .business: return "经营性资产"
        case .otherAsset: return "其他资产"
        case .mortgage: return "房贷"
        case .carLoan: return "车贷"
        case .consumerLoan: return "消费贷 / 网贷"
        case .otherLiability: return "其他负债"
        }
    }

    var isLiability: Bool {
        switch self {
        case .mortgage, .carLoan, .consumerLoan, .otherLiability: return true
        default: return false
        }
    }

    /// 一年内要还清的算流动负债
    var isCurrent: Bool { self == .consumerLoan || self == .otherLiability }

    static var assetKinds: [ManualItemKind] { allCases.filter { !$0.isLiability } }
    static var liabilityKinds: [ManualItemKind] { allCases.filter { $0.isLiability } }
}

struct ManualItem: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var kind: ManualItemKind
    var value: Double
    var note: String = ""
    var updatedAt: Date = Date()

    var isLiability: Bool { kind.isLiability }
}

/// 手工科目的本地存储（与账本快照分开存，避免改存档格式）
final class AccountingBook: ObservableObject {
    static let shared = AccountingBook()

    @Published var items: [ManualItem] = [] {
        didSet { save() }
    }

    private let key = "moneymate.accounting.manualItems"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ManualItem].self, from: data) {
            items = decoded
        }
    }

    func upsert(_ item: ManualItem) {
        var list = items
        var fresh = item
        fresh.updatedAt = Date()
        if let idx = list.firstIndex(where: { $0.id == fresh.id }) {
            list[idx] = fresh
        } else {
            list.append(fresh)
        }
        items = list
    }

    func delete(_ id: String) {
        items = items.filter { $0.id != id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - 资产负债表

struct BalanceLine: Identifiable, Hashable {
    var id: String { "\(source)-\(accountID?.uuidString ?? manualID ?? name)" }
    var name: String
    var value: Double
    var source: String          // account / manual
    var accountID: UUID?
    var manualID: String?
    var kind: String
}

struct BalanceGroup: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var lines: [BalanceLine]
    var total: Double
    var isLiability: Bool
}

struct BalanceSheet {
    var assetGroups: [BalanceGroup] = []
    var liabilityGroups: [BalanceGroup] = []
    var totalAssets: Double = 0
    var totalLiabilities: Double = 0
    var currentAssets: Double = 0
    var currentLiabilities: Double = 0
    var liquidAssets: Double = 0
    var monthlyExpense: Double = 0
    var at: Date = Date()

    var netWorth: Double { totalAssets - totalLiabilities }

    /// 资产负债率
    var debtRatio: Double { totalAssets <= 0 ? 0 : totalLiabilities / totalAssets }

    /// 流动比率
    var currentRatio: Double { currentLiabilities <= 0 ? 99 : currentAssets / currentLiabilities }

    /// 应急金能撑几个月
    var emergencyMonths: Double { monthlyExpense <= 0 ? 0 : liquidAssets / monthlyExpense }

    var isEmpty: Bool { assetGroups.isEmpty && liabilityGroups.isEmpty }
}

// MARK: - 收入支出表

struct StatementLine: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var value: Double
    var count: Int
}

struct StatementSection: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var lines: [StatementLine]
    var total: Double
}

struct FlowLine: Identifiable, Hashable {
    var id: String { nature.rawValue }
    var nature: EntryNature
    var count: Int
    var inflow: Double
    var outflow: Double
    var net: Double { inflow - outflow }
}

struct IncomeStatement {
    var title: String = ""
    var start: Date = Date()
    var end: Date = Date()
    var income: Double = 0
    var expense: Double = 0
    var incomeSections: [StatementSection] = []
    var expenseSections: [StatementSection] = []
    var flows: [FlowLine] = []
    var refundAmount: Double = 0

    var net: Double { income - expense }
    var savingRate: Double { income <= 0 ? 0 : net / income }
    /// 非损益的资金流转净额（借钱、还本金、买卖资产）
    var nonPlNet: Double { flows.reduce(0) { $0 + $1.net } }
}

// MARK: - 财务比率

struct FinanceRatio: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var value: Double
    var display: String
    var status: String      // 优秀 / 健康 / 关注 / 一般 / 风险
    var advice: String
    var score: Int          // 0...100
}

struct LoanResult {
    var monthlyFirst: Double
    var monthlyLast: Double
    var totalPayment: Double
    var totalInterest: Double
}

struct CompoundResult {
    var finalValue: Double
    var contributed: Double
    var gain: Double
}

struct FireResult {
    var target: Double
    var gap: Double
    var years: Int
    var progress: Double
}

// MARK: - 报表引擎

enum AccountingEngine {

    // MARK: 资产负债表

    static func buildBalanceSheet(accounts: [Account], txs: [Tx], items: [ManualItem],
                                 monthlyExpense: Double = 0, at: Date? = nil) -> BalanceSheet {
        var sheet = BalanceSheet()
        sheet.at = at ?? Date()
        sheet.monthlyExpense = monthlyExpense

        var cash: [BalanceLine] = []
        var invest: [BalanceLine] = []
        var receivable: [BalanceLine] = []
        var overdraft: [BalanceLine] = []
        var credit: [BalanceLine] = []
        var payable: [BalanceLine] = []

        for account in accounts where !account.archived {
            let value = FinanceMath.balance(account, txs: txs, before: at)
            guard abs(value) > 0.005 else { continue }
            let line = BalanceLine(name: account.displayName, value: value, source: "account",
                                   accountID: account.id, manualID: nil, kind: account.kind.rawValue)
            switch account.kind {
            case .cash, .debit, .wallet:
                if value >= 0 { cash.append(line) } else { overdraft.append(line) }
            case .investment:
                if value >= 0 { invest.append(line) } else { overdraft.append(line) }
            case .receivable:
                if value >= 0 { receivable.append(line) } else { payable.append(line) }
            case .credit, .payable:
                if value < 0 {
                    var l = line
                    l.value = -value
                    if account.kind == .credit { credit.append(l) } else { payable.append(l) }
                } else {
                    cash.append(line)   // 溢缴款算资产
                }
            }
        }

        var assetGroups: [BalanceGroup] = []
        func addAssetGroup(_ title: String, _ lines: [BalanceLine]) {
            guard !lines.isEmpty else { return }
            let total = lines.reduce(0) { $0 + $1.value }
            assetGroups.append(BalanceGroup(title: title, lines: lines, total: total, isLiability: false))
        }
        addAssetGroup("现金与存款", cash)
        addAssetGroup("投资资产", invest)
        addAssetGroup("应收借出", receivable)
        for kind in ManualItemKind.assetKinds {
            addAssetGroup(kind.label, items.filter { $0.kind == kind }.map { item in
                BalanceLine(name: item.name, value: item.value, source: "manual",
                            accountID: nil, manualID: item.id, kind: item.kind.rawValue)
            })
        }

        var liabilityGroups: [BalanceGroup] = []
        func addLiabilityGroup(_ title: String, _ lines: [BalanceLine]) {
            guard !lines.isEmpty else { return }
            let total = lines.reduce(0) { $0 + $1.value }
            liabilityGroups.append(BalanceGroup(title: title, lines: lines, total: total, isLiability: true))
        }
        addLiabilityGroup("信用卡欠款", credit)
        addLiabilityGroup("借入款项", payable)
        addLiabilityGroup("账户透支", overdraft)
        for kind in ManualItemKind.liabilityKinds {
            addLiabilityGroup(kind.label, items.filter { $0.kind == kind }.map { item in
                BalanceLine(name: item.name, value: item.value, source: "manual",
                            accountID: nil, manualID: item.id, kind: item.kind.rawValue)
            })
        }

        sheet.assetGroups = assetGroups
        sheet.liabilityGroups = liabilityGroups
        sheet.totalAssets = assetGroups.reduce(0) { $0 + $1.total }
        sheet.totalLiabilities = liabilityGroups.reduce(0) { $0 + $1.total }

        let cashTotal = assetGroups.first { $0.title == "现金与存款" }?.total ?? 0
        let investTotal = assetGroups.first { $0.title == "投资资产" }?.total ?? 0
        sheet.liquidAssets = cashTotal
        sheet.currentAssets = cashTotal + investTotal

        let creditTotal = liabilityGroups.first { $0.title == "信用卡欠款" }?.total ?? 0
        let payableTotal = liabilityGroups.first { $0.title == "借入款项" }?.total ?? 0
        let overdraftTotal = liabilityGroups.first { $0.title == "账户透支" }?.total ?? 0
        let shortManual = items.filter { $0.isLiability && $0.kind.isCurrent }.reduce(0) { $0 + $1.value }
        sheet.currentLiabilities = creditTotal + payableTotal + overdraftTotal + shortManual
        return sheet
    }

    // MARK: 均值 / 期间

    static func monthlyAverageExpense(_ txs: [Tx], months: Int = 3, end: Date = Date()) -> Double {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -months,
                                   to: cal.startOfDay(for: end)) else { return 0 }
        var total = 0.0
        for tx in txs {
            guard tx.kind != .transfer else { continue }
            guard tx.date > start && tx.date <= end else { continue }
            let nature = effectiveNature(tx)
            guard nature.inStatement else { continue }
            if tx.kind == .refund {
                total -= abs(tx.amountCNY)
            } else if nature == .expense {
                total += abs(tx.amountCNY)
            }
        }
        return max(total, 0) / Double(max(months, 1))
    }

    static func monthRange(offset: Int, now: Date = Date()) -> (Date, Date) {
        let cal = Calendar.current
        let base = cal.date(byAdding: .month, value: -offset, to: now) ?? now
        let start = cal.date(from: cal.dateComponents([.year, .month], from: base)) ?? base
        let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? base
        return (start, end)
    }

    static func yearRange(now: Date = Date()) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
        let end = cal.date(byAdding: DateComponents(year: 1, second: -1), to: start) ?? now
        return (start, end)
    }

    // MARK: 科目解析

    static func effectiveNature(_ tx: Tx, accountKind: AccountKind? = nil) -> EntryNature {
        AccountingClassifier.effectiveNature(kind: tx.kind, nature: tx.nature,
                                             category: tx.category, payee: tx.merchant,
                                             note: tx.note, accountKind: accountKind)
    }

    // MARK: 收入支出表

    static func buildStatement(txs: [Tx], accounts: [Account],
                               start: Date, end: Date, title: String) -> IncomeStatement {
        var st = IncomeStatement()
        st.title = title
        st.start = start
        st.end = end

        var kindOf: [UUID: AccountKind] = [:]
        for a in accounts { kindOf[a.id] = a.kind }

        var incomeBucket: [String: (Double, Int)] = [:]
        var expenseBucket: [String: (Double, Int)] = [:]
        var flows: [EntryNature: (Int, Double, Double)] = [:]

        for tx in txs {
            guard tx.kind != .transfer else { continue }
            guard tx.date >= start && tx.date <= end else { continue }
            let nature = effectiveNature(tx, accountKind: tx.accountID.flatMap { kindOf[$0] })
            let amount = abs(tx.amountCNY)

            if nature.inStatement {
                if nature == .income {
                    if tx.kind == .refund { continue }
                    st.income += amount
                    var b = incomeBucket[tx.category] ?? (0, 0)
                    b.0 += amount; b.1 += 1
                    incomeBucket[tx.category] = b
                } else if tx.kind == .refund {
                    st.refundAmount += amount
                    st.expense -= amount
                    var b = expenseBucket[tx.category] ?? (0, 0)
                    b.0 -= amount; b.1 += 1
                    expenseBucket[tx.category] = b
                } else {
                    st.expense += amount
                    var b = expenseBucket[tx.category] ?? (0, 0)
                    b.0 += amount; b.1 += 1
                    expenseBucket[tx.category] = b
                }
            } else {
                var f = flows[nature] ?? (0, 0, 0)
                f.0 += 1
                if nature.flow > 0 { f.1 += amount } else { f.2 += amount }
                flows[nature] = f
            }
        }

        func sections(_ bucket: [String: (Double, Int)]) -> [StatementSection] {
            let lines = bucket.filter { $0.value.0 > 0.005 }
                .map { StatementLine(name: $0.key, value: $0.value.0, count: $0.value.1) }
                .sorted { $0.value > $1.value }
            guard !lines.isEmpty else { return [] }
            return [StatementSection(title: "构成", lines: lines,
                                     total: lines.reduce(0) { $0 + $1.value })]
        }
        st.incomeSections = sections(incomeBucket)
        st.expenseSections = sections(expenseBucket)
        st.flows = flows.map { key, value in
            FlowLine(nature: key, count: value.0, inflow: value.1, outflow: value.2)
        }.sorted { $0.nature.rawValue < $1.nature.rawValue }

        st.income = max(st.income, 0)
        st.expense = max(st.expense, 0)
        return st
    }

    // MARK: 财务比率

    static func buildRatios(sheet: BalanceSheet, statement: IncomeStatement,
                            passiveIncome: Double, netWorthGrowth: Double = 0) -> [FinanceRatio] {
        var list: [FinanceRatio] = []

        /// 升序阈值：命中第一个「value <= 阈值」
        func grade(_ value: Double, _ buckets: [(Double, String, Int)]) -> (String, Int) {
            for (threshold, name, score) in buckets where value <= threshold {
                return (name, score)
            }
            return buckets.last.map { ($0.1, $0.2) } ?? ("一般", 50)
        }

        func row(_ name: String, _ value: Double, _ display: String,
                 _ buckets: [(Double, String, Int)],
                 _ adviceGood: String, _ adviceBad: String) {
            let result = grade(value, buckets)
            let good = result.1 >= 75
            list.append(FinanceRatio(name: name, value: value, display: display,
                                     status: result.0, advice: good ? adviceGood : adviceBad,
                                     score: result.1))
        }

        // 1 资产负债率
        let debt = sheet.debtRatio * 100
        row("资产负债率", debt, String(format: "%.1f%%", debt),
            [(40, "优秀", 92), (50, "健康", 80), (60, "关注", 64), (70, "一般", 50),
             (Double.greatestFiniteMagnitude, "风险", 25)],
            "负债率健康，还有加杠杆空间，但别为了投资硬上杠杆",
            "负债偏重，先还高息消费贷，再谈投资")

        // 2 流动比率
        let current = sheet.currentRatio
        row("流动比率", current, String(format: "%.2f 倍", current),
            [(1.0, "风险", 25), (1.5, "一般", 50), (2.0, "关注", 65), (3.0, "健康", 80),
             (Double.greatestFiniteMagnitude, "优秀", 93)],
            "短期偿债能力没问题",
            "流动资产覆盖不了短期负债，先留足现金")

        // 3 储蓄率
        let saving = statement.savingRate * 100
        row("储蓄率", saving, String(format: "%.1f%%", saving),
            [(0, "风险", 22), (10, "一般", 45), (25, "关注", 62), (40, "健康", 80),
             (Double.greatestFiniteMagnitude, "优秀", 92)],
            "储蓄率不错，钱有在变成资产",
            "支出占比偏高，先砍非必要开支")

        // 4 负债收入比（总负债 = 几个月收入）
        let monthlyIncome = statement.income
        let dti = sheet.totalLiabilities <= 0 ? 0 : sheet.totalLiabilities / max(monthlyIncome, 1)
        row("负债收入比", dti, String(format: "%.1f 个月收入", dti),
            [(6, "优秀", 92), (12, "健康", 80), (18, "关注", 64), (24, "一般", 50),
             (Double.greatestFiniteMagnitude, "风险", 25)],
            "负债规模可控",
            "总负债超过两年收入，风险偏高")

        // 5 应急金
        let emergency = sheet.emergencyMonths
        row("应急金", emergency, String(format: "%.1f 个月", emergency),
            [(0.5, "风险", 25), (1.5, "一般", 48), (3, "关注", 65), (6, "健康", 82),
             (Double.greatestFiniteMagnitude, "优秀", 95)],
            "应急金充足，可以放心投资",
            "先攒够 3–6 个月开支再谈投资")

        // 6 投资资产占比
        let investTotal = sheet.assetGroups.first { $0.title == "投资资产" }?.total ?? 0
        let investRatio = sheet.totalAssets <= 0 ? 0 : investTotal / sheet.totalAssets * 100
        row("投资资产占比", investRatio, String(format: "%.1f%%", investRatio),
            [(10, "一般", 45), (20, "关注", 60), (30, "健康", 78),
             (Double.greatestFiniteMagnitude, "优秀", 90)],
            "资产结构偏成长，注意波动承受力",
            "钱大多躺在现金里，长期跑不赢通胀")

        // 7 财务自由度
        let freedom = sheet.monthlyExpense <= 0 ? 0 : passiveIncome / sheet.monthlyExpense
        row("财务自由度", freedom, String(format: "%.0f%%", min(freedom, 9.99) * 100),
            [(0.05, "风险", 25), (0.2, "一般", 45), (0.5, "关注", 62), (1, "健康", 85),
             (Double.greatestFiniteMagnitude, "优秀", 96)],
            "被动收入已覆盖开支，可以考虑不上班",
            "被动收入还撑不起生活，继续扩大本金")

        // 8 净资产增长
        let growth = netWorthGrowth * 100
        row("净资产增长", growth, String(format: "%+.1f%%", growth),
            [(0, "风险", 25), (5, "一般", 48), (15, "关注", 62), (30, "健康", 80),
             (Double.greatestFiniteMagnitude, "优秀", 92)],
            "净资产在涨，方向对",
            "净资产没涨，检查是不是被支出吃掉了")

        return list
    }

    static func healthScore(_ ratios: [FinanceRatio]) -> Int {
        guard !ratios.isEmpty else { return 0 }
        let avg = Double(ratios.reduce(0) { $0 + $1.score }) / Double(ratios.count)
        return Int(avg.rounded())
    }

    // MARK: 贷款 / 复利 / FIRE

    static func loanEqualInstallment(principal: Double, annualRate: Double, months: Int) -> LoanResult {
        guard principal > 0, months > 0 else {
            return LoanResult(monthlyFirst: 0, monthlyLast: 0, totalPayment: 0, totalInterest: 0)
        }
        let monthlyRate = annualRate / 100 / 12
        if monthlyRate <= 0 {
            let m = principal / Double(months)
            return LoanResult(monthlyFirst: m, monthlyLast: m, totalPayment: principal, totalInterest: 0)
        }
        let factor = pow(1 + monthlyRate, Double(months))
        let m = principal * monthlyRate * factor / (factor - 1)
        return LoanResult(monthlyFirst: m, monthlyLast: m,
                          totalPayment: m * Double(months),
                          totalInterest: m * Double(months) - principal)
    }

    static func loanEqualPrincipal(principal: Double, annualRate: Double, months: Int) -> LoanResult {
        guard principal > 0, months > 0 else {
            return LoanResult(monthlyFirst: 0, monthlyLast: 0, totalPayment: 0, totalInterest: 0)
        }
        let monthlyRate = annualRate / 100 / 12
        let principalPart = principal / Double(months)
        let first = principalPart + principal * monthlyRate
        let last = principalPart + principalPart * monthlyRate
        let interest = principal * monthlyRate * Double(months + 1) / 2
        return LoanResult(monthlyFirst: first, monthlyLast: last,
                          totalPayment: principal + interest, totalInterest: interest)
    }

    static func compound(initial: Double, monthly: Double, annualRate: Double, years: Int) -> CompoundResult {
        let monthlyRate = annualRate / 100 / 12
        var value = initial
        var contributed = initial
        for _ in 0..<max(years, 0) * 12 {
            value = value * (1 + monthlyRate) + monthly
            contributed += monthly
        }
        return CompoundResult(finalValue: value, contributed: contributed, gain: value - contributed)
    }

    static func fire(annualExpense: Double, currentNetWorth: Double, monthlySaving: Double,
                     annualReturn: Double = 5, withdrawRate: Double = 4) -> FireResult {
        let target = annualExpense / max(withdrawRate, 0.1) * 100
        let gap = max(target - currentNetWorth, 0)
        let progress = target <= 0 ? 0 : min(currentNetWorth / target, 1)
        var years = 0
        if monthlySaving > 0 && currentNetWorth < target {
            var value = currentNetWorth
            let monthlyRate = annualReturn / 100 / 12
            while value < target && years < 100 {
                for _ in 0..<12 { value = value * (1 + monthlyRate) + monthlySaving }
                years += 1
            }
        }
        return FireResult(target: target, gap: gap, years: years, progress: progress)
    }
}
