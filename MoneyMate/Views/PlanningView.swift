import SwiftUI

// MARK: - 前瞻规划页

/// 把「记账」升级成「指导未来」：
/// ① 流动性阶梯与生存跑道 ② 标普四象限偏离度 ③ 未来现金流沙盒 ④ 提前还贷 vs 投资 ⑤ 负债压力测试与雪崩
/// 全部纯本地内存计算，不发起任何网络请求。
struct PlanningPage: View {
    @ObservedObject var store: MoneyStore
    @ObservedObject private var planning = PlanningBook.shared
    @ObservedObject private var accounting = AccountingBook.shared

    @State private var tab = 0
    @State private var horizon = 24
    @State private var idleCash: Double = 100_000
    @State private var expectedReturn: Double = 3.5
    @State private var extraMonthly: Double = 1_000
    @State private var stressFactor: Double = 1.0
    @State private var stressShock: Double = 0
    @State private var editingMilestone: Milestone?
    @State private var addingMilestone = false
    @State private var showMacro = false

    private static let tabs = ["跑道", "四象限", "沙盒", "罗盘", "负债"]
    private static let horizons = [12, 24, 36, 60]

    var body: some View {
        let data = plan()
        ScrollView {
            VStack(spacing: 14) {
                tabBar
                switch tab {
                case 0: runwayTab(data)
                case 1: allocationTab(data)
                case 2: sandboxTab(data)
                case 3: compassTab(data)
                default: debtTab(data)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .navigationTitle("前瞻规划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMacro = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .sheet(item: $editingMilestone) { item in
            MilestoneEditor(item: item, book: planning) { editingMilestone = nil }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $addingMilestone) {
            MilestoneEditor(item: Milestone(title: "", amount: 0, date: Date()), book: planning) {
                addingMilestone = false
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMacro) {
            MacroEditor(macro: planning.macro) { updated in
                planning.macro = updated
                showMacro = false
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: 数据汇总

    private struct PlanData {
        var runway: RunwayReport
        var allocation: SpAllocation
        var projection: CashProjection
        var compass: CompassResult
        var debts: [DebtItem]
        var avalanche: AvalanchePlan
        var stress: StressReport
        var current: StressScenario
        var monthlyIncome: Double
        var monthlySurplus: Double
        var netWorth: Double
        var hasMortgage: Bool
        var mortgageName: String
    }

    private func plan() -> PlanData {
        let txs = store.scopedTxs
        let accounts = store.activeAccounts
        var balances: [UUID: Double] = [:]
        for account in accounts {
            balances[account.id] = FinanceMath.balance(account, txs: txs)
        }
        let macro = planning.macro
        let runway = PlanningEngine.buildRunway(
            accounts: accounts, balances: balances, items: accounting.items, txs: txs, macro: macro
        )
        let allocation = PlanningEngine.buildAllocation(accounts: accounts, balances: balances, items: accounting.items)
        let income = PlanningEngine.averageIncome(txs)
        let surplus = income - PlanningEngine.averageExpense(txs)
        let worth = FinanceMath.netWorth(accounts: accounts, txs: txs).net
        let safeFloor = max(macro.safeCashFloorMonths * runway.rigidMonthly, 0)
        let projection = PlanningEngine.projectCashFlow(
            currentCash: runway.tier1,
            monthlySurplus: surplus,
            milestones: planning.milestones,
            months: horizon,
            safeFloor: safeFloor,
            netWorth: worth,
            investedAssets: PlanningEngine.investedAssets(of: allocation),
            macro: macro
        )

        let mortgage = accounting.items.first { $0.kind == .mortgage && $0.value > 0 }
        let mortgageBalance = mortgage?.value ?? 1_000_000
        let mortgageRate = (mortgage?.rate ?? 0) > 0 ? (mortgage!.rate ?? 0) : macro.mortgageRate
        let mortgageMonths = (mortgage?.termMonths ?? 0) > 0 ? (mortgage!.termMonths ?? 240) : 240
        let compass = PlanningEngine.mortgageCompass(
            balance: mortgageBalance,
            rate: mortgageRate,
            termMonths: mortgageMonths,
            equalInstallment: mortgage?.equalInstallment ?? true,
            idleCash: idleCash,
            expectedReturn: expectedReturn
        )

        let debtList = PlanningEngine.debts(accounts: accounts, balances: balances, items: accounting.items, macro: macro)
        let avalanche = PlanningEngine.avalanche(debtList, extraMonthly: extraMonthly)
        let stress = PlanningEngine.stressTest(
            monthlyIncome: income,
            debts: debtList,
            tier1: runway.tier1,
            rigidMonthly: runway.rigidMonthly,
            factor: 1,
            rateShock: 0
        )
        let current = PlanningEngine.scenario(
            label: "当前滑块",
            monthlyIncome: income,
            factor: stressFactor,
            rateShock: stressShock,
            debts: debtList,
            tier1: runway.tier1,
            rigidMonthly: runway.rigidMonthly
        )

        return PlanData(
            runway: runway,
            allocation: allocation,
            projection: projection,
            compass: compass,
            debts: debtList,
            avalanche: avalanche,
            stress: stress,
            current: current,
            monthlyIncome: income,
            monthlySurplus: surplus,
            netWorth: worth,
            hasMortgage: mortgage != nil,
            mortgageName: mortgage?.name ?? "假设房贷"
        )
    }

    // MARK: 通用组件

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Self.tabs.indices, id: \.self) { index in
                Button {
                    Haptics.select()
                    withAnimation(.snappy(duration: 0.22)) { tab = index }
                } label: {
                    Text(Self.tabs[index])
                        .font(.system(size: 12.5, weight: tab == index ? .bold : .medium))
                        .foregroundStyle(tab == index ? Palette.primaryDeep : Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if tab == index {
                                Color.white
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: Palette.ink.opacity(0.08), radius: 6, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.tile, strong: true)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func lineRow(_ name: String, _ value: String, sub: String? = nil, color: Color? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                if let sub {
                    Text(sub)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color ?? Palette.textPrimary)
                .monospacedDigit()
        }
    }

    private func metric(_ title: String, _ value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color ?? Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color(white: 0.965), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(white: 0.925), lineWidth: 0.8)
        )
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 1: return Palette.rose
        case 2: return Palette.amberGlow
        case 3: return Palette.mint
        case 4: return Palette.primary
        default: return Palette.textTertiary
        }
    }

    private func sliderBlock(_ title: String, _ value: String, _ slider: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
            }
            slider()
        }
    }

    // MARK: Tab 0 跑道

    @ViewBuilder
    private func runwayTab(_ data: PlanData) -> some View {
        let r = data.runway
        let color = levelColor(r.level)

        card {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.status)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(color.opacity(0.12), in: Capsule())
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(r.rigidMonthly > 0 ? String(format: "%.1f", r.runwayMonths) : "—")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                        Text("个月")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    caption("Tier-1 极速流动资产 ÷ 月均刚性支出 \(money(r.rigidMonthly))")
                }
                Spacer(minLength: 0)
                GaugeRing(progress: r.progress, level: r.level)
                    .frame(width: 92, height: 92)
            }
            Divider().overlay(Palette.ink.opacity(0.06))
            HStack(spacing: 8) {
                metric("极速可用", money(r.tier1))
                metric("加缓冲层", "\(String(format: "%.1f", r.runwayWithBuffer)) 月")
                metric("安全线", "\(String(format: "%.0f", r.safeMonths)) 月")
            }
        }

        card {
            Text("资产流动性阶梯")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            tierBar(r)
            ForEach(r.layers) { layer in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle()
                            .fill(tierColor(layer.tier))
                            .frame(width: 7, height: 7)
                        Text(layer.tier.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(money(layer.total))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                    }
                    caption(layer.tier.subtitle)
                    ForEach(layer.lines) { line in
                        HStack {
                            Text(line.name)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(money(line.value))
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.textSecondary)
                                .monospacedDigit()
                        }
                    }
                    if layer.lines.isEmpty {
                        caption("这一层还没有资产，\(layer.tier.advice)")
                    }
                }
                .padding(.top, 4)
                Divider().overlay(Palette.ink.opacity(0.05))
            }
            HStack(spacing: 8) {
                metric("总资产", money(r.totalAssets))
                metric("实际月均支出", money(r.hardMonthly), color: Palette.textSecondary)
            }
        }

        if !r.rigidBreakdown.isEmpty {
            card {
                Text("刚性支出构成（近 \(r.monthsCovered) 个月均摊）")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                ForEach(r.rigidBreakdown) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textSecondary)
                            Spacer()
                            Text(money(item.amount))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            let ratio = r.rigidMonthly > 0 ? min(item.amount / max(r.rigidMonthly, 1), 1) : 0
                            ZStack(alignment: .leading) {
                                Capsule().fill(Palette.ink.opacity(0.06))
                                Capsule()
                                    .fill(Palette.primary.opacity(0.65))
                                    .frame(width: max(proxy.size.width * CGFloat(ratio), 3))
                            }
                        }
                        .frame(height: 6)
                    }
                }
                caption("只算居住、餐饮、交通、通讯、医疗；购物、娱乐、人情这些可以砍的支出不进跑道分母。")
            }
        }

        card {
            Text("前瞻提示")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text(r.advice)
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(r.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.amberGlow)
                    Text(tip)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tierColor(_ tier: LiquidityTier) -> Color {
        switch tier {
        case .fast: return Palette.mint
        case .buffer: return Palette.primary
        case .fixed: return Palette.amberWarm
        }
    }

    @ViewBuilder
    private func tierBar(_ r: RunwayReport) -> some View {
        GeometryReader { proxy in
            let total = max(r.totalAssets, 1)
            HStack(spacing: 2) {
                ForEach(r.layers) { layer in
                    Capsule()
                        .fill(tierColor(layer.tier).opacity(0.8))
                        .frame(width: max(proxy.size.width * CGFloat(layer.total / total), layer.total > 0 ? 4 : 0))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 12)
    }

    // MARK: Tab 1 四象限

    @ViewBuilder
    private func allocationTab(_ data: PlanData) -> some View {
        let alloc = data.allocation
        card {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("结构分 \(alloc.score)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(alloc.score >= 70 ? Palette.mint : Palette.amberGlow)
                    caption(alloc.headline)
                    Text(money(alloc.total))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                RadarChart(
                    values: alloc.buckets.map { alloc.total > 0 ? $0.amount / alloc.total : 0 },
                    targets: alloc.buckets.map { $0.target }
                )
                .frame(width: 118, height: 118)
            }
            HStack(spacing: 14) {
                legendDot(Palette.primary, "当前占比")
                legendDot(Palette.textTertiary, "标普基准")
            }
        }

        ForEach(alloc.buckets) { bucket in
            let share = alloc.total > 0 ? bucket.amount / alloc.total : 0
            let delta = (share - bucket.target) * 100
            card {
                HStack {
                    Text(bucket.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(Int(share * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                    Text("/ \(bucket.targetLabel)")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                }
                caption(bucket.detail)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.ink.opacity(0.06))
                        Capsule()
                            .fill(Palette.primary.opacity(0.6))
                            .frame(width: max(proxy.size.width * CGFloat(min(share, 1)), 2))
                        Rectangle()
                            .fill(Palette.textPrimary.opacity(0.5))
                            .frame(width: 1.6)
                            .offset(x: max(proxy.size.width * CGFloat(bucket.target) - 1, 0))
                    }
                }
                .frame(height: 7)
                HStack {
                    Text(delta >= 0 ? "超配 \(String(format: "%.0f", delta)) 个百分点" : "低配 \(String(format: "%.0f", -delta)) 个百分点")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(abs(delta) > 5 ? Palette.amberGlow : Palette.textTertiary)
                    Spacer()
                    Text(money(bucket.amount))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                }
                ForEach(bucket.lines) { line in
                    HStack {
                        Text(line.name)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(line.value < 0 ? "−\(money(abs(line.value)))" : money(line.value))
                            .font(.system(size: 11))
                            .foregroundStyle(line.value < 0 ? Palette.rose : Palette.textSecondary)
                            .monospacedDigit()
                    }
                }
            }
        }

        card {
            Text("再平衡指令")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            ForEach(alloc.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.primary)
                    Text(note)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            caption("负债已在「保本升值的钱」里按房产净值口径扣过；不用为了凑比例卖出资产，只调整新增结余的流向。")
        }
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.textTertiary)
        }
    }

    // MARK: Tab 2 沙盒

    @ViewBuilder
    private func sandboxTab(_ data: PlanData) -> some View {
        let p = data.projection
        card {
            HStack {
                Text("未来 \(horizon) 个月现金流水位")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                ForEach(Self.horizons, id: \.self) { months in
                    Button {
                        Haptics.select()
                        withAnimation(.snappy(duration: 0.2)) { horizon = months }
                    } label: {
                        Text("\(months)")
                            .font(.system(size: 11, weight: horizon == months ? .bold : .medium))
                            .foregroundStyle(horizon == months ? Palette.primaryDeep : Palette.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                horizon == months ? Color.white : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            WaveChart(points: p.points.map { $0.end }, floor: p.safeFloor)
                .frame(height: 152)
            HStack(spacing: 8) {
                metric("期初可用", money(p.startCash))
                metric("月结余", money(p.monthlySurplus), color: p.monthlySurplus >= 0 ? Palette.mint : Palette.rose)
                metric("安全线", money(p.safeFloor))
            }
            Text(p.verdict)
                .font(.system(size: 12))
                .foregroundStyle(p.ok ? Palette.textSecondary : Palette.rose)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    (p.ok ? Palette.mint : Palette.rose).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }

        card {
            Text("未来净资产演进")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            WaveChart(
                points: p.points.map { $0.netWorth },
                floor: nil
            )
            .frame(height: 118)
            HStack(spacing: 8) {
                metric("当前净资产", money(data.netWorth))
                metric("\(horizon) 个月后", money(p.endNetWorth), color: Palette.primary)
            }
        }

        card {
            Text("未来重大收支事件")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            if planning.milestones.isEmpty {
                caption("还没有预设事件。年终奖、买车首付、每年保费都可以先打点，沙盒才能提前算出破线月份。")
            }
            ForEach(planning.milestones) { item in
                Button {
                    editingMilestone = item
                } label: {
                    HStack {
                        Image(systemName: item.isInflow ? "arrow.down.left.circle" : "arrow.up.right.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(item.isInflow ? Palette.mint : Palette.rose)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title.isEmpty ? "未命名事件" : item.title)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(dateText(item.date))\(item.repeatYearly ? " · 每年重复" : "")")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Palette.textTertiary)
                        }
                        Spacer()
                        Text(item.isInflow ? "+\(money(item.amount))" : "−\(money(abs(item.amount)))")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(item.isInflow ? Palette.mint : Palette.rose)
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            Button {
                Haptics.tap()
                addingMilestone = true
            } label: {
                Text("添加未来事件")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.primaryDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Palette.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }

        card {
            Text("推演参数")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            lineRow("月均稳定结余", money(data.monthlySurplus), sub: "近 3 个月收入均值 − 支出均值")
            lineRow("模拟年化", "\(String(format: "%.1f", planning.macro.investReturn))%", sub: "生钱的钱按此复利滚")
            lineRow("通胀参考", "\(String(format: "%.1f", planning.macro.inflation))%", sub: "只做提示，不改名义金额")
            Button {
                showMacro = true
            } label: {
                Text("修改宏观参数")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.primaryDeep)
            }
            .buttonStyle(.plain)
            caption("推演全部在本地内存完成，不请求任何网络接口。")
        }
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: date)
    }

    // MARK: Tab 3 罗盘

    @ViewBuilder
    private func compassTab(_ data: PlanData) -> some View {
        let c = data.compass
        card {
            Text("房贷现状 · \(data.mortgageName)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: 8) {
                metric("剩余本金", money(c.balance))
                metric("年利率", "\(String(format: "%.2f", c.rate))%")
                metric("剩余期数", "\(c.termMonths) 期")
            }
            caption(data.hasMortgage
                ? "数据来自资产负债表里的房贷科目。"
                : "还没有录入房贷科目，这里用 100 万 / 20 年 / \(String(format: "%.2f", c.rate))% 做演示；在报表页补一条房贷科目后会自动换成真实数据。")
        }

        card {
            Text("决策输入")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            sliderBlock("拟支配闲钱", money(idleCash)) {
                Slider(value: $idleCash, in: 0...max(c.balance, 100_000), step: 5_000)
                    .tint(Palette.primary)
            }
            sliderBlock("预期稳健年化", "\(String(format: "%.1f", expectedReturn))%") {
                Slider(value: $expectedReturn, in: 0...10, step: 0.1)
                    .tint(Palette.mint)
            }
            caption("「稳健」指货币基金、国债、大额存单一类，不含股票与杠杆。")
        }

        card {
            Text("路径 A · 提前还贷")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            lineRow("一次性还掉", money(min(idleCash, c.balance)))
            lineRow("剩余贷款", money(max(c.balance - idleCash, 0)), sub: "期限不变，月供变小")
            lineRow("省下利息", money(c.interestSaving), color: Palette.mint)
            lineRow("每月释放", money(c.freedMonthly), sub: "省下的月供可以转去定投")
            lineRow("代价", "还进去的钱取不出来", sub: "流动性折损：急用钱时无法反悔", color: Palette.rose)
        }

        card {
            Text("路径 B · 保持月供 + 拿去投资")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            lineRow("一次性投入", money(min(idleCash, c.balance)))
            lineRow("每月追加", money(c.investMonthlyOutlay), sub: "相当于 A 释放出来的月供")
            lineRow("累计投入", money(min(idleCash, c.balance) + c.investMonthlyOutlay * Double(c.termMonths)))
            lineRow("复利后金额", money(c.investFinal), color: Palette.primary)
            lineRow("净收益", money(c.investGain), color: c.investGain >= 0 ? Palette.mint : Palette.rose)
            lineRow("代价", "收益不确定，且要长期拿得住", color: Palette.rose)
        }

        card {
            Text("决策罗盘")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            CompassBar(score: c.investScore)
                .frame(height: 34)
            HStack {
                Text("还贷")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
                Text(c.winner)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(c.investWins ? Palette.mint : Palette.rose)
                Spacer()
                Text("投资")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
            }
            Text(c.advice)
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            caption("利差 = 预期年化 − 房贷利率 = \(String(format: "%.2f", c.spread)) 个百分点。")
        }
    }

    // MARK: Tab 4 负债

    @ViewBuilder
    private func debtTab(_ data: PlanData) -> some View {
        let s = data.stress
        let plan = data.avalanche
        card {
            HStack(alignment: .firstTextBaseline) {
                Text(s.monthlyIncome > 0 ? "\(Int(s.dsr * 100))%" : "—")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                Text("DSR 偿债收入比")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                pill(s.dsrStatus, color: s.dsr <= 0.35 ? Palette.mint : (s.dsr <= 0.4 ? Palette.amberGlow : Palette.rose))
            }
            caption("每月还贷 \(money(s.monthlyDebt)) ÷ 每月可支配收入 \(money(s.monthlyIncome))；警戒线 35%~40%。")
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.06))
                    Capsule()
                        .fill(s.dsr <= 0.35 ? Palette.mint.opacity(0.75) : Palette.rose.opacity(0.75))
                        .frame(width: max(proxy.size.width * CGFloat(min(s.dsr, 1)), s.monthlyDebt > 0 ? 3 : 0))
                    Rectangle()
                        .fill(Palette.amberGlow.opacity(0.85))
                        .frame(width: 1.6)
                        .offset(x: max(proxy.size.width * 0.35 - 1, 0))
                }
            }
            .frame(height: 8)
            caption("琥珀刻线 = 35% 警戒线。")
        }

        card {
            Text("极端偿债压力测试")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            sliderBlock("收入变化", "\(Int((stressFactor - 1) * 100))%") {
                Slider(value: $stressFactor, in: 0...1.2, step: 0.05)
                    .tint(Palette.primary)
            }
            sliderBlock("利率上浮", "+\(String(format: "%.1f", stressShock))%") {
                Slider(value: $stressShock, in: 0...3, step: 0.25)
                    .tint(Palette.amberGlow)
            }
            let c = data.current
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(c.stable ? "现金流仍为正" : "现金流为负")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(c.stable ? Palette.mint : Palette.rose)
                    Spacer()
                    Text("可撑 \(c.monthsToDefault >= 99 ? "99+" : String(format: "%.1f", c.monthsToDefault)) 个月")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(c.monthsToDefault >= 6 ? Palette.textPrimary : Palette.rose)
                        .monospacedDigit()
                }
                caption("月供合计 \(money(c.monthlyDebt))，收入 \(money(c.monthlyIncome))，刚性支出 \(money(data.runway.rigidMonthly))，结余 \(money(c.surplus))")
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                (c.stable ? Palette.mint : Palette.rose).opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            ForEach(s.scenarios) { scenario in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(scenario.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(scenario.survives ? "撑得住" : "\(String(format: "%.1f", scenario.monthsToDefault)) 个月见底")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(scenario.survives ? Palette.mint : (scenario.monthsToDefault >= 6 ? Palette.amberGlow : Palette.rose))
                            .monospacedDigit()
                    }
                    GeometryReader { proxy in
                        let ratio = scenario.monthsToDefault >= 99 ? 1 : min(scenario.monthsToDefault / 24, 1)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.ink.opacity(0.05))
                            Capsule()
                                .fill((scenario.survives ? Palette.mint : Palette.rose).opacity(0.7))
                                .frame(width: max(proxy.size.width * CGFloat(ratio), 3))
                        }
                    }
                    .frame(height: 5)
                }
            }
            caption("月供按各笔负债的实际利率重算；信用卡按月供 10% 且利率上浮。")
        }

        card {
            Text("负债雪崩 · 先还哪一笔")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            if data.debts.isEmpty {
                caption("没有负债。保持零杠杆，把钱先铺满 6 个月跑道，再谈投资。")
            } else {
                ForEach(data.debts) { debt in
                    HStack {
                        Text("\(debt.rate >= 15 ? "🔥" : "")\(debt.name)")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(String(format: "%.1f", debt.rate))%")
                            .font(.system(size: 11))
                            .foregroundStyle(debt.rate >= 10 ? Palette.rose : Palette.textSecondary)
                            .monospacedDigit()
                        Text(money(debt.balance))
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                    }
                }
                sliderBlock("每月额外还债", money(extraMonthly)) {
                    Slider(value: $extraMonthly, in: 0...10_000, step: 200)
                        .tint(Palette.rose)
                }
                HStack(spacing: 8) {
                    metric("只还最低", "\(plan.baselineMonths) 个月")
                    metric("雪崩法", "\(plan.plannedMonths) 个月", color: Palette.mint)
                    metric("少付利息", money(plan.savedInterest), color: Palette.mint)
                }
                Text(plan.headline)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(plan.steps.prefix(4)) { step in
                    HStack(spacing: 8) {
                        Text("\(step.order)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Palette.primary, in: Circle())
                        Text(step.name)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(step.months) 个月 · \(String(format: "%.1f", step.rate))%")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.textTertiary)
                            .monospacedDigit()
                    }
                }
            }
            caption("雪崩法 = 按实际年化从高到低清，数学上最省利息；和「先还小的」比，雪崩省息更多但心理成就感更慢。")
        }
    }
}

