import Foundation

/// 报告里的一段话。
struct ReportBlock: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let body: String
    var footnote: String?
}

/// 一份完整的「体检报告」：开场白 + 若干段 + 结尾。
struct CoachingReport {
    let greeting: String
    let blocks: [ReportBlock]
    let closing: String
    /// 一句话的「现在最该做的事」
    let priority: String
}

/// 把冷冰冰的指标翻译成人话。
///
/// 全部用本地数据 + 本地规则拼字符串，不联网、不调模型、不上传任何数据，
/// 同一份数据每次生成的结果完全一致（可复现、可解释）。
enum ReportWriter {

    static func build(
        runway: RunwayReport,
        allocation: SpAllocation,
        projection: CashProjection,
        compass: CompassResult,
        avalanche: AvalanchePlan,
        stress: StressReport,
        monthlyIncome: Double,
        monthlySurplus: Double,
        netWorth: Double,
        hasMortgage: Bool,
        mortgageName: String
    ) -> CoachingReport {
        var blocks: [ReportBlock] = []
        let runwayMonths = runway.runwayMonths

        // 1. 跑道
        let runwayWord: String
        switch runway.level {
        case ...1: runwayWord = "这是要立刻处理的事"
        case 2: runwayWord = "还差一口气"
        case 3: runwayWord = "算安全，但不算宽裕"
        default: runwayWord = "很稳"
        }
        let runwayText: String
        if runway.level <= 2 {
            let target = runway.rigidMonthly * runway.safeMonths
            let gap = max(target - runway.tier1, 0)
            runwayText = "按你现在的开销，把「马上能拿出来的钱」攒到 \(money(target)) 才算真正安全，缺口大约 \(money(gap))。"
        } else {
            runwayText = "接下来可以把多出来的钱放到长期账户，而不是继续堆在活期里。"
        }
        blocks.append(ReportBlock(
            title: "如果明天没有收入",
            body: "你手头「马上能拿出来」的钱是 \(money(runway.tier1))，"
                + "每个月雷打不动的硬开销大约 \(money(runway.rigidMonthly))，"
                + "所以你的生存跑道是 \(runwayMonths >= 99 ? "足够长" : String(format: "%.1f 个月", runwayMonths))——\(runwayWord)。"
                + runwayText,
            footnote: "口径：只算现金 / 活期 / 零钱 / 货币基金；股票基金、房子、车都不算「马上能拿出来的钱」。"
        ))

        // 2. 结构
        if let largest = allocation.largest, allocation.total > 0 {
            let drift = allocation.deviation(of: largest.key)
            let driftWord = drift > 0 ? "超配" : "低配"
            blocks.append(ReportBlock(
                title: "你的钱放在哪几个篮子里",
                body: "四个篮子的配比打了 \(allocation.score) 分（100 分是完全贴住标准普尔建议）。"
                    + "最偏的是「\(largest.name)」，占了 \(pct(allocation.percent(of: largest.key)))，"
                    + "标准建议是 \(largest.targetLabel)，\(driftWord) \(String(format: "%.0f", abs(drift) * 100)) 个百分点。"
                    + (drift > 0 ? "这意味着你的钱比「教科书」更冒险，波动会更大。" : "这意味着你偏保守，抗跌但也涨得慢。")
                    + "不用现在就去卖，把接下来每个月的结余优先补到偏少的那只篮子里，一年下来结构自然就回来了。",
                footnote: allocation.notes.first
            ))
        } else {
            blocks.append(ReportBlock(
                title: "你的钱放在哪几个篮子里",
                body: "现在还没有可分配的资产，先把账户余额和房产、车这些手工科目补上，这里才看得出结构。"
            ))
        }

        // 3. 现金流
        if projection.points.isEmpty {
            blocks.append(ReportBlock(
                title: "接下来 24 个月的钱够不够",
                body: "还没有足够的流水做推演，先记满一个月账再看这里。"
            ))
        } else if projection.alerts.isEmpty {
            blocks.append(ReportBlock(
                title: "接下来 \(projection.months) 个月的钱够不够",
                body: "按每月结余 \(money(monthlySurplus)) 推演，\(projection.months) 个月里不会掉到安全线以下，"
                    + "最低点是 \(money(projection.minBalance))，最后预计剩 \(money(projection.endBalance))。"
                    + "这一栏目前是绿色的——继续保持，别为了收益把钱锁死。"
            ))
        } else if let first = projection.alerts.first {
            blocks.append(ReportBlock(
                title: "接下来 \(projection.months) 个月的钱够不够",
                body: "有 \(projection.alerts.count) 个月会跌破你给自己定的安全线（\(money(projection.safeFloor))），"
                    + "最早出现在 \(first.label)，那个月只剩 \(money(first.end))。"
                    + "解决办法不是少吃几顿，而是提前把这笔钱单独存出来，或者把那笔大额支出往后推。"
            ))
        }

        // 4. 负债
        if stress.monthlyDebt > 0 {
            var body = "每个月还贷大约 \(money(stress.monthlyDebt))，占收入 \(pct(stress.dsr))——\(stress.dsrStatus)。"
            body += stress.dsr > 0.4
                ? "超过 40% 就意味着你的现金流很脆，任何一次收入波动都可能出问题，先把高息负债干掉比投资更要紧。"
                : "在警戒线以内，属于可控范围。"
            if let firstStep = avalanche.steps.first {
                body += "如果每月能多拿出 \(money(avalanche.extraMonthly))，先砸「\(firstStep.name)」"
                    + "（利率 \(String(format: "%.1f", firstStep.rate))%），按雪崩法能少付利息 \(money(avalanche.savedInterest))、"
                    + "提前 \(String(format: "%.0f", avalanche.savedMonths)) 个月清完。"
            }
            blocks.append(ReportBlock(
                title: "你的还款压力",
                body: body,
                footnote: "顺序原则：先还利率最高的那笔，而不是金额最小的那笔（后者是「雪球法」，心理爽但更贵）。"
            ))
        }

        // 5. 还贷 vs 投资
        if hasMortgage && compass.balance > 0 {
            let body: String
            if compass.investWins {
                body = "以「\(mortgageName)」为例：房贷利率 \(String(format: "%.1f", compass.rate))%，"
                    + "你预期理财年化 \(String(format: "%.1f", compass.expectedReturn))%，"
                    + "中间有 \(String(format: "%.1f", compass.spread)) 个点的利差。"
                    + "算下来不提前还、拿去投，最后大约多出 \(money(compass.investFinal - compass.investMonthlyOutlay))，"
                    + "所以优先投资——但前提是这笔钱真的能拿住 5 年以上，且不影响你的生存跑道。"
            } else {
                body = "以「\(mortgageName)」为例：房贷利率 \(String(format: "%.1f", compass.rate))%，"
                    + "预期理财年化 \(String(format: "%.1f", compass.expectedReturn))%，"
                    + "利差只有 \(String(format: "%.1f", compass.spread)) 个点，而房贷利息是「确定省下」的，理财收益是「可能拿到」的。"
                    + "这种时候提前还掉更划算：一次还 \(money(compass.idleCash)) 能省利息 \(money(compass.interestSaving))，"
                    + "每月月供也松出 \(money(compass.freedMonthly))。"
            }
            blocks.append(ReportBlock(
                title: "闲钱该提前还贷还是拿去投",
                body: body,
                footnote: "别忘了流动性：还进房贷的钱拿不回来；留着的钱随时能救命。"
            ))
        }

        // 6. 不用焦虑
        var reassures: [String] = []
        if runway.level >= 3 { reassures.append("你有 \(Int(runwayMonths)) 个月的跑道，已经比大多数人稳") }
        if stress.monthlyDebt == 0 { reassures.append("目前没有在还的贷款，负债压力为零") }
        if allocation.score >= 70 { reassures.append("资产结构和教科书偏差不大，不需要折腾") }
        if projection.ok { reassures.append("未来 \(projection.months) 个月现金流不会断") }
        if !reassures.isEmpty {
            blocks.append(ReportBlock(
                title: "这几件事你可以不用焦虑",
                body: reassures.joined(separator: "；") + "。理财最容易亏钱的动作，是在没事的时候乱动。"
            ))
        }

        let greeting = "我把你账本里的数字读了一遍。"
            + "净资产 \(money(netWorth))，月收入约 \(money(monthlyIncome))，"
            + "每月能存下 \(money(monthlySurplus))"
            + (monthlyIncome <= 0 ? "。" : "（\(pct(max(monthlySurplus / monthlyIncome, 0)))，已经是不错的储蓄率）。")
            + "下面这些不讲术语，只说人话。"

        return CoachingReport(
            greeting: greeting,
            blocks: blocks,
            closing: "这份报告是拿你本地账本算的，没上传任何数据。"
                + "下个月记完账再跑一次，看跑道有没有变长、结构有没有回来——改善是慢慢累积出来的，不是靠一次操作。",
            priority: priority(runway: runway, allocation: allocation, stress: stress,
                               projection: projection, monthlySurplus: monthlySurplus)
        )
    }

