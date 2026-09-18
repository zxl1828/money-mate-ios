import SwiftUI

// MARK: - 余额对账

struct ReconcileCard: View {
    @ObservedObject var store: MoneyStore
    @State private var target: Account?
    @State private var amountText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "余额对账", subtitle: "拿真实余额对一次，差额记成调整")
            ForEach(store.activeAccounts) { account in
                HStack(spacing: 10) {
                    Image(systemName: account.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                    Text(account.displayName)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    Text(store.money(store.balance(of: account.id)))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.7))
                    Button("对账") {
                        amountText = String(format: "%.2f", store.balance(of: account.id))
                        target = account
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.primary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .sheet(item: $target) { account in
            ReconcileSheet(store: store, account: account, text: amountText)
        }
    }
}

struct ReconcileSheet: View {
    @ObservedObject var store: MoneyStore
    let account: Account
    @State var text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("在银行/支付宝里看到的真实余额填进来，差额会自动记成「余额调整」。")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("真实余额", text: $text)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .innerTile(Radius.chip, opacity: 0.10)
                Button {
                    reconcile()
                } label: {
                    Text("生成调整")
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func reconcile() {
        guard let real = Double(text.trimmingCharacters(in: .whitespaces)) else { return }
        let diff = real - store.balance(of: account.id)
        guard abs(diff) > 0.005 else {
            Haptics.tap()
            dismiss()
            return
        }
        let tx = Tx(title: "余额调整",
                    amount: diff,
                    category: "余额调整",
                    date: Date(),
                    note: "对账差额",
                    kind: diff >= 0 ? .income : .expense,
                    accountID: account.id,
                    updatedAt: Date(),
                    memberName: store.myName)
        store.add(tx)
        Haptics.success()
        dismiss()
    }
}

// MARK: - 分期管理

struct InstallmentPlan: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var total: Double
    var months: Int
    var paid: Int = 0
    var accountID: UUID?

    var monthly: Double { months > 0 ? total / Double(months) : total }
    var remaining: Int { max(months - paid, 0) }
}

enum InstallmentStore {
    private static let key = "moneymate.installments.v1"

    static func load() -> [InstallmentPlan] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([InstallmentPlan].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [InstallmentPlan]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct InstallmentCard: View {
    @ObservedObject var store: MoneyStore
    @State private var plans = InstallmentStore.load()
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "分期付款", subtitle: plans.isEmpty ? "把大额消费拆成月供" : "每月点一下记本期") {
                showEditor = true
            }
            if plans.isEmpty {
                Text("例如：手机 ¥5999 分 12 期，每月 ¥499")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            } else {
                ForEach(plans) { plan in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text("月供 " + store.money(plan.monthly) + " · 还剩 " + String(plan.remaining) + " 期")
                                .font(.caption2)
                                .foregroundStyle(Palette.ink.opacity(0.6))
                        }
                        Spacer(minLength: 0)
                        if plan.remaining > 0 {
                            Button("记本期") { post(plan) }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(Palette.primary)
                        } else {
                            Text("已还清").font(.caption2).foregroundStyle(Palette.mint)
                        }
                        Button {
                            plans.removeAll { $0.id == plan.id }
                            InstallmentStore.save(plans)
                        } label: {
                            Image(systemName: "trash").font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.rose)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .sheet(isPresented: $showEditor) {
            InstallmentEditorSheet(store: store) { plan in
                plans.append(plan)
                InstallmentStore.save(plans)
                Haptics.success()
            }
        }
    }

    private func post(_ plan: InstallmentPlan) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        let tx = Tx(title: plan.name + " 第" + String(plan.paid + 1) + "期",
                    amount: -plan.monthly,
                    category: "分期",
                    date: Date(),
                    note: "分期月供",
                    kind: .expense,
                    accountID: plan.accountID ?? store.activeAccounts.first?.id,
                    updatedAt: Date(),
                    memberName: store.myName)
        store.add(tx)
        plans[index].paid += 1
        InstallmentStore.save(plans)
        Haptics.success()
    }
}

