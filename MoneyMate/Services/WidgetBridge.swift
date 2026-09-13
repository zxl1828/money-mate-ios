import Foundation
import WidgetKit

/// 主 App 侧写入小组件摘要
/// 说明：数据写进 App Group 共享容器；若签名未开启 App Groups，写入会落到本机标准存储，
/// 小组件读不到数据时显示引导态（不会崩溃）。要启用共享，需在签名时勾选 App Groups: group.com.moneymate.app。
enum WidgetBridge {
    static func write(store: MoneyStore) {
        let snapshot = WidgetShared.Snapshot(
            monthExpense: store.expense,
            monthBudget: store.budget,
            todayExpense: store.todayTxs.filter { $0.isExpense }.reduce(0) { $0 - $1.amountCNY },
            balance: store.balance,
            netWorth: store.netWorthValue,
            updatedAt: Date())
        WidgetShared.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetShared.Snapshot? {
        WidgetShared.read()
    }
}
