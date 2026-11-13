import SwiftUI

// MARK: - 家庭财务中心

struct FamilyCenterPage: View {
    @ObservedObject var store: MoneyStore
    @ObservedObject private var book = FinanceBook.shared
    @ObservedObject private var accounting = AccountingBook.shared

    @State private var tab = 0
    @State private var editingPolicy: InsurancePolicy?
    @State private var addingPolicy = false
    @State private var editingGoal: MoneyGoal?
    @State private var addingGoal = false
    @State private var editingScenario: FinanceScenario?
    @State private var addingScenario = false
    @State private var showTax = false

    private let tabs = ["保障", "税务", "目标", "情景", "归因"]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                tabBar
                switch tab {
                case 0: protectionBody
                case 1: taxBody
                case 2: goalBody
                case 3: scenarioBody
                default: attributionBody
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .background(Color.clear)
        .navigationTitle("家庭财务中心")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { capture() }
        .sheet(isPresented: $addingPolicy) {
            PolicyEditor(policy: nil) { item in book.upsertPolicy(item) }
        }
        .sheet(item: $editingPolicy) { item in
            PolicyEditor(policy: item) { updated in book.upsertPolicy(updated) } onDelete: {
                book.deletePolicy(item.id)
            }
        }
        .sheet(isPresented: $addingGoal) {
            GoalEditor(goal: nil) { item in book.upsertGoal(item) }
        }
        .sheet(item: $editingGoal) { item in
            GoalEditor(goal: item) { updated in book.upsertGoal(updated) } onDelete: {
                book.deleteGoal(item.id)
            }
        }
        .sheet(isPresented: $addingScenario) {
            ScenarioEditor(scenario: nil) { item in book.upsertScenario(item) }
        }
        .sheet(item: $editingScenario) { item in
            ScenarioEditor(scenario: item) { updated in book.upsertScenario(updated) } onDelete: {
                book.deleteScenario(item.id)
            }
        }
        .sheet(isPresented: $showTax) {
            TaxEditor(profile: book.tax) { item in book.tax = item }
        }
    }

    // MARK: 基础数据

    private var txs: [Tx] { store.scopedTxs }
    private var accounts: [Account] { store.accounts.filter { !$0.archived } }

    private var liquidAssets: Double {
        accounts.filter { $0.kind == .cash || $0.kind == .debit || $0.kind == .wallet }
            .reduce(0) { $0 + max(FinanceMath.balance($1, txs: txs), 0) }
    }

    private var totalDebt: Double {
        let netWorth = FinanceMath.netWorth(accounts: accounts, txs: txs)
        let manualDebt = accounting.items.filter { $0.isLiability }.reduce(0) { $0 + $1.value }
        return netWorth.liabilities + manualDebt
    }

    private var monthlySurplus: Double {
        let income = FinanceEngine.incomeMonthly(txs)
        let expense = FinanceEngine.monthlyAverage(txs, root: nil, months: 3, type: .expense)
        return income - expense
    }

    private func capture() {
        let netWorth = FinanceMath.netWorth(accounts: accounts, txs: txs)
        let manual = accounting.items.filter { !$0.isLiability }.reduce(0) { $0 + $1.value }
            - accounting.items.filter { $0.isLiability }.reduce(0) { $0 + $1.value }
        book.captureSnapshot(assets: netWorth.assets, liabilities: netWorth.liabilities, manual: manual)
    }

