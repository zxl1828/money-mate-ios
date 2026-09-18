import Foundation

/// 主 App 与桌面小组件共用的数据桥（此文件同时被 App 与 Widget 两个 target 编译，不要引用 MoneyStore）
enum WidgetShared {
    static let suiteName = "group.com.moneymate.app"
    static let snapshotKey = "moneymate.widget.snapshot"
    static let standardKey = "moneymate.summary.v1"
    static let deepLink = "moneymate://add"
    static let pendingQuickAddKey = "moneymate.pending.quickadd"

    struct Snapshot: Codable, Hashable {
        var monthExpense: Double = 0
        var monthBudget: Double = 0
        var todayExpense: Double = 0
        var balance: Double = 0
        var netWorth: Double = 0
        var updatedAt: Date = Date()

        var budgetRatio: Double { monthBudget > 0 ? min(monthExpense / monthBudget, 1) : 0 }
        var budgetLeft: Double { max(monthBudget - monthExpense, 0) }
    }

    private static func groupDefaults() -> UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func write(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        groupDefaults()?.set(data, forKey: snapshotKey)
        UserDefaults.standard.set(data, forKey: standardKey)
    }

    /// 小组件读取（优先共享容器，取不到时回落本机标准存储）
    static func read() -> Snapshot? {
        if let data = groupDefaults()?.data(forKey: snapshotKey),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return snap
        }
        if let data = UserDefaults.standard.data(forKey: standardKey),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return snap
        }
        return nil
    }

    /// 小组件上点「记一笔」：写一个时间戳，主 App 回前台时消费掉
    static func queueQuickAdd() {
        groupDefaults()?.set(Date().timeIntervalSince1970, forKey: pendingQuickAddKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: pendingQuickAddKey)
    }

    /// 5 分钟内有效，消费后清除
    static func consumeQuickAdd() -> Bool {
        let stamp = (groupDefaults()?.object(forKey: pendingQuickAddKey) as? Double)
            ?? (UserDefaults.standard.object(forKey: pendingQuickAddKey) as? Double)
        guard let stamp else { return false }
        groupDefaults()?.removeObject(forKey: pendingQuickAddKey)
        UserDefaults.standard.removeObject(forKey: pendingQuickAddKey)
        return Date().timeIntervalSince1970 - stamp < 300
    }
}
