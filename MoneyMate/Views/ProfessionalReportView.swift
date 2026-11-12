import SwiftUI

// MARK: - 专业财务报表（资产负债表 / 收入支出表 / 财务分析）

private enum ReportTab: String, CaseIterable, Identifiable {
    case balance
    case statement
    case analysis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balance: return "资产负债表"
        case .statement: return "收入支出表"
        case .analysis: return "财务分析"
        }
    }
}

struct ProfessionalReportPage: View {
    @ObservedObject var store: MoneyStore
    @StateObject private var book = AccountingBook.shared

    @State private var tab: ReportTab = .balance
    @State private var period = 0            // 0 本月 / 1 上月 / 2 近三月 / 3 今年
    @State private var editingItem: ManualItem?
    @State private var addingKind: ManualItemKind?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                tabBar
                switch tab {
                case .balance: balanceTab
                case .statement: statementTab
                case .analysis: analysisTab
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .navigationTitle("专业财务报表")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingItem) { item in
            ManualItemEditor(item: item) { saved in
                if let saved { book.upsert(saved) }
                editingItem = nil
            } onDelete: { id in
                book.delete(id)
                editingItem = nil
            }
        }
        .sheet(item: $addingKind) { kind in
            ManualItemEditor(item: ManualItem(name: "", kind: kind, value: 0)) { saved in
                if let saved { book.upsert(saved) }
                addingKind = nil
            } onDelete: { _ in addingKind = nil }
        }
    }

    // MARK: 数据

    private var accounts: [Account] { store.activeAccounts }
    private var txs: [Tx] { store.scopedTxs }

    private var monthlyExpense: Double {
        AccountingEngine.monthlyAverageExpense(txs, months: 3)
    }

    private func buildSheet() -> BalanceSheet {
        AccountingEngine.buildBalanceSheet(accounts: accounts, txs: txs,
                                           items: book.items, monthlyExpense: monthlyExpense)
    }

    private var periodRange: (start: Date, end: Date, title: String) {
        switch period {
        case 0:
            let (s, e) = AccountingEngine.monthRange(offset: 0)
            return (s, e, "本月")
        case 1:
            let (s, e) = AccountingEngine.monthRange(offset: 1)
            return (s, e, "上月")
        case 3:
            let (s, e) = AccountingEngine.yearRange()
            return (s, e, "今年")
        default:
            let (s, _) = AccountingEngine.monthRange(offset: 2)
            let (_, e) = AccountingEngine.monthRange(offset: 0)
            return (s, e, "近三个月")
        }
    }

    private func buildStatement() -> IncomeStatement {
        let range = periodRange
        return AccountingEngine.buildStatement(txs: txs, accounts: accounts,
                                               start: range.start, end: range.end,
                                               title: range.title)
    }

    /// 被动收入（理财 / 分红 / 利息 / 房租等），用于财务自由度
    private func passiveIncome(_ statement: IncomeStatement) -> Double {
        let keys = ["理财", "分红", "股息", "利息", "投资", "租金", "房租", "被动"]
        var total = 0.0
        for section in statement.incomeSections {
            for line in section.lines where keys.contains(where: { line.name.contains($0) }) {
                total += line.value
            }
        }
        return total
    }

    private func netWorthGrowth() -> Double {
        let series = FinanceMath.netWorthSeries(accounts: accounts, txs: txs, months: 2)
        guard let first = series.first, let last = series.last else { return 0 }
        guard abs(first.net) > 0.01 else { return 0 }
        return (last.net - first.net) / abs(first.net)
    }

    // MARK: 顶部 Tab

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(ReportTab.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { tab = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(tab == item ? Palette.primaryDeep : Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if tab == item {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Palette.primary.opacity(0.16), radius: 5, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Palette.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    // MARK: 资产负债表

    private var balanceTab: some View {
        let sheet = buildSheet()
        return VStack(spacing: 16) {
            netWorthHero(sheet)
            structureCard(sheet)
            assetCard(sheet)
            liabilityCard(sheet)
            addItemButton
            footnoteCard
        }
    }

    private func netWorthHero(_ sheet: BalanceSheet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("净资产")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
            Text(store.money(sheet.netWorth))
                .font(.system(size: 32, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.primaryDeep)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            HStack(spacing: 10) {
                heroMetric("总资产", store.money(sheet.totalAssets))
                heroMetric("总负债", store.money(sheet.totalLiabilities))
                heroMetric("资产负债率", String(format: "%.1f%%", sheet.debtRatio * 100))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.heroSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.primary.opacity(0.18), lineWidth: 0.8)
        }
    }

    private func heroMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.primaryDeep)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func structureCard(_ sheet: BalanceSheet) -> some View {
        let total = max(sheet.totalAssets + sheet.totalLiabilities, 1)
        let assetRatio = CGFloat(sheet.totalAssets / total)
        return card {
            caption("资产 / 负债结构")
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Palette.mint)
                        .frame(width: max(proxy.size.width * assetRatio - 2, 6))
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Palette.rose)
                }
            }
            .frame(height: 10)
            HStack(spacing: 14) {
                legendDot(Palette.mint, "资产 " + store.money(sheet.totalAssets))
                legendDot(Palette.rose, "负债 " + store.money(sheet.totalLiabilities))
            }
            Divider().opacity(0.35)
            lineRow("流动资产", store.money(sheet.currentAssets), sub: "现金 + 投资，能较快变现")
            lineRow("流动负债", store.money(sheet.currentLiabilities), sub: "信用卡 + 借入 + 一年内到期")
            lineRow("流动比率", String(format: "%.2f", sheet.currentRatio),
                    sub: sheet.currentRatio >= 1.5 ? "短期偿债无压力" : "流动资产不足以覆盖短期负债",
                    valueColor: sheet.currentRatio >= 1.5 ? Palette.mint : Palette.rose)
            lineRow("应急金可撑", String(format: "%.1f 个月", sheet.emergencyMonths),
                    sub: "按近 3 个月平均开支 " + store.money(monthlyExpense) + " 计",
                    valueColor: sheet.emergencyMonths >= 3 ? Palette.mint : Palette.rose)
        }
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func assetCard(_ sheet: BalanceSheet) -> some View {
        card {
            HStack {
                Text("资产").font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(store.money(sheet.totalAssets))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.mint)
            }
            if sheet.assetGroups.isEmpty {
                emptyHint("还没有资产 —— 先建一个现金或银行卡账户")
            } else {
                ForEach(sheet.assetGroups) { group in
                    groupBlock(group, accent: Palette.mint)
                }
            }
        }
    }

    private func liabilityCard(_ sheet: BalanceSheet) -> some View {
        card {
            HStack {
                Text("负债").font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(store.money(sheet.totalLiabilities))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.rose)
            }
            if sheet.liabilityGroups.isEmpty {
                emptyHint("没有负债，保持住")
            } else {
                ForEach(sheet.liabilityGroups) { group in
                    groupBlock(group, accent: Palette.rose)
                }
            }
        }
    }

    private func groupBlock(_ group: BalanceGroup, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(store.money(group.total))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accent)
            }
            ForEach(group.lines) { line in
                Button {
                    guard let manualID = line.manualID,
                          let item = book.items.first(where: { $0.id == manualID }) else { return }
                    editingItem = item
                } label: {
                    HStack(spacing: 8) {
                        Text(line.name)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(store.money(line.value))
                            .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(Palette.textPrimary)
                        if line.source == "manual" {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(Color(red: 0.965, green: 0.957, blue: 0.98),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addItemButton: some View {
        VStack(spacing: 10) {
            Button {
                addingKind = .house
            } label: {
                Label("添加资产 / 负债科目", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: Radius.button))

            HStack(spacing: 8) {
                ForEach(ManualItemKind.assetKinds.prefix(3)) { kind in
                    quickChip(kind.label) { addingKind = kind }
                }
                ForEach(ManualItemKind.liabilityKinds.prefix(3)) { kind in
                    quickChip(kind.label) { addingKind = kind }
                }
            }
        }
    }

    private func quickChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.primaryDeep)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Palette.primary.opacity(0.09),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var footnoteCard: some View {
        card {
            caption("口径说明")
            bullet("账户里的钱（现金 / 银行卡 / 信用卡 / 投资 / 应收应付）按余额自动进表。")
            bullet("房产、车、公积金、房贷、车贷、网贷这些不在账户里，请手动添加，否则净资产会算少或算多。")
            bullet("信用卡已用额度算负债，投资账户余额算资产；账户透支会单列为负债。")
            bullet("记账时选的「会计科目」决定这笔钱是支出还是资产/负债的形态变化，直接影响收支表。")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle().fill(Palette.primary.opacity(0.5)).frame(width: 4, height: 4).padding(.top, 6)
            Text(text)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: 收入支出表

    private var statementTab: some View {
        let statement = buildStatement()
        return VStack(spacing: 16) {
            periodBar
            statementSummary(statement)
            sectionCard("收入", statement.incomeSections, total: statement.income, accent: Palette.mint)
            sectionCard("支出", statement.expenseSections, total: statement.expense, accent: Palette.rose)
            flowCard(statement)
            statementFootnote(statement)
        }
    }

    private var periodBar: some View {
        HStack(spacing: 8) {
            ForEach(Array(["本月", "上月", "近三月", "今年"].enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { period = index }
                } label: {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(period == index ? .white : Palette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            if period == index {
                                Capsule().fill(Palette.primary)
                            } else {
                                Capsule().fill(Palette.primary.opacity(0.08))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func statementSummary(_ statement: IncomeStatement) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryTile("收入", store.money(statement.income), Palette.mint)
                summaryTile("支出", store.money(statement.expense), Palette.rose)
            }
            HStack(spacing: 12) {
                summaryTile("结余", store.money(statement.net),
                            statement.net >= 0 ? Palette.primaryDeep : Palette.rose)
                summaryTile("储蓄率", String(format: "%.1f%%", statement.savingRate * 100),
                            statement.savingRate >= 0.2 ? Palette.primaryDeep : Palette.textSecondary)
            }
            if statement.refundAmount > 0.005 {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10))
                    Text("其中退款冲减支出 " + store.money(statement.refundAmount))
                        .font(.system(size: 10, design: .rounded))
                }
                .foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func summaryTile(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.965, green: 0.957, blue: 0.98),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionCard(_ title: String, _ sections: [StatementSection],
                             total: Double, accent: Color) -> some View {
        card {
            HStack {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(store.money(total))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accent)
            }
            if sections.isEmpty || total <= 0.005 {
                emptyHint("这一期间没有\(title)记录")
            } else {
                let lines = sections.flatMap(\.lines).sorted { $0.value > $1.value }
                ForEach(Array(lines.prefix(10).enumerated()), id: \.element.id) { pair in
                    let line = pair.element
                    let index = pair.offset
                    let ratio = line.value / total
                    VStack(spacing: 5) {
                        HStack(spacing: 6) {
                            Text(line.name)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Palette.textPrimary)
                            if index == 0 {
                                Text("最多")
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(accent.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", ratio * 100))
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Palette.textTertiary)
                            Text(store.money(line.value))
                                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(Palette.textPrimary)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(accent.opacity(0.12))
                                Capsule().fill(accent.opacity(0.75))
                                    .frame(width: max(proxy.size.width * CGFloat(min(ratio, 1)), 2))
                            }
                        }
                        .frame(height: 5)
                    }
                    .padding(.bottom, 2)
                }
                if lines.count > 10 {
                    Text("其他 \(lines.count - 10) 项")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
    }

    private func flowCard(_ statement: IncomeStatement) -> some View {
        card {
            caption("资金流转（不计入收支）")
            if statement.flows.isEmpty {
                emptyHint("没有借款、还款或买卖资产，收支表就是全部了")
            } else {
                ForEach(statement.flows) { flow in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: flow.nature == .borrow ? "arrow.down.circle.fill"
                              : flow.nature == .repay ? "arrow.up.circle.fill"
                              : flow.nature == .lend ? "person.crop.circle.badge.minus"
                              : flow.nature == .collect ? "person.crop.circle.badge.checkmark"
                              : flow.nature == .assetIn ? "chart.pie.fill"
                              : "banknote.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.primary.opacity(0.8))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(flow.nature.label)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.textPrimary)
                                Text("\(flow.count) 笔")
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                            Text(flow.nature.detail)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Palette.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Text((flow.net >= 0 ? "+" : "") + store.money(flow.net))
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(flow.net >= 0 ? Palette.mint : Palette.rose)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func statementFootnote(_ statement: IncomeStatement) -> some View {
        card {
            caption("口径说明")
            bullet("只有「支出 / 收入」两个科目进这张表，会影响结余和储蓄率。")
            bullet("「还本金」不扣支出：还信用卡是减少负债，不是花掉的钱；只有利息和手续费才算支出。")
            bullet("「借入」不算收入：借来的钱要还。")
            bullet("「买入资产 / 卖出资产 / 借出 / 收回」都只是钱换形态，单列在资金流转里。")
            if statement.nonPlNet != 0 {
                HStack {
                    Text("本期非损益流转净额")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text((statement.nonPlNet >= 0 ? "+" : "") + store.money(statement.nonPlNet))
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.primaryDeep)
                }
            }
        }
    }

    // MARK: 财务分析

    private var analysisTab: some View {
        let sheet = buildSheet()
        let statement = buildStatement()
        let ratios = AccountingEngine.buildRatios(sheet: sheet,
                                                  statement: statement,
                                                  passiveIncome: passiveIncome(statement),
                                                  netWorthGrowth: netWorthGrowth())
        let score = AccountingEngine.healthScore(ratios)
        let passed = ratios.filter { $0.score >= 75 }.count
        return VStack(spacing: 16) {
            scoreCard(score, passed: passed, total: ratios.count)
            ForEach(ratios) { ratio in
                ratioCard(ratio)
            }
            toolsCard
        }
    }

    private func scoreCard(_ score: Int, passed: Int, total: Int) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Palette.primary.opacity(0.14), lineWidth: 8)
                    .frame(width: 78, height: 78)
                Circle()
                    .trim(from: 0, to: CGFloat(min(Double(score) / 100, 1)))
                    .stroke(Palette.hero, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 78, height: 78)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.primaryDeep)
                    Text("分")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("财务健康分")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(total) 项指标里有 \(passed) 项达标")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Text(scoreAdvice(score))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.heroSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func scoreAdvice(_ score: Int) -> String {
        if score >= 85 { return "结构很稳，可以开始规划更长期的目标" }
        if score >= 70 { return "整体健康，个别指标还能优化" }
        if score >= 55 { return "有短板，先补应急金、再降负债" }
        return "先别投资，把现金流和负债理顺"
    }

    private func ratioCard(_ ratio: FinanceRatio) -> some View {
        card {
            HStack(spacing: 10) {
                Text(ratio.status)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(ratio.status),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(ratio.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(ratio.display)
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(statusColor(ratio.status))
            }
            Text(ratio.advice)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "优秀": return Palette.mint
        case "健康": return Palette.primary
        case "关注": return Palette.amberGlow
        case "一般": return Palette.amberWarm
        default: return Palette.rose
        }
    }

    private var toolsCard: some View {
        card {
            caption("专业工具")
            NavigationLink {
                CoachReportPage(store: store)
            } label: {
                toolRow("财务体检报告", "用大白话讲给你听，一段一段打出来", "text.bubble")
            }
            .buttonStyle(.plain)
            NavigationLink {
                PlanningPage(store: store)
            } label: {
                toolRow("前瞻规划", "生存跑道 · 四象限 · 现金流沙盒 · 还贷罗盘 · 负债雪崩", "scope")
            }
            .buttonStyle(.plain)
            NavigationLink {
                LoanCalculatorView(store: store)
            } label: {
                toolRow("贷款计算器", "等额本息 / 等额本金，看清利息", "percent")
            }
            .buttonStyle(.plain)
            NavigationLink {
                CompoundCalculatorView(store: store)
            } label: {
                toolRow("复利定投", "每月定投，20 年后是多少", "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.plain)
            NavigationLink {
                FireCalculatorView(store: store)
            } label: {
                toolRow("FIRE 退休测算", "攒够 25 倍年开支要多久", "leaf.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private func toolRow(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.primaryDeep)
                .frame(width: 30, height: 30)
                .background(Palette.primary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: 通用组件

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: squircle(15))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.89, blue: 0.94), lineWidth: 0.8)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(Palette.textTertiary)
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(Palette.textTertiary)
            .padding(.vertical, 6)
    }

    private func lineRow(_ title: String, _ value: String, sub: String? = nil,
                         valueColor: Color = Palette.textPrimary) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                if let sub {
                    Text(sub)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - 手工科目编辑

private struct ManualItemEditor: View {
    let item: ManualItem
    let onSave: (ManualItem?) -> Void
    let onDelete: (String) -> Void

    @State private var name: String
    @State private var kind: ManualItemKind
    @State private var valueText: String
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(item: ManualItem,
         onSave: @escaping (ManualItem?) -> Void,
         onDelete: @escaping (String) -> Void) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: item.name)
        _kind = State(initialValue: item.kind)
        _valueText = State(initialValue: item.value == 0 ? "" : String(format: "%.2f", item.value))
        _note = State(initialValue: item.note)
    }

    private var isNew: Bool { name.isEmpty && item.value == 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(isNew ? "添加科目" : "编辑科目")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("名称")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                    TextField("例如：自住房、比亚迪汉", text: $name)
                        .font(.system(size: 15, design: .rounded))
                        .padding(12)
                        .background(Color(red: 0.965, green: 0.957, blue: 0.98),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("类型")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                    FlowChips(items: ManualItemKind.allCases, selected: kind) { picked in
                        kind = picked
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.isLiability ? "当前欠款（元）" : "当前市值（元）")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                    TextField("0", text: $valueText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                        .padding(12)
                        .background(Color(red: 0.965, green: 0.957, blue: 0.98),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    Text(kind.isLiability ? "填剩余未还本金，不是月供" : "填现在能卖掉的价钱，不是买入价")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("备注")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                    TextField("可选", text: $note)
                        .font(.system(size: 13, design: .rounded))
                        .padding(12)
                        .background(Color(red: 0.965, green: 0.957, blue: 0.98),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }

                Button {
                    var saved = item
                    saved.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved.kind = kind
                    saved.value = Double(valueText.replacingOccurrences(of: ",", with: "")) ?? 0
                    saved.note = note
                    if saved.name.isEmpty {
                        saved.name = kind.label
                    }
                    onSave(saved)
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: Radius.button))

                if !isNew {
                    Button(role: .destructive) {
                        onDelete(item.id)
                        dismiss()
                    } label: {
                        Text("删除这个科目")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.rose)
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
    }
}

private struct FlowChips: View {
    let items: [ManualItemKind]
    let selected: ManualItemKind
    let onPick: (ManualItemKind) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(items) { kind in
                Button {
                    onPick(kind)
                } label: {
                    Text(kind.label)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(selected == kind ? .white
                                         : (kind.isLiability ? Palette.rose : Palette.primaryDeep))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected == kind
                                      ? (kind.isLiability ? Palette.rose : Palette.primary)
                                      : (kind.isLiability ? Palette.rose.opacity(0.09) : Palette.primary.opacity(0.09)))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 贷款计算器

struct LoanCalculatorView: View {
    let store: MoneyStore

    @State private var principalText = ""
    @State private var rateText = "4.2"
    @State private var monthsText = "240"
    @State private var equalInstallment = true

    private var principal: Double { Double(principalText.replacingOccurrences(of: ",", with: "")) ?? 0 }
    private var rate: Double { Double(rateText) ?? 0 }
    private var months: Int { Int(monthsText) ?? 0 }

    private var result: LoanResult {
        equalInstallment
            ? AccountingEngine.loanEqualInstallment(principal: principal, annualRate: rate, months: months)
            : AccountingEngine.loanEqualPrincipal(principal: principal, annualRate: rate, months: months)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                toolCard {
                    toolField("贷款金额（元）", $principalText, "1000000")
                    toolField("年利率（%）", $rateText, "4.2")
                    toolField("期限（月）", $monthsText, "240")
                    HStack(spacing: 8) {
                        modeChip("等额本息", active: equalInstallment) { equalInstallment = true }
                        modeChip("等额本金", active: !equalInstallment) { equalInstallment = false }
                    }
                }
                toolCard {
                    resultRow("首月月供", store.money(result.monthlyFirst), Palette.primaryDeep)
                    if !equalInstallment {
                        resultRow("末月月供", store.money(result.monthlyLast), Palette.textPrimary)
                    }
                    resultRow("还款总额", store.money(result.totalPayment), Palette.textPrimary)
                    resultRow("利息总额", store.money(result.totalInterest), Palette.rose)
                    if principal > 0 && result.totalInterest > 0 {
                        resultRow("利息 / 本金",
                                  String(format: "%.1f%%", result.totalInterest / principal * 100),
                                  Palette.amberGlow)
                    }
                }
                toolCard {
                    Text("等额本息月供固定、前期利息多；等额本金月供递减、总利息少。同样利率下等额本金更省利息，但前期压力大。")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("贷款计算器")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(active ? .white : Palette.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(active ? Palette.primary : Palette.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 复利定投

struct CompoundCalculatorView: View {
    let store: MoneyStore

    @State private var initialText = "0"
    @State private var monthlyText = "2000"
    @State private var rateText = "6"
    @State private var yearsText = "20"

    private var result: CompoundResult {
        AccountingEngine.compound(initial: Double(initialText) ?? 0,
                                  monthly: Double(monthlyText) ?? 0,
                                  annualRate: Double(rateText) ?? 0,
                                  years: Int(yearsText) ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                toolCard {
                    toolField("初始本金（元）", $initialText, "0")
                    toolField("每月定投（元）", $monthlyText, "2000")
                    toolField("预期年化（%）", $rateText, "6")
                    toolField("年限（年）", $yearsText, "20")
                }
                toolCard {
                    resultRow("最终金额", store.money(result.finalValue), Palette.primaryDeep)
                    resultRow("累计投入", store.money(result.contributed), Palette.textPrimary)
                    resultRow("投资收益", store.money(result.gain), Palette.mint)
                    if result.contributed > 0 {
                        resultRow("收益 / 投入",
                                  String(format: "%.0f%%", result.gain / result.contributed * 100),
                                  Palette.amberGlow)
                    }
                }
                toolCard {
                    Text("复利的关键是时间和不中断。年化 6% 下，同样每月 2000 元，坚持 20 年的终值几乎是指数曲线；中途取用或停投，损失的是最赚钱的后期。")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("复利定投")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FIRE 退休测算

struct FireCalculatorView: View {
    let store: MoneyStore

    @State private var expenseText = ""
    @State private var netWorthText = ""
    @State private var savingText = "5000"
    @State private var rateText = "5"
    @State private var withdrawText = "4"

    private var result: FireResult {
        AccountingEngine.fire(annualExpense: Double(expenseText) ?? 0,
                              currentNetWorth: Double(netWorthText) ?? 0,
                              monthlySaving: Double(savingText) ?? 0,
                              annualReturn: Double(rateText) ?? 5,
                              withdrawRate: Double(withdrawText) ?? 4)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                toolCard {
                    toolField("每年开支（元）", $expenseText, "120000")
                    toolField("当前净资产（元）", $netWorthText, "500000")
                    toolField("每月能存（元）", $savingText, "5000")
                    toolField("预期年化（%）", $rateText, "5")
                    toolField("提取率（%）", $withdrawText, "4")
                }
                toolCard {
                    resultRow("财务自由目标", store.money(result.target), Palette.primaryDeep)
                    resultRow("还差", store.money(result.gap), Palette.rose)
                    resultRow("还需要", result.years >= 100 ? "100 年以上" : "\(result.years) 年",
                              Palette.textPrimary)
                    resultRow("完成度", String(format: "%.1f%%", result.progress * 100), Palette.mint)
                }
                toolCard {
                    Text("FIRE 的 4% 法则：攒够年开支的 25 倍，按 4% 提取基本能长期不耗尽本金。想要更稳就按 3.5% 或 3% 算，目标会更大。")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("FIRE 退休测算")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 工具页通用组件

private func toolCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) { content() }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color(red: 0.91, green: 0.89, blue: 0.94), lineWidth: 0.8)
        }
}

private func toolField(_ title: String, _ text: Binding<String>, _ placeholder: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title)
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(Palette.textTertiary)
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
            .padding(11)
            .background(Color(red: 0.965, green: 0.957, blue: 0.98),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private func resultRow(_ title: String, _ value: String, _ color: Color) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Palette.textSecondary)
        Spacer()
        Text(value)
            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(color)
    }
}
