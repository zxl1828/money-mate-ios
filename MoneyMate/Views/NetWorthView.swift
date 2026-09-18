import SwiftUI

private struct AccountGroup: Identifiable {
    let kind: AccountKind
    let accounts: [Account]
    var id: String { kind.rawValue }
}

private struct CreditReminderItem: Identifiable {
    let account: Account
    let summary: CreditSummary
    var id: UUID { account.id }
}

// MARK: - 资产页（账户 / 信用卡 / 净值）

struct NetWorthPage: View {
    @ObservedObject var store: MoneyStore

    @State private var showEditor = false
    @State private var editingAccount: Account?
    @State private var showTransfer = false
    @State private var detailAccount: Account?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                netWorthCard
                CreditReminderCard(store: store)
                actionRow
                accountGroups
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showEditor) {
            AccountEditorSheet(store: store, editing: nil)
        }
        .sheet(item: $editingAccount) { account in
            AccountEditorSheet(store: store, editing: account)
        }
        .sheet(isPresented: $showTransfer) {
            TransferSheet(store: store)
        }
        .sheet(item: $detailAccount) { account in
            AccountDetailSheet(store: store, account: account)
        }
    }

    // MARK: 净值卡

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("净资产")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
            Text(store.money(store.netWorthValue))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            HStack(spacing: 12) {
                metric(title: "总资产", value: store.money(store.totalAssets))
                metric(title: "总负债", value: store.money(store.totalLiabilities))
            }
            chart(store.netWorthSeries(months: 6))
            HStack {
                Text("近 6 个月")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let last = store.netWorthSeries(months: 6).last, let first = store.netWorthSeries(months: 6).first {
                    let delta = last.net - first.net
                    Text((delta >= 0 ? "+" : "") + store.money(delta))
                        .font(.system(size: 10, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.hero, in: squircle(Radius.hero))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    private func chart(_ points: [NetWorthPoint]) -> some View {
        let values = points.map(\.net)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, 1)
        let stepX: CGFloat = points.count > 1 ? (280 / CGFloat(points.count - 1)) : 280
        return Canvas { context, size in
            guard points.count > 1 else { return }
            let scaleX = size.width / 280
            var line = Path()
            var area = Path()
            for (index, point) in points.enumerated() {
                let x = CGFloat(index) * stepX * scaleX
                let ratio = CGFloat((point.net - minValue) / span)
                let y = size.height * (1 - ratio * 0.82) - size.height * 0.09
                if index == 0 {
                    line.move(to: CGPoint(x: x, y: y))
                    area.move(to: CGPoint(x: x, y: size.height))
                    area.addLine(to: CGPoint(x: x, y: y))
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                    area.addLine(to: CGPoint(x: x, y: y))
                }
                if index == points.count - 1 {
                    area.addLine(to: CGPoint(x: x, y: size.height))
                    area.closeSubpath()
                }
            }
            context.fill(area, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(.white), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 88)
    }

    // MARK: 操作

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                showEditor = true
            } label: {
                Label("新建账户", systemImage: "plus.circle.fill")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: Radius.button))

            Button {
                showTransfer = true
            } label: {
                Label("转账 / 还款", systemImage: "arrow.left.arrow.right")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .innerTile(Radius.button, opacity: 0.12)
        }
    }

    // MARK: 账户分组

    private var groupedAccounts: [AccountGroup] {
        AccountKind.allCases.compactMap { kind in
            let items = store.activeAccounts.filter { $0.kind == kind }
            return items.isEmpty ? nil : AccountGroup(kind: kind, accounts: items)
        }
    }

    @ViewBuilder
    private var accountGroups: some View {
        if groupedAccounts.isEmpty {
            VStack(spacing: 8) {
                Text("还没有账户")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("点上面的「新建账户」，把现金、银行卡、信用卡都加进来")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .glassPanel(Radius.card, strong: true)
        } else {
            ForEach(groupedAccounts) { group in
                groupCard(kind: group.kind, accounts: group.accounts)
            }
        }
    }

    private func groupCard(kind: AccountKind, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: kind.title, subtitle: "共 " + String(accounts.count) + " 个")
            ForEach(accounts) { account in
                row(account)
                if account.id != accounts.last?.id {
                    Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func row(_ account: Account) -> some View {
        Button {
            detailAccount = account
        } label: {
            rowLabel(account)
        }
        .buttonStyle(.plain)
    }

    /// 拆成独立小函数，避免类型检查器超时
    private func rowLabel(_ account: Account) -> some View {
        let balance: Double = store.balance(of: account.id)
        let summary: CreditSummary? = account.kind == .credit ? store.creditSummary(for: account) : nil
        return VStack(alignment: .leading, spacing: 8) {
            topLine(account: account, balance: balance, limit: summary?.limit)
            if let summary, summary.hasLimit {
                creditLine(summary)
            }
        }
    }

    private func topLine(account: Account, balance: Double, limit: Double?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.primary)
                .frame(width: 36, height: 36)
                .background(Palette.primary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if let limit {
                    Text("额度 " + store.money(limit))
                        .font(.caption2)
                        .foregroundStyle(Palette.ink.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
            Text(store.money(balance))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(balance < 0 ? Palette.rose : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.35))
        }
    }

    private func creditLine(_ summary: CreditSummary) -> some View {
        let usedText: String = "已用 " + store.money(summary.used) + " \u{00B7} 可用 " + store.money(summary.available)
        let dueText: String = summary.daysToDue.map { " \u{00B7} 距还款 " + String($0) + " 天" } ?? ""
        let ratio: Double = summary.usage
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.primary.opacity(0.15))
                    Capsule().fill(Palette.hero).frame(width: max(geo.size.width * ratio, 4))
                }
            }
            .frame(height: 6)
            Text(usedText + dueText)
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.55))
        }
    }
}

