import AppIntents
import Foundation

// MARK: - 快捷指令待入库队列

struct PendingQuickTx: Codable {
    var amount: Double
    var category: String
    var note: String
    var isIncome: Bool
    var createdAt: Date
}

enum PendingQuickStore {
    static let key = "moneymate.pending.v1"

    static func append(_ item: PendingQuickTx) {
        var list = load()
        list.append(item)
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [PendingQuickTx] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([PendingQuickTx].self, from: data) else { return [] }
        return list
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - 记一笔（Siri / 快捷指令）

struct QuickAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "记一笔"
    static var description: IntentDescription = IntentDescription("把一笔支出或收入快速记进 MoneyMate")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "分类", default: "餐饮")
    var category: String

    @Parameter(title: "备注")
    var note: String?

    @Parameter(title: "是收入", default: false)
    var isIncome: Bool

    init() {}

    init(amount: Double, category: String = "餐饮", note: String? = nil, isIncome: Bool = false) {
        self.amount = amount
        self.category = category
        self.note = note
        self.isIncome = isIncome
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        PendingQuickStore.append(PendingQuickTx(amount: abs(amount),
                                                category: category,
                                                note: note ?? "",
                                                isIncome: isIncome,
                                                createdAt: Date()))
        let kind = isIncome ? "收入" : "支出"
        return .result(dialog: "已记下\(kind)：\(category) \u{00A5}\(String(format: "%.2f", abs(amount)))")
    }
}

// MARK: - 查本月支出

struct MonthSpendIntent: AppIntent {
    static var title: LocalizedStringResource = "查本月支出"
    static var description: IntentDescription = IntentDescription("看看这个月花了多少、预算还剩多少")
    static var openAppWhenRun: Bool = false

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snap = WidgetShared.read() else {
            return .result(dialog: "还没有账本数据，先打开 MoneyMate 记一笔吧")
        }
        let money = { (value: Double) -> String in
            String(format: "\u{00A5}%.2f", value)
        }
        var text = "本月已花 \(money(snap.monthExpense))"
        if snap.monthBudget > 0 {
            text += "，预算 \(money(snap.monthBudget))，还剩 \(money(snap.budgetLeft))"
        }
        text += "；今天花了 \(money(snap.todayExpense))。"
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

// MARK: - Siri 短语

struct MoneyMateShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: QuickAddExpenseIntent(),
                    phrases: ["用 \(.applicationName) 记一笔",
                              "让 \(.applicationName) 记账",
                              "\(.applicationName) 记一笔"],
                    shortTitle: "记一笔",
                    systemImageName: "plus.circle.fill")
        AppShortcut(intent: MonthSpendIntent(),
                    phrases: ["用 \(.applicationName) 查本月支出",
                              "\(.applicationName) 这个月花了多少"],
                    shortTitle: "本月支出",
                    systemImageName: "chart.bar.fill")
    }
}

// MARK: - 把快捷指令记的账并入账本

extension MoneyStore {
    /// App 回到前台时把 Siri / 快捷指令记的账并入账本，返回并入条数
    @discardableResult
    func consumePendingQuickItems() -> Int {
        let items = PendingQuickStore.load()
        guard !items.isEmpty else { return 0 }
        let fallback = activeAccounts.first { $0.kind == .wallet } ?? activeAccounts.first
        for item in items {
            let title = item.note.isEmpty ? item.category : item.note
            let amount = item.isIncome ? abs(item.amount) : -abs(item.amount)
            let tx = Tx(title: title,
                        amount: amount,
                        category: item.category,
                        date: item.createdAt,
                        note: item.note,
                        kind: item.isIncome ? .income : .expense,
                        accountID: fallback?.id,
                        updatedAt: Date(),
                        memberName: myName)
            add(tx)
        }
        PendingQuickStore.clear()
        persist()
        return items.count
    }
}
