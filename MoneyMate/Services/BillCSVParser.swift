import Foundation

// MARK: - 微信 / 支付宝账单 CSV 智能解析引擎

struct ParsedBillItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var amount: Double          // 支出为负，收入为正
    var kind: TxKind
    var category: String
    var date: Date
    var merchant: String
    var note: String
    var platform: String        // "微信支付" / "支付宝"
    var isDuplicate: Bool = false
    var isSelected: Bool = true
}

struct BillParseResult {
    let platform: String
    var items: [ParsedBillItem]
    let totalExpense: Double
    let totalIncome: Double
    let duplicateCount: Int
}


enum BillCSVParser {
    /// 尝试以 UTF-8 或 GB18030/GBK 格式解码二进制数据
    static func decodeCSVData(_ data: Data) -> String? {
        if let str = String(data: data, encoding: .utf8) {
            return str
        }
        let gbkEncoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let str = String(data: data, encoding: String.Encoding(rawValue: gbkEncoding)) {
            return str
        }
        return nil
    }

    /// 解析 CSV 文本并对比已有账本进行去重
    static func parse(csvText: String, existingTxs: [Tx] = []) -> BillParseResult? {
        let lines = csvText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        // 识别平台类型
        let isWeChat = lines.prefix(15).contains { $0.contains("微信支付账单明细") || $0.contains("微信支付") }
        let isAlipay = lines.prefix(15).contains { $0.contains("支付宝") || $0.contains("支付宝交易记录") }

        if isWeChat {
            return parseWeChat(lines: lines, existingTxs: existingTxs)
        } else if isAlipay {
            return parseAlipay(lines: lines, existingTxs: existingTxs)
        } else {
            // 通用备用尝试：若表头包含 "金额"
            if lines.contains(where: { $0.contains("金额") && $0.contains("时间") }) {
                return parseWeChat(lines: lines, existingTxs: existingTxs)
            }
            return nil
        }
    }

    // MARK: - 微信账单解析
    private static func parseWeChat(lines: [String], existingTxs: [Tx]) -> BillParseResult {
        var headerIndex = -1
        for (i, line) in lines.enumerated() {
            if line.contains("交易时间") && line.contains("金额") {
                headerIndex = i
                break
            }
        }

        guard headerIndex >= 0 else {
            return BillParseResult(platform: "微信支付", items: [], totalExpense: 0, totalIncome: 0, duplicateCount: 0)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var items: [ParsedBillItem] = []
        var dupCount = 0

        for line in lines.dropFirst(headerIndex + 1) {
            let cols = splitCSVLine(line)
            guard cols.count >= 6 else { continue }

            // 微信典型列顺序：
            // 0:交易时间, 1:交易类型, 2:交易对方, 3:商品, 4:收/支, 5:金额(元), 6:支付方式, 7:当前状态, 8:交易单号, 9:商户单号, 10:备注
            let dateStr = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let date = dateFormatter.date(from: dateStr) ?? Date()

            let txType = cols[1]
            let payee = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let goods = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let direction = cols[4] // "支出" / "收入" / "/"
            let rawAmt = cols[5].replacingOccurrences(of: "¥", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
            guard let amountNum = Double(rawAmt), amountNum > 0 else { continue }

            let status = cols.count > 7 ? cols[7] : ""
            // 过滤退款或关闭交易
            if status.contains("已退款") || status.contains("已关闭") {
                continue
            }

            let kind: TxKind
            if direction.contains("收入") {
                kind = .income
            } else if direction.contains("支出") {
                kind = .expense
            } else {
                continue // 忽略资金内部划转
            }

            let title = goods.isEmpty || goods == "/" ? (payee.isEmpty || payee == "/" ? txType : payee) : goods
            let merchant = payee == "/" ? "" : payee
            let signedAmount = kind == .expense ? -abs(amountNum) : abs(amountNum)
            let category = autoCategorize(title: title, merchant: merchant, note: "")

            // 查重：同日期(按天) + 同金额 + 类似商户/标题
            let isDup = existingTxs.contains { ex in
                abs(ex.amountCNY - signedAmount) < 0.01 &&
                Calendar.current.isDate(ex.date, inSameDayAs: date)
            }

            if isDup { dupCount += 1 }

            items.append(ParsedBillItem(
                title: title,
                amount: signedAmount,
                kind: kind,
                category: category,
                date: date,
                merchant: merchant,
                note: "微信导入 · \(txType)",
                platform: "微信支付",
                isDuplicate: isDup,
                isSelected: !isDup // 默认不勾选已存在的重复项
            ))
        }

        let totalExp = items.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }
        let totalInc = items.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }

        return BillParseResult(
            platform: "微信支付",
            items: items,
            totalExpense: totalExp,
            totalIncome: totalInc,
            duplicateCount: dupCount
        )
    }

