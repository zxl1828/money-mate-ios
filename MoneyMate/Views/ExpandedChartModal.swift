import SwiftUI
import Charts

// MARK: - 图表聚焦放大视窗枚举
enum ExpandedChartType: Identifiable, Equatable {
    case budget
    case trend
    case category
    case months

    var id: String {
        switch self {
        case .budget: return "budget"
        case .trend: return "trend"
        case .category: return "category"
        case .months: return "months"
        }
    }

    var title: String {
        switch self {
        case .budget: return "预算进度全维度透视"
        case .trend: return "支出趋势精细分析"
        case .category: return "分类支出结构全景视窗"
        case .months: return "收支周期全景透视"
        }
    }

    var subtitle: String {
        switch self {
        case .budget: return "3D 晶石流光导轨 · 智能弹性缓冲全景"
        case .trend: return "高精度数据探针 · 毫秒级磁吸连续跟踪"
        case .category: return "彩色水晶切片 · 结构与渗透率交互透镜"
        case .months: return "近 6 个月趋势对比与资产沉淀"
        }
    }

    var icon: String {
        switch self {
        case .budget: return "gauge.with.needle.fill"
        case .trend: return "chart.xyaxis.line"
        case .category: return "chart.pie.fill"
        case .months: return "chart.bar.xaxis"
        }
    }
}

// MARK: - 沉浸式图表放大检查弹窗
struct ExpandedChartModal: View {
    let type: ExpandedChartType
    let range: StatsRange
    @ObservedObject var store: MoneyStore
    let onDismiss: () -> Void

    @State private var selectedDate: String? = nil
    @State private var selectedCategory: String? = nil
    @State private var dragOffset: CGFloat = 0

    private var points: [StatsPoint] { store.series(range) }
    private var categories: [CategoryTotal] { store.rangeCategories(range) }
    private var monthlyPoints: [MonthPoint] { store.monthlySeries(months: 6) }

