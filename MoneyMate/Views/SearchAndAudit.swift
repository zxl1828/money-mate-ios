import SwiftUI

// MARK: - 高级搜索语法

/// 支持：`餐饮 >100 本月 标签:出差 账户:招商` —— 关键词照旧模糊匹配
struct SearchQuery {
    var keyword = ""
    var category: String?
    var minAmount: Double?
    var maxAmount: Double?
    var tag: String?
    var accountName: String?
    var range: DateInterval?

    static func parse(_ text: String) -> SearchQuery {
        var query = SearchQuery()
        let cal = Calendar.current
        let now = Date()
        for raw in text.split(separator: " ") {
            let token = String(raw).trimmingCharacters(in: .whitespaces)
            if token.isEmpty { continue }

            if token.hasPrefix(">") , let value = Double(token.dropFirst()) {
                query.minAmount = value
                continue
            }
            if token.hasPrefix("<"), let value = Double(token.dropFirst()) {
                query.maxAmount = value
                continue
            }
            if token.contains("-"), token.hasPrefix(" ") == false,
               let dash = token.firstIndex(of: "-"),
               let low = Double(token[token.startIndex..<dash]),
               let high = Double(token[token.index(after: dash)...]) {
                query.minAmount = low
                query.maxAmount = high
                continue
            }
            if let value = prefixValue(token, key: "标签:") ?? prefixValue(token, key: "#") {
                query.tag = value
                continue
            }
            if let value = prefixValue(token, key: "账户:") {
                query.accountName = value
                continue
            }
            switch token {
            case "本月":
                if let start = cal.date(from: cal.dateComponents([.year, .month], from: now)),
                   let end = cal.date(byAdding: .month, value: 1, to: start) {
                    query.range = DateInterval(start: start, end: end)
                }
            case "上月":
                if let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)),
                   let start = cal.date(byAdding: .month, value: -1, to: thisMonth) {
                    query.range = DateInterval(start: start, end: thisMonth)
                }
            case "今年":
                if let start = cal.date(from: cal.dateComponents([.year], from: now)),
                   let end = cal.date(byAdding: .year, value: 1, to: start) {
                    query.range = DateInterval(start: start, end: end)
                }
            case "近7天":
                query.range = DateInterval(start: cal.date(byAdding: .day, value: -7, to: now) ?? now, end: now)
            case "近30天":
                query.range = DateInterval(start: cal.date(byAdding: .day, value: -30, to: now) ?? now, end: now)
            default:
                if Tx.categories.contains(token) && query.category == nil {
                    query.category = token
                } else if query.keyword.isEmpty {
                    query.keyword = token
                } else {
                    query.keyword += " " + token
                }
            }
        }
        return query
    }

    private static func prefixValue(_ token: String, key: String) -> String? {
        guard token.hasPrefix(key) else { return nil }
        let value = String(token.dropFirst(key.count))
        return value.isEmpty ? nil : value
    }

    func matches(_ tx: Tx, store: MoneyStore) -> Bool {
        let amount = abs(tx.amountCNY)
        if let minAmount, amount < minAmount { return false }
        if let maxAmount, amount > maxAmount { return false }
        if let tag, !tx.tags.contains(where: { $0.contains(tag) }) { return false }
        if let accountName, !store.accountName(tx.accountID).contains(accountName) { return false }
        if let range, !range.contains(tx.date) { return false }
        return true
    }

    var isEmpty: Bool {
        keyword.isEmpty && category == nil && minAmount == nil && maxAmount == nil
            && tag == nil && accountName == nil && range == nil
    }
}

// MARK: - 保存筛选

enum SavedFilters {
    private static let key = "moneymate.filters.v1"

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func save(_ list: [String]) {
        UserDefaults.standard.set(list, forKey: key)
    }
}

struct SavedFilterBar: View {
    @Binding var query: String
    @State private var saved = SavedFilters.load()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(saved, id: \.self) { item in
                    Button {
                        query = item
                        Haptics.select()
                    } label: {
                        Text(item)
                            .font(.system(size: 11, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.primary)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .innerTile(Radius.chip, opacity: 0.12)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("删除这个筛选", role: .destructive) {
                            saved.removeAll { $0 == item }
                            SavedFilters.save(saved)
                        }
                    }
                }
                if !query.isEmpty && !saved.contains(query) {
                    Button {
                        saved.append(query)
                        SavedFilters.save(saved)
                        Haptics.success()
                    } label: {
                        Text("+ 存下「" + query + "」")
                            .font(.system(size: 11, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .innerTile(Radius.chip, opacity: 0.08)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - 审计日志

enum AuditLog {
    private static let key = "moneymate.audit.v1"
    private static let limit = 500

    struct Entry: Codable, Identifiable, Hashable {
        var id: UUID = UUID()
        var date: Date
        var action: String
        var detail: String
    }

    static func append(_ action: String, _ detail: String) {
        var list = load()
        list.insert(Entry(date: Date(), action: action, detail: detail), at: 0)
        if list.count > limit { list = Array(list.prefix(limit)) }
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return list
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct AuditLogCard: View {
    @State private var entries = AuditLog.load()
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "操作日志", subtitle: "谁在什么时候改了什么（最近 " + String(entries.count) + " 条）") {
                showAll = true
            }
            if entries.isEmpty {
                Text("还没有记录，改一笔账就会写一条")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            } else {
                ForEach(entries.prefix(3)) { entry in
                    HStack(spacing: 8) {
                        Text(entry.action)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.primary)
                            .frame(width: 40, alignment: .leading)
                        Text(entry.detail)
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.75))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.45))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .sheet(isPresented: $showAll) {
            NavigationStack {
                List {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.action + " · " + entry.detail)
                                .font(.system(.footnote, design: .rounded))
                            Text(entry.date.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("操作日志")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("清空") {
                            AuditLog.clear()
                            entries = []
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showAll = false }
                    }
                }
            }
        }
    }
}
