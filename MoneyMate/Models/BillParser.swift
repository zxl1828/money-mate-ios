import Foundation

// MARK: - OCR 解析出的待确认账单

struct DraftTx: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var amount: Double            // 有符号：> 0 收入，< 0 支出
    var category: String
    var date: Date
    var rawLine: String
    var included: Bool = true
    var hasTime: Bool = false

    var isIncome: Bool { amount >= 0 }
}

// MARK: - 账单文本解析（纯本地规则，无第三方依赖）

enum BillParser {

    /// 摘要行：里面的数字是统计值，入库会重复计算
    private static let summaryKeys = ["合计", "总计", "小计", "共计", "累计", "总额",
                                      "本月支出", "本月收入", "本月账单", "笔数", "共 ", "共记", "余额"]
    /// 干扰词：仅用于清理标题，不用于判定整行
    private static let noiseWords = ["微信支付", "支付宝", "订单号", "交易单号", "商户单号", "交易时间",
                                     "付款方式", "支付方式", "交易状态", "商品说明", "收款方", "查看详情",
                                     "查看更多", "账单详情", "账单明细", "全部账单", "返回", "筛选"]
    private static let incomeKeys = ["收入", "退款", "收到", "工资", "薪", "奖金", "红包", "利息",
                                     "分红", "到账", "转入", "报销", "返现"]

    private static let categoryKeys: [(name: String, keys: [String])] = [
        ("餐饮", ["餐", "饭", "食品", "外卖", "咖啡", "奶茶", "茶饮", "烧烤", "火锅", "小吃", "面馆",
                 "早餐", "午餐", "晚餐", "快餐", "麦当劳", "肯德基", "星巴克", "瑞幸", "蜜雪", "food", "cafe"]),
        ("交通", ["地铁", "公交", "打车", "滴滴", "出租", "加油", "停车", "高铁", "火车", "机票",
                 "航班", "机场", "共享单车", "ETC", "过路", "车费"]),
        ("购物", ["超市", "商场", "淘宝", "天猫", "京东", "拼多多", "便利店", "百货", "服饰", "衣",
                 "鞋", "化妆品", "数码", "苹果", "小米", "购物", "下单", "shop"]),
        ("居家", ["房租", "水电", "电费", "水费", "燃气", "物业", "宽带", "话费", "通讯", "家政",
                 "装修", "家具", "家电"]),
        ("娱乐", ["电影", "游戏", "KTV", "健身", "音乐", "视频会员", "会员", "网吧", "演唱会", "门票", "酒吧"]),
        ("医疗", ["医院", "药", "诊所", "体检", "挂号", "医保", "牙科", "眼科"]),
        ("学习", ["书店", "图书", "书", "课程", "网课", "培训", "考试", "报名", "教育", "文具"]),
        ("旅行", ["酒店", "民宿", "旅行", "旅游", "门票", "景点", "度假", "客栈"]),
        ("宠物", ["宠物", "猫", "狗", "宠物医院", "猫粮", "狗粮"]),
        ("工资", ["工资", "薪资", "薪水", "月薪", "奖金", "年终", "绩效", "补贴", "报销"]),
        ("理财", ["基金", "股票", "利息", "分红", "理财", "定期", "债券", "黄金", "收益"])
    ]

    // MARK: 主入口