    // MARK: - 优先级

    private static func priority(
        runway: RunwayReport,
        allocation: SpAllocation,
        stress: StressReport,
        projection: CashProjection,
        monthlySurplus: Double
    ) -> String {
        if runway.level <= 1 {
            let target = runway.rigidMonthly * runway.safeMonths
            let gap = max(target - runway.tier1, 0)
            let perMonth = monthlySurplus > 0 ? monthlySurplus * 0.7 : runway.rigidMonthly * 0.15
            return "先把「救命钱」攒到 \(money(target))：每月结余优先划 \(money(perMonth)) 进活期或货币基金，缺口 \(money(gap))。"
        }
        if stress.dsr > 0.5 {
            return "先降负债：每月还款占收入 \(pct(stress.dsr))，把最高利率那笔优先还掉，投资的事往后放。"
        }
        if let idx = projection.firstAlertIndex, idx >= 0, let first = projection.alerts.first {
            return "先给「\(first.label)」那笔大额支出做准备，把 \(money(projection.safeFloor)) 提前单独存出来。"
        }
        if let largest = allocation.largest, allocation.deviation(of: largest.key) > 0.08 {
            return "别再加「\(largest.name)」了：把每月结余的新增部分转去偏少的那只篮子，让结构慢慢回到目标比例。"
        }
        if monthlySurplus <= 0 {
            return "先让结余转正：找出可选消费里最大的一项，砍掉三成，比研究投资标的更有用。"
        }
        return "结构已经不错：把每月结余按目标比例定投，然后一年只复盘两次，别频繁操作。"
    }

    private static func pct(_ v: Double) -> String {
        String(format: "%.0f%%", v * 100)
    }
}
