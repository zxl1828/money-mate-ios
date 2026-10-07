import SwiftUI
import Charts
import UIKit
import UniformTypeIdentifiers

// MARK: - 统计区间

enum StatsRange: String, CaseIterable, Identifiable {
    case week, month, year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "近 7 天"
        case .month: return "近 30 天"
        case .year: return "近 12 月"
        }
    }

    var days: Int { self == .week ? 7 : 30 }
}

struct StatsPoint: Identifiable {
    var id: String { label }
    let label: String
    let expense: Double
    let income: Double
}

enum TxType: String, CaseIterable, Identifiable {
    case all = "全部", expense = "支出", income = "收入"
    var id: String { rawValue }
}

extension MoneyStore {
    func series(_ range: StatsRange) -> [StatsPoint] {
        let cal = Calendar.current
        if range == .year {
            return monthlySeries(months: 12).map { StatsPoint(label: $0.label, expense: $0.expense, income: $0.income) }
        }
        let fmt = DateFormatter()
        fmt.dateFormat = range == .week ? "E" : "M/d"
        return stride(from: range.days - 1, through: 0, by: -1).compactMap { offset -> StatsPoint? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let list = txs.filter { cal.isDate($0.date, inSameDayAs: day) }
            let exp = list.filter { $0.isExpense }.reduce(0) { $0 - $1.amountCNY }
            let inc = list.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCNY }
            return StatsPoint(label: fmt.string(from: day), expense: exp, income: inc)
        }
    }

    func rangeTx(_ range: StatsRange) -> [Tx] {
        range == .year ? yearTxs : txs(in: range.days)
    }

    func rangeExpense(_ range: StatsRange) -> Double {
        rangeTx(range).filter { $0.isExpense }.reduce(0) { $0 - $1.amountCNY }
    }

    func rangeIncome(_ range: StatsRange) -> Double {
        rangeTx(range).filter { $0.isIncome }.reduce(0) { $0 + $1.amountCNY }
    }

    func rangeCategories(_ range: StatsRange) -> [CategoryTotal] {
        var bucket: [String: Double] = [:]
        for tx in rangeTx(range) where tx.isExpense {
            bucket[tx.category, default: 0] += -tx.amountCNY
        }
        return bucket.map { CategoryTotal(label: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    func rangeTopExpense(_ range: StatsRange) -> Tx? {
        rangeTx(range).filter { $0.isExpense }.min { $0.amountCNY < $1.amountCNY }
    }

    /// 小紫的账单洞察
    func insights(_ range: StatsRange) -> [String] {
        var result: [String] = []
        let cats = rangeCategories(range)
        if let top = cats.first {
            let total = max(cats.reduce(0) { $0 + $1.value }, 1)
            result.append("「" + top.label + "」占了大头，" + String(Int(top.value / total * 100)) + "%，共 " + money(top.value))
        }
        let label = range == .year ? "这一年" : (range == .week ? "这 7 天" : "这 30 天")
        let exp = rangeExpense(range)
        let days = range == .year ? 365 : range.days
        result.append(label + "一共花掉 " + money(exp) + "，日均 " + money(exp / Double(days)))
        if let moM = monthOverMonth {
            if moM > 0 {
                result.append("比上月同期多了 " + String(Int(moM * 100)) + "%，收敛一点就更好")
            } else {
                result.append("比上月同期省了 " + String(Int(abs(moM) * 100)) + "%，继续保持")
            }
        }
        if budgetRatio >= 1 {
            result.append("预算已超支，看看分类排行，先砍掉最贵的那一项")
        } else if budgetRatio >= 0.85 {
            result.append("预算已用 " + String(Int(budgetRatio * 100)) + "%，接下来几天建议少花点")
        }
        // 更丰富的洞察（与安卓一致）
        if income > 0 {
            let rate = (income - expense) / income
            if rate >= 0.3 {
                result.append("储蓄率 " + String(Int(rate * 100)) + "%，很健康，保持这个节奏")
            } else if rate >= 0 {
                result.append("储蓄率只有 " + String(Int(rate * 100)) + "%，可以从非必要支出里再挤一点")
            } else {
                result.append("本月支出已经超过收入，先看分类排行砍掉最贵那项")
            }
        }
        let cal = Calendar.current
        let daySet = Set(txs(in: 90).map { cal.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        if !daySet.contains(cursor), let y = cal.date(byAdding: .day, value: -1, to: cursor) {
            cursor = y
        }
        while daySet.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        if streak >= 3 {
            result.append("已经连续记账 " + String(streak) + " 天，坚持就是最好的理财习惯")
        }
        if let big = txs(in: 30).filter({ $0.isExpense }).max(by: { $0.amountCNY < $1.amountCNY }) {
            let who = big.merchant.isEmpty ? big.category : big.category + "·" + big.merchant
            result.append("本期最大一笔：" + who + " " + money(big.amountCNY))
        }
        return result
    }
}
// MARK: - 明细页

struct TransactionsPage: View {
    @ObservedObject var store: MoneyStore
    var namespace: Namespace.ID
    var onOpen: (Tx) -> Void

    @State private var query = ""
    @State private var category: String? = nil
    @State private var type: TxType = .all
    @State private var monthOffset = 0
    @State private var onlyRecurring = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                titleRow
                searchBar
                typePicker
                categoryChips
                summaryCard
                listSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.24, dampingFraction: 0.92), value: category)
        .animation(.spring(response: 0.24, dampingFraction: 0.92), value: type)
        .animation(.spring(response: 0.24, dampingFraction: 0.92), value: monthOffset)
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("全部明细")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Palette.ink)
                Text("共 " + String(filtered.count) + " 笔 · " + monthLabel)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                withAnimation { monthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left").frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: Circle())

            Button {
                withAnimation { monthOffset = min(monthOffset + 1, 0) }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 38, height: 38)
                    .opacity(monthOffset == 0 ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .disabled(monthOffset == 0)
            .liquidGlass(.clear.interactive(), in: Circle())
        }
    }

    private var monthLabel: String {
        guard let month = selectedMonth else { return "全部时间" }
        return month.formatted(.dateTime.year().month())
    }

    private var selectedMonth: Date? {
        guard monthOffset != 0 else { return nil }
        return Calendar.current.date(byAdding: .month, value: monthOffset, to: Date())
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.primary)
            TextField("搜索商家 / 备注 / 标签", text: $query)
                .textFieldStyle(.plain)
                .foregroundStyle(Palette.ink)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            SavedFilterBar(query: $query)
                .offset(y: 30)
        }
        .font(.system(.subheadline, design: .rounded))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassPanel(Radius.chip, strong: true)
    }

    private var typePicker: some View {
        HStack(spacing: 8) {
            ForEach(TxType.allCases) { item in
                Button {
                    type = item
                } label: {
                    Text(item.rawValue)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(type == item ? Palette.primary : Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .liquidGlass(type == item ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
            }
            Button {
                onlyRecurring.toggle()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(onlyRecurring ? Palette.primary : Palette.textSecondary)
                    .frame(width: 42)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .liquidGlass(onlyRecurring ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: "全部", active: category == nil) { category = nil }
                ForEach(Tx.categories, id: \.self) { name in
                    chip(title: name, active: category == name) {
                        category = (category == name) ? nil : name
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if title != "全部" {
                    Image(systemName: Tx.symbol(for: title)).font(.system(size: 11))
                }
                Text(title).font(.system(.footnote, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(active ? Palette.primary : Palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .liquidGlass(active ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            MetricChip(title: "筛选支出", value: store.money(filteredExpense), icon: "arrow.up.right", gradient: Palette.expense)
            MetricChip(title: "筛选收入", value: store.money(filteredIncome), icon: "arrow.down.left", gradient: Palette.income)
        }
        .padding(10)
        .glassPanel(Radius.tile)
    }

    private var listSection: some View {
        VStack(spacing: 16) {
            if groups.isEmpty {
                VStack {
                    BuddyHint(mood: .sleepy, title: "没有找到账单", subtitle: "换个关键词或分类试试")
                        .padding(.vertical, 18)
                }
                .frame(maxWidth: .infinity)
                .glassPanel(Radius.tile)
            } else {
                ForEach(groups) { group in
                    daySection(group)
                }
            }
        }
    }

    private func daySection(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dayLabel(group.day))
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink.opacity(0.8))
                Spacer()
                if group.expense > 0 {
                    Text("支出 " + store.money(group.expense))
                        .font(.caption2).foregroundStyle(Palette.rose)
                }
                if group.income > 0 {
                    Text("收入 " + store.money(group.income))
                        .font(.caption2).foregroundStyle(Palette.mint)
                }
            }
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(Array(group.txs.enumerated()), id: \.element.id) { index, tx in
                        TxRow(tx: tx, namespace: namespace, showsTags: true) { onOpen(tx) }
                            .springCascade(index: index)
                            .contextMenu {
                                Button {
                                    onOpen(tx)
                                } label: {
                                    Label("查看详情", systemImage: "info.circle")
                                }
                                Button(role: .destructive) {
                                    store.delete(tx)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    private var filtered: [Tx] {
        let parsed = SearchQuery.parse(query)
        let base = store.filter(query: parsed.keyword,
                                category: parsed.category ?? category,
                                month: parsed.range == nil ? selectedMonth : nil,
                                onlyRecurring: onlyRecurring)
            .filter { parsed.matches($0, store: store) }
        switch type {
        case .all: return base
        case .expense: return base.filter { $0.isExpense }
        case .income: return base.filter { $0.isIncome }
        }
    }

    private var filteredExpense: Double {
        filtered.filter { $0.isExpense }.reduce(0) { $0 - $1.amountCNY }
    }

    private var filteredIncome: Double {
        filtered.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCNY }
    }

    private var groups: [DayGroup] {
        store.groupedByDay(filtered)
    }
}
// MARK: - 统计页


struct StatsPage: View {
    @ObservedObject var store: MoneyStore
    var namespace: Namespace.ID

    @State private var range: StatsRange = .week
    @State private var expandedChart: ExpandedChartType? = nil
    @State private var hoveredPoint: StatsPoint? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                titleRow.springCascade(index: 0, trigger: range)
                rangePicker.springCascade(index: 1, trigger: range)
                overviewCard.springCascade(index: 2, trigger: range)
                trendCard.springCascade(index: 3, trigger: range)
                categoryCard.springCascade(index: 4, trigger: range)
                monthsCard.springCascade(index: 5, trigger: range)
                metricsGrid.springCascade(index: 6, trigger: range)
                insightsCard.springCascade(index: 7, trigger: range)
                LatteFactorCard(store: store).springCascade(index: 8, trigger: range)
                InsightPanel(store: store).springCascade(index: 9, trigger: range)
            }

            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.24, dampingFraction: 0.92), value: range)
        .sheet(item: $expandedChart) { chartType in
            ExpandedChartModal(
                type: chartType,
                range: range,
                store: store,
                onDismiss: { expandedChart = nil }
            )
            // 清掉系统弹窗底板：否则顶部圆角与状态栏处会露出灰白底（脏边）
            .presentationBackground(.clear)
            .presentationCornerRadius(0)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .ignoresSafeArea()
        }
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("数据洞察")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundStyle(Palette.ink)
                Text("小紫帮你把钱看明白").font(.caption).foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            CoinBuddy(mood: MascotMood.forBudget(store.budgetRatio), size: 38)
                .frame(width: 62, height: 62)
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(StatsRange.allCases) { item in
                Button {
                    range = item
                } label: {
                    Text(item.title)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(range == item ? Palette.primary : Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .liquidGlass(range == item ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
            }
        }
    }

    private var points: [StatsPoint] { store.series(range) }

    private var overviewCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                BudgetRing(progress: store.budgetProgress,
                           size: 78,
                           label: String(Int(store.budgetProgress * 100)) + "%")
                VStack(alignment: .leading, spacing: 8) {
                    Text("本月结余").font(.caption).foregroundStyle(Palette.textSecondary)
                    Text(store.money(store.balance))
                        .financialNumber(size: 26, weight: .heavy)
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if let moM = store.monthOverMonth {
                        Text((moM >= 0 ? "环比多花 " : "环比省下 ") + String(Int(abs(moM) * 100)) + "%")
                            .font(.caption2)
                            .foregroundStyle(moM >= 0 ? Palette.rose : Palette.mint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .innerTile(Radius.small, opacity: 0.12)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                MetricChip(title: "区间收入", value: store.money(store.rangeIncome(range)), icon: "arrow.down.left", gradient: Palette.income)
                MetricChip(title: "区间支出", value: store.money(store.rangeExpense(range)), icon: "arrow.up.right", gradient: Palette.expense)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassPanel(Radius.card, strong: true)
        .auraBorder(cornerRadius: Radius.card)
        .purpleBreathingBacklight(cornerRadius: Radius.card)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onTapGesture {
            Haptics.tap()
            expandedChart = .budget
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("支出趋势")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    if let pt = hoveredPoint {
                        Text("当前数值: ¥ " + String(format: "%.2f", pt.expense))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.amberGlow)
                            .contentTransition(.numericText())
                    } else {
                        Text(range.title + " · 虚线为日均")
                            .font(.caption2)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
            }
            TrendChart(points: points,
                       average: store.rangeExpense(range) / Double(max(points.count, 1)),
                       onSelect: { hoveredPoint = $0 })
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .purpleBreathingBacklight(cornerRadius: Radius.card)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onTapGesture {
            Haptics.tap()
            expandedChart = .trend
        }
        .onLongPressGesture {
            Haptics.tap()
            expandedChart = .trend
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "分类占比", subtitle: "支出结构一目了然")
            if store.rangeCategories(range).isEmpty {
                BuddyHint(mood: .happy, title: "这个区间还没有支出", size: 64)
                    .padding(.vertical, 10)
            } else {
                DonutChart(items: store.rangeCategories(range),
                           total: store.rangeExpense(range),
                           money: { store.money($0) })
                VStack(spacing: 10) {
                    ForEach(store.rangeCategories(range).prefix(6)) { item in
                        CategoryRow(item: item,
                                    total: max(store.rangeExpense(range), 1),
                                    budget: store.categoryBudget(item.label),
                                    money: store.money(item.value))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .purpleBreathingBacklight(cornerRadius: Radius.card)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onTapGesture {
            Haptics.tap()
            expandedChart = .category
        }
        .onLongPressGesture {
            Haptics.tap()
            expandedChart = .category
        }
    }

    private var monthsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "近 6 个月收支", subtitle: "柱状为支出，折线为收入")
            MonthsChart(points: store.monthlySeries(months: 6))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .purpleBreathingBacklight(cornerRadius: Radius.card)
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .onTapGesture {
            Haptics.tap()
            expandedChart = .months
        }
        .onLongPressGesture {
            Haptics.tap()
            expandedChart = .months
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "日均支出", value: store.money(store.dailyAverage), icon: "calendar.day.timeline.left", tint: Palette.primary)
            MetricTile(title: "最大单笔", value: store.biggestExpense.map { store.money(abs($0.amountCNY)) } ?? store.money(0), icon: "arrow.up.heart", tint: Palette.rose)
            MetricTile(title: "记账天数", value: String(store.activeDays) + " 天", icon: "checkmark.seal.fill", tint: Palette.mint)
            MetricTile(title: "周期账单", value: String(store.recurringRules.count) + " 条", icon: "arrow.triangle.2.circlepath", tint: Palette.primarySoft)
        }
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CoinBuddy(mood: .cheer, size: 40)
                    .frame(width: 62, height: 62)
                VStack(alignment: .leading, spacing: 2) {
                    Text("小紫的洞察")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("根据你的账本自动生成").font(.caption2).foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            ForEach(Array(store.insights(range).enumerated()), id: \.offset) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Palette.hero).frame(width: 6, height: 6).padding(.top, 6)
                    Text(entry.element)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }
}
// MARK: - 图表组件


struct TrendChart: View {
    let points: [StatsPoint]
    let average: Double
    var onSelect: ((StatsPoint?) -> Void)? = nil

    @State private var selectedDate: String? = nil

    private var maxExpense: Double {
        points.map(\.expense).max() ?? 0
    }

    var body: some View {
        let selected = points.first(where: { $0.label == selectedDate })
        Chart {
            ForEach(points) { point in
                // 面积流光渐变：纵向线性渐变，半透明紫光均匀衰减至底部完全透明
                AreaMark(x: .value("日期", point.label), y: .value("支出", point.expense))
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: Palette.neonViolet.opacity(0.35), location: 0.0),
                                .init(color: Palette.auroraPurple.opacity(0.10), location: 0.55),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                // 平滑高光折线：2.5pt 粗细紫白渐变高光描边
                LineMark(x: .value("日期", point.label), y: .value("支出", point.expense))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Palette.neonViolet, Palette.auroraPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                // 发光数据节点：双层同心圆结构，中心纯白实体高光核，静态霓虹紫晕，彻底消除持续重绘
                if point.expense == maxExpense && maxExpense > 0 {
                    PointMark(x: .value("日期", point.label), y: .value("支出", point.expense))
                        .symbolSize(56)
                        .foregroundStyle(Palette.neonViolet.opacity(0.45))

                    PointMark(x: .value("日期", point.label), y: .value("支出", point.expense))
                        .symbolSize(16)
                        .foregroundStyle(Color.white)
                } else if points.count <= 7 {
                    PointMark(x: .value("日期", point.label), y: .value("支出", point.expense))
                        .symbolSize(26)
                        .foregroundStyle(Palette.neonViolet.opacity(0.35))

                    PointMark(x: .value("日期", point.label), y: .value("支出", point.expense))
                        .symbolSize(10)
                        .foregroundStyle(Color.white)
                }
            }

            // 基准日均参考线：高辨识度双色细虚线（琥珀金/紫霓虹）
            RuleMark(y: .value("日均", average))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Palette.amberGlow, Palette.amberWarm],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("日均 ¥" + String(format: "%.0f", average))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.amberGlow)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                }

            if let sel = selected {
                RuleMark(x: .value("日期", sel.label))
                    .foregroundStyle(Palette.amberGlow.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                PointMark(x: .value("日期", sel.label), y: .value("支出", sel.expense))
                    .symbolSize(88)
                    .foregroundStyle(Palette.amberGlow.opacity(0.35))

                PointMark(x: .value("日期", sel.label), y: .value("支出", sel.expense))
                    .symbolSize(22)
                    .foregroundStyle(Color.white)
                    .annotation(position: .top) {
                        Text("¥ " + String(format: "%.2f", sel.expense))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Palette.amberGlow, lineWidth: 1.2))
                            .shadow(color: Palette.amberGlow.opacity(0.4), radius: 6)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .onChange(of: selectedDate) { _, newDate in
            let pt = points.first(where: { $0.label == newDate })
            onSelect?(pt)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [2, 4]))
                    .foregroundStyle(Palette.textTertiary.opacity(0.18))
                AxisValueLabel().font(.system(size: 9, design: .rounded)).foregroundStyle(Palette.textTertiary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(points.count, 7))) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [2, 4]))
                    .foregroundStyle(Palette.textTertiary.opacity(0.15))
                AxisValueLabel().font(.system(size: 9, design: .rounded)).foregroundStyle(Palette.textTertiary)
            }
        }
        .frame(height: 190)
    }
}

struct DonutChart: View {
    let items: [CategoryTotal]
    let total: Double
    let money: (Double) -> String
    var selectedCategory: String? = nil
    var onSelect: ((CategoryTotal?) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let activeItem = items.first(where: { $0.label == selectedCategory })
        let isDark = colorScheme == .dark
        let trackColors = isDark
            ? [Color(red: 0.08, green: 0.05, blue: 0.16).opacity(0.95),
               Color(red: 0.14, green: 0.08, blue: 0.24).opacity(0.85)]
            : [Color(red: 0.86, green: 0.84, blue: 0.93).opacity(0.94),
               Color.white.opacity(0.88)]
        let wellColors = isDark
            ? [Color(red: 0.06, green: 0.04, blue: 0.14).opacity(0.92),
               Color(red: 0.18, green: 0.11, blue: 0.32).opacity(0.40)]
            : [Color.white.opacity(0.96),
               Color(red: 0.88, green: 0.85, blue: 0.95).opacity(0.72)]
        ZStack {
            // 环形凹槽导轨底座 (Recessed Track Well)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: trackColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 36
                )
                .frame(width: 174, height: 174)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 208, height: 208)
                )

            // 分类多扇区独立镶嵌彩色水晶切片 (2.5pt 物理间隙与倒角切面)
            Chart(items) { item in
                let isSelected = item.label == selectedCategory
                SectorMark(
                    angle: .value("金额", item.value),
                    innerRadius: .ratio(0.62),
                    outerRadius: isSelected ? .ratio(1.05) : .ratio(1.0),
                    angularInset: 2.5
                )
                .cornerRadius(5)
                .foregroundStyle(Palette.categoryColor(item.label))
                .opacity(selectedCategory == nil || isSelected ? 1.0 : 0.45)
            }
            .chartLegend(.hidden)
            .frame(height: 220)

            // 微凹透镜内芯 (Concave Glass Well)
            Circle()
                .fill(
                    RadialGradient(
                        colors: wellColors,
                        center: .center,
                        startRadius: 0,
                        endRadius: 68
                    )
                )
                .frame(width: 136, height: 136)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Palette.neonViolet.opacity(0.25), radius: 8)

            // 居中高对比度层级文字 (联动选中)
            VStack(spacing: 2) {
                if let sel = activeItem {
                    let pct = Int((sel.value / max(total, 1)) * 100)
                    Text(sel.label)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.categoryColor(sel.label))
                    Text(money(sel.value))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("\(pct)%")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("总支出")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    Text(money(total))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("全部分类")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .frame(width: 118)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: selectedCategory)
    }
}

