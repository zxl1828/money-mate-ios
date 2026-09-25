import SwiftUI
import UIKit

/// 用于 sheet(item:) 的日期包一层（Date 本身不满足 Identifiable）
private struct DayBox: Identifiable {
    let id = UUID()
    let day: Date
}

/// 日历记账：月历看每天的账 + 节假日 + 人情往来（给谁送了什么）。
/// 与安卓 `calendar_page.dart` 一一对应。
struct GiftRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: String        // yyyy-MM-dd
    var person: String
    var relation: String
    var occasion: String
    var item: String
    var amount: Double
}

struct CalendarView: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var month = Date()
    @State private var gifts: [GiftRecord] = CalendarView.load()
    @State private var daySheet: DayBox?

    /// 固定公历节日（农历节日每年不同，用「人情/重要日子」自己加）
    private let holidays: [String: String] = ["01-01": "元旦", "05-01": "劳动节", "10-01": "国庆节"]

    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthCard
                    giftCard
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("日历记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $daySheet) { day in
                dayDetail(day.day)
            }
        }
    }

    // MARK: 月历

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
                ForEach(weekdays, id: \.self) { w in
                    Text(w).font(.caption2).foregroundStyle(Palette.ink.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
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
        let spent = dayTxs(day).filter { $0.isExpense }.reduce(0) { $0 + abs($1.amountCNY) }
        let holiday = holidays[String(key.suffix(5))]
        let hasGift = gifts.contains { $0.date == key }
        let isToday = Calendar.current.isDateInToday(day)
        return Button {
            Haptics.tap()
            daySheet = DayBox(day: day)
        } label: {
            VStack(spacing: 1) {
                Text(String(Calendar.current.component(.day, from: day)))
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(Palette.ink)
                if let holiday {
                    Text(holiday).font(.system(size: 8)).foregroundStyle(Palette.rose).lineLimit(1)
                }
                if spent > 0 {
                    Text("¥" + String(Int(spent))).font(.system(size: 8))
                        .foregroundStyle(Palette.ink.opacity(0.6)).lineLimit(1)
                }
                if hasGift {
                    Image(systemName: "gift.fill").font(.system(size: 8)).foregroundStyle(Palette.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(isToday ? Palette.primary.opacity(0.16) : (holiday != nil ? Palette.rose.opacity(0.10) : .clear),
                    in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    // MARK: 人情往来

    private var giftCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "人情往来",
                          subtitle: String(monthGifts.count) + " 条 · 点日历上的日子添加")
            if monthGifts.isEmpty {
                Text("本月还没有记录，比如「二姨生日 · 送按摩仪」")
                    .font(.caption2).foregroundStyle(Palette.ink.opacity(0.6))
            } else {
                ForEach(monthGifts) { gift in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gift.person + "（" + gift.relation + "）")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                            Text(String(gift.date.suffix(5)) + " · " + gift.occasion + " · " + gift.item)
                                .font(.caption2).foregroundStyle(Palette.ink.opacity(0.6))
                        }
                        Spacer(minLength: 0)
                        if gift.amount > 0 {
                            Text("¥" + String(Int(gift.amount))).font(.caption)
                        }
                        Button {
                            gifts.removeAll { $0.id == gift.id }
                            Self.save(gifts)
                        } label: {
                            Image(systemName: "trash").font(.system(size: 12))
                                .foregroundStyle(Palette.rose)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            glassButton(title: "新增人情记录", systemImage: "plus") {
                daySheet = DayBox(day: Date())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func dayDetail(_ day: Date) -> some View {
        let txs = dayTxs(day)
        let key = Self.key(day)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Self.longLabel(day)).font(.system(.title3, design: .rounded).weight(.bold))
                    Text(holidays[String(key.suffix(5))] ?? (String(txs.count) + " 笔"))
                        .font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                    if txs.isEmpty {
                        Text("这天还没有记账").font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.6))
                    } else {
                        ForEach(txs) { tx in
                            HStack {
                                Text(tx.category + (tx.payee.isEmpty ? "" : " " + tx.payee))
                                    .font(.footnote).lineLimit(1)
                                Spacer()
                                Text((tx.isExpense ? "-" : "+") + store.money(abs(tx.amountCNY)))
                                    .font(.footnote)
                                    .foregroundStyle(tx.isExpense ? Palette.rose : Palette.mint)
                            }
                        }
                    }
                    glassButton(title: "记一条人情（送礼 / 收礼）", systemImage: "gift") {
                        addGift(on: key)
                    }
                }
                .padding(20)
            }
            .background(GlassBackground())
        }
    }

    private func addGift(on date: String) {
        var person = ""
        var relation = "朋友"
        var occasion = ""
        var item = ""
        var amount = ""
        // 用系统输入弹窗保持代码轻量（后续可换成完整表单）
        let alert = UIAlertController(title: "人情记录 " + date, message: "给谁 / 关系 / 场合 / 礼物 / 金额（用 / 分隔）", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "二姨 / 亲戚 / 生日 / 按摩仪 / 588" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            let text = alert.textFields?.first?.text ?? ""
            let parts = text.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count > 0 { person = parts[0] }
            if parts.count > 1 { relation = parts[1] }
            if parts.count > 2 { occasion = parts[2] }
            if parts.count > 3 { item = parts[3] }
            if parts.count > 4 { amount = parts[4] }
            guard !person.isEmpty else { return }
            gifts.append(GiftRecord(date: date, person: person, relation: relation,
                                    occasion: occasion, item: item,
                                    amount: Double(amount) ?? 0))
            Self.save(gifts)
            Haptics.success()
        })
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.keyWindow?.rootViewController {
            root.present(alert, animated: true)
        }
    }

    // MARK: 工具

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: month)
    }

    private var daysInMonth: [Date] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month)) else { return [] }
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

    private func shift(_ delta: Int) {
        Haptics.tap()
        if let m = Calendar.current.date(byAdding: .month, value: delta, to: month) { month = m }
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

    private static func load() -> [GiftRecord] {
        guard let data = UserDefaults.standard.data(forKey: "moneymate.gifts"),
              let list = try? JSONDecoder().decode([GiftRecord].self, from: data) else { return [] }
        return list
    }

    private static func save(_ list: [GiftRecord]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "moneymate.gifts")
        }
    }
}
