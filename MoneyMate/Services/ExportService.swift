import Foundation

/// 导出：CSV（Excel 可直接打开）/ JSON
enum ExportService {

    static func csvString(store: MoneyStore) -> String {
        var rows: [String] = ["日期,类型,金额,币种,折合人民币,分类,账户,转入账户,商户,备注,标签,记账人,地点"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        for tx in store.txs.sorted(by: { $0.date < $1.date }) {
            let kind = tx.isTransfer ? "转账" : (tx.isIncome ? "收入" : "支出")
            let fields = [
                formatter.string(from: tx.date),
                kind,
                String(format: "%.2f", tx.amount),
                tx.currency.rawValue,
                String(format: "%.2f", tx.amountCNY),
                tx.category,
                store.accountName(tx.accountID),
                tx.isTransfer ? store.accountName(tx.toAccountID) : "",
                tx.merchant,
                tx.note,
                tx.tags.joined(separator: ";"),
                tx.memberName,
                tx.location
            ]
            rows.append(fields.map(escape).joined(separator: ","))
        }
        // 前置 BOM，Excel 打开不乱码
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }

    static func csvFile(store: MoneyStore) -> URL? {
        write(csvString(store: store).data(using: .utf8), name: "MoneyMate-账本-" + stamp() + ".csv")
    }

    static func jsonFile(store: MoneyStore) -> URL? {
        write(store.exportJSON(), name: "MoneyMate-账本-" + stamp() + ".json")
    }

    // MARK: - 内部

    private static func write(_ data: Data?, name: String) -> URL? {
        guard let data else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }
}