    var body: some View {
        ZStack {
            // 背景深色液态玻璃遮罩，突出当前浮层的核心地位
            Color.black.opacity(0.68)
                .ignoresSafeArea()
                .onTapGesture {
                    Haptics.tap()
                    onDismiss()
                }

            VStack(spacing: 0) {
                // 顶部向下滑动拖拽指示把手
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 44, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // 顶部控制栏
                topControlBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.horizontal, 16)

                // 核心图表与数据探针展开内容
                ScrollView {
                    VStack(spacing: 20) {
                        switch type {
                        case .budget:
                            expandedBudgetSection
                        case .trend:
                            expandedTrendSection
                        case .category:
                            expandedCategorySection
                        case .months:
                            expandedMonthsSection
                        }

                        // 底部数据摘要栏 (通透微卡片群)
                        bottomMetricsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.12, green: 0.08, blue: 0.22).opacity(0.96), location: 0.0),
                                .init(color: Color(red: 0.07, green: 0.05, blue: 0.14).opacity(0.98), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.40), location: 0.0),
                                        .init(color: Palette.neonViolet.opacity(0.30), location: 0.4),
                                        .init(color: Color.white.opacity(0.08), location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.65), radius: 36, x: 0, y: 16)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 24)
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 90 || value.predictedEndTranslation.height > 160 {
                            Haptics.tap()
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.88).combined(with: .opacity),
            removal: .scale(scale: 0.92).combined(with: .opacity)
        ))
    }

    // MARK: - 顶部控制栏
    private var topControlBar: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Palette.neonViolet.opacity(0.25))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(Palette.neonViolet.opacity(0.45), lineWidth: 1))
                Image(systemName: type.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.neonViolet)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                Text(type.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.82, green: 0.72, blue: 0.98).opacity(0.85))
            }

            Spacer(minLength: 0)

            // 半透明晶石关闭按钮 (“×”)
            Button {
                Haptics.tap()
                onDismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 展开折线图视窗
    private var expandedTrendSection: some View {
        let selectedPt = points.first(where: { $0.label == selectedDate })
        let avg = store.rangeExpense(range) / Double(max(points.count, 1))

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前探针数值")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(store.money(selectedPt?.expense ?? store.rangeExpense(range)))
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.amberGlow)
                            .contentTransition(.numericText())
                        if let sel = selectedPt {
                            Text("(\(sel.label))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.75))
                        }
                    }
                }
                Spacer()
                Text("拖拽折线自由探查")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.neonViolet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.neonViolet.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(Palette.neonViolet.opacity(0.3), lineWidth: 1))
            }
            .padding(14)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))

            // 全尺寸高分辨率折线图
            Chart {
                ForEach(points) { pt in
                    AreaMark(x: .value("日期", pt.label), y: .value("支出", pt.expense))
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: Palette.neonViolet.opacity(0.45), location: 0.0),
                                    .init(color: Palette.auroraPurple.opacity(0.15), location: 0.6),
                                    .init(color: Color.clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                    LineMark(x: .value("日期", pt.label), y: .value("支出", pt.expense))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Palette.neonViolet, Palette.auroraPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)

                    PointMark(x: .value("日期", pt.label), y: .value("支出", pt.expense))
                        .symbolSize(36)
                        .foregroundStyle(Palette.neonViolet.opacity(0.4))

                    PointMark(x: .value("日期", pt.label), y: .value("支出", pt.expense))
                        .symbolSize(14)
                        .foregroundStyle(Color.white)
                }

                // 日均参考线
                RuleMark(y: .value("日均", avg))
                    .foregroundStyle(Palette.amberGlow)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("日均 " + store.money(avg))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.amberGlow)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6), in: Capsule())
                            .overlay(Capsule().stroke(Palette.amberGlow.opacity(0.6), lineWidth: 1))
                    }

                // 交互磁吸探针
                if let sel = selectedPt {
                    RuleMark(x: .value("日期", sel.label))
                        .foregroundStyle(Palette.amberGlow)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))

                    PointMark(x: .value("日期", sel.label), y: .value("支出", sel.expense))
                        .symbolSize(120)
                        .foregroundStyle(Palette.amberGlow.opacity(0.35))

                    PointMark(x: .value("日期", sel.label), y: .value("支出", sel.expense))
                        .symbolSize(28)
                        .foregroundStyle(Color.white)
                        .annotation(position: .top) {
                            VStack(spacing: 2) {
                                Text(sel.label)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                Text(store.money(sel.expense))
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Palette.amberGlow)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.10, green: 0.07, blue: 0.18).opacity(0.95), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.amberGlow, lineWidth: 1.2))
                            .shadow(color: Palette.amberGlow.opacity(0.5), radius: 8)
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 4]))
                        .foregroundStyle(Color.white.opacity(0.12))
                    AxisValueLabel().font(.system(size: 10, design: .rounded)).foregroundStyle(Color.white.opacity(0.65))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(points.count, 7))) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 4]))
                        .foregroundStyle(Color.white.opacity(0.12))
                    AxisValueLabel().font(.system(size: 10, design: .rounded)).foregroundStyle(Color.white.opacity(0.65))
                }
            }
            .frame(height: 250)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 展开预算环视窗
    private var expandedBudgetSection: some View {
        VStack(spacing: 22) {
            // 大号 3D 晶石流光环体 (屏幕宽度约 70%)
            ToroidalGemRing(
                progress: store.budgetProgress,
                size: 210,
                percentText: String(Int(store.budgetProgress * 100)) + "%",
                label: store.budgetProgress >= 1.0 ? "已超预算" : "已用预算",
                showOuterGlow: true,
                showCenterWell: true
            )
            .padding(.top, 8)

            // 环形外围数据药丸卡片
            HStack(spacing: 12) {
                glassIndicatorPill(title: "总预算", value: store.money(store.budget), color: Palette.primary)
                glassIndicatorPill(title: "已支出", value: store.money(store.expense), color: Palette.rose)
                glassIndicatorPill(title: "可用结余", value: store.money(store.budgetLeft), color: Palette.mint)
            }
        }
    }

    private func glassIndicatorPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.65))
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - 展开分类饼图视窗
    private var expandedCategorySection: some View {
        VStack(spacing: 20) {
            // 大号多扇区晶石切面饼图
            DonutChart(
                items: categories,
                total: store.rangeExpense(range),
                money: { store.money($0) },
                selectedCategory: selectedCategory,
                onSelect: { cat in
                    selectedCategory = cat?.label
                }
            )
            .scaleEffect(1.22)
            .frame(height: 230)
            .padding(.vertical, 12)

            Text("点击下方分类卡片或图表切片，透镜即刻联动")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textSecondary)

            // 图例网格平铺列表 (点击联动透镜)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(categories) { cat in
                    let isSelected = selectedCategory == cat.label
                    let pct = Int((cat.value / max(store.rangeExpense(range), 1)) * 100)

                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            selectedCategory = (selectedCategory == cat.label ? nil : cat.label)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Palette.categoryColor(cat.label))
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                Text("\(pct)%")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            Spacer(minLength: 0)
                            Text(store.money(cat.value))
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Palette.neonViolet.opacity(0.25) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? Palette.neonViolet : Color.white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 展开近 6 个月收支视窗
    private var expandedMonthsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonthsChart(points: monthlyPoints)
                .frame(height: 220)
                .padding(.vertical, 8)
        }
    }

    // MARK: - 底部数据摘要栏 (通透微卡片形式)
    private var bottomMetricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("精细指标透视")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.85))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                switch type {
                case .trend:
                    let maxVal = points.map(\.expense).max() ?? 0
                    let avgVal = store.rangeExpense(range) / Double(max(points.count, 1))
                    metricCard(title: "区间峰值单日", value: store.money(maxVal), icon: "chart.line.uptrend.xyaxis", tint: Palette.rose)
                    metricCard(title: "日均基线支出", value: store.money(avgVal), icon: "calendar.day.timeline.left", tint: Palette.amberGlow)
                    if let mom = store.monthOverMonth {
                        metricCard(title: "环比趋势涨跌", value: (mom >= 0 ? "+" : "") + String(format: "%.1f%%", mom * 100), icon: mom >= 0 ? "arrow.up.right" : "arrow.down.right", tint: mom >= 0 ? Palette.rose : Palette.mint)
                    } else {
                        metricCard(title: "记录数据点", value: "\(points.count) 天", icon: "checkmark.seal", tint: Palette.mint)
                    }
                    metricCard(title: "区间累计总支出", value: store.money(store.rangeExpense(range)), icon: "creditcard.fill", tint: Palette.neonViolet)

                case .budget:
                    let remDays = max(1, 30 - Calendar.current.component(.day, from: Date()))
                    let dailyCeiling = store.budgetLeft > 0 ? store.budgetLeft / Double(remDays) : 0
                    metricCard(title: "建议日均限额", value: store.money(dailyCeiling), icon: "shield.lefthalf.filled", tint: Palette.mint)
                    metricCard(title: "距离月末天数", value: "\(remDays) 天", icon: "calendar", tint: Palette.primary)
                    metricCard(title: "预算防御健康度", value: store.budgetProgress < 0.85 ? "安全" : (store.budgetProgress <= 1.0 ? "偏紧" : "超支"), icon: "heart.text.square.fill", tint: store.budgetProgress < 0.85 ? Palette.mint : Palette.rose)
                    metricCard(title: "弹性缓冲池", value: "8% 预留", icon: "sparkles", tint: Palette.auroraPurple)

                case .category:
                    let topCat = categories.first
                    metricCard(title: "首要开销分类", value: topCat?.label ?? "无", icon: "crown.fill", tint: Palette.amberGlow)
                    metricCard(title: "涉及支出类目", value: "\(categories.count) 类", icon: "square.grid.2x2", tint: Palette.primary)
                    metricCard(title: "最大单笔开销", value: store.biggestExpense.map { store.money(abs($0.amountCNY)) } ?? store.money(0), icon: "arrow.up.heart", tint: Palette.rose)
                    metricCard(title: "平均类目消耗", value: categories.isEmpty ? "¥0" : store.money(store.rangeExpense(range) / Double(categories.count)), icon: "divide", tint: Palette.mint)

                case .months:
                    let totalExp = monthlyPoints.reduce(0.0) { $0 + $1.expense }
                    let totalInc = monthlyPoints.reduce(0.0) { $0 + $1.income }
                    metricCard(title: "半年总支出", value: store.money(totalExp), icon: "arrow.up.right", tint: Palette.rose)
                    metricCard(title: "半年总收入", value: store.money(totalInc), icon: "arrow.down.left", tint: Palette.mint)
                    metricCard(title: "半年净结余", value: store.money(totalInc - totalExp), icon: "wallet.pass.fill", tint: Palette.mint)
                    metricCard(title: "月均消耗", value: store.money(totalExp / Double(max(monthlyPoints.count, 1))), icon: "calendar.badge.clock", tint: Palette.primary)
                }
            }
        }
    }

    private func metricCard(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
                Text(value)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
}
