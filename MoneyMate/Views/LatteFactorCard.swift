import SwiftUI

// MARK: - “拿铁因子”（Latte Factor）隐形微开销透视卡片

struct LatteFactorCard: View {
    @ObservedObject var store: MoneyStore

    @State private var threshold: Double = 30.0
    @State private var showDetailList = false

    private let thresholds: [Double] = [20.0, 30.0, 50.0]

    private var currentMonthExpenses: [Tx] {
        let cal = Calendar.current
        let now = Date()
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return []
        }
        return store.txs.filter { $0.isExpense && $0.date >= startOfMonth && $0.date <= now }
    }

    private var latteItems: [Tx] {
        currentMonthExpenses.filter { abs($0.amountCNY) <= threshold && abs($0.amountCNY) > 0 }
    }

    private var totalLatteAmount: Double {
        latteItems.reduce(0) { $0 + abs($1.amountCNY) }
    }

    private var totalMonthExpense: Double {
        max(currentMonthExpenses.reduce(0) { $0 + abs($1.amountCNY) }, 1.0)
    }

    private var annualizedCost: Double {
        totalLatteAmount * 12.0
    }

    private var equivalentReward: (icon: String, text: String) {
        if annualizedCost >= 6000 {
            return ("iphone", "相当于每年不知不觉省下一台 iPhone 17 (¥5,999)")
        } else if annualizedCost >= 3000 {
            return ("airplane.departure", "相当于每年可兑换 1 次海岛往返度假基金")
        } else if annualizedCost >= 1200 {
            let cups = Int(annualizedCost / 32.0)
            return ("cup.and.saucer.fill", "相当于每年喝掉 \(cups) 杯星巴克大杯拿铁")
        } else {
            return ("sparkles", "积少成多，控住微开销能为小金库省下更多活钱")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow
            thresholdPicker
            heroMetrics
            equivalenceBanner
            categoryBreakdown
            if !latteItems.isEmpty {
                detailButton
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .sheet(isPresented: $showDetailList) {
            latteDetailSheet
        }
    }

    // MARK: - 标题行
    private var headerRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.neonViolet)
                    .frame(width: 28, height: 28)
                    .background(Palette.auroraPurple.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("拿铁因子透视")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("洞察日常 ≤ ¥\(Int(threshold)) 的隐形漏斗开销")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer()
            Text("\(latteItems.count) 笔")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Palette.primary.opacity(0.12), in: Capsule())
        }
    }

    // MARK: - 门槛切换胶囊
    private var thresholdPicker: some View {
        HStack(spacing: 8) {
            ForEach(thresholds, id: \.self) { t in
                Button {
                    Haptics.tap()
                    threshold = t
                } label: {
                    Text("≤ ¥\(Int(t))")
                        .font(.system(size: 12, weight: threshold == t ? .bold : .medium))
                        .foregroundStyle(threshold == t ? Palette.primary : Palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            threshold == t ? Palette.primary.opacity(0.15) : Color.white.opacity(0.04),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                threshold == t ? Palette.primary.opacity(0.4) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - 核心数字看板
    private var heroMetrics: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("本月微开销总计")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary)
                Text(store.money(totalLatteAmount))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("年化累计投影")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary)
                Text("¥\(String(format: "%.0f", annualizedCost))")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.neonViolet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        }
    }

    // MARK: - 等值折算横幅
    private var equivalenceBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: equivalentReward.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.neonViolet)
            Text(equivalentReward.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textPrimary.opacity(0.9))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.amethystDeep.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.primary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 微开销分类排行
    private var categoryBreakdown: some View {
        let grouped = Dictionary(grouping: latteItems, by: { $0.category })
            .map { (cat: $0.key, count: $0.value.count, sum: $0.value.reduce(0) { $0 + abs($1.amountCNY) }) }
            .sorted { $0.sum > $1.sum }
            .prefix(3)

        return VStack(spacing: 6) {
            ForEach(grouped, id: \.cat) { item in
                HStack {
                    Text(item.cat)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(item.count) 笔")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text(store.money(item.sum))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.rose)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - 明细展开按钮
    private var detailButton: some View {
        Button {
            Haptics.tap()
            showDetailList = true
        } label: {
            HStack {
                Spacer()
                Text("查看全部 \(latteItems.count) 笔隐形开销明细")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.primary)
                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 拿铁明细 Sheet
    private var latteDetailSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(latteItems) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tx.title.isEmpty ? tx.category : tx.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(Palette.textPrimary)
                                HStack(spacing: 6) {
                                    Text(tx.category)
                                    if !tx.merchant.isEmpty {
                                        Text("· \(tx.merchant)")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(Palette.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(store.money(abs(tx.amountCNY)))
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Palette.rose)
                                Text(tx.date, format: .dateTime.month().day())
                                    .font(.caption2)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    }
                } header: {
                    Text("≤ ¥\(Int(threshold)) 消费共计 \(latteItems.count) 笔 · ¥\(String(format: "%.2f", totalLatteAmount))")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(GlassBackground())
            .navigationTitle("拿铁因子账单明细")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showDetailList = false }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.primary)
                }
            }
        }
    }
}
