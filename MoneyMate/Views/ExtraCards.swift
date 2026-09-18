import SwiftUI

// MARK: - 目标储蓄

struct SavingsGoal: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var target: Double
    var saved: Double = 0
    var deadline: Date?

    var progress: Double { target > 0 ? min(saved / target, 1) : 0 }
}

enum GoalStore {
    private static let key = "moneymate.goals.v1"

    static func load() -> [SavingsGoal] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([SavingsGoal].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [SavingsGoal]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct GoalCard: View {
    @ObservedObject var store: MoneyStore
    @State private var goals: [SavingsGoal] = GoalStore.load()
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "目标储蓄", subtitle: goals.isEmpty ? "比如：旅行基金 ¥8000" : "攒到目标就有进度条") {
                showEditor = true
            }
            if goals.isEmpty {
                Text("设一个目标，每月往里存一点，进度看得见")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            } else {
                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            Text(store.money(goal.saved) + " / " + store.money(goal.target))
                                .font(.caption)
                                .foregroundStyle(Palette.ink.opacity(0.7))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.primary.opacity(0.15))
                                Capsule()
                                    .fill(Palette.hero)
                                    .frame(width: max(geo.size.width * goal.progress, 4))
                            }
                        }
                        .frame(height: 7)
                        HStack(spacing: 10) {
                            Button {
                                deposit(goal, amount: 100)
                            } label: {
                                Text("+100").font(.caption2.weight(.bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Palette.primary)
                            Button {
                                deposit(goal, amount: 500)
                            } label: {
                                Text("+500").font(.caption2.weight(.bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Palette.primary)
                            Spacer()
                            Text(String(Int(goal.progress * 100)) + "%")
                                .font(.caption2)
                                .foregroundStyle(Palette.ink.opacity(0.6))
                            Button {
                                goals.removeAll { $0.id == goal.id }
                                GoalStore.save(goals)
                            } label: {
                                Image(systemName: "trash").font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Palette.rose)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .sheet(isPresented: $showEditor) {
            GoalEditorSheet { created in
                goals.append(created)
                GoalStore.save(goals)
                Haptics.success()
            }
        }
    }

    private func deposit(_ goal: SavingsGoal, amount: Double) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index].saved += amount
        GoalStore.save(goals)
        Haptics.tap()
    }
}

struct GoalEditorSheet: View {
    var onSaved: (SavingsGoal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("目标名称（如：旅行基金）", text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .innerTile(Radius.chip, opacity: 0.10)
                TextField("目标金额", text: $targetText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .innerTile(Radius.chip, opacity: 0.10)
                Button {
                    let target = Double(targetText.trimmingCharacters(in: .whitespaces)) ?? 0
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty, target > 0 else { return }
                    onSaved(SavingsGoal(name: name.trimmingCharacters(in: .whitespaces), target: target))
                    dismiss()
                } label: {
                    Text("创建目标")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: Radius.button))
                Spacer()
            }
            .padding(20)
            .background(GlassBackground())
            .navigationTitle("新建目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 报销台账

struct ReimbursementCard: View {
    @ObservedObject var store: MoneyStore
    var toast: (String) -> Void = { _ in }

    var body: some View {
        let pending = store.txs.filter { $0.reimbursable && $0.isExpense }
        if !pending.isEmpty {
            let total = pending.reduce(0) { $0 - $1.amountCNY }
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "待报销", subtitle: "共 " + String(pending.count) + " 笔 · " + store.money(total))
                ForEach(pending.prefix(5)) { tx in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.title)
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(Palette.ink.opacity(0.55))
                        }
                        Spacer(minLength: 0)
                        Text(tx.shortAmount)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Palette.ink)
                        Button("核销") { settle(tx) }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(Palette.primary)
                    }
                }
                if pending.count > 5 {
                    Text("还有 " + String(pending.count - 5) + " 笔待报销")
                        .font(.caption2)
                        .foregroundStyle(Palette.ink.opacity(0.55))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.card, strong: true)
        }
    }

    /// 核销：标记完成 + 记一笔等额收入（报销到账）
    private func settle(_ tx: Tx) {
        var target = tx
        target.reimbursable = false
        store.update(target)
        let income = Tx(title: "报销到账 · " + tx.title,
                        amount: abs(tx.amountCNY),
                        category: "其他",
                        date: Date(),
                        merchant: tx.merchant,
                        note: "报销核销",
                        kind: .income,
                        accountID: tx.accountID,
                        updatedAt: Date(),
                        memberName: store.myName)
        store.add(income)
        Haptics.success()
        toast("已核销并记入报销到账")
    }
}

