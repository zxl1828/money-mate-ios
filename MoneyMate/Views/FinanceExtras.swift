import SwiftUI

// MARK: - 储蓄率 / 同比 / 分类趋势 / 返现 / 完整性 / 大额提醒

struct FinanceExtrasPanel: View {
    @ObservedObject var store: MoneyStore
    @AppStorage("moneymate.bigspend.threshold") private var threshold: Double = 1000
    @State private var integrity = IntegrityReport()

    var body: some View {
        VStack(spacing: 16) {
            savingsCard
            yoyCard
            trendCard
            cashbackCard
            bigSpendCard
            integrityCard
        }
        .onAppear { integrity = Self.check(store) }
    }

    // 储蓄率
    private var savingsCard: some View {
        let rate = store.income > 0 ? (store.income - store.expense) / store.income : 0
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "储蓄率", subtitle: "本月结余 ÷ 收入")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.0f%%", rate * 100))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(rate >= 0.2 ? Palette.mint : Palette.rose)
                Text("结余 " + store.money(store.balance))
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.65))
            }
            Text(rate >= 0.3 ? "很健康：三成以上都存下来了" : rate >= 0.1 ? "还行，试试把目标提到 20%" : "偏低了，先盯住最大的两个分类")
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    // 同比（今年 vs 去年同月）
    private var yoyCard: some View {
        let cal = Calendar.current
        let thisMonth = store.expense
        let lastYear = store.txs.filter {
            $0.isExpense && cal.isDate($0.date, equalTo: Date(), toGranularity: .month)
                && cal.component(.year, from: $0.date) == cal.component(.year, from: Date()) - 1
                && cal.component(.month, from: $0.date) == cal.component(.month, from: Date())
        }.reduce(0) { $0 - $1.amountCNY }
        return Group {
            if lastYear > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "同比", subtitle: "今年本月 vs 去年同月")
                    let delta = thisMonth - lastYear
                    Text((delta >= 0 ? "多花 " : "少花 ") + store.money(abs(delta)))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(delta >= 0 ? Palette.rose : Palette.mint)
                    Text("今年 " + store.money(thisMonth) + " · 去年 " + store.money(lastYear))
                        .font(.caption2)
                        .foregroundStyle(Palette.ink.opacity(0.6))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(Radius.card, strong: true)
            }
        }
    }

    // 分类 12 个月趋势
    private var trendCard: some View {
        let tops = store.categoryTotals().prefix(3)
        let cal = Calendar.current
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "分类趋势", subtitle: "近 12 个月 · 点分类看走势")
            ForEach(Array(tops)) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    HStack(alignment: .bottom, spacing: 3) {
                        let series = Self.monthlySeries(store, category: item.label, months: 12, cal: cal)
                        let peak = max(series.max() ?? 1, 1)
                        ForEach(Array(series.enumerated()), id: \.offset) { pair in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Palette.primary.opacity(0.35 + 0.65 * (pair.element / peak)))
                                .frame(width: 12, height: max(6, 34 * (pair.element / peak)))
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(height: 36, alignment: .bottom)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    // 返现 / 优惠
    private var cashbackCard: some View {
        let hits = store.txs.filter { tx in
            tx.title.contains("返现") || tx.title.contains("优惠") || tx.note.contains("返现")
                || tx.category == "返现"
        }
        let total = hits.filter { $0.isIncome }.reduce(0) { $0 + $1.amountCNY }
        return Group {
            if !hits.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "优惠 / 返现", subtitle: "共 " + String(hits.count) + " 条记录")
                    Text("累计拿回 " + store.money(total))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.mint)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(Radius.card, strong: true)
            }
        }
    }

    // 大额消费阈值提醒
    private var bigSpendCard: some View {
        let bigs = store.monthTxs.filter { $0.isExpense && abs($0.amountCNY) >= threshold }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "大额消费提醒", subtitle: "超过阈值会在记完账后提示")
            HStack {
                Text("阈值").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                Slider(value: $threshold, in: 100...10000, step: 100)
                    .tint(Palette.primary)
                Text(store.money(threshold))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink)
            }
            Text(bigs.isEmpty ? "本月还没有超过阈值的大额支出" : "本月有 " + String(bigs.count) + " 笔超过阈值")
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    // 数据完整性
    private var integrityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "数据检查", subtitle: "账本自检")
            if integrity.issues.isEmpty {
                Label("没有发现问题", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.mint)
            } else {
                ForEach(integrity.issues, id: \.self) { issue in
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(Palette.rose)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    // MARK: 计算

    struct IntegrityReport {
        var issues: [String] = []
    }

    static func check(_ store: MoneyStore) -> IntegrityReport {
        var report = IntegrityReport()
        let accountIDs = Set(store.accounts.map(\.id))
        let orphans = store.txs.filter { tx in
            guard let id = tx.accountID else { return false }
            return !accountIDs.contains(id)
        }
        if !orphans.isEmpty { report.issues.append(String(orphans.count) + " 笔流水的账户已不存在") }
        var seen = Set<UUID>()
        var duplicates = 0
        for tx in store.txs {
            if seen.contains(tx.id) { duplicates += 1 } else { seen.insert(tx.id) }
        }
        if duplicates > 0 { report.issues.append(String(duplicates) + " 笔流水 id 重复") }
        let credits = store.activeAccounts.filter { $0.kind == .credit }
        let noCycle = credits.filter { $0.statementDay == 0 && $0.dueDay == 0 }
        if !noCycle.isEmpty { report.issues.append(String(noCycle.count) + " 张信用卡没设账单日/还款日") }
        return report
    }

    static func monthlySeries(_ store: MoneyStore, category: String, months: Int, cal: Calendar) -> [Double] {
        var out: [Double] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let month = cal.date(byAdding: .month, value: -offset, to: Date()) else { continue }
            let total = store.txs.filter {
                $0.isExpense && $0.category == category
                    && cal.isDate($0.date, equalTo: month, toGranularity: .month)
            }.reduce(0) { $0 - $1.amountCNY }
            out.append(total)
        }
        return out
    }
}
