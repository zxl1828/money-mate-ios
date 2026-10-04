import SwiftUI
import UIKit

/// 日历记账与未来现金流预测：
/// 1. 月历看每天的账 + 节假日 + 人情往来（给谁送了什么）
/// 2. 未来 30 天现金流预测：结合可用流动资产 + 周期账单 + 信用卡还款日预测资金水位与预警
struct GiftRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: String
    var person: String
    var relation: String
    var occasion: String
    var item: String
    var amount: Double
}

private struct DayBox: Identifiable {
    let id = UUID()
    let day: Date
}

struct CashFlowScheduleItem: Identifiable, Hashable {
    var id = UUID()
    let date: Date
    let dateString: String
    let title: String
    let amount: Double
    let isIncome: Bool
    let tag: String
}

struct CashFlowDayPoint: Identifiable, Hashable {
    var id = UUID()
    let dayIndex: Int
    let date: Date
    let dateLabel: String
    let balance: Double
    let isLow: Bool
}

struct CalendarView: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Int = 0 // 0: 记账日历, 1: 现金流预测
    @State private var month = Date()
    @State private var gifts: [GiftRecord] = CalendarView.loadGifts()
    @State private var daySheet: DayBox?

    private let holidays: [String: String] = [
        "01-01": "元旦", "05-01": "劳动节", "10-01": "国庆节"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    modePicker
                    if mode == 0 {
                        monthCard
                        giftCard
                    } else {
                        cashFlowHeroCard
                        cashFlowTrendCard
                        upcomingScheduleCard
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("日历与现金流")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.primary)
                }
            }
            .sheet(item: $daySheet) { box in
                dayDetail(box.day)
            }
        }
    }

    // MARK: - 模式切换
    private var modePicker: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                mode = 0
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("日历与人情")
                }
                .font(.system(.footnote, design: .rounded).weight(mode == 0 ? .bold : .medium))
                .foregroundStyle(mode == 0 ? Palette.primary : Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    mode == 0 ? Palette.primary.opacity(0.16) : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .strokeBorder(mode == 0 ? Palette.primary.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                mode = 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("30天现金流预测")
                }
                .font(.system(.footnote, design: .rounded).weight(mode == 1 ? .bold : .medium))
                .foregroundStyle(mode == 1 ? Palette.primary : Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    mode == 1 ? Palette.primary.opacity(0.16) : Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                        .strokeBorder(mode == 1 ? Palette.primary.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 模式 1：日历卡片
    private var monthCard: some View {
        VStack(spacing: 10) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text(monthTitle).font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain)
            }
            .foregroundStyle(Palette.ink.opacity(0.8))

            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { w in
                    Text(w)
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                      spacing: 4) {
                ForEach(daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassPanel(Radius.card, strong: true)
    }

    private func dayCell(_ day: Date) -> some View {
        let key = Self.key(day)
        let spent = daySpent(day)
        let holiday = holidays[String(key.suffix(5))]
        let hasGift = gifts.contains { $0.date == key }
        let isToday = Calendar.current.isDateInToday(day)
        let dayNumber = Calendar.current.component(.day, from: day)
        let bg: Color = isToday ? Palette.primary.opacity(0.16)
            : (holiday != nil ? Palette.rose.opacity(0.10) : Color.clear)
        return Button {
            Haptics.tap()
            daySheet = DayBox(day: day)
        } label: {
            VStack(spacing: 1) {
                Text("\(dayNumber)")
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(Palette.ink)
                if let holiday {
                    Text(holiday).font(.system(size: 8))
                        .foregroundStyle(Palette.rose).lineLimit(1)
                }
                if spent > 0 {
                    Text("¥\(Int(spent))").font(.system(size: 8))
                        .foregroundStyle(Palette.ink.opacity(0.6)).lineLimit(1)
                }
                if hasGift {
                    Image(systemName: "gift.fill").font(.system(size: 8))
                        .foregroundStyle(Palette.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(bg, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    // MARK: - 人情往来卡片
    private var giftCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "人情往来",
                          subtitle: "\(monthGifts.count) 条 · 点日历上的日子添加")
            if monthGifts.isEmpty {
                Text("本月还没有记录，比如「二姨生日 · 送按摩仪」")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
            ForEach(monthGifts) { gift in
                giftRow(gift)
            }
            Button {
                daySheet = DayBox(day: Date())
            } label: {
                Label("新增人情记录", systemImage: "plus")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear, in: Capsule())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func giftRow(_ gift: GiftRecord) -> some View {
        let title = gift.person + "（" + gift.relation + "）"
        let sub = String(gift.date.suffix(5)) + " · " + gift.occasion + " · " + gift.item
        let money = gift.amount > 0 ? "¥" + String(Int(gift.amount)) : ""
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.footnote, design: .rounded).weight(.semibold))
                Text(sub).font(.caption2).foregroundStyle(Palette.ink.opacity(0.6))
            }
            Spacer(minLength: 0)
            Text(money).font(.caption)
            Button {
                gifts.removeAll { $0.id == gift.id }
                Self.saveGifts(gifts)
            } label: {
                Image(systemName: "trash").font(.system(size: 12))
                    .foregroundStyle(Palette.rose)
            }
            .buttonStyle(.plain)
        }
    }

    private func dayDetail(_ day: Date) -> some View {
        let txs = dayTxs(day)
        let key = Self.key(day)
        let sub = holidays[String(key.suffix(5))] ?? "\(txs.count) 笔"
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Self.longLabel(day))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(sub).font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                    if txs.isEmpty {
                        Text("这天还没有记账")
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.6))
                    }
                    ForEach(txs) { tx in
                        txRow(tx)
                    }
                    Button {
                        addGift(on: key)
                    } label: {
                        Label("记一条人情（送礼 / 收礼）", systemImage: "gift")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(.clear, in: Capsule())
                }
                .padding(20)
            }
            .background(GlassBackground())
        }
    }

    private func txRow(_ tx: Tx) -> some View {
        let who = tx.merchant.isEmpty ? tx.category : tx.category + " " + tx.merchant
        let amount = (tx.isExpense ? "-" : "+") + store.money(abs(tx.amountCNY))
        let color = tx.isExpense ? Palette.rose : Palette.mint
        return HStack {
            Text(who).font(.footnote).lineLimit(1)
            Spacer()
            Text(amount).font(.footnote).foregroundStyle(color)
        }
    }

    // MARK: - 模式 2：现金流预测看板
    private var liquidBalance: Double {
        store.activeAccounts
            .filter { !$0.isCredit }
            .reduce(0.0) { $0 + store.balance(of: $1.id) }
    }


    private var futureSchedule: [CashFlowScheduleItem] {
        var items: [CashFlowScheduleItem] = []
        let cal = Calendar.current
        let today = Date()

        for dayOffset in 1...30 {
            guard let targetDate = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let targetDay = cal.component(.day, from: targetDate)
            let targetWeekday = cal.component(.weekday, from: targetDate)

            // 周期账单
            for rule in store.recurringRules {
                var matches = false
                switch rule.recurrence {
                case .daily:
                    matches = true
                case .weekly:
                    let ruleWeekday = cal.component(.weekday, from: rule.date)
                    matches = (ruleWeekday == targetWeekday)
                case .monthly:
                    let ruleDay = cal.component(.day, from: rule.date)
                    matches = (ruleDay == targetDay)
                case .none:
                    break
                }

                if matches {
                    let amount = abs(rule.amountCNY)
                    items.append(CashFlowScheduleItem(
                        date: targetDate,
                        dateString: Self.longLabel(targetDate),
                        title: rule.title.isEmpty ? rule.category : rule.title,
                        amount: amount,
                        isIncome: !rule.isExpense,
                        tag: rule.isExpense ? "周期支出" : "预期收入"
                    ))
                }
            }

            // 信用卡到期还款
            for acc in store.activeAccounts where acc.isCredit {
                if acc.dueDay > 0 && acc.dueDay == targetDay {
                    let balance = store.balance(of: acc.id)
                    if balance < 0 {

                        let debt = abs(balance)
                        items.append(CashFlowScheduleItem(
                            date: targetDate,
                            dateString: Self.longLabel(targetDate),
                            title: "\(acc.name) 信用卡到期还款",
                            amount: debt,
                            isIncome: false,
                            tag: "信用卡还款"
                        ))
                    }
                }
            }
        }

        return items.sorted(by: { $0.date < $1.date })
    }

    private var cashFlowPoints: [CashFlowDayPoint] {
        let cal = Calendar.current
        let today = Date()
        var current = liquidBalance
        var points: [CashFlowDayPoint] = [
            CashFlowDayPoint(dayIndex: 0, date: today, dateLabel: "今天", balance: current, isLow: current < 1000)
        ]

        let schedule = futureSchedule

        for dayOffset in 1...30 {
            guard let targetDate = cal.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dayItems = schedule.filter { cal.isDate($0.date, inSameDayAs: targetDate) }
            for it in dayItems {
                if it.isIncome {
                    current += it.amount
                } else {
                    current -= it.amount
                }
            }
            let label = "\(cal.component(.month, from: targetDate))/\(cal.component(.day, from: targetDate))"
            points.append(CashFlowDayPoint(
                dayIndex: dayOffset,
                date: targetDate,
                dateLabel: label,
                balance: current,
                isLow: current < 1000
            ))
        }

        return points
    }

    private var lowestPoint: CashFlowDayPoint? {
        cashFlowPoints.min(by: { $0.balance < $1.balance })
    }

    private var projectedEndingBalance: Double {
        cashFlowPoints.last?.balance ?? liquidBalance
    }

    private var cashFlowHeroCard: some View {
        let lowest = lowestPoint?.balance ?? liquidBalance
        let isCritical = lowest < 0
        let isWarning = lowest < 1000 && !isCritical

        return VStack(spacing: 12) {
            HStack {
                Label("未来 30 天流动性预测", systemImage: "shield.lefthalf.filled")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(isCritical ? Palette.rose : (isWarning ? Palette.amberGlow : Palette.mint))
                Spacer()
                Text(isCritical ? "⚠️ 预警：资金有透支风险" : (isWarning ? "⚡️ 关注：余额将低于千元" : "✅ 资金水位健康"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isCritical ? Palette.rose : (isWarning ? Palette.amberGlow : Palette.mint))
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前活期资金")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                    Text(store.money(liquidBalance))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text("30 天后预估结余")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                    Text(store.money(projectedEndingBalance))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(projectedEndingBalance < liquidBalance ? Palette.rose : Palette.mint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))

            if let low = lowestPoint, low.isLow {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.amberGlow)
                    Text("预计 \(low.dateLabel) 触及最低水位：\(store.money(low.balance))，请留意")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.amberGlow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassPanel(Radius.card, strong: true)
    }

    private var cashFlowTrendCard: some View {
        let points = cashFlowPoints
        let maxVal = max(points.map(\.balance).max() ?? 1000, 1000)
        let minVal = min(points.map(\.balance).min() ?? 0, 0)
        let range = max(maxVal - minVal, 1.0)

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "资金水位走势", subtitle: "未来 30 天每日结余推演")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(points) { p in
                        VStack(spacing: 4) {
                            Spacer()
                            let heightRatio = CGFloat(max(p.balance - minVal, 50) / range)
                            let barHeight = max(heightRatio * 70, 4)

                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(
                                    p.balance < 0 ? Palette.rose :
                                    (p.balance < 1000 ? Palette.amberGlow : Palette.primary)
                                )
                                .frame(width: 8, height: barHeight)

                            Text(p.dayIndex == 0 ? "今天" : (p.dayIndex % 5 == 0 ? p.dateLabel : ""))
                                .font(.system(size: 8))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(height: 12)
                        }
                        .frame(width: 14, height: 95)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var upcomingScheduleCard: some View {
        let items = futureSchedule

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "待发生收支时间线", subtitle: "\(items.count) 笔待入账与待还款")

            if items.isEmpty {
                Text("未来 30 天内暂无固定的周期账单与信用卡还款")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { it in
                    HStack(spacing: 10) {
                        Text(it.dateString)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.primary)
                            .frame(width: 52, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(it.title)
                                .font(.system(.footnote, design: .rounded).weight(.medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text(it.tag)
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.textSecondary)
                        }

                        Spacer()

                        Text((it.isIncome ? "+" : "-") + store.money(it.amount))
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(it.isIncome ? Palette.mint : Palette.rose)
                    }
                    .padding(.vertical, 4)
                    Divider().background(Color.white.opacity(0.06))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func addGift(on date: String) {
        let alert = UIAlertController(
            title: "人情记录 \(date)",
            message: "按「给谁 / 关系 / 场合 / 礼物 / 金额」填写",
            preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "二姨 / 亲戚 / 生日 / 按摩仪 / 588" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            let text = alert.textFields?.first?.text ?? ""
            let parts = text.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let person = parts.first, !person.isEmpty else { return }
            let relation = parts.count > 1 ? parts[1] : "朋友"
            let occasion = parts.count > 2 ? parts[2] : ""
            let item = parts.count > 3 ? parts[3] : ""
            let amount = parts.count > 4 ? (Double(parts[4]) ?? 0) : 0
            gifts.append(GiftRecord(date: date, person: person, relation: relation,
                                    occasion: occasion, item: item, amount: amount))
            Self.saveGifts(gifts)
            Haptics.success()
        })
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(alert, animated: true)
        }
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: month)
    }

    private var daysInMonth: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: first) }
    }

    private var monthGifts: [GiftRecord] {
        let prefix = String(Self.key(month).prefix(7))
        return gifts.filter { $0.date.hasPrefix(prefix) }.sorted { $0.date < $1.date }
    }

    private func dayTxs(_ day: Date) -> [Tx] {
        let cal = Calendar.current
        return store.txs(in: 400).filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func daySpent(_ day: Date) -> Double {
        dayTxs(day).filter { $0.isExpense }.reduce(0) { $0 + abs($1.amountCNY) }
    }

    private func shift(_ delta: Int) {
        Haptics.tap()
        if let m = Calendar.current.date(byAdding: .month, value: delta, to: month) {
            month = m
        }
    }

    private static func key(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private static func longLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M 月 d 日"
        return f.string(from: d)
    }

    private static func loadGifts() -> [GiftRecord] {
        guard let data = UserDefaults.standard.data(forKey: "moneymate.gifts"),
              let list = try? JSONDecoder().decode([GiftRecord].self, from: data)
        else { return [] }
        return list
    }

    private static func saveGifts(_ list: [GiftRecord]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "moneymate.gifts")
        }
    }
}
