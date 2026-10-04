import Foundation

// MARK: - 智能预算推荐引擎与数据模型

/// 被自动识别并剥离的非日常偶发/特殊开销条目
struct StrippedExpenseItem: Identifiable, Hashable {
    var id: UUID = UUID()
    let title: String
    let amount: Double
    let category: String
    let date: Date
    let reason: String // 剥离原因，如 "节假日/人情往来"、"非日常耐用品购置"、"突发大额开销"、"非常规分类"
}

/// 智能预算诊断与推荐报告
struct SmartBudgetReport: Hashable {
    let recommendedBudget: Double           // 最终智能推荐月度总预算（四舍五入整百）
    let baselineDaily: Double               // 剔除特殊支出后的常规刚性日均
    let baselineMonthly: Double             // 日常月度刚性基线（日均 × 当月天数）
    let recurringCommitment: Double         // 每月固定周期账单（房租、固定订阅）
    let safetyBuffer: Double                // 弹性安全流动储备金（约 8%）
    let strippedSpecialExpenses: [StrippedExpenseItem] // 自动识别并剥离的特殊支出明细
    let strippedTotal: Double               // 剥离的特殊支出总额
    let analyzedDays: Int                   // 分析的历史真实样本跨度（天数）
    let analyzedTxCount: Int                // 分析的历史交易总笔数
    let reasoningSummary: String            // 简明易懂的智能诊断分析摘要
}

enum SmartBudgetEngine {
    // 节假日 / 人情往来偶发关键词
    private static let holidayKeywords = [
        "过节", "节日", "中秋", "国庆", "春节", "元旦", "端午", "清明", "七夕", "情人节", "圣诞",
        "年货", "送礼", "礼物", "份子钱", "礼金", "红包", "喜酒", "办酒"
    ]

    // 一次性大件购置 / 突发医疗急诊 / 旅游度假
    private static let oneOffKeywords = [
        "手机", "电脑", "单反", "相机", "家电", "空调", "冰箱", "洗衣机", "电视", "平板",
        "ipad", "iphone", "macbook", "主机", "显卡", "住院", "门诊", "手术", "大修", "装修",
        "学费", "驾校", "旅游", "机票", "门票", "年费", "首饰", "黄金"
    ]