// MARK: - 信用卡还款提醒

struct CreditReminderCard: View {
    @ObservedObject var store: MoneyStore

    private var items: [CreditReminderItem] {
        store.activeAccounts
            .filter { $0.kind == .credit }
            .map { CreditReminderItem(account: $0, summary: store.creditSummary(for: $0)) }
            .sorted { ($0.summary.daysToDue ?? 999) < ($1.summary.daysToDue ?? 999) }
    }

    @ViewBuilder
    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "信用卡还款", subtitle: "按剩余天数排序")
                ForEach(items) { item in
                    HStack(spacing: 12) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                            .frame(width: 32, height: 32)
                            .background(Palette.primary.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.account.displayName)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(item.summary.dueDate.map { "还款日 " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "未设置还款日")
                                .font(.caption2)
                                .foregroundStyle(Palette.ink.opacity(0.55))
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(store.money(item.summary.currentBill))
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(Palette.ink)
                            if let days = item.summary.daysToDue {
                                Text(days <= 0 ? "今天到期" : "还剩 " + String(days) + " 天")
                                    .font(.caption2)
                                    .foregroundStyle(days <= 7 ? Palette.rose : Palette.ink.opacity(0.55))
                            }
                        }
                    }
                    if item.id != items.last?.id {
                        Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.card, strong: true)
        }
    }
}

// MARK: - 新建 / 编辑账户

struct AccountEditorSheet: View {
    @ObservedObject var store: MoneyStore
    var editing: Account? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: AccountKind = .wallet
    @State private var currency: Currency = .cny
    @State private var initialText = "0"
    @State private var cardTail = ""
    @State private var limitText = ""
    @State private var statementDay = 0
    @State private var dueDay = 0
    @State private var archived = false
    @State private var confirmDelete = false