    static func parse(_ lines: [OCRLine], baseDate: Date = Date()) -> [DraftTx] {
        let calendar = Calendar.current
        let joined = lines.map { $0.text }.joined(separator: " ")
        let fallback = date(in: joined, base: baseDate, calendar: calendar)
            ?? calendar.startOfDay(for: baseDate)

        var drafts: [DraftTx] = []
        for line in lines {
            let raw = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard raw.count >= 2, !isSummary(raw) else { continue }
            let cleaned = cleanForAmounts(raw)
            guard let hit = amount(in: cleaned) else { continue }

            let income = hit.positive || isIncomeLine(raw)
            let value = income ? hit.value : -hit.value
            var title = titleText(from: cleaned, removing: hit.range)
            if title.isEmpty { title = income ? "账单收入" : "账单支出" }
            let category = category(for: raw + " " + title, income: income)

            var when = date(in: raw, base: fallback, calendar: calendar) ?? fallback
            var hasTime = false
            if let composed = time(in: raw, calendar: calendar) {
                when = calendar.date(bySettingHour: composed.0, minute: composed.1, second: 0, of: when) ?? when
                hasTime = true
            }
            drafts.append(DraftTx(title: title,
                                  amount: value,
                                  category: category,
                                  date: when,
                                  rawLine: raw,
                                  included: true,
                                  hasTime: hasTime))
        }
        return spread(dedupe(drafts), calendar: calendar)
    }

    /// 转成可入库的账单：没有时间的行按 9:00 起每笔 +3 分钟排开，便于按天分组
    static func merge(_ drafts: [DraftTx]) -> [Tx] {
        drafts.filter { $0.included }.map { draft in
            Tx(title: draft.title,
               amount: draft.amount,
               category: draft.category,
               date: draft.date,
               merchant: draft.title,
               note: "OCR 识别导入",
               tags: ["OCR"])
        }
    }
    // MARK: 私有实现

    private struct Hit {
        let value: Double
        let range: Range<String.Index>
        let positive: Bool
    }

    private static let amountRegex = try? NSRegularExpression(
        pattern: "([+\\-]|－|−)?\\s*([¥￥$])?\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)\\s*(元|块)?",
        options: [])

    /// 先把日期 / 时间 / 长编号抹掉，避免被当成金额
    private static let cleanPatterns: [(String, String)] = [
        ("\\d{4}\\s*[-/.年]\\s*\\d{1,2}\\s*[-/.月]\\s*\\d{1,2}\\s*日?", " "),
        ("\\d{1,2}\\s*[:：]\\s*\\d{2}(\\s*[:：]\\s*\\d{2})?", " "),
        ("\\d{1,2}\\s*[-/]\\s*\\d{1,2}\\s*日?", " "),
        ("\\d{5,}", " ")
    ]

