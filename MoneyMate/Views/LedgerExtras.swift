import SwiftUI

// MARK: - 借还台账 + AA 分账 + 旅行模式

enum LedgerFlags {
    private static let tripKey = "moneymate.trip.mode"

    static var tripMode: Bool {
        get { UserDefaults.standard.bool(forKey: tripKey) }
        set { UserDefaults.standard.set(newValue, forKey: tripKey) }
    }
}

/// 借出 / 借入 台账：余额 + 一键结清
struct DebtTrackerCard: View {
    @ObservedObject var store: MoneyStore
    var toast: (String) -> Void = { _ in }
    @State private var settleTarget: Account?

    private var debts: [Account] {
        store.activeAccounts.filter { $0.kind == .receivable || $0.kind == .payable }
    }

    var body: some View {
        Group {
            if !debts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "借还台账", subtitle: "别人欠我 / 我欠别人")
                    ForEach(debts) { account in
                        let balance = store.balance(of: account.id)
                        HStack(spacing: 10) {
                            Image(systemName: account.kind == .receivable ? "hand.raised.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(account.kind == .receivable ? Palette.mint : Palette.rose)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName)
                                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Palette.ink)
                                Text(account.kind == .receivable ? "待收回" : "待还出")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.ink.opacity(0.55))
                            }
                            Spacer(minLength: 0)
                            Text(store.money(abs(balance)))
                                .font(.system(.footnote, design: .rounded).weight(.bold))
                                .foregroundStyle(Palette.ink)
                            if abs(balance) > 0.01 {
                                Button("结清") { settleTarget = account }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Palette.primary)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(Radius.card, strong: true)
                .sheet(item: $settleTarget) { account in
                    SettleSheet(store: store, account: account) { amount in
                        settle(account, amount: amount)
                    }
                }
            }
        }
    }

    /// 结清：钱回到/离开主账户
    private func settle(_ account: Account, amount: Double) {
        guard let main = store.activeAccounts.first(where: { $0.id != account.id }) else { return }
        if account.kind == .receivable {
            // 别人还我：从「借出账户」转回主账户
            store.addTransfer(from: account.id, to: main.id, amount: amount, note: "收回借款", member: store.myName)
        } else {
            store.addTransfer(from: main.id, to: account.id, amount: amount, note: "还款", member: store.myName)
        }
        Haptics.success()
        toast("已结清 " + store.money(amount))
    }
}

struct SettleSheet: View {
    @ObservedObject var store: MoneyStore
    let account: Account
    var onSettle: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("结清金额（默认全部）")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("0.00", text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .innerTile(Radius.chip, opacity: 0.10)
                Button {
                    let value = Double(text.trimmingCharacters(in: .whitespaces)) ?? abs(store.balance(of: account.id))
                    onSettle(abs(value))
                    dismiss()
                } label: {
                    Text("确认结清")
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
            .navigationTitle(account.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                text = String(format: "%.2f", abs(store.balance(of: account.id)))
            }
        }
    }
}

/// AA 分账：把一笔账按人数拆，我只承担 1/N
struct AASplitSheet: View {
    @ObservedObject var store: MoneyStore
    let tx: Tx

    @Environment(\.dismiss) private var dismiss
    @State private var people = 2

    var body: some View {
        let total = abs(tx.amountCNY)
        let mine = total / Double(people)
        NavigationStack {
            VStack(spacing: 16) {
                Text("这笔 " + store.money(total) + " 由几个人分摊？")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Stepper("共 " + String(people) + " 人", value: $people, in: 2...20)
                    .font(.system(.subheadline, design: .rounded))
                VStack(alignment: .leading, spacing: 6) {
                    Text("我承担 " + store.money(mine))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("别人欠我 " + store.money(total - mine))
                        .font(.caption)
                        .foregroundStyle(Palette.mint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    apply(total: total, mine: mine)
                } label: {
                    Text("确认分摊")
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
            .navigationTitle("AA 分摊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func apply(total: Double, mine: Double) {
        // 我的支出改成我的那份
        var reduced = tx
        reduced.amount = -mine
        reduced.rate = 1
        reduced.updatedAt = Date()
        store.update(reduced)

        // 别人欠我的部分进「借出」账户
        var lender = store.activeAccounts.first { $0.kind == .receivable }
        if lender == nil {
            let account = Account(name: "AA 垫付", kind: .receivable)
            store.addAccount(account)
            lender = store.accounts.first { $0.name == "AA 垫付" }
        }
        if let lender {
            store.add(Tx(title: "AA 垫付 · " + tx.title,
                         amount: total - mine,
                         category: "其他",
                         date: Date(),
                         merchant: tx.merchant,
                         note: "AA 分摊应收",
                         kind: .income,
                         accountID: lender.id,
                         updatedAt: Date(),
                         memberName: store.myName))
        }
        Haptics.success()
        dismiss()
    }
}

/// 旅行模式
struct TripModeCard: View {
    @ObservedObject var store: MoneyStore
    @AppStorage("moneymate.trip.mode") private var trip = false

    private var tripTxs: [Tx] {
        store.txs.filter { $0.tags.contains("旅行") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "旅行模式", subtitle: trip ? "新记的账自动打「旅行」标签" : "出行时打开，账目单独统计")
            Toggle(isOn: $trip) {
                Text("开启旅行模式")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.primary)
            if !tripTxs.isEmpty {
                let total = tripTxs.filter { $0.isExpense }.reduce(0) { $0 - $1.amountCNY }
                Text("旅行账共 " + String(tripTxs.count) + " 笔 · 合计 " + store.money(total))
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.65))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }
}
