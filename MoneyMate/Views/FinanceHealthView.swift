import SwiftUI

/// Compact planning surface for the statistics page. The scenario slider is
/// intentionally ephemeral and never mutates the user's budget or transactions.
struct FinanceHealthCard: View {
    @ObservedObject var store: MoneyStore
    @State private var reduction: Double = 0.15

    private var snapshot: FinanceHealthSnapshot { store.financeHealth }
    private var scenarioExpense: Double {
        max(snapshot.projectedMonthExpense - store.expense * reduction, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "财务健康", subtitle: "离线计算 · 只使用当前账本")
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Palette.primary.opacity(0.16), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(snapshot.score) / 100)
                        .stroke(LinearGradient(colors: [Palette.primarySoft, Palette.primaryDeep, Palette.amberGlow], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(String(snapshot.score)).financialNumber(size: 23, weight: .heavy).foregroundStyle(Palette.textPrimary)
                        Text("健康分").font(.caption2).foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(width: 78, height: 78)
                VStack(alignment: .leading, spacing: 5) {
                    Text(snapshot.score >= 80 ? "节奏很稳" : (snapshot.score >= 60 ? "保持观察" : "需要调整"))
                        .font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(Palette.textPrimary)
                    Text("今天安全可花 " + store.money(snapshot.safeToSpendToday))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold)).foregroundStyle(Palette.mint)
                    Text(snapshot.savingsRate.map { "储蓄率 " + String(Int($0 * 100)) + "%" } ?? "还没有足够收入数据")
                        .font(.caption).foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metric(title: "无消费连续", value: String(snapshot.noSpendStreak) + " 天", icon: "moon.stars.fill", color: Palette.primary)
                metric(title: "固定承诺", value: store.money(snapshot.monthlyRecurringExpense), icon: "arrow.triangle.2.circlepath", color: Palette.amberGlow)
                metric(title: "预计月底", value: store.money(snapshot.projectedMonthExpense), icon: "calendar.badge.clock", color: Palette.rose)
                metric(title: "预算剩余", value: store.money(store.budgetLeft), icon: "shield.checkered", color: Palette.mint)
            }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("情景模拟").font(.system(.footnote, design: .rounded).weight(.semibold)).foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("非必要支出 -" + String(Int(reduction * 100)) + "%").font(.caption2).foregroundStyle(Palette.primary)
                }
                Slider(value: $reduction, in: 0...0.4, step: 0.05).tint(Palette.primary)
                Text("预计月底为 " + store.money(scenarioExpense) + "，比当前基线少 " + store.money(max(snapshot.projectedMonthExpense - scenarioExpense, 0)))
                    .font(.caption2).foregroundStyle(Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .innerTile(Radius.tile, opacity: 0.10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: reduction)
    }

    private func metric(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color).frame(width: 25, height: 25).background(color.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(Palette.textSecondary)
                Text(value).financialNumber(size: 13, weight: .bold).foregroundStyle(Palette.textPrimary).minimumScaleFactor(0.7).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .innerTile(Radius.small, opacity: 0.08)
    }
}
