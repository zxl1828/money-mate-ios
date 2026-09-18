import SwiftUI

// MARK: - 智能洞察：账单日 / 异常消费 / 现金流 / 订阅 / 热力图

struct InsightPanel: View {
    @ObservedObject var store: MoneyStore

    var body: some View {
        VStack(spacing: 16) {
            statementNotice
            insightCards
            heatmapCard
        }
    }

    // MARK: 账单日 / 还款日预告

    @ViewBuilder
    private var statementNotice: some View {
        let upcoming = Self.upcomingDays(store)
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "临近的日子", subtitle: "来自信用卡的账单日 / 还款日")
                ForEach(upcoming) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Palette.primary)
                        Text(item.accountName + " " + item.kindLabel)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                        Text(item.days <= 0 ? "就是今天" : "还有 \(item.days) 天")
                            .font(.caption)
                            .foregroundStyle(item.days <= 1 ? Palette.rose : Palette.ink.opacity(0.6))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.card, strong: true)
        }
    }

    struct UpcomingDay: Identifiable {
        var id: String { accountName + kindLabel }
        let accountName: String
        let kindLabel: String
        let days: Int
    }

    static func upcomingDays(_ store: MoneyStore) -> [UpcomingDay] {
        store.activeAccounts.compactMap { account -> UpcomingDay? in
            guard account.kind == .credit else { return nil }
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            if let statement = FinanceMath.nextDay(account.statementDay),
               let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: statement)).day,
               days <= 3 {
                return UpcomingDay(accountName: account.displayName, kindLabel: "账单日", days: days)
            }
            if let due = FinanceMath.nextDay(account.dueDay),
               let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: due)).day,
               days <= 3 {
                return UpcomingDay(accountName: account.displayName, kindLabel: "还款日", days: days)
            }
            return nil
        }
    }

    // MARK: 异常消费 + 现金流 + 订阅

    @ViewBuilder
    private var insightCards: some View {
        let anomalies = Self.anomalies(store)
        let forecast = Self.forecast(store)
        let subs = Self.subscriptions(store)
        if !anomalies.isEmpty || forecast != nil || !subs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "本月洞察", subtitle: "本地计算，不上传任何数据")
                if let forecast {
                    insightRow(icon: "chart.line.uptrend.xyaxis",
                               title: "预计月底支出 " + store.money(forecast.projected),
                               detail: "已花 " + store.money(forecast.spent) + " · 按日均 " + store.money(forecast.daily) + " 推算")
                }
                ForEach(anomalies, id: \.text) { item in
                    insightRow(icon: "exclamationmark.triangle.fill",
                               title: item.text,
                               detail: item.detail,
                               tint: Palette.rose)
                }
                if !subs.isEmpty {
                    insightRow(icon: "repeat",
                               title: "识别到 " + String(subs.count) + " 个固定扣款",
                               detail: subs.prefix(3).joined(separator: " · "))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.card, strong: true)
        }
    }

    private func insightRow(icon: String, title: String, detail: String, tint: Color = Palette.primary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: 消费日历热力图

    private var heatmapCard: some View {
        let days = Self.lastDays(store, count: 70)
        let peak = max(days.map(\.value).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "消费日历", subtitle: "近 10 周，颜色越深花得越多")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10), spacing: 4) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Palette.primary.opacity(0.12 + 0.85 * min(day.value / peak, 1)))
                        .frame(height: 18)
                        .overlay {
                            if Calendar.current.isDateInToday(day.date) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Palette.primary, lineWidth: 1.4)
                            }
                        }
                }
            }
            HStack {
                Text("少").font(.caption2).foregroundStyle(Palette.ink.opacity(0.5))
                ForEach([0.15, 0.35, 0.6, 0.85, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.primary.opacity(0.12 + 0.85 * level))
                        .frame(width: 14, height: 12)
                }
                Text("多").font(.caption2).foregroundStyle(Palette.ink.opacity(0.5))
                Spacer()
                Text("共 " + store.money(days.reduce(0) { $0 + $1.value }))
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    // MARK: - 计算

    struct DayValue: Identifiable {
        var id: Date { date }
        let date: Date
        let value: Double
    }

    static func lastDays(_ store: MoneyStore, count: Int) -> [DayValue] {
        let cal = Calendar.current
        var out: [DayValue] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let total = store.txs
                .filter { $0.isExpense && cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 - $1.amountCNY }
            out.append(DayValue(date: cal.startOfDay(for: day), value: total))
        }
        return out
    }

    struct Anomaly { let text: String; let detail: String }

    /// 本月分类支出 vs 近 3 个月平均，涨得最猛的 2 个
    static func anomalies(_ store: MoneyStore) -> [Anomaly] {
        let cal = Calendar.current
        let currentMonth = store.categoryTotals()
        var result: [Anomaly] = []
        for item in currentMonth.prefix(6) {
            var history: [Double] = []
            for offset in 1...3 {
                guard let month = cal.date(byAdding: .month, value: -offset, to: Date()) else { continue }
                let total = store.txs
                    .filter { $0.isExpense && $0.category == item.label && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
                    .reduce(0) { $0 - $1.amountCNY }
                history.append(total)
            }
            guard !history.isEmpty else { continue }
            let average = history.reduce(0, +) / Double(history.count)
            guard average > 20 else { continue }
            let delta = item.value - average
            guard delta > 100, item.value > average * 1.4 else { continue }
            result.append(Anomaly(text: item.label + "比平时多花 " + store.money(delta),
                                  detail: "本月 " + store.money(item.value) + "，近 3 个月平均 " + store.money(average)))
        }
        return Array(result.prefix(2))
    }

    struct Forecast { let spent: Double; let daily: Double; let projected: Double }

    /// 现金流预测：本月已花 + 日均 × 剩余天数
    static func forecast(_ store: MoneyStore) -> Forecast? {
        let cal = Calendar.current
        let day = cal.component(.day, from: Date())
        guard day >= 3 else { return nil }
        let spent = store.expense
        guard spent > 0 else { return nil }
        let daily = spent / Double(day)
        let total = cal.range(of: .day, in: .month, for: Date())?.count ?? 30
        return Forecast(spent: spent, daily: daily, projected: daily * Double(total))
    }

    /// 订阅识别：同一商户在 ≥2 个月出现、金额接近
    static func subscriptions(_ store: MoneyStore) -> [String] {
        let cal = Calendar.current
        var buckets: [String: [Tx]] = [:]
        for tx in store.txs where tx.isExpense {
            let name = tx.merchant.isEmpty ? tx.title : tx.merchant
            guard !name.isEmpty else { continue }
            buckets[name, default: []].append(tx)
        }
        var found: [String] = []
        for (name, list) in buckets {
            guard list.count >= 2 else { continue }
            let months = Set(list.map { cal.dateComponents([.year, .month], from: $0.date) }
                .map { "\($0.year ?? 0)-\($0.month ?? 0)" })
            guard months.count >= 2 else { continue }
            let amounts = list.map { -$0.amountCNY }
            let average = amounts.reduce(0, +) / Double(amounts.count)
            let spread = (amounts.max() ?? 0) - (amounts.min() ?? 0)
            guard average > 5, spread <= average * 0.25 else { continue }
            found.append(name + " " + store.money(average))
        }
        return Array(found.prefix(4))
    }
}
