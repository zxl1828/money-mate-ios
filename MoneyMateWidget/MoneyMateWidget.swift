import WidgetKit
import SwiftUI

// MARK: - 时间线

struct MoneyMateEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetShared.Snapshot?
}

struct MoneyMateProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoneyMateEntry {
        MoneyMateEntry(date: Date(), snapshot: WidgetShared.Snapshot(monthExpense: 1234, monthBudget: 6000,
                                                                    todayExpense: 48, balance: 3200, netWorth: 25600))
    }

    func getSnapshot(in context: Context, completion: @escaping (MoneyMateEntry) -> Void) {
        completion(MoneyMateEntry(date: Date(), snapshot: WidgetShared.read() ?? placeholder(in: context).snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MoneyMateEntry>) -> Void) {
        let entry = MoneyMateEntry(date: Date(), snapshot: WidgetShared.read())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - 视图

struct MoneyMateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MoneyMateEntry

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                if family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline {
                    accessory(snap)
                } else {
                    content(snap)
                }
            } else if family == .accessoryInline {
                Text("MoneyMate")
            } else {
                emptyState
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.97, green: 0.96, blue: 1.00),
                                    Color(red: 0.90, green: 0.87, blue: 1.00)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(URL(string: WidgetShared.deepLink))
    }

    /// 锁屏小组件（圆形 / 矩形 / 单行）
    @ViewBuilder
    private func accessory(_ snap: WidgetShared.Snapshot) -> some View {
        switch family {
        case .accessoryCircular:
            VStack(spacing: 2) {
                Text(snap.monthBudget > 0 ? short(snap.budgetLeft) : short(snap.monthExpense))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(snap.monthBudget > 0 ? "剩余" : "本月")
                    .font(.system(size: 9, design: .rounded))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("本月支出 " + short(snap.monthExpense))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if snap.monthBudget > 0 {
                    Text("预算剩 " + short(snap.budgetLeft))
                        .font(.system(size: 11, design: .rounded))
                }
                Text("今日 " + short(snap.todayExpense))
                    .font(.system(size: 11, design: .rounded))
            }
        default:
            Text("本月剩 " + short(snap.monthBudget > 0 ? snap.budgetLeft : snap.monthExpense))
        }
    }

    private func short(_ value: Double) -> String {
        if value >= 10000 {
            return "\u{00A5}" + String(format: "%.1f万", value / 10000)
        }
        return "\u{00A5}" + String(format: "%.0f", value)
    }

    private func content(_ snap: WidgetShared.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
            HStack(spacing: 6) {
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.58, green: 0.47, blue: 0.99))
                Text("本月支出")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.40).opacity(0.7))
                Spacer(minLength: 0)
            }

            Text(money(snap.monthExpense))
                .font(.system(size: family == .systemSmall ? 22 : 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.40))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if snap.monthBudget > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(red: 0.58, green: 0.47, blue: 0.99).opacity(0.15))
                            Capsule()
                                .fill(LinearGradient(colors: [Color(red: 0.74, green: 0.66, blue: 1.00),
                                                              Color(red: 0.58, green: 0.47, blue: 0.99)],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(geo.size.width * snap.budgetRatio, 4))
                        }
                    }
                    .frame(height: 6)

                    Text("剩余 " + money(snap.budgetLeft) + " / 预算 " + money(snap.monthBudget))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.40).opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            if family != .systemSmall {
                HStack(spacing: 14) {
                    metric(title: "今日", value: money(snap.todayExpense))
                    metric(title: "净资产", value: money(snap.netWorth))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(red: 0.58, green: 0.47, blue: 0.99))
            Text("打开 MoneyMate")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.40))
            Text("记录第一笔账，这里就会显示本月支出")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.40).opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.40).opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.24, green: 0.20, blue: 0.40))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func money(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value >= 1000 ? 0 : 2
        let text = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "\u{00A5}" + text
    }
}

// MARK: - Widget 定义

struct MoneyMateWidget: Widget {
    static let kind = "MoneyMateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: MoneyMateProvider()) { entry in
            MoneyMateWidgetView(entry: entry)
        }
        .configurationDisplayName("MoneyMate 账本")
        .description("本月支出、预算剩余与净资产，一眼看清")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct MoneyMateWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoneyMateWidget()
    }
}