    // MARK: - 支付宝账单解析
    private static func parseAlipay(lines: [String], existingTxs: [Tx]) -> BillParseResult {
        var headerIndex = -1
        for (i, line) in lines.enumerated() {
            if (line.contains("交易时间") || line.contains("交易创建时间")) && line.contains("金额") {
                headerIndex = i
                break
            }
        }

        guard headerIndex >= 0 else {
            return BillParseResult(platform: "支付宝", items: [], totalExpense: 0, totalIncome: 0, duplicateCount: 0)
        }

        let headers = splitCSVLine(lines[headerIndex])
        let dateCol = headers.firstIndex(where: { $0.contains("交易时间") || $0.contains("交易创建时间") || $0.contains("付款时间") }) ?? 2
        let payeeCol = headers.firstIndex(where: { $0.contains("交易对方") }) ?? 7
        let goodsCol = headers.firstIndex(where: { $0.contains("商品") }) ?? 8
        let amountCol = headers.firstIndex(where: { $0.contains("金额") }) ?? 9
        let dirCol = headers.firstIndex(where: { $0.contains("收/支") }) ?? 10
        let statusCol = headers.firstIndex(where: { $0.contains("交易状态") }) ?? 11

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var items: [ParsedBillItem] = []
        var dupCount = 0

        for line in lines.dropFirst(headerIndex + 1) {
            let cols = splitCSVLine(line)
            guard cols.count > max(dateCol, max(amountCol, dirCol)) else { continue }

            let dateStr = cols[dateCol].trimmingCharacters(in: .whitespacesAndNewlines)
            let date = dateFormatter.date(from: dateStr) ?? Date()

            let payee = payeeCol < cols.count ? cols[payeeCol].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let goods = goodsCol < cols.count ? cols[goodsCol].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let direction = cols[dirCol].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawAmt = cols[amountCol].replacingOccurrences(of: "¥", with: "").replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
            guard let amountNum = Double(rawAmt), amountNum > 0 else { continue }

            let status = statusCol < cols.count ? cols[statusCol] : ""
            if status.contains("退款") || status.contains("关闭") || status.contains("失败") {
                continue
            }

            let kind: TxKind
            if direction.contains("收入") {
                kind = .income
            } else if direction.contains("支出") {
                kind = .expense
            } else {
                continue
            }

            let title = goods.isEmpty || goods == "/" ? (payee.isEmpty || payee == "/" ? "支付宝消费" : payee) : goods
            let merchant = payee == "/" ? "" : payee
            let signedAmount = kind == .expense ? -abs(amountNum) : abs(amountNum)
            let category = autoCategorize(title: title, merchant: merchant, note: "")

            let isDup = existingTxs.contains { ex in
                abs(ex.amountCNY - signedAmount) < 0.01 &&
                Calendar.current.isDate(ex.date, inSameDayAs: date)
            }

            if isDup { dupCount += 1 }

            items.append(ParsedBillItem(
                title: title,
                amount: signedAmount,
                kind: kind,
                category: category,
                date: date,
                merchant: merchant,
                note: "支付宝导入",
                platform: "支付宝",
                isDuplicate: isDup,
                isSelected: !isDup
            ))
        }

        let totalExp = items.filter { $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }
        let totalInc = items.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }

        return BillParseResult(
            platform: "支付宝",
            items: items,
            totalExpense: totalExp,
            totalIncome: totalInc,
            duplicateCount: dupCount
        )
    }

    // MARK: - 智能分类匹配字典
    static func autoCategorize(title: String, merchant: String, note: String) -> String {
        let text = "\(title) \(merchant) \(note)".lowercased()

        if text.contains("麦当劳") || text.contains("肯德基") || text.contains("星巴克") || text.contains("瑞幸") ||
           text.contains("美团") || text.contains("饿了么") || text.contains("奶茶") || text.contains("咖啡") ||
           text.contains("餐饮") || text.contains("食堂") || text.contains("饭店") || text.contains("面馆") ||
           text.contains("火锅") || text.contains("烧烤") || text.contains("喜茶") || text.contains("茶百道") ||
           text.contains("古茗") || text.contains("霸王茶姬") || text.contains("奈雪") || text.contains("面包") {
            return "餐饮"
        }
        if text.contains("滴滴") || text.contains("花小猪") || text.contains("地铁") || text.contains("公交") ||
           text.contains("高德") || text.contains("铁路") || text.contains("12306") || text.contains("加油") ||
           text.contains("停车") || text.contains("顺风车") || text.contains("打车") || text.contains("单车") ||
           text.contains("租车") || text.contains("过路费") || text.contains("etc") {
            return "交通"
        }
        if text.contains("淘宝") || text.contains("天猫") || text.contains("京东") || text.contains("拼多多") ||
           text.contains("唯品会") || text.contains("盒马") || text.contains("超市") || text.contains("便利店") ||
           text.contains("7-eleven") || text.contains("全家") || text.contains("罗森") || text.contains("商场") ||
           text.contains("服饰") || text.contains("百货") || text.contains("衣服") || text.contains("鞋") {
            return "购物"
        }
        if text.contains("电影") || text.contains("影城") || text.contains("游戏") || text.contains("腾讯") ||
           text.contains("网易") || text.contains("哔哩哔哩") || text.contains("爱奇艺") || text.contains("优酷") ||
           text.contains("网易云") || text.contains("qq音乐") || text.contains("steam") || text.contains("ktv") ||
           text.contains("剧本杀") || text.contains("密室") || text.contains("大麦") || text.contains("演唱会") {
            return "娱乐"
        }
        if text.contains("水费") || text.contains("电费") || text.contains("燃气") || text.contains("物业") ||
           text.contains("宽带") || text.contains("房租") || text.contains("自如") || text.contains("宜家") ||
           text.contains("话费") || text.contains("联通") || text.contains("移动") || text.contains("电信") {
            return "居家"
        }
        if text.contains("医院") || text.contains("药房") || text.contains("药店") || text.contains("诊所") ||
           text.contains("门诊") || text.contains("体检") || text.contains("阿里健康") || text.contains("叮当快药") {
            return "医疗"
        }
        if text.contains("书") || text.contains("课程") || text.contains("培训") || text.contains("学费") ||
           text.contains("考试") || text.contains("知网") || text.contains("文具") || text.contains("得到") {
            return "学习"
        }
        if text.contains("宠物") || text.contains("猫") || text.contains("狗") || text.contains("兽医") ||
           text.contains("动物") || text.contains("绝育") {
            return "宠物"
        }
        if text.contains("工资") || text.contains("薪酬") || text.contains("奖金") || text.contains("劳务") {
            return "工资"
        }
        if text.contains("理财") || text.contains("基金") || text.contains("利息") || text.contains("分红") {
            return "理财"
        }
        return "其他"
    }

    /// 正确解析包含引号、逗号的 CSV 行
    private static func splitCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if (char == "," || char == "\t") && !inQuotes {
                result.append(cleanField(current))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(cleanField(current))
        return result
    }

    private static func cleanField(_ str: String) -> String {
        var s = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2 {
            s.removeFirst()
            s.removeLast()
        }
        return s.replacingOccurrences(of: "\"\"", with: "\"").trimmingCharacters(in: .whitespaces)
    }
}