// MARK: - 信用卡工具 + 记账习惯

struct CreditToolsCard: View {
    @ObservedObject var store: MoneyStore

    var body: some View {
        let cards = store.activeAccounts.filter { $0.kind == .credit }
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "信用卡助手", subtitle: "免息期与还款顺序")
                ForEach(cards) { account in
                    let summary = store.creditSummary(for: account)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(account.displayName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            if summary.hasLimit {
                                Text("已用 " + store.money(summary.used))
                                    .font(.caption)
                                    .foregroundStyle(Palette.ink.opacity(0.65))
                            }
                        }
                        if let tip = Self.interestFreeTip(account, summary: summary) {
                            Text(tip)
                                .font(.caption2)
                                .foregroundStyle(Palette.primary)
                        }
                        if let days = summary.daysToDue {
                            Text(days <= 0 ? "今天到期" : "距还款 " + String(days) + " 天 · 本期 " + store.money(summary.currentBill))
                                .font(.caption2)
                                .foregroundStyle(days <= 7 ? Palette.rose : Palette.ink.opacity(0.6))
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text(Self.repaymentOrderTip(store, cards))
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.card, strong: true)
        }
    }

    /// 免息期：账单日之后刷，免息最长
    static func interestFreeTip(_ account: Account, summary: CreditSummary) -> String? {
        guard account.statementDay > 0 else { return nil }
        let cal = Calendar.current
        let today = cal.component(.day, from: Date())
        let statement = account.statementDay
        let due = account.dueDay > 0 ? account.dueDay : statement + 20
        if today > statement {
            let days = (30 - today) + due
            return "今天刷卡最长免息约 " + String(max(days, 0)) + " 天（账单日 " + String(statement) + " 号）"
        }
        let wait = statement - today
        return "再等 " + String(max(wait, 0)) + " 天到账单日，刷这张卡免息能多赚约 20 天"
    }

    /// 还款顺序：本期账单大、临近到期的优先
    static func repaymentOrderTip(_ store: MoneyStore, _ cards: [Account]) -> String {
        let ranked = cards.map { ($0, store.creditSummary(for: $0)) }
            .sorted { ($0.1.daysToDue ?? 999) < ($1.1.daysToDue ?? 999) }
        guard let first = ranked.first else { return "" }
        return "优先还：" + first.0.displayName + "（距今 " + String(first.1.daysToDue ?? 0) + " 天，账单 " + store.money(first.1.currentBill) + "）"
    }
}

struct HabitCard: View {
    @ObservedObject var store: MoneyStore

    var body: some View {
        let streak = Self.streak(store)
        let biggest = store.biggestExpense
        let activeDays = store.activeDays
        HStack(spacing: 12) {
            metric(icon: "flame.fill", title: "连续记账", value: String(streak) + " 天")
            metric(icon: "calendar", title: "本月记账", value: String(activeDays) + " 天")
            metric(icon: "arrow.up.right", title: "最贵一笔",
                   value: biggest.map { store.money(abs($0.amountCNY)) } ?? "—")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func metric(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.primary)
            Text(title)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.6))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 连续记账天数
    static func streak(_ store: MoneyStore) -> Int {
        let cal = Calendar.current
        let days = Set(store.txs.map { cal.startOfDay(for: $0.date) })
        var count = 0
        var cursor = cal.startOfDay(for: Date())
        while days.contains(cursor) {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