struct MonthsChart: View {
    let points: [MonthPoint]

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(x: .value("月份", point.label), y: .value("支出", point.expense), width: .fixed(14))
                    .foregroundStyle(Palette.hero)
                    .cornerRadius(6)
                LineMark(x: .value("月份", point.label), y: .value("收入", point.income))
                    .foregroundStyle(Palette.mint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .symbol(.circle)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.ink.opacity(0.08))
                AxisValueLabel().font(.system(size: 9, design: .rounded))
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.system(size: 9, design: .rounded))
            }
        }
        .frame(height: 170)
    }
}

struct CategoryRow: View {
    let item: CategoryTotal
    let total: Double
    let budget: Double
    let money: String

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: Tx.symbol(for: item.label))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Palette.categoryGradient(item.label), in: Circle())
                Text(item.label)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Palette.ink)
                Text(String(Int(min(item.value / max(total, 1), 1) * 100)) + "%")
                    .font(.caption2).foregroundStyle(Palette.textSecondary)
                Spacer()
                Text(money)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.7)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.ink.opacity(0.08))
                    Capsule()
                        .fill(Palette.categoryGradient(item.label))
                        .frame(width: max(8, proxy.size.width * min(item.value / max(total, 1), 1)))
                    if budget > 0 {
                        Capsule()
                            .fill(Palette.textSecondary)
                            .frame(width: 2)
                            .offset(x: max(0, min(proxy.size.width - 2, proxy.size.width * min(budget / max(total, 1), 1))))
                    }
                }
            }
            .frame(height: 8)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            Text(title).font(.caption2).foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel(Radius.tile)
    }
}
// MARK: - 备份文档

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - 资产概览卡片