struct InstallmentEditorSheet: View {
    @ObservedObject var store: MoneyStore
    var onSaved: (InstallmentPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var totalText = ""
    @State private var months = 12
    @State private var accountID: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField("名称（如：iPhone）", text: $name)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .innerTile(Radius.chip, opacity: 0.10)
                TextField("总金额", text: $totalText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .innerTile(Radius.chip, opacity: 0.10)
                Picker("期数", selection: $months) {
                    ForEach([3, 6, 9, 12, 18, 24, 36], id: \.self) { m in
                        Text(String(m) + " 期").tag(m)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.primary)
                Picker("账户", selection: $accountID) {
                    Text("默认").tag(UUID?.none)
                    ForEach(store.activeAccounts) { account in
                        Text(account.displayName).tag(UUID?.some(account.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.primary)
                Button {
                    let total = Double(totalText.trimmingCharacters(in: .whitespaces)) ?? 0
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty, total > 0 else { return }
                    onSaved(InstallmentPlan(name: name.trimmingCharacters(in: .whitespaces),
                                            total: total,
                                            months: months,
                                            accountID: accountID))
                    dismiss()
                } label: {
                    Text("创建分期")
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
            .navigationTitle("新建分期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 预算结转

struct RolloverCard: View {
    @ObservedObject var store: MoneyStore
    @AppStorage("moneymate.budget.rollover") private var rollover = false

    private var lastMonthExpense: Double {
        let cal = Calendar.current
        guard let last = cal.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        return store.txs
            .filter { $0.isExpense && cal.isDate($0.date, equalTo: last, toGranularity: .month) }
            .reduce(0) { $0 - $1.amountCNY }
    }

    var body: some View {
        let left = max(store.budget - lastMonthExpense, 0)
        let effective = store.budget + (rollover ? left : 0)
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "预算结转", subtitle: rollover ? "上月结余滚入本月" : "每月预算清零")
            Toggle(isOn: $rollover) {
                Text("把上月没花完的预算滚到本月")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.primary)
            Text("上月结余 " + store.money(left) + " · 本月可用 " + store.money(effective))
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.65))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }
}

// MARK: - 拆分成多笔（多分类）

struct SplitSheet: View {
    @ObservedObject var store: MoneyStore
    let tx: Tx
    @Environment(\.dismiss) private var dismiss

    @State private var firstCategory = "餐饮"
    @State private var firstAmount = ""
    @State private var secondCategory = "购物"

    var body: some View {
        let total = abs(tx.amountCNY)
        let first = Double(firstAmount.trimmingCharacters(in: .whitespaces)) ?? 0
        let second = max(total - first, 0)
        NavigationStack {
            VStack(spacing: 16) {
                Text("把这一笔（" + store.money(total) + "）拆成两笔，各自进不同分类")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                categoryPicker(title: "第一笔分类", selection: $firstCategory)
                TextField("第一笔金额", text: $firstAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .innerTile(Radius.chip, opacity: 0.10)
                categoryPicker(title: "第二笔分类", selection: $secondCategory)
                Text("第二笔自动为 " + store.money(second))
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    split(first: first, second: second)
                } label: {
                    Text("确认拆分")
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
            .navigationTitle("拆分这笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func categoryPicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            Picker(title, selection: selection) {
                ForEach(store.expenseCategories) { item in
                    Text(item.name).tag(item.name)
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func split(first: Double, second: Double) {
        guard first > 0, second > 0 else { return }
        var a = tx
        a.category = firstCategory
        a.amount = -first
        a.rate = 1
        a.updatedAt = Date()
        var b = tx
        b.id = UUID()
        b.category = secondCategory
        b.amount = -second
        b.rate = 1
        b.updatedAt = Date()
        store.delete(tx)
        store.add(a)
        store.add(b)
        Haptics.success()
        dismiss()
    }
}

// MARK: - 月度账单长图

struct ShareReportCard: View {
    @ObservedObject var store: MoneyStore
    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "月度账单", subtitle: "生成一张图，发给家人或存下来")
            HStack(spacing: 10) {
                Button {
                    render()
                } label: {
                    Label("生成账单图", systemImage: "photo")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .liquidGlass(.clear.interactive(), in: Capsule())

                if let image {
                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview("月度账单", image: Image(uiImage: image))) {
                        Label("分享", systemImage: "square.and.arrow.up")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(.regular.tint(Palette.glassTint).interactive(), in: Capsule())
                }
            }
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(squircle(Radius.chip))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    @MainActor
    private func render() {
        let view = MonthReportView(store: store)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        image = renderer.uiImage
        Haptics.success()
    }
}

struct MonthReportView: View {
    @ObservedObject var store: MoneyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.money(store.expense))
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("本月支出")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.categoryTotals().prefix(5)) { item in
                    HStack {
                        Text(item.label)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text(store.money(item.value))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            if let biggest = store.biggestExpense {
                Text("最贵一笔：" + biggest.title + " " + store.money(abs(biggest.amountCNY)))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text("MoneyMate · " + Date().formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(24)
        .frame(width: 390, alignment: .leading)
        .background(Palette.hero)
    }
}