    init(store: MoneyStore, editing: Account?) {
        self.store = store
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _kind = State(initialValue: editing?.kind ?? .wallet)
        _currency = State(initialValue: editing?.currency ?? .cny)
        _initialText = State(initialValue: editing.map { String(format: "%.2f", $0.initialBalance) } ?? "0")
        _cardTail = State(initialValue: editing?.cardTail ?? "")
        _limitText = State(initialValue: editing.map { $0.creditLimit > 0 ? String(format: "%.0f", $0.creditLimit) : "" } ?? "")
        _statementDay = State(initialValue: editing?.statementDay ?? 0)
        _dueDay = State(initialValue: editing?.dueDay ?? 0)
        _archived = State(initialValue: editing?.archived ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    card {
                        Text("账户名称").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        TextField("例如：招商银行储蓄卡", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .innerTile(Radius.chip, opacity: 0.10)

                        Text("类型").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        Picker("类型", selection: $kind) {
                            ForEach(AccountKind.allCases) { item in
                                Label(item.title, systemImage: item.icon).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Palette.primary)
                    }

                    card {
                        Text("初始余额").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        TextField("0.00", text: $initialText)
                            .keyboardType(.numbersAndPunctuation)
                            .textFieldStyle(.plain)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .innerTile(Radius.chip, opacity: 0.10)
                        Text("信用卡 / 借入请填负数（欠款金额）")
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.5))

                        Text("币种").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        Picker("币种", selection: $currency) {
                            ForEach(Currency.allCases) { item in
                                Text(item.name).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Palette.primary)
                    }

                    card {
                        Text("卡号后四位").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        TextField("可选", text: $cardTail)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .innerTile(Radius.chip, opacity: 0.10)

                        if kind == .credit {
                            Text("信用额度").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                            TextField("例如：30000", text: $limitText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .font(.system(.subheadline, design: .rounded))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .innerTile(Radius.chip, opacity: 0.10)

                            HStack {
                                Text("账单日").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                                Spacer()
                                Picker("账单日", selection: $statementDay) {
                                    Text("未设置").tag(0)
                                    ForEach(1...28, id: \.self) { day in
                                        Text(String(day) + " 号").tag(day)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Palette.primary)
                            }
                            HStack {
                                Text("还款日").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                                Spacer()
                                Picker("还款日", selection: $dueDay) {
                                    Text("未设置").tag(0)
                                    ForEach(1...28, id: \.self) { day in
                                        Text(String(day) + " 号").tag(day)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Palette.primary)
                            }
                        }
                    }

                    if editing != nil {
                        Toggle(isOn: $archived) {
                            Label("归档（不计入净值）", systemImage: "archivebox.fill")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Palette.ink)
                        }
                        .tint(Palette.primary)
                        .padding(16)
                        .glassPanel(Radius.card, strong: true)
                    }

                    Button(action: save) {
                        Text(editing == nil ? "创建账户" : "保存修改")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: Radius.button))

                    if let editing {
                        Button {
                            confirmDelete = true
                        } label: {
                            Label("删除账户", systemImage: "trash")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.rose)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("删除「" + editing.name + "」？该账户的流水会保留但不再归属账户。",
                                            isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("删除", role: .destructive) {
                                store.deleteAccount(editing)
                                dismiss()
                            }
                            Button("取消", role: .cancel) { }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle(editing == nil ? "新建账户" : "编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.card, strong: true)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let balance = Double(initialText.trimmingCharacters(in: .whitespaces)) ?? 0
        let limit = Double(limitText.trimmingCharacters(in: .whitespaces)) ?? 0
        var account = editing ?? Account(name: trimmed, kind: kind)
        account.name = trimmed
        account.kind = kind
        account.currency = currency
        account.initialBalance = balance
        account.cardTail = cardTail.trimmingCharacters(in: .whitespaces)
        account.creditLimit = kind == .credit ? limit : 0
        account.statementDay = kind == .credit ? statementDay : 0
        account.dueDay = kind == .credit ? dueDay : 0
        account.archived = archived
        if editing == nil {
            store.addAccount(account)
        } else {
            store.updateAccount(account)
        }
        dismiss()
    }
}

// MARK: - 转账 / 信用卡还款

struct TransferSheet: View {
    @ObservedObject var store: MoneyStore
    var presetFrom: UUID? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var error: String?

    private var fromAccount: Account? { store.account(fromID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("转出账户").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        accountPicker(selection: $fromID)
                        Text("转入账户").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        accountPicker(selection: $toID)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(Radius.card, strong: true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("金额").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .innerTile(Radius.chip, opacity: 0.10)
                        DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .font(.system(.subheadline, design: .rounded))
                        TextField("备注（可选）", text: $note)
                            .textFieldStyle(.plain)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .innerTile(Radius.chip, opacity: 0.10)
                        if let fromAccount, fromAccount.kind == .credit {
                            Text("信用卡转出会记为取现，请确认手续费")
                                .font(.caption2)
                                .foregroundStyle(Palette.rose)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(Radius.card, strong: true)

                    if let error {
                        Text(error)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Palette.rose)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: submit) {
                        Text("确认转账")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: Radius.button))
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .onAppear {
            if fromID == nil { fromID = presetFrom ?? store.activeAccounts.first?.id }
            if toID == nil { toID = store.activeAccounts.first(where: { $0.id != fromID })?.id }
        }
    }

    private var title: String {
        if let to = store.account(toID), to.kind == .credit { return "还信用卡" }
        return "转账"
    }

    private func accountPicker(selection: Binding<UUID?>) -> some View {
        Menu {
            ForEach(store.activeAccounts) { account in
                Button {
                    selection.wrappedValue = account.id
                } label: {
                    Text(account.displayName + " \u{00B7} " + store.money(store.balance(of: account.id)))
                }
            }
        } label: {
            HStack {
                Text(store.account(selection.wrappedValue)?.displayName ?? "请选择")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .innerTile(Radius.chip, opacity: 0.10)
        }
    }

    private func submit() {
        guard let fromID, let toID else {
            error = "请选择转出与转入账户"
            return
        }
        guard fromID != toID else {
            error = "转出与转入不能是同一个账户"
            return
        }
        guard let amount = Double(amountText.trimmingCharacters(in: .whitespaces)), amount > 0 else {
            error = "请输入大于 0 的金额"
            return
        }
        store.addTransfer(from: fromID, to: toID, amount: amount, date: date,
                          note: note, member: store.myName)
        Haptics.success()
        dismiss()
    }
}

// MARK: - 账户详情

struct AccountDetailSheet: View {
    @ObservedObject var store: MoneyStore
    let account: Account

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    if account.kind == .credit { creditCard }
                    txCard
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle(account.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 8) {
            Image(systemName: account.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Palette.hero, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            Text(account.kind.title)
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.6))
            Text(store.money(store.balance(of: account.id)))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(store.balance(of: account.id) < 0 ? Palette.rose : Palette.ink)
            Text("初始余额 " + store.money(account.initialBalance))
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.5))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassPanel(Radius.card, strong: true)
    }

    private var creditCard: some View {
        let summary = store.creditSummary(for: account)
        return VStack(spacing: 12) {
            SectionHeader(title: "账单与额度", subtitle: summary.dueDate.map {
                "还款日 " + $0.formatted(date: .abbreviated, time: .omitted)
            } ?? "未设置还款日")
            HStack(spacing: 12) {
                tile(title: "本期账单", value: store.money(summary.currentBill))
                tile(title: "已用额度", value: store.money(summary.used))
                tile(title: "可用额度", value: store.money(summary.available))
            }
            if let days = summary.daysToDue {
                Text(days <= 0 ? "今天到期，记得还款" : "距还款日还有 " + String(days) + " 天")
                    .font(.caption)
                    .foregroundStyle(days <= 7 ? Palette.rose : Palette.ink.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func tile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .innerTile(Radius.chip, opacity: 0.10)
    }

    private var txCard: some View {
        let items = store.txs(of: account.id)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "流水", subtitle: "共 " + String(items.count) + " 笔")
            if items.isEmpty {
                Text("这个账户还没有流水")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.55))
            } else {
                ForEach(items.prefix(60)) { tx in
                    HStack(spacing: 10) {
                        Image(systemName: store.categoryIcon(tx.category))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                            .frame(width: 30, height: 30)
                            .background(Palette.primary.opacity(0.10), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.title)
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Text(tx.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Palette.ink.opacity(0.5))
                        }
                        Spacer(minLength: 0)
                        Text(tx.shortAmount)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(tx.isIncome ? Palette.mint : Palette.ink)
                    }
                    if tx.id != items.prefix(60).last?.id {
                        Rectangle().fill(Palette.ink.opacity(0.06)).frame(height: 1)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }
}
