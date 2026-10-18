import Foundation

/// Offline, explainable financial health metrics derived from the current ledger.
struct FinanceHealthSnapshot {
    let score: Int
    let safeToSpendToday: Double
    let noSpendStreak: Int
    let monthlyRecurringExpense: Double
    let projectedMonthExpense: Double
    let savingsRate: Double?
}

extension MoneyStore {
    var financeHealth: FinanceHealthSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let day = calendar.component(.day, from: now)
        let monthDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let projectedRemainingDays = max(monthDays - day, 0)
        let remainingDays = max(monthDays - day + 1, 1)
        let dailyAverage = day > 0 ? expense / Double(day) : 0
        let projected = expense + dailyAverage * Double(projectedRemainingDays)
        let rate = income > 0 ? (income - expense) / income : nil
        var recurring = 0.0
        let recurringRules = scopedTxs.filter { $0.recurrence != .none && $0.sourceID == nil }
        for rule in recurringRules where rule.isExpense {
            let value = abs(rule.amountCNY)
            switch rule.recurrence {
            case .daily: recurring += value * 30
            case .weekly: recurring += value * 4.33
            case .monthly: recurring += value
            case .none: break
            }
        }

        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? cursor
        while cursor >= monthStart {
            if monthTxs.contains(where: { $0.isExpense && calendar.isDate($0.date, inSameDayAs: cursor) }) { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        var score = 0
        if budget > 0 {
            let ratio = expense / budget
            score += ratio <= 0.80 ? 40 : (ratio <= 1.0 ? 25 : 8)
        } else {
            score += 15
        }
        if let rate {
            score += rate >= 0.30 ? 30 : (rate >= 0.10 ? 22 : (rate >= 0 ? 12 : 0))
        } else {
            score += 12
        }
        score += min(streak * 5, 15)
        score += income > 0 ? (recurring / income < 0.45 ? 15 : 7) : (recurring == 0 ? 15 : 5)

        let safe = max(budget - expense - recurring, 0) / Double(remainingDays)
        return FinanceHealthSnapshot(
            score: min(max(score, 0), 100),
            safeToSpendToday: safe,
            noSpendStreak: streak,
            monthlyRecurringExpense: recurring,
            projectedMonthExpense: projected,
            savingsRate: rate
        )
    }
}
