import SwiftUI
import UserNotifications

struct SubscriptionRadar: View {
    @ObservedObject var store: MoneyStore

    private var rows: [(tx: Tx, next: Date)] {
        store.recurringRules.compactMap { tx in
            guard tx.isExpense, tx.recurrence != .none else { return nil }
            var date = tx.date
            for _ in 0..<240 {
                guard let next = tx.recurrence.advance(date) else { return nil }
                date = next
                if next >= Calendar.current.startOfDay(for: Date()) { return (tx, next) }
            }
            return nil
        }.sorted { $0.next < $1.next }
    }

    private var monthly: Double {
        rows.reduce(0) { total, row in
            let amount = abs(row.tx.amountCNY)
            switch row.tx.recurrence {
            case .daily: return total + amount * 30.4375
            case .weekly: return total + amount * 52 / 12
            case .monthly: return total + amount
            case .none: return total
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        metric("每月固定刚性成本", value: store.money(monthly))
                        Divider()
                        metric("年化总固定开销", value: store.money(monthly * 12))
                    }.padding(.vertical, 8)
                }
                Section("即将扣费") {
                    if rows.isEmpty {
                        ContentUnavailableView("暂无周期扣费", systemImage: "radar")
                    }
                    ForEach(rows, id: \.tx.id) { row in
                        HStack(spacing: 12) {
                            Image(systemName: Tx.symbol(for: row.tx.category))
                                .foregroundStyle(Palette.primary)
                                .frame(width: 34, height: 34)
                                .background(Palette.primary.opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.tx.merchant.isEmpty ? row.tx.title : row.tx.merchant)
                                    .font(.subheadline.weight(.semibold))
                                Text("下次 \(row.next.formatted(date: .abbreviated, time: .omitted)) · \(row.next.timeIntervalSinceNow <= 0 ? "今天" : "(Calendar.current.dateComponents([.day], from: Date(), to: row.next).day ?? 0) 天后")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(store.money(abs(row.tx.amountCNY)))
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("订阅雷达")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .task { await scheduleAlerts() }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.weight(.bold)).foregroundStyle(Palette.primary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor private func scheduleAlerts() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("moneymate.subscription.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for row in rows.prefix(20) {
            guard let fire = Calendar.current.date(byAdding: .hour, value: -24, to: row.next), fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "周期扣费提醒"
            content.body = "(row.tx.merchant.isEmpty ? row.tx.title : row.tx.merchant) 将在 24 小时内扣款，预计 \(store.money(abs(row.tx.amountCNY)))。请核对余额或取消不需要的服务。"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "moneymate.subscription.\(row.tx.id.uuidString)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false))
            try? await center.add(request)
        }
    }
}