// MARK: - 仪表盘

private struct GaugeRing: View {
    var progress: Double
    var level: Int

    var body: some View {
        let color: Color = {
            switch level {
            case 1: return Palette.rose
            case 2: return Palette.amberGlow
            case 3: return Palette.mint
            default: return Palette.primary
            }
        }()
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 8
            let start = Angle.degrees(150)
            let sweep = 240.0
            let track = Path { p in
                p.addArc(center: center, radius: radius, startAngle: start,
                         endAngle: .degrees(150 + sweep), clockwise: false)
            }
            context.stroke(track, with: .color(Color.gray.opacity(0.16)),
                           style: StrokeStyle(lineWidth: 9, lineCap: .round))
            let end = 150 + sweep * max(min(progress, 1), 0)
            let value = Path { p in
                p.addArc(center: center, radius: radius, startAngle: start,
                         endAngle: .degrees(end), clockwise: false)
            }
            context.stroke(value, with: .color(color),
                           style: StrokeStyle(lineWidth: 9, lineCap: .round))
            // 安全线刻度（6 个月 = 50%）
            let safeAngle = (150 + sweep / 2) * Double.pi / 180
            let inner = CGPoint(x: center.x + (radius - 7) * cos(safeAngle),
                                y: center.y + (radius - 7) * sin(safeAngle))
            let outer = CGPoint(x: center.x + (radius + 7) * cos(safeAngle),
                                y: center.y + (radius + 7) * sin(safeAngle))
            var tick = Path()
            tick.move(to: inner)
            tick.addLine(to: outer)
            context.stroke(tick, with: .color(Palette.amberGlow), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

// MARK: - 四象限雷达图

private struct RadarChart: View {
    var values: [Double]
    var targets: [Double]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 14
            let count = max(values.count, 1)
            let maxValue = max(0.05, (values + targets).max() ?? 0.4)

            func point(_ index: Int, _ ratio: Double) -> CGPoint {
                let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(count)
                return CGPoint(x: center.x + radius * CGFloat(ratio * cos(angle)),
                               y: center.y + radius * CGFloat(ratio * sin(angle)))
            }

            // 网格
            for ring in 1...3 {
                let ratio = Double(ring) / 3
                let path = Path { p in
                    for i in 0..<count {
                        let pt = point(i, ratio)
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                    p.closeSubpath()
                }
                context.stroke(path, with: .color(Color.gray.opacity(0.18)), lineWidth: 0.8)
            }
            // 轴
            for i in 0..<count {
                var axis = Path()
                axis.move(to: center)
                axis.addLine(to: point(i, 1))
                context.stroke(axis, with: .color(Color.gray.opacity(0.14)), lineWidth: 0.6)
            }
            // 当前
            let current = Path { p in
                for i in 0..<count {
                    let pt = point(i, min((values[safe: i] ?? 0) / maxValue, 1))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
            }
            context.fill(current, with: .color(Palette.primary.opacity(0.22)))
            context.stroke(current, with: .color(Palette.primary), lineWidth: 1.6)
            // 目标（虚线）
            let target = Path { p in
                for i in 0..<count {
                    let pt = point(i, min((targets[safe: i] ?? 0) / maxValue, 1))
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
            }
            context.stroke(target, with: .color(Palette.textTertiary.opacity(0.8)),
                           style: StrokeStyle(lineWidth: 1.1, dash: [3, 3]))
            // 顶点
            for i in 0..<count {
                let pt = point(i, min((values[safe: i] ?? 0) / maxValue, 1))
                let dot = Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4))
                context.fill(dot, with: .color(Palette.primary))
            }
        }
    }
}

// MARK: - 水位波形图

private struct WaveChart: View {
    var points: [Double]
    var floor: Double?

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            var minValue = points.min() ?? 0
            var maxValue = points.max() ?? 1
            if let floor {
                minValue = min(minValue, floor)
                maxValue = max(maxValue, floor)
            }
            let span = max(maxValue - minValue, 1)
            let inset: CGFloat = 10
            let usableW = size.width - inset * 2
            let usableH = size.height - inset * 2

            func point(_ index: Int, _ value: Double) -> CGPoint {
                let x = inset + usableW * CGFloat(index) / CGFloat(points.count - 1)
                let y = inset + usableH * CGFloat(1 - (value - minValue) / span)
                return CGPoint(x: x, y: y)
            }

            // 横向网格
            for ring in 0...2 {
                let y = inset + usableH * CGFloat(ring) / 2
                var grid = Path()
                grid.move(to: CGPoint(x: inset, y: y))
                grid.addLine(to: CGPoint(x: size.width - inset, y: y))
                context.stroke(grid, with: .color(Color.gray.opacity(0.12)), lineWidth: 0.6)
            }

            // 曲线
            let line = Path { p in
                p.move(to: point(0, points[0]))
                for i in 1..<points.count {
                    let prev = point(i - 1, points[i - 1])
                    let curr = point(i, points[i])
                    let midX = (prev.x + curr.x) / 2
                    p.addCurve(to: curr,
                               control1: CGPoint(x: midX, y: prev.y),
                               control2: CGPoint(x: midX, y: curr.y))
                }
            }
            // 面积
            let area = Path { p in
                p.move(to: CGPoint(x: inset, y: size.height - inset))
                p.addLine(to: point(0, points[0]))
                for i in 1..<points.count {
                    let prev = point(i - 1, points[i - 1])
                    let curr = point(i, points[i])
                    let midX = (prev.x + curr.x) / 2
                    p.addCurve(to: curr,
                               control1: CGPoint(x: midX, y: prev.y),
                               control2: CGPoint(x: midX, y: curr.y))
                }
                p.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
                p.closeSubpath()
            }
            context.fill(area, with: .linearGradient(
                Gradient(colors: [Palette.primary.opacity(0.28), Palette.primary.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            context.stroke(line, with: .color(Palette.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            // 安全线
            if let floor {
                let y = point(0, floor).y
                var dash = Path()
                dash.move(to: CGPoint(x: inset, y: y))
                dash.addLine(to: CGPoint(x: size.width - inset, y: y))
                context.stroke(dash, with: .color(Palette.amberGlow.opacity(0.9)),
                               style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
            }
            // 破线红点
            if let floor {
                for i in 0..<points.count where points[i] < floor {
                    let pt = point(i, points[i])
                    let dot = Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5))
                    context.fill(dot, with: .color(Palette.rose))
                }
            }
            // 末点
            let last = point(points.count - 1, points[points.count - 1])
            let halo = Path(ellipseIn: CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8))
            context.fill(halo, with: .color(Palette.primary))
            let core = Path(ellipseIn: CGRect(x: last.x - 1.6, y: last.y - 1.6, width: 3.2, height: 3.2))
            context.fill(core, with: .color(.white))
        }
    }
}

// MARK: - 决策罗盘条

private struct CompassBar: View {
    var score: Int

    var body: some View {
        GeometryReader { proxy in
            let ratio = CGFloat(min(max(score, 0), 100)) / 100
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [Palette.rose.opacity(0.7), Palette.amberGlow.opacity(0.7), Palette.mint.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                Rectangle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 1.6)
                    .offset(x: proxy.size.width / 2)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Palette.textPrimary.opacity(0.25), lineWidth: 1))
                    .shadow(color: Palette.ink.opacity(0.18), radius: 3, y: 1)
                    .offset(x: max(min(proxy.size.width * ratio - 7, proxy.size.width - 14), 0))
            }
        }
    }
}

// MARK: - 未来事件编辑

private struct MilestoneEditor: View {
    @State var item: Milestone
    @ObservedObject var book: PlanningBook
    var onClose: () -> Void

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var repeatYearly = false
    @State private var isInflow = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.title.isEmpty ? "添加未来事件" : "编辑未来事件")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)

                    Picker("方向", selection: $isInflow) {
                        Text("流出（花钱）").tag(false)
                        Text("流入（进钱）").tag(true)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("名称")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                        TextField("年终奖 / 买车首付 / 保费", text: $title)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color(white: 0.97), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("金额（元）")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color(white: 0.97), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .font(.system(size: 13))

                    Toggle("每年重复（保费、学费）", isOn: $repeatYearly)
                        .font(.system(size: 13))

                    Button {
                        save()
                    } label: {
                        Text("保存")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.primary, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if !item.title.isEmpty {
                        Button(role: .destructive) {
                            book.delete(item.id)
                            onClose()
                        } label: {
                            Text("删除这个事件")
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(20)
            }
            .background(GlassBackground())
            .onAppear {
                guard !loaded else { return }
                loaded = true
                title = item.title
                amountText = item.amount == 0 ? "" : String(format: "%.0f", abs(item.amount))
                date = item.date
                repeatYearly = item.repeatYearly
                isInflow = item.amount >= 0 && item.amount != 0
            }
        }
    }

    private func save() {
        let value = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
        var fresh = item
        fresh.title = title.trimmingCharacters(in: .whitespaces)
        fresh.amount = isInflow ? value : -value
        fresh.date = date
        fresh.repeatYearly = repeatYearly
        guard !fresh.title.isEmpty else { return }
        book.upsert(fresh)
        Haptics.success()
        onClose()
    }
}