    private static func cleanForAmounts(_ text: String) -> String {
        var out = text
        for (pattern, replacement) in cleanPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            out = regex.stringByReplacingMatches(in: out,
                                                 options: [],
                                                 range: NSRange(out.startIndex..., in: out),
                                                 withTemplate: replacement)
        }
        return out
    }

    private static func amount(in text: String) -> Hit? {
        guard let regex = amountRegex else { return nil }
        let ns = text as NSString
        var best: Hit?
        regex.enumerateMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            guard let match else { return }
            let signRange = match.range(at: 1)
            let sign = signRange.location == NSNotFound ? "" : ns.substring(with: signRange)
            let symbol = match.range(at: 2).location != NSNotFound
            let numberRange = match.range(at: 3)
            guard numberRange.location != NSNotFound else { return }
            let number = ns.substring(with: numberRange)
            let yuan = match.range(at: 4).location != NSNotFound
            let digits = number.replacingOccurrences(of: ",", with: "")
            guard let value = Double(digits), value > 0, value < 1_000_000 else { return }
            let hasDecimal = number.contains(".")
            // 纯整数且没有任何货币标记时更保守，避免把编号、数量当金额
            if !hasDecimal && !yuan && !symbol && sign.isEmpty && digits.count > 4 { return }
            guard let range = Range(match.range, in: text) else { return }
            if let head = text[text.startIndex..<range.lowerBound].last, head.isNumber { return }
            if range.upperBound < text.endIndex, text[range.upperBound].isNumber { return }
            let hit = Hit(value: value, range: range, positive: sign == "+")
            if best == nil {
                best = hit
            } else if symbol || yuan || hasDecimal {
                best = hit
            }
        }
        return best
    }
    private static func isSummary(_ text: String) -> Bool {
        if text.contains("余额"), !text.contains("收益"), !text.contains("转入") { return true }
        return summaryKeys.contains { text.contains($0) }
    }

    private static func isIncomeLine(_ text: String) -> Bool {
        incomeKeys.contains { text.contains($0) }
    }

    private static func category(for text: String, income: Bool) -> String {
        let lower = text.lowercased()
        for entry in categoryKeys {
            for key in entry.keys where lower.contains(key.lowercased()) {
                if entry.name == "工资" && !income { continue }
                return entry.name
            }
        }
        return "其他"
    }

    private static func titleText(from cleaned: String, removing range: Range<String.Index>) -> String {
        var out = cleaned
        out = String(cleaned[cleaned.startIndex..<range.lowerBound]) + String(cleaned[range.upperBound...])
        for word in noiseWords { out = out.replacingOccurrences(of: word, with: " ") }
        out = out.replacingOccurrences(of: "|", with: " ")
        out = out.trimmingCharacters(in: CharacterSet(charactersIn: " \t-:：·,，、./\\()（）[]【】*+"))
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        if out.count > 22 { out = String(out.prefix(22)) }
        return out
    }

    private static func dedupe(_ drafts: [DraftTx]) -> [DraftTx] {
        let calendar = Calendar.current
        var out: [DraftTx] = []
        for draft in drafts {
            let duplicate = out.contains { existing in
                calendar.isDate(existing.date, inSameDayAs: draft.date)
                    && existing.title == draft.title
                    && abs(existing.amount - draft.amount) < 0.005
            }
            if !duplicate { out.append(draft) }
        }
        return out
    }

    /// 同一天的多笔账单按 3 分钟一档铺开，避免全部挤在同一秒
    private static func spread(_ drafts: [DraftTx], calendar: Calendar) -> [DraftTx] {
        var counters: [Date: Int] = [:]
        var out: [DraftTx] = []
        for var draft in drafts {
            let day = calendar.startOfDay(for: draft.date)
            let slot = counters[day, default: 0]
            counters[day] = slot + 1
            if !draft.hasTime, let when = calendar.date(bySettingHour: 9, minute: min(slot * 3, 59), second: 0, of: day) {
                draft.date = when
            }
            out.append(draft)
        }
        return out
    }

    private static func date(in text: String, base: Date, calendar: Calendar) -> Date? {
        let patterns = [
            "(\\d{4})\\s*[-/.年]\\s*(\\d{1,2})\\s*[-/.月]\\s*(\\d{1,2})\\s*日?",
            "(\\d{1,2})\\s*[-/.月]\\s*(\\d{1,2})\\s*日?"
        ]
        let ns = text as NSString
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
                  let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            else { continue }
            func group(_ i: Int) -> Int? {
                guard match.range(at: i).location != NSNotFound else { return nil }
                return Int(ns.substring(with: match.range(at: i)))
            }
            let year = index == 0 ? group(1) : nil
            let month = index == 0 ? group(2) : group(1)
            let day = index == 0 ? group(3) : group(2)
            guard let month, let day, (1...12).contains(month), (1...31).contains(day) else { continue }
            var comps = DateComponents()
            comps.year = year ?? calendar.component(.year, from: base)
            comps.month = month
            comps.day = day
            comps.minute = 0
            guard var result = calendar.date(from: comps) else { continue }
            if year == nil, result.timeIntervalSince(base) > 180 * 86_400,
               let shifted = calendar.date(byAdding: .year, value: -1, to: result) {
                result = shifted
            }
            return result
        }
        return nil
    }

    private static func time(in text: String, calendar: Calendar) -> (Int, Int)? {
        guard let regex = try? NSRegularExpression(pattern: "(\\d{1,2})\\s*[:：]\\s*(\\d{2})", options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        else { return nil }
        let ns = text as NSString
        guard let hour = Int(ns.substring(with: match.range(at: 1))),
              let minute = Int(ns.substring(with: match.range(at: 2))),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }
}