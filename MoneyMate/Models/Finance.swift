import Foundation

// MARK: - 账户类型

enum AccountKind: String, Codable, CaseIterable, Identifiable {
    case cash, debit, credit, wallet, investment, receivable, payable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: return "现金"
        case .debit: return "储蓄卡"
        case .credit: return "信用卡"
        case .wallet: return "电子钱包"
        case .investment: return "投资"
        case .receivable: return "借出"
        case .payable: return "借入"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .debit: return "creditcard"
        case .credit: return "creditcard.fill"
        case .wallet: return "wallet.pass.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .receivable: return "hand.raised.fill"
        case .payable: return "arrow.down.circle.fill"
        }
    }

    /// 欠款类账户：余额为负表示欠款
    var isLiability: Bool { self == .credit || self == .payable }

    /// 需要账单日 / 还款日
    var hasBillingCycle: Bool { self == .credit }
}

// MARK: - 账户

struct Account: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: AccountKind
    var currency: Currency = .cny
    var initialBalance: Double = 0
    var cardTail: String = ""      // 卡号后四位
    var creditLimit: Double = 0    // 信用额度，0 = 未设置
    var statementDay: Int = 0      // 账单日 1...28，0 = 未设置
    var dueDay: Int = 0            // 还款日 1...28，0 = 未设置
    var archived: Bool = false
    var createdAt: Date = Date()

    init(id: UUID = UUID(),
         name: String,
         kind: AccountKind,
         currency: Currency = .cny,
         initialBalance: Double = 0,
         cardTail: String = "",
         creditLimit: Double = 0,
         statementDay: Int = 0,
         dueDay: Int = 0,
         archived: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.kind = kind
        self.currency = currency
        self.initialBalance = initialBalance
        self.cardTail = cardTail
        self.creditLimit = creditLimit
        self.statementDay = statementDay
        self.dueDay = dueDay
        self.archived = archived
        self.createdAt = createdAt
    }

    var icon: String { kind.icon }
    var isCredit: Bool { kind == .credit }

    var displayName: String {
        cardTail.isEmpty ? name : "\(name) \u{2022}\(cardTail)"
    }
}

// MARK: - 信用卡账单摘要

struct CreditSummary {
    var used: Double = 0            // 已用额度（正数）
    var limit: Double = 0
    var available: Double = 0
    var currentBill: Double = 0     // 本期账单
    var dueDate: Date?
    var daysToDue: Int?
    var statementDate: Date?

    var hasLimit: Bool { limit > 0 }
    var usage: Double { limit > 0 ? min(used / limit, 1) : 0 }
}

// MARK: - 分类（可自定义）

struct TxCategory: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var isIncome: Bool = false
    var hidden: Bool = false
    var builtin: Bool = false
    var sortIndex: Int = 0

    init(id: UUID = UUID(),
         name: String,
         icon: String,
         isIncome: Bool = false,
         hidden: Bool = false,
         builtin: Bool = false,
         sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isIncome = isIncome
        self.hidden = hidden
        self.builtin = builtin
        self.sortIndex = sortIndex
    }

    /// 内置 12 个分类（与旧版本一致，升级后不丢历史数据）
    static func builtins() -> [TxCategory] {
        let expense: [(String, String)] = [
            ("餐饮", "fork.knife"), ("交通", "tram.fill"), ("购物", "bag.fill"),
            ("居家", "house.fill"), ("娱乐", "gamecontroller.fill"), ("医疗", "cross.case.fill"),
            ("学习", "book.fill"), ("旅行", "airplane"), ("宠物", "pawprint.fill"),
            ("其他", "ellipsis.circle.fill")
        ]
        let income: [(String, String)] = [
            ("工资", "banknote.fill"), ("理财", "chart.line.uptrend.xyaxis")
        ]
        var list: [TxCategory] = []
        for (i, item) in expense.enumerated() {
            list.append(TxCategory(name: item.0, icon: item.1, isIncome: false, builtin: true, sortIndex: i))
        }
        for (i, item) in income.enumerated() {
            list.append(TxCategory(name: item.0, icon: item.1, isIncome: true, builtin: true, sortIndex: 100 + i))
        }
        return list
    }
}

// MARK: - 附件（收据 / 发票）

struct TxAttachment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var fileName: String
    var isImage: Bool = true
    var addedAt: Date = Date()

    init(id: UUID = UUID(), fileName: String, isImage: Bool = true, addedAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.isImage = isImage
        self.addedAt = addedAt
    }
}

// MARK: - 账单类型

enum TxKind: String, Codable {
    case expense, income, transfer

    var title: String {
        switch self {
        case .expense: return "支出"
        case .income: return "收入"
        case .transfer: return "转账"
        }
    }
}

// MARK: - 外观

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }
}

// MARK: - 共享账本成员

