import Foundation

// MARK: - 账户 / 转账 / 净值 / 分类（MoneyStore 扩展）

extension MoneyStore {

    // MARK: 数据迁移

    /// 老版本升级：补齐账户与分类，把没有账户的历史流水挂到默认账户
    func migrateIfNeeded() {
        var changed = false
        if categories.isEmpty {
            categories = TxCategory.builtins()
            changed = true
        }
        if accounts.isEmpty {
            let def = Account(name: "我的钱包", kind: .wallet)
            accounts.append(def)
            for i in txs.indices where txs[i].accountID == nil {
                txs[i].accountID = def.id
            }
            changed = true
        }
        if members.isEmpty {
            members = [LedgerMember(name: myName.isEmpty ? "我" : myName, isMe: true)]
            changed = true
        }
        if changed { persist() }
    }

    // MARK: 账户

    var activeAccounts: [Account] { accounts.filter { !$0.archived } }

    func account(_ id: UUID?) -> Account? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    func accountName(_ id: UUID?) -> String {
        account(id)?.name ?? "未指定"
    }

    func addAccount(_ account: Account) { accounts.append(account) }

    func updateAccount(_ account: Account) {
        guard let idx = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[idx] = account
    }

    func deleteAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        for i in txs.indices {
            if txs[i].accountID == account.id { txs[i].accountID = nil }
            if txs[i].toAccountID == account.id { txs[i].toAccountID = nil }
        }
    }

    func balance(of accountID: UUID) -> Double {
        guard let account = account(accountID) else { return 0 }
        return FinanceMath.balance(account, txs: txs)
    }

    func txs(of accountID: UUID) -> [Tx] {
        txs.filter { $0.accountID == accountID || $0.toAccountID == accountID }
            .sorted { $0.date > $1.date }
    }

    func creditSummary(for account: Account) -> CreditSummary {
        FinanceMath.creditSummary(account, txs: txs)
    }

    /// 账户间转账（也用于信用卡还款）
    @discardableResult
    func addTransfer(from: UUID, to: UUID, amount: Double, date: Date = Date(),
                     note: String = "", member: String = "") -> Tx? {
        guard amount > 0, from != to else { return nil }
        let tx = Tx(title: "转账", amount: -abs(amount), category: "转账", date: date,
                    note: note, kind: .transfer, accountID: from, toAccountID: to,
                    updatedAt: Date(), memberName: member)
        add(tx)
        return tx
    }

    // MARK: 资产 / 净值

    var totalAssets: Double { FinanceMath.netWorth(accounts: accounts, txs: txs).assets }
    var totalLiabilities: Double { FinanceMath.netWorth(accounts: accounts, txs: txs).liabilities }
    var netWorthValue: Double { totalAssets - totalLiabilities }

    func netWorthSeries(months: Int = 6) -> [NetWorthPoint] {
        FinanceMath.netWorthSeries(accounts: accounts, txs: txs, months: months)
    }

    // MARK: 分类

    var visibleCategories: [TxCategory] {
        categories.filter { !$0.hidden }.sorted { $0.sortIndex < $1.sortIndex }
    }
    var expenseCategories: [TxCategory] { visibleCategories.filter { !$0.isIncome } }
    var incomeCategories: [TxCategory] { visibleCategories.filter { $0.isIncome } }

    func categoryIcon(_ name: String) -> String {
        categories.first { $0.name == name }?.icon ?? "ellipsis.circle.fill"
    }

    @discardableResult
    func addCategory(name: String, icon: String, isIncome: Bool) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !categories.contains(where: { $0.name == trimmed }) else { return false }
        let maxIndex = categories.filter { $0.isIncome == isIncome }.map(\.sortIndex).max() ?? 0
        categories.append(TxCategory(name: trimmed, icon: icon, isIncome: isIncome, sortIndex: maxIndex + 1))
        return true
    }

    func updateCategory(_ category: TxCategory) {
        guard let idx = categories.firstIndex(where: { $0.id == category.id }) else { return }
        let old = categories[idx].name
        categories[idx] = category
        guard old != category.name else { return }
        for i in txs.indices where txs[i].category == old { txs[i].category = category.name }
    }

    func setCategoryHidden(_ category: TxCategory, hidden: Bool) {
        guard let idx = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[idx].hidden = hidden
    }

    func deleteCategory(_ category: TxCategory) {
        if category.builtin {
            setCategoryHidden(category, hidden: true)
        } else {
            categories.removeAll { $0.id == category.id }
        }
    }

    func restoreCategories() {
        categories = TxCategory.builtins()
    }
}