struct AssetOverviewCard: View {
    let netWorth: Double
    let accountCount: Int
    let money: (Double) -> String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                iconView
                textView
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(16)
            .clearLiquidGlass(cornerRadius: Radius.tile)
        }
        .buttonStyle(GelPressButtonStyle(cornerRadius: Radius.tile))
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Palette.auroraPurple, Palette.primaryDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: Palette.neonViolet.opacity(0.35), radius: 6)

            Image(systemName: "banknote.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var textView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("资产管理与净资产")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            Text("净资产 \(money(netWorth)) · \(accountCount) 个活跃账户")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }
}

// MARK: - 我的（设置）

struct SettingsPage: View {
    @ObservedObject var store: MoneyStore
    var namespace: Namespace.ID
    var toast: (String) -> Void

    @State private var confirmClear = false
    @State private var showExport = false
    @State private var showImport = false
    @State private var showNetWorth = false
    @State private var showCategoryBudget = false
    @State private var showCalendar = false
    @State private var showCategories = false
    @State private var showLedgerMerge = false
    @State private var showSmartBudget = false
    @State private var showBillImport = false
    @State private var shareFile: ShareFile?
    @ObservedObject private var cloud = CloudSyncService.shared
    @ObservedObject private var privacy = PrivacyState.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                assetCard
                budgetCard
                prefsCard
                reminderCard
                toolsCard
                ledgerCard
                dataCard
                aboutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("确定清空全部账单？此操作不可撤销。",
                            isPresented: $confirmClear,
                            titleVisibility: .visible) {
            Button("清空全部", role: .destructive) {
                store.clearAll()
                toast("已清空全部账单")
            }
            Button("取消", role: .cancel) { }
        }
        .fileExporter(isPresented: $showExport,
                      document: BackupDocument(data: store.exportJSON() ?? Data()),
                      contentType: .json,
                      defaultFilename: "MoneyMate-backup") { result in
            if case .success = result { toast("备份已导出") } else { toast("导出已取消") }
        }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showNetWorth) {
            NetWorthPage(store: store)
        }
        .sheet(isPresented: $showCategoryBudget) {
            CategoryBudgetSheet(store: store)
        }
        .sheet(isPresented: $showCalendar) {
            CalendarView(store: store)
        }
        .sheet(isPresented: $showCategories) {
            CategoryManagerSheet(store: store)
        }
        .sheet(isPresented: $showSmartBudget) {
            SmartBudgetSheet(store: store)
        }
        .sheet(isPresented: $showBillImport) {
            BillImportSheet(store: store)
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url])
        }
        .fileImporter(isPresented: $showLedgerMerge, allowedContentTypes: [.json]) { result in
            handleLedgerMerge(result)
        }
    }


    private func handleLedgerMerge(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { toast("文件读不出来"); return }
            if let report = SharedLedgerService.merge(data, into: store) {
                toast("已合并：新增 \(report.addedTx) 笔，更新 \(report.updatedTx) 笔")
            } else {
                toast("不是 MoneyMate 共享包")
            }
        case .failure:
            toast("导入已取消")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), store.importJSON(data) {
                toast("账本已恢复")
            } else {
                toast("文件无法识别")
            }
        case .failure:
            toast("导入已取消")
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            CoinBuddy(mood: MascotMood.forBudget(store.budgetRatio), size: 50)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 6) {
                Text("我的账本")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("共 " + String(store.txs.count) + " 笔记录 · 本月记账 " + String(store.activeDays) + " 天")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 6) {
                    TagChip(text: store.baseCurrency.rawValue)
                    TagChip(text: "离线优先")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var assetCard: some View {
        AssetOverviewCard(
            netWorth: store.netWorthValue,
            accountCount: store.activeAccounts.count,
            money: { store.money($0) },
            onTap: { showNetWorth = true }
        )
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "预算管理", subtitle: "每月预算 " + store.money(store.budget))
            PiggyBuddy(progress: store.budgetProgress, size: 108)
                .frame(maxWidth: .infinity)
            Slider(value: $store.budget, in: 500...80000, step: 500)
                .tint(Palette.primary)
            HStack {
                Text("剩余 " + store.money(store.budgetLeft))
                    .font(.caption).foregroundStyle(Palette.ink.opacity(0.65))
                Spacer()
                Text("已用 " + String(Int(store.budgetRatio * 100)) + "%")
                    .font(.caption).foregroundStyle(Palette.ink.opacity(0.65))
            }
            HStack(spacing: 10) {
                glassButton(title: "智能预算", systemImage: "sparkles") {
                    showSmartBudget = true
                }
                glassButton(title: "分类预算", systemImage: "chart.pie.fill") {
                    showCategoryBudget = true
                }
                glassButton(title: "日历记账", systemImage: "calendar") {
                    showCalendar = true
                }
            }

            // 非常规支出：标了就不参与预算建议（节日 / 婚礼 / 一次性大件）
            Text("非常规支出（不计入预算建议）")
                .font(.caption2).foregroundStyle(Palette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.expenseCategories.map(\.name), id: \.self) { name in
                        Button {
                            store.toggleIrregularCategory(name)
                            Haptics.select()
                        } label: {
                            Text(name)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(store.irregularCategories.contains(name)
                                                 ? Palette.primary : Palette.ink.opacity(0.7))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .liquidGlass(store.irregularCategories.contains(name)
                                     ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
                    }
                }
            }
            ForEach(store.overBudgetCategories.prefix(3)) { item in
                Text("提醒：" + item.label + " 已用掉预算的 " + String(Int(item.value * 100)) + "%")
                    .font(.caption2)
                    .foregroundStyle(Palette.rose)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func glassButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: Capsule())
    }

    private var prefsCard: some View {
        VStack(spacing: 2) {
            appearanceRow
            divider
            toggleRow(title: "隐私模式（金额模糊）", icon: "eye.slash.fill", isOn: $privacy.enabled)
            divider
            toggleRow(title: "启动隐私锁（面容 / 指纹）", icon: "faceid", isOn: $store.privacyLock)
            divider
            toggleRow(title: "震动反馈", icon: "iphone.radiowaves.left.and.right", isOn: $store.hapticsEnabled)
            divider
            toggleRow(title: "周期账单自动补录", icon: "arrow.triangle.2.circlepath", isOn: $store.recurringEnabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    /// 深色 / 浅色 / 跟随系统
    private var appearanceRow: some View {
        HStack(spacing: 12) {
            Image(systemName: store.appearance.icon)
                .foregroundStyle(Palette.primary)
                .frame(width: 22)
            Text("外观")
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Picker("外观", selection: $store.appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 210)
        }
        .padding(.vertical, 9)
    }

    /// 本地提醒（全部离线，不需要账号）
    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "提醒", subtitle: "本地通知，不上传任何数据")
            toggleRow(title: "每日记账提醒", icon: "bell.badge.fill", isOn: $store.dailyReminder)
            if store.dailyReminder {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill").foregroundStyle(Palette.primary)
                    DatePicker("提醒时间",
                               selection: Binding(get: {
                                   Calendar.current.date(bySettingHour: store.dailyReminderHour,
                                                         minute: store.dailyReminderMinute,
                                                         second: 0, of: Date()) ?? Date()
                               }, set: { newValue in
                                   let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                   store.dailyReminderHour = comps.hour ?? 21
                                   store.dailyReminderMinute = comps.minute ?? 0
                               }),
                               displayedComponents: .hourAndMinute)
                        .font(.system(.subheadline, design: .rounded))
                }
                .padding(.leading, 34)
            }
            divider
            toggleRow(title: "超预算提醒", icon: "exclamationmark.triangle.fill", isOn: $store.budgetAlert)
            divider
            toggleRow(title: "信用卡还款提醒", icon: "creditcard.fill", isOn: $store.creditAlert)
            Button {
                Task { @MainActor in
                    let ok = await NotificationService.shared.requestPermission()
                    NotificationService.shared.reschedule(store: store)
                    toast(ok ? "通知已开启" : "请在系统设置里允许通知")
                }
            } label: {
                Label("开启系统通知权限", systemImage: "bell.and.waves.left.and.right.fill")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .innerTile(Radius.button, opacity: 0.10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    /// 分类与导出
    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "分类与导出", subtitle: "自定义分类、导出 CSV 给 Excel")
            glassRow(title: "分类管理", systemImage: "square.grid.2x2.fill") {
                showCategories = true
            }
            glassRow(title: "导出 CSV（Excel 可打开）", systemImage: "tablecells") {
                if let url = ExportService.csvFile(store: store) {
                    shareFile = ShareFile(url: url)
                } else {
                    toast("导出失败")
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    /// 共享账本 + iCloud
    private var ledgerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "共享账本", subtitle: store.ledgerName + " \u{00B7} " + String(store.members.count) + " 人")
            Text("各自在自己手机上记，再用「共享包」合并成一本账；同一条记录以最后修改的为准，不会重复入账。")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Text("账本名").font(.caption).foregroundStyle(Palette.textSecondary)
                TextField("账本名", text: $store.ledgerName)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                Spacer(minLength: 0)
                Text("我").font(.caption).foregroundStyle(Palette.textSecondary)
                TextField("称呼", text: $store.myName)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .frame(maxWidth: 70)
            }
            .padding(.vertical, 6)
            glassRow(title: "导出共享包给对方", systemImage: "square.and.arrow.up.on.square") {
                if let data = SharedLedgerService.exportPackage(store: store) {
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent(SharedLedgerService.suggestedFileName(store: store))
                    do {
                        try data.write(to: url, options: .atomic)
                        shareFile = ShareFile(url: url)
                    } catch {
                        toast("导出失败")
                    }
                } else {
                    toast("导出失败")
                }
            }
            glassRow(title: "合并对方的共享包", systemImage: "arrow.triangle.merge") {
                showLedgerMerge = true
            }
            divider
            toggleRow(title: "iCloud 同步（同账号多设备）", icon: "icloud.fill", isOn: $store.cloudSync)
            Text(cloud.status.text)
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if store.cloudSync {
                HStack(spacing: 10) {
                    glassButton(title: "立即上传", systemImage: "icloud.and.arrow.up") {
                        if let data = store.exportJSON() {
                            cloud.push(data: data)
                            toast("已上传到 iCloud")
                        }
                    }
                    glassButton(title: "从 iCloud 恢复", systemImage: "icloud.and.arrow.down") {
                        if let data = cloud.remotePayload(), store.importJSON(data) {
                            toast("已从 iCloud 恢复")
                        } else {
                            toast("云端还没有账本")
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var divider: some View {
        Rectangle().fill(Palette.ink.opacity(0.08)).frame(height: 1)
    }

    private func toggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.9))
            } icon: {
                Image(systemName: icon).foregroundStyle(Palette.primary)
            }
        }
        .tint(Palette.primary)
        .padding(.vertical, 9)
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "数据与备份", subtitle: "账单导入、数据备份与迁移")
            glassRow(title: "微信 / 支付宝账单 CSV 导入", systemImage: "arrow.down.doc.fill") {
                showBillImport = true
            }
            glassRow(title: "导出账本备份", systemImage: "square.and.arrow.up") { showExport = true }
            glassRow(title: "从备份恢复", systemImage: "tray.and.arrow.down") { showImport = true }

            plainRow(title: "恢复示例数据", systemImage: "arrow.counterclockwise", tint: Palette.ink.opacity(0.85)) {
                store.restoreSamples()
                toast("已恢复示例数据")
            }
            plainRow(title: "清空全部账单", systemImage: "trash", tint: Palette.rose) {
                confirmClear = true
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func glassRow(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    private func plainRow(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关于 MoneyMate")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.ink)
            Text("版本 1.1 · iOS 26 液态玻璃 · 纯本地存储，账本只留在你的手机里。")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                TagChip(text: "无第三方库")
                TagChip(text: "SwiftUI")
                TagChip(text: "Swift Charts")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card)
    }
}

// MARK: - 分类预算

struct CategoryBudgetSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    ForEach(Tx.categories, id: \.self) { name in
                        row(name)
                    }
                }
                .padding(20)
            }
            .background(GlassBackground())
            .navigationTitle("分类预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            PiggyBuddy(progress: store.budgetProgress, size: 84)
                .frame(width: 104, height: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text("给小猪分好口粮")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text("0 表示该分类不单独设限").font(.caption).foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassPanel(Radius.tile, strong: true)
    }

    private func row(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: Tx.symbol(for: name))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Palette.categoryGradient(name), in: Circle())
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(store.categoryBudget(name) > 0 ? store.money(store.categoryBudget(name)) : "不限额")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.primary)
            }
            Slider(value: binding(name), in: 0...10000, step: 100)
                .tint(Palette.primary)
            Text("本月已花 " + store.money(store.categorySpent(name)))
                .font(.caption2).foregroundStyle(Palette.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.tile)
    }

    private func binding(_ name: String) -> Binding<Double> {
        Binding(get: { store.budgetByCategory[name] ?? 0 },
                set: { store.budgetByCategory[name] = $0 })
    }
}

// MARK: - 分享文件（CSV / 共享包）

struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