// MARK: - 宏观参数编辑

private struct MacroEditor: View {
    @State var inflation: Double
    @State var benchmarkRate: Double
    @State var mortgageRate: Double
    @State var investReturn: Double
    @State var safeRunwayMonths: Double
    @State var safeCashFloorMonths: Double
    var onSave: (MacroAssumptions) -> Void

    init(macro: MacroAssumptions, onSave: @escaping (MacroAssumptions) -> Void) {
        _inflation = State(initialValue: macro.inflation)
        _benchmarkRate = State(initialValue: macro.benchmarkRate)
        _mortgageRate = State(initialValue: macro.mortgageRate)
        _investReturn = State(initialValue: macro.investReturn)
        _safeRunwayMonths = State(initialValue: macro.safeRunwayMonths)
        _safeCashFloorMonths = State(initialValue: macro.safeCashFloorMonths)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("这些参数只存在本机，用来推演；不联网、不上传。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textTertiary)

                    row("通胀参考", "\(String(format: "%.1f", inflation))%", $inflation, 0...8, 0.1)
                    row("基准利率参考", "\(String(format: "%.2f", benchmarkRate))%", $benchmarkRate, 0...6, 0.05)
                    row("房贷利率兜底", "\(String(format: "%.2f", mortgageRate))%", $mortgageRate, 0...8, 0.05)
                    row("稳健投资年化", "\(String(format: "%.1f", investReturn))%", $investReturn, 0...12, 0.1)
                    row("生存跑道安全线", "\(String(format: "%.0f", safeRunwayMonths)) 月", $safeRunwayMonths, 3...24, 1)
                    row("现金流安全垫", "\(String(format: "%.1f", safeCashFloorMonths)) 月", $safeCashFloorMonths, 0...6, 0.5)

                    Button {
                        onSave(MacroAssumptions(
                            inflation: inflation,
                            benchmarkRate: benchmarkRate,
                            mortgageRate: mortgageRate,
                            investReturn: investReturn,
                            safeRunwayMonths: safeRunwayMonths,
                            safeCashFloorMonths: safeCashFloorMonths
                        ))
                        Haptics.success()
                    } label: {
                        Text("保存参数")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.primary, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(GlassBackground())
            .navigationTitle("推演参数")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ title: String, _ value: String, _ binding: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(value)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
            }
            Slider(value: binding, in: range, step: step)
                .tint(Palette.primary)
        }
    }
}

// MARK: - 安全下标

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