struct LedgerMember: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var isMe: Bool = false

    init(id: UUID = UUID(), name: String, isMe: Bool = false) {
        self.id = id
        self.name = name
        self.isMe = isMe
    }
}

// MARK: - 净值

struct NetWorthPoint: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let assets: Double
    let liabilities: Double
    let net: Double
}

// MARK: - 余额 / 净值算法（纯函数，便于复用）

enum FinanceMath {
    /// 单笔对某账户的影响（人民币口径）
    static func delta(_ tx: Tx, for accountID: UUID) -> Double {
        if tx.kind == .transfer {
            if tx.accountID == accountID { return tx.amountCNY }
            if tx.toAccountID == accountID { return -tx.amountCNY }
            return 0
        }
        return tx.accountID == accountID ? tx.amountCNY : 0
    }

    static func balance(_ account: Account, txs: [Tx]) -> Double {
        txs.reduce(account.initialBalance) { $0 + delta($1, for: account.id) }
    }

    static func balance(_ account: Account, txs: [Tx], before date: Date?) -> Double {
        guard let date else { return balance(account, txs: txs) }
        return txs.filter { $0.date <= date }.reduce(account.initialBalance) { $0 + delta($1, for: account.id) }
    }

    /// 未分配账户的流水（老数据升级前的兜底）
    static func unassignedNet(_ txs: [Tx]) -> Double {
        txs.filter { $0.accountID == nil && $0.kind != .transfer }.reduce(0) { $0 + $1.amountCNY }
    }

    static func netWorth(accounts: [Account], txs: [Tx], at date: Date? = nil) -> (assets: Double, liabilities: Double, net: Double) {
        var assets = 0.0
        var liabilities = 0.0
        for account in accounts where !account.archived {
            let value = balance(account, txs: txs, before: date)
            if account.kind.isLiability {
                liabilities += max(-value, 0)
                // 负债账户出现正余额（溢缴款）时算资产
                assets += max(value, 0)
            } else {
                if value >= 0 { assets += value } else { liabilities += -value }
            }
        }
        if date == nil {
            let unassigned = unassignedNet(txs)
            if unassigned >= 0 { assets += unassigned } else { liabilities += -unassigned }
        }
        return (assets, liabilities, assets - liabilities)
    }

    /// 近 N 个月净资产曲线（取每月最后一天）
    static func netWorthSeries(accounts: [Account], txs: [Tx], months: Int = 6) -> [NetWorthPoint] {
        let cal = Calendar.current
        var points: [NetWorthPoint] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let month = cal.date(byAdding: .month, value: -offset, to: Date()),
                  let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: cal.startOfDay(for: month)) else { continue }
            let stamp = cal.date(byAdding: .hour, value: 23, to: end) ?? end
            let isCurrent = offset == 0
            let snapshot = netWorth(accounts: accounts, txs: txs, at: isCurrent ? nil : stamp)
            points.append(NetWorthPoint(date: stamp, assets: snapshot.assets, liabilities: snapshot.liabilities, net: snapshot.net))
        }
        return points
    }

    /// 下一个月度还款/账单日
    static func nextDay(_ day: Int, from date: Date = Date()) -> Date? {
        guard day > 0 else { return nil }
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: date)
        comps.day = min(day, 28)
        comps.hour = 9
        guard let thisMonth = cal.date(from: comps) else { return nil }
        if cal.startOfDay(for: thisMonth) >= cal.startOfDay(for: date) { return thisMonth }
        return cal.date(byAdding: .month, value: 1, to: thisMonth)
    }

    static func previousDay(_ day: Int, from date: Date = Date()) -> Date? {
        guard let next = nextDay(day, from: date) else { return nil }
        return Calendar.current.date(byAdding: .month, value: -1, to: next)
    }

    /// 信用卡账单摘要
    static func creditSummary(_ account: Account, txs: [Tx]) -> CreditSummary {
        var s = CreditSummary()
        let balance = FinanceMath.balance(account, txs: txs)
        s.used = max(-balance, 0)
        s.limit = account.creditLimit
        s.available = account.creditLimit > 0 ? max(account.creditLimit - s.used, 0) : 0

        let start = previousDay(account.statementDay, from: Date())
        let end = nextDay(account.statementDay, from: Date())
        if let start {
            s.statementDate = start
            s.currentBill = txs.filter { tx in
                guard tx.accountID == account.id, tx.kind != .transfer else { return false }
                return tx.amountCNY < 0 && tx.date > start && (end.map { tx.date <= $0 } ?? true)
            }.reduce(0) { $0 - $1.amountCNY }
        }
        s.dueDate = nextDay(account.dueDay)
        if let due = s.dueDate {
            s.daysToDue = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                          to: Calendar.current.startOfDay(for: due)).day
        }
        return s
    }
}
