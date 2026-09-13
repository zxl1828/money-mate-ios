import Foundation

/// 共享账本：导出「共享包」给对方，对方合并进自己的账本
struct LedgerPackage: Codable {
    var ledgerName: String
    var ownerName: String
    var exportedAt: Date
    var accounts: [Account]
    var categories: [TxCategory]
    var txs: [Tx]
}

struct MergeReport {
    var addedTx: Int = 0
    var updatedTx: Int = 0
    var addedAccounts: Int = 0
    var addedCategories: Int = 0

    var summary: String {
        "新增 \(addedTx) 笔，更新 \(updatedTx) 笔"
    }
}

enum SharedLedgerService {

    static func exportPackage(store: MoneyStore) -> Data? {
        let package = LedgerPackage(ledgerName: store.ledgerName,
                                    ownerName: store.myName,
                                    exportedAt: Date(),
                                    accounts: store.accounts,
                                    categories: store.categories,
                                    txs: store.txs)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(package)
    }

    static func suggestedFileName(store: MoneyStore) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let safeName = store.ledgerName.isEmpty ? "账本" : store.ledgerName
        return "MoneyMate-共享账本-" + safeName + "-" + formatter.string(from: Date()) + ".json"
    }

    static func decode(_ data: Data) -> LedgerPackage? {
        try? JSONDecoder().decode(LedgerPackage.self, from: data)
    }

    /// 合并：同一条记录以 updatedAt 较新的为准；账户 / 分类按 id / 名称去重
    @discardableResult
    static func merge(_ data: Data, into store: MoneyStore) -> MergeReport? {
        guard let package = decode(data) else { return nil }
        var report = MergeReport()

        var accountIDs = Set(store.accounts.map(\.id))
        for account in package.accounts where !accountIDs.contains(account.id) {
            store.addAccount(account)
            accountIDs.insert(account.id)
            report.addedAccounts += 1
        }

        let existingNames = Set(store.categories.map(\.name))
        for category in package.categories where !existingNames.contains(category.name) {
            if store.addCategory(name: category.name, icon: category.icon, isIncome: category.isIncome) {
                report.addedCategories += 1
            }
        }

        var index: [UUID: Tx] = [:]
        for tx in store.txs { index[tx.id] = tx }
        for incoming in package.txs {
            if let local = index[incoming.id] {
                guard incoming.updatedAt > local.updatedAt else { continue }
                store.update(incoming)
                index[incoming.id] = incoming
                report.updatedTx += 1
            } else {
                store.add(incoming)
                index[incoming.id] = incoming
                report.addedTx += 1
            }
        }

        store.persist()
        return report
    }
}
