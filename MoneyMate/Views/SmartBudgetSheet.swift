import SwiftUI

// MARK: - 智能预算诊断与推荐抽屉

struct SmartBudgetSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var report: SmartBudgetReport?
    @State private var adjustedBudget: Double = 0
    @State private var hasAdopted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let rep = report {
                        heroRecommendCard(rep)
                        breakdownCard(rep)
                        if !rep.strippedSpecialExpenses.isEmpty {
                            strippedCard(rep)
                        }
                        fineTuneCard
                    } else {
                        ProgressView("正在基于历史真实数据建模测算...")
                            .padding(.top, 40)
                    }
                }
                .padding(20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("智能预算推荐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("采纳并保存") {
                        adoptBudget()
                    }
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.primary)
                }
            }
            .onAppear {
                calculate()
            }
        }
    }

    private func calculate() {
        let rep = SmartBudgetEngine.generateReport(
            txs: store.txs,
            irregularCategories: Set(store.irregularCategories),
            recurringRules: store.recurringRules,
            currentBudget: store.budget
        )

        report = rep
        adjustedBudget = rep.recommendedBudget
    }

    private func adoptBudget() {
        Haptics.success()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            store.budget = adjustedBudget
            hasAdopted = true
        }
        dismiss()
    }

    // MARK: - 1. 核心推荐 Hero 卡片
    private func heroRecommendCard(_ rep: SmartBudgetReport) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label("AI 智能去噪测算", systemImage: "sparkles")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.neonViolet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Palette.neonViolet.opacity(0.16), in: Capsule())
                Spacer()
                Text("当前预算: " + store.money(store.budget))
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }

            VStack(spacing: 4) {
                Text("下月建议预算")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                Text(store.money(adjustedBudget))
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
            }

            Text(rep.reasoningSummary)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button(action: adoptBudget) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("一键采纳此推荐")
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Palette.auroraPurple, Palette.primaryDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(color: Palette.neonViolet.opacity(0.4), radius: 10, y: 4)
            }
            .buttonStyle(GelPressButtonStyle(cornerRadius: 24))
            .padding(.top, 6)
        }
        .padding(20)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }

    // MARK: - 2. 测算组成拆解
    private func breakdownCard(_ rep: SmartBudgetReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "预算组成拆解", subtitle: "拒绝一刀切，多维结构化推导")

            VStack(spacing: 10) {
                breakdownRow(
                    title: "常规日常刚需",
                    subtitle: "日均约 \(store.money(rep.baselineDaily)) · 餐饮、日常交通、生活杂支",
                    value: store.money(rep.baselineMonthly),
                    color: Palette.mint,
                    icon: "cart.fill"
                )

                breakdownRow(
                    title: "固定周期账单",
                    subtitle: "\(store.recurringRules.count) 笔周期规则 · 房租、水电、定期订阅",
                    value: store.money(rep.recurringCommitment),
                    color: Palette.auroraPurple,
                    icon: "arrow.triangle.2.circlepath"
                )

                breakdownRow(
                    title: "弹性安全储备金",
                    subtitle: "建议预留 8% 缓冲，防范日常临时波动",
                    value: store.money(rep.safetyBuffer),
                    color: Palette.amberGlow,
                    icon: "shield.lefthalf.filled"
                )
            }
        }
        .padding(18)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }

    private func breakdownRow(title: String, subtitle: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: 4)

            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(12)
        .background(Palette.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 3. 自动剥离的特殊/节假日偶发支出
    private func strippedCard(_ rep: SmartBudgetReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("已自动剥离特殊支出", systemImage: "sparkles.rectangle.stack.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("已剔除 " + store.money(rep.strippedTotal))
                    .font(.caption)
                    .foregroundStyle(Palette.amberGlow)
            }

            Text("以下开销被识别为节日礼物、耐用品大件或非常规支出，系统已将其从日常基线中剥离，防止日常预算被意外拉高：")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)

            VStack(spacing: 8) {
                ForEach(rep.strippedSpecialExpenses.prefix(6)) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.textPrimary)
                            HStack(spacing: 6) {
                                Text(item.category)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.primary)
                                Text("·")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.textTertiary)
                                Text(item.reason)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.amberWarm)
                            }
                        }

                        Spacer()

                        Text("-" + store.money(item.amount))
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Palette.rose)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(18)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }

    // MARK: - 4. 微调滑块
    private var fineTuneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("手动微调")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(store.money(adjustedBudget))
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Palette.primary)
            }

            Slider(value: $adjustedBudget, in: 500...50000, step: 100)
                .tint(Palette.primary)
                .onChange(of: adjustedBudget) { _, _ in
                    Haptics.select()
                }

            HStack {
                Text("¥500")
                    .font(.caption2)
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
                Text("¥50,000")
                    .font(.caption2)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(16)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }
}