    /// 核心算法：结合去噪过滤、离群点检测、周期债务与弹性储备金生成智能预算报告
    static func generateReport(
        txs: [Tx],
        irregularCategories: Set<String>,
        recurringRules: [Tx],
        currentBudget: Double
    ) -> SmartBudgetReport {
        let calendar = Calendar.current
        let now = Date()
        let lookbackDays = 60 // 采样近 60 天数据作为统计基准池
        guard let cutoffDate = calendar.date(byAdding: .day, value: -lookbackDays, to: now) else {
            return fallbackReport(currentBudget: currentBudget)
        }

        // 仅筛选实际支出
        let expenses = txs.filter { $0.isExpense && $0.date >= cutoffDate && $0.date <= now }
        guard !expenses.isEmpty else {
            return fallbackReport(currentBudget: currentBudget)
        }

        // 计算所有单笔支出中位数作为基准标尺
        let expenseAmounts = expenses.map { abs($0.amountCNY) }.sorted()
        let medianAmount = expenseAmounts[expenseAmounts.count / 2]

        var strippedItems: [StrippedExpenseItem] = []
        var regularExpenses: [Tx] = []

        for tx in expenses {
            let amount = abs(tx.amountCNY)
            let cat = tx.category
            let text = "\(tx.title) \(tx.merchant) \(tx.note) \(tx.tags.joined(separator: " "))".lowercased()

            var strippedReason: String? = nil

            // 规则 1：用户主动标记的非常规分类（节日/婚礼/大件等）
            if irregularCategories.contains(cat) {
                strippedReason = "标记为非常规分类（\(cat)）"
            }
            // 规则 2：命中节假日、送礼、年货、人情往来关键词
            else if holidayKeywords.contains(where: { text.contains($0) }) {
                strippedReason = "识别为节假日/人情偶发消费"
            }
            // 规则 3：命中数码家电、旅游大件、医疗急诊等非日常耐用品关键词且金额大于 200
            else if oneOffKeywords.contains(where: { text.contains($0) }) && amount > 200 {
                strippedReason = "识别为一次性耐用品/非日常突发购置"
            }
            // 规则 4：统计学离群点（金额超过单笔中位数的 5 倍，且单笔 > 600 元）
            else if amount > max(medianAmount * 5.0, 600) {
                strippedReason = "单笔异常大额突发支出（远超日常基准）"
            }

            if let reason = strippedReason {
                strippedItems.append(StrippedExpenseItem(
                    id: tx.id,
                    title: tx.title.isEmpty ? cat : tx.title,
                    amount: amount,
                    category: cat,
                    date: tx.date,
                    reason: reason
                ))
            } else {
                regularExpenses.append(tx)
            }
        }

        let strippedTotal = strippedItems.reduce(0) { $0 + $1.amount }

        // 计算常规日常真实日均开销
        let earliestDate = regularExpenses.map(\.date).min() ?? cutoffDate
        let actualSpan = max(calendar.dateComponents([.day], from: earliestDate, to: now).day ?? 1, 1) + 1
        let regularTotal = regularExpenses.reduce(0) { $0 + abs($1.amountCNY) }
        let baselineDaily = regularTotal / Double(actualSpan)

        // 目标月份天数
        let targetMonthDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let baselineMonthly = baselineDaily * Double(targetMonthDays)

        // 每月固定周期账单与负债承诺
        var recurringCommitment: Double = 0
        for rule in recurringRules {
            let val = abs(rule.amountCNY)
            switch rule.recurrence {
            case .monthly: recurringCommitment += val
            case .weekly: recurringCommitment += val * 4.33
            case .daily: recurringCommitment += val * 30.0
            case .none: break
            }
        }

        // 弹性安全流动缓冲金（8%）
        let safetyBuffer = (baselineMonthly + recurringCommitment) * 0.08

        // 最终推荐总额：四舍五入至整百元
        let rawRecommended = baselineMonthly + recurringCommitment + safetyBuffer
        let roundedRecommended = max(round(rawRecommended / 100.0) * 100.0, 500.0)

        // 智能诊断说明
        let summary: String
        if !strippedItems.isEmpty {
            summary = "已为您自动识别并剥离 \(strippedItems.count) 笔非日常偶发开销（共 ¥\(String(format: "%.0f", strippedTotal))），杜绝偶发大单拉高日常预算；结合您的日常真实刚需（¥\(String(format: "%.0f", baselineMonthly))）与 8% 弹性安全储备金综合测算。"
        } else {
            summary = "近 \(actualSpan) 天消费规律平稳健康，已基于您的真实日常支出速率与 8% 弹性安全储备金给出科学预算推荐。"
        }

        return SmartBudgetReport(
            recommendedBudget: roundedRecommended,
            baselineDaily: baselineDaily,
            baselineMonthly: baselineMonthly,
            recurringCommitment: recurringCommitment,
            safetyBuffer: safetyBuffer,
            strippedSpecialExpenses: strippedItems.sorted(by: { $0.amount > $1.amount }),
            strippedTotal: strippedTotal,
            analyzedDays: actualSpan,
            analyzedTxCount: expenses.count,
            reasoningSummary: summary
        )
    }

    private static func fallbackReport(currentBudget: Double) -> SmartBudgetReport {
        let b = max(currentBudget, 3000.0)
        return SmartBudgetReport(
            recommendedBudget: b,
            baselineDaily: b / 30.0 * 0.92,
            baselineMonthly: b * 0.92,
            recurringCommitment: 0,
            safetyBuffer: b * 0.08,
            strippedSpecialExpenses: [],
            strippedTotal: 0,
            analyzedDays: 30,
            analyzedTxCount: 0,
            reasoningSummary: "历史记账数据较少，已基于当前预算提供基准弹性分配建议。"
        )
    }
}