    // MARK: 组件

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, name in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { tab = index }
                    Haptics.select()
                } label: {
                    Text(name)
                        .font(.system(size: 12, weight: tab == index ? .semibold : .regular))
                        .foregroundStyle(tab == index ? Palette.primaryDeep : Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            tab == index ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.ink.opacity(0.05), in: Capsule())
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.tile, strong: true)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Palette.textTertiary)
    }

    private func lineRow(_ name: String, _ value: String, sub: String? = nil, color: Color? = nil) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.textSecondary)
                if let sub {
                    Text(sub)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color ?? Palette.textPrimary)
        }
    }

    private func metric(_ title: String, _ value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textTertiary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color ?? Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.lilac.opacity(0.45), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }

    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.13), in: Capsule())
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0: return Palette.textTertiary
        case 1: return Palette.rose
        case 2: return Palette.amberGlow
        case 3: return Palette.mint
        default: return Palette.primary
        }
    }

    // MARK: 保障

    private var protectionBody: some View {
        let gap = FinanceEngine.buildProtectionGap(
            policies: book.policies,
            debts: totalDebt,
            liquidAssets: liquidAssets,
            txs: txs
        )
        return Group {
            card {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gap.gap > 0 ? money(gap.gap) : "无缺口")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(levelColor(gap.level))
                        pill(gap.status, levelColor(gap.level))
                        caption("寿险建议保额 = 家庭负债 + 未来 5 年刚性支出 − 可动用现金；再与「年收入 × 8」取大，打八折作为起步目标。")
                    }
                    Spacer()
                    CoverageRing(ratio: gap.coverageRatio, color: levelColor(gap.level))
                        .frame(width: 86, height: 86)
                }
                HStack(spacing: 8) {
                    metric("建议寿险", store.money(gap.suggested))
                    metric("已有寿险", store.money(gap.existingCoverage))
                }
                HStack(spacing: 8) {
                    metric("重疾缺口", store.money(gap.criticalGap), color: gap.criticalGap > 0 ? Palette.rose : Palette.mint)
                    metric("年保费占比", String(format: "%.1f%%", gap.premiumRatio * 100), color: gap.premiumRatio > 0.1 ? Palette.amberGlow : Palette.textPrimary)
                }
                caption("行业经验：年保费支出建议控制在年收入的 5%~10%，超过 10% 会挤压现金流。")
            }

            card {
                Text("保单台账")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                if book.policies.isEmpty {
                    caption("还没有登记保单。先把手里的寿险 / 重疾险填进来，缺口才算得准。")
                } else {
                    ForEach(book.policies) { policy in
                        Button {
                            editingPolicy = policy
                        } label: {
                            lineRow(
                                "\(InsurancePolicy.label(policy.kind)) · \(policy.name.isEmpty ? "未命名" : policy.name)",
                                store.money(policy.coverage),
                                sub: "年保费 \(store.money(policy.premium))\(policy.holder.isEmpty ? "" : " · 被保人 \(policy.holder)")"
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.35)
                    }
                }
                Button {
                    addingPolicy = true
                    Haptics.tap()
                } label: {
                    Label("添加保单", systemImage: "plus.circle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Palette.primary.opacity(0.12), in: Capsule())
                        .foregroundStyle(Palette.primaryDeep)
                }
                .buttonStyle(.plain)
            }

            card {
                Text("怎么用这份体检")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                caption("① 先补「家庭负债 + 5 年刚性支出」这一块，它决定家人不会因为你的意外而卖房；② 重疾险按 3~5 倍年收入配；③ 医疗险和意外险一年几百块，先买齐；④ 年金类最后考虑，先把保障打满。")
            }
        }
    }

    // MARK: 税务

    private var taxBody: some View {
        let report = FinanceEngine.buildTaxReport(book.tax)
        return Group {
            card {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.money(report.totalSaving))
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Palette.primary)
                        caption("按你填的档案估算，一年大约能省这么多税")
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if report.missingSaving > 0 {
                            pill("还可能多省 \(money(report.missingSaving))", Palette.amberGlow)
                        }
                        Button("编辑档案") { showTax = true }
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Palette.primaryDeep)
                    }
                }
                caption("仅为估算，实际以个税 App 与单位代扣为准；专项附加扣除每人情况不同。")
            }

            card {
                Text("专项附加扣除")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                ForEach(report.lines) { line in
                    lineRow(
                        line.name + (line.claimed ? "" : "（未用）"),
                        "省 \(store.money(line.saving))",
                        sub: line.detail,
                        color: line.claimed ? Palette.textPrimary : Palette.amberGlow
                    )
                }
            }

            card {
                Text("个人养老金")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                lineRow("今年已缴", store.money(min(book.tax.pensionContributed, TaxProfile.pensionLimit)))
                lineRow("当年可省税", store.money(report.pensionSaving), color: Palette.mint)
                caption("每年上限 12000 元，缴费当年按你的边际税率抵扣，领取时本金和收益按 3% 单独计税。高税率人群更划算。")
            }

            if book.tax.annualBonus > 0 {
                card {
                    Text("年终奖怎么计税更省")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    HStack(spacing: 8) {
                        metric("单独计税", store.money(FinanceEngine.bonusSeparateTax(book.tax.annualBonus)))
                        metric("并入综合所得", store.money(FinanceEngine.bonusMergedTax(book.tax.annualBonus, marginalRate: book.tax.marginalRate)))
                    }
                    caption(report.bonusTip)
                }
            }
        }
    }

    // MARK: 目标

    private var goalBody: some View {
        let volatility = FinanceEngine.surplusVolatility(txs)
        let plans = FinanceEngine.buildGoals(book.goals, monthlySurplus: monthlySurplus, volatility: volatility)
        let needTotal = plans.reduce(0) { $0 + $1.requiredMonthly }
        return Group {
            card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每月要存 \(store.money(needTotal))")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        caption("你现在的月结余大约 \(store.money(monthlySurplus))，结余波动约 \(Int(volatility * 100))%")
                    }
                    Spacer()
                    pill(needTotal <= monthlySurplus ? "排得开" : "有点紧", needTotal <= monthlySurplus ? Palette.mint : Palette.amberGlow)
                }
                BulletChart(
                    value: needTotal,
                    target: max(monthlySurplus, 0),
                    maxValue: max(needTotal, monthlySurplus) * 1.15,
                    tint: needTotal <= monthlySurplus ? Palette.mint : Palette.rose
                )
            }

            ForEach(plans) { plan in
                card {
                    HStack {
                        Text(plan.goal.name.isEmpty ? "未命名目标" : plan.goal.name)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        pill(String(format: "达标概率 %.0f%%", plan.probability * 100), plan.probability >= 0.7 ? Palette.mint : (plan.probability >= 0.4 ? Palette.amberGlow : Palette.rose))
                    }
                    BulletChart(value: plan.projected, target: plan.goal.target, tint: Palette.primary)
                    HStack(spacing: 8) {
                        metric("目标", store.money(plan.goal.target))
                        metric("按现速度预计", store.money(plan.projected), color: plan.onTrack ? Palette.mint : Palette.rose)
                    }
                    lineRow("还差", plan.monthsLeft > 0 ? "\(plan.monthsLeft) 个月" : "已到期")
                    lineRow("每月要存", store.money(plan.requiredMonthly), color: Palette.primaryDeep)
                    Button("改一改") { editingGoal = plan.goal }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Palette.primaryDeep)
                }
            }

            Button {
                addingGoal = true
                Haptics.tap()
            } label: {
                Label("添加目标", systemImage: "target")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Palette.hero, in: Capsule())
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 情景

    private var scenarioBody: some View {
        let expense = FinanceEngine.monthlyAverage(txs, root: nil, months: 3, type: .expense)
        let floor = max(expense, 1) * 1.0
        let outcomes = book.scenarios.map {
            FinanceEngine.runScenario($0, currentCash: liquidAssets, monthlyIncome: FinanceEngine.incomeMonthly(txs), monthlyExpense: expense, safeFloor: floor)
        }
        return Group {
            card {
                HStack(spacing: 8) {
                    metric("可动用现金", store.money(liquidAssets))
                    metric("月结余", store.money(monthlySurplus), color: monthlySurplus > 0 ? Palette.mint : Palette.rose)
                }
                caption("情境按月推演：现金 = 上月现金 + 收入×系数 − 支出 − 额外支出，第 1 个月再扣一次性大额。安全线取 1 个月支出。")
            }

            ForEach(outcomes) { outcome in
                card {
                    HStack {
                        Text(outcome.scenario.name)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        pill(outcome.ok ? "撑得住" : "第 \(outcome.breakMonth) 个月破线", outcome.ok ? Palette.mint : Palette.rose)
                    }
                    BulletChart(value: outcome.lowestCash, target: outcome.safeFloor, tint: outcome.ok ? Palette.mint : Palette.rose)
                    HStack(spacing: 8) {
                        metric("最低现金", store.money(outcome.lowestCash), color: outcome.ok ? Palette.textPrimary : Palette.rose)
                        metric("末期现金", store.money(outcome.endCash))
                    }
                    if !outcome.scenario.note.isEmpty { caption(outcome.scenario.note) }
                    Button("改一改") { editingScenario = outcome.scenario }
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Palette.primaryDeep)
                }
            }

            HStack(spacing: 10) {
                Button {
                    addingScenario = true
                    Haptics.tap()
                } label: {
                    Label("自定义情景", systemImage: "plus.circle.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.primary.opacity(0.12), in: Capsule())
                        .foregroundStyle(Palette.primaryDeep)
                }
                .buttonStyle(.plain)

                Button {
                    book.scenarios = FinanceEngine.presetScenarios()
                    Haptics.success()
                } label: {
                    Text("恢复预设")
                        .font(.system(size: 12.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.ink.opacity(0.06), in: Capsule())
                        .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 归因

    private var attributionBody: some View {
        let report = FinanceEngine.buildAttribution(txs: txs, now: book.latestSnapshot, before: book.previousSnapshot)
        let netWorth = FinanceMath.netWorth(accounts: accounts, txs: txs)
        let budgetRows = store.budgetByCategory
            .map { key, value -> DumbbellRow in
                let spent = txs.filter { $0.kind == .expense && $0.category == key && Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }.reduce(0) { $0 + abs($1.amountCNY) }
                return DumbbellRow(label: key, left: value, right: spent)
            }
            .sorted { $0.right - $0.left > $1.right - $1.left }
            .prefix(6)

        return Group {
            card {
                Text(report.delta >= 0 ? "+\(store.money(report.delta))" : store.money(report.delta))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(report.delta >= 0 ? Palette.mint : Palette.rose)
                caption("\(report.month) 净资产变化 · 期初 \(store.money(report.netBefore)) → 期末 \(store.money(report.netNow))")
                WaterfallChart(entries: [
                    WaterfallEntry(label: "储蓄", value: report.saving),
                    WaterfallEntry(label: "还本", value: report.repayment),
                    WaterfallEntry(label: "投资", value: report.investment),
                    WaterfallEntry(label: "合计", value: report.delta),
                ], height: 150, format: { store.money($0) })
                caption("储蓄 = 收入 − 支出；还本 = 还款 − 借入；投资 = 资产买卖价差 + 重估。三项加起来应接近净资产变化，差额就是估值口径差异。")
            }

            if !budgetRows.isEmpty {
                card {
                    Text("预算 vs 实际（本月）")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    DumbbellChart(rows: Array(budgetRows), format: { store.money($0) })
                    caption("红点 = 预算，绿点 = 实际。绿在红右边说明这个分类超了。")
                }
            }

            card {
                HStack(spacing: 8) {
                    metric("总资产", store.money(netWorth.assets))
                    metric("总负债", store.money(netWorth.liabilities + accounting.items.filter { $0.isLiability }.reduce(0) { $0 + $1.value }), color: Palette.rose)
                }
                Button {
                    capture()
                    Haptics.success()
                } label: {
                    Label("记录本月快照", systemImage: "camera.aperture")
                        .font(.system(size: 12.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.primary.opacity(0.12), in: Capsule())
                        .foregroundStyle(Palette.primaryDeep)
                }
                .buttonStyle(.plain)
                caption("已有 \(book.snapshots.count) 份月度快照，最多保留 36 份；同一个月重复记录会覆盖。")
            }

            card {
                Text("最近 14 周支出热度")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                HeatCalendar(values: dailySpending())
                caption("每一列是一周、每一格是一天，颜色越深代表那天花得越多，能一眼看出哪几周失控。")
            }
        }
    }

    private func dailySpending() -> [Double] {
        let cal = Calendar.current
        var days: [Double] = []
        for offset in stride(from: 97, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let total = txs.filter { $0.kind == .expense && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + abs($1.amountCNY) }
            days.append(total)
        }
        return days
    }
}

// MARK: - 覆盖率环

private struct CoverageRing: View {
    let ratio: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.ink.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: CGFloat(min(ratio, 1)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.55), color], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text("\(Int(min(ratio, 1) * 100))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("覆盖率")
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }
}

// MARK: - 保单编辑

private struct PolicyEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: InsurancePolicy
    private let onSave: (InsurancePolicy) -> Void
    private let onDelete: (() -> Void)?

    init(policy: InsurancePolicy?, onSave: @escaping (InsurancePolicy) -> Void, onDelete: (() -> Void)? = nil) {
        _draft = State(initialValue: policy ?? InsurancePolicy())
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    Picker("类型", selection: $draft.kind) {
                        ForEach(InsurancePolicy.kinds, id: \.self) { kind in
                            Text(InsurancePolicy.label(kind)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("基本信息") {
                    TextField("名称，如 平安福 2024", text: $draft.name)
                    TextField("被保人", text: $draft.holder)
                }
                Section("金额") {
                    numberField("保额", value: $draft.coverage)
                    numberField("年保费", value: $draft.premium)
                    Stepper("缴费年限：\(draft.payYears) 年", value: $draft.payYears, in: 0...40)
                }
                Section("备注") {
                    TextField("备注", text: $draft.note, axis: .vertical)
                }
                if let onDelete {
                    Section {
                        Button("删除这张保单", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "保单" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
    }
}

// MARK: - 税务档案编辑

private struct TaxEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaxProfile
    private let onSave: (TaxProfile) -> Void
    private let rates: [Double] = [0.03, 0.10, 0.20, 0.25, 0.30, 0.35, 0.45]

    init(profile: TaxProfile, onSave: @escaping (TaxProfile) -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("收入") {
                    HStack {
                        Text("月收入")
                        Spacer()
                        TextField("0", value: $draft.monthlyIncome, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    Picker("边际税率", selection: $draft.marginalRate) {
                        ForEach(rates, id: \.self) { rate in
                            Text("\(Int(rate * 100))%").tag(rate)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("专项附加扣除") {
                    Stepper("子女数：\(draft.children)", value: $draft.children, in: 0...5)
                    Toggle("3 岁以下照护", isOn: $draft.childCare)
                    Toggle("赡养老人", isOn: $draft.elderlySupport)
                    Toggle("住房贷款利息", isOn: $draft.mortgageInterest)
                    Toggle("住房租金", isOn: $draft.housingRent)
                    if draft.housingRent {
                        Picker("城市档位", selection: $draft.rentTier) {
                            Text("一线 1500").tag(1)
                            Text("二线 1100").tag(2)
                            Text("其他 800").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }
                    Toggle("继续教育", isOn: $draft.continuingEducation)
                }
                Section("其他") {
                    HStack {
                        Text("年度自付医疗")
                        Spacer()
                        TextField("0", value: $draft.seriousIllness, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("个人养老金已缴")
                        Spacer()
                        TextField("0", value: $draft.pensionContributed, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("年终奖")
                        Spacer()
                        TextField("0", value: $draft.annualBonus, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("税务档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - 目标编辑

private struct GoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MoneyGoal
    private let onSave: (MoneyGoal) -> Void
    private let onDelete: (() -> Void)?

    init(goal: MoneyGoal?, onSave: @escaping (MoneyGoal) -> Void, onDelete: (() -> Void)? = nil) {
        _draft = State(initialValue: goal ?? MoneyGoal())
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("目标") {
                    TextField("名称，如 换车首付", text: $draft.name)
                    HStack {
                        Text("目标金额")
                        Spacer()
                        TextField("0", value: $draft.target, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("已存")
                        Spacer()
                        TextField("0", value: $draft.saved, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("每月定投")
                        Spacer()
                        TextField("0", value: $draft.monthly, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("预期年化 %")
                        Spacer()
                        TextField("3", value: $draft.annualReturn, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    DatePicker("目标日期", selection: $draft.dueDate, displayedComponents: .date)
                }
                if let onDelete {
                    Section {
                        Button("删除这个目标", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "目标" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - 情景编辑

private struct ScenarioEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: FinanceScenario
    private let onSave: (FinanceScenario) -> Void
    private let onDelete: (() -> Void)?

    init(scenario: FinanceScenario?, onSave: @escaping (FinanceScenario) -> Void, onDelete: (() -> Void)? = nil) {
        _draft = State(initialValue: scenario ?? FinanceScenario())
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("情景") {
                    TextField("名称，如 失业半年", text: $draft.name)
                    Stepper("推演 \(draft.months) 个月", value: $draft.months, in: 1...60)
                }
                Section("参数") {
                    HStack {
                        Text("收入系数")
                        Spacer()
                        Text(String(format: "%.0f%%", draft.incomeFactor * 100))
                    }
                    Slider(value: $draft.incomeFactor, in: 0...1.5, step: 0.05)
                    HStack {
                        Text("一次性大额支出")
                        Spacer()
                        TextField("0", value: $draft.lumpSum, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("每月额外支出")
                        Spacer()
                        TextField("0", value: $draft.extraMonthly, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                if let onDelete {
                    Section {
                        Button("删除这个情景", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "情景" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}
