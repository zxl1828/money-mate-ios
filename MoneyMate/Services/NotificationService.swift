import Foundation
import UserNotifications

/// 本地通知：每日记账提醒、超预算提醒、信用卡还款提醒（全部离线，不需要账号）
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 重建全部本地提醒（设置变化 / 每次启动时调用）
    func reschedule(store: MoneyStore) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        Task { @MainActor in
            let status = await authorizationStatus()
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            scheduleDaily(store: store, center: center)
            scheduleBudget(store: store, center: center)
            scheduleCredits(store: store, center: center)
        }
    }

    // MARK: - 具体提醒

    private func scheduleDaily(store: MoneyStore, center: UNUserNotificationCenter) {
        guard store.dailyReminder else { return }
        var comps = DateComponents()
        comps.hour = min(max(store.dailyReminderHour, 0), 23)
        comps.minute = min(max(store.dailyReminderMinute, 0), 59)
        let body = "本月已花 " + store.money(store.expense) + "，别忘了记下今天这一笔"
        add(center, id: "moneymate.daily", title: "今天记账了吗？", body: body, comps: comps, repeats: true)
    }

    private func scheduleBudget(store: MoneyStore, center: UNUserNotificationCenter) {
        guard store.budgetAlert, store.budget > 0, store.expense >= store.budget else { return }
        let content = UNMutableNotificationContent()
        content.title = "本月预算已超支"
        content.body = "已花 " + store.money(store.expense) + "，超出预算 " + store.money(store.expense - store.budget)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        center.add(UNNotificationRequest(identifier: "moneymate.budget", content: content, trigger: trigger),
                   withCompletionHandler: nil)
    }

    private func scheduleCredits(store: MoneyStore, center: UNUserNotificationCenter) {
        guard store.creditAlert else { return }
        let cal = Calendar.current
        for account in store.accounts where account.kind == .credit && !account.archived {
            let summary = store.creditSummary(for: account)
            guard let due = summary.dueDate else { continue }
            for offset in [3, 0] {
                guard let fireDay = cal.date(byAdding: .day, value: -offset, to: due) else { continue }
                var comps = cal.dateComponents([.year, .month, .day], from: fireDay)
                comps.hour = 9
                comps.minute = 0
                guard let fire = cal.date(from: comps), fire > Date() else { continue }
                let title = offset == 0 ? "今天是还款日" : "还有 \(offset) 天到还款日"
                let body = account.displayName + " 本期账单 " + store.money(summary.currentBill)
                    + "，还款日 " + due.formatted(date: .abbreviated, time: .omitted)
                add(center, id: "moneymate.credit.\(account.id.uuidString).\(offset)",
                    title: title, body: body, comps: comps, repeats: false)
            }
        }
    }

    private func add(_ center: UNUserNotificationCenter, id: String, title: String, body: String,
                     comps: DateComponents, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger),
                   withCompletionHandler: nil)
    }
}
