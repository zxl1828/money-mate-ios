import SwiftUI

// MARK: - 账本状态

final class LedgerState: ObservableObject {
    static let shared = LedgerState()

    private static let activeKey = "moneymate.ledger.active"
    private static let tripKey = "moneymate.ledger.trips"

    /// 当前账本名；空串 = 全部账本
    @Published var active: String {
        didSet { UserDefaults.standard.set(active, forKey: Self.activeKey) }
    }

    /// 旅行账本的起止日期（账本名 → "yyyy-MM-dd|yyyy-MM-dd"）
    @Published var tripRanges: [String: String] {
        didSet {
            if let data = try? JSONEncoder().encode(tripRanges) {
                UserDefaults.standard.set(data, forKey: Self.tripKey)
            }
        }
    }

    static let defaultLedger = "日常"

    private init() {
        active = UserDefaults.standard.string(forKey: Self.activeKey) ?? ""
        if let data = UserDefaults.standard.data(forKey: Self.tripKey),
           let map = try? JSONDecoder().decode([String: String].self, from: data) {
            tripRanges = map
        } else {
            tripRanges = [:]
        }
    }

    var isAll: Bool { active.isEmpty }
    var displayName: String { active.isEmpty ? "全部账本" : active }
}

// MARK: - 首页/统计页顶部的账本切换条

struct LedgerBar: View {
    @ObservedObject var store: MoneyStore
    @ObservedObject private var ledger = LedgerState.shared
    @State private var showCenter = false

    private var names: [String] {
        var set = Set(store.txs.map(\.ledger))
        set.insert(LedgerState.defaultLedger)
        return set.sorted()
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button("全部账本") { switchTo("") }
                ForEach(names, id: \.self) { name in
                    Button(name + (ledger.active == name ? "  ✓" : "")) { switchTo(name) }
                }
                Divider()
                Button("管理账本…") { showCenter = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: ledger.isAll ? "books.vertical.fill" : "book.closed.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(ledger.displayName)
                        .font(.system(size: 12, design: .rounded).weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(Palette.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .innerTile(Radius.chip, opacity: 0.12)
            }
            if !ledger.isAll {
                Text("只看这个账本")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            Spacer(minLength: 0)
            Button {
                showCenter = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .padding(8)
                    .innerTile(Radius.chip, opacity: 0.10)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showCenter) {
            LedgerCenterSheet(store: store)
        }
    }

    private func switchTo(_ name: String) {
        ledger.active = name
        Haptics.select()
        store.objectWillChange.send()
    }
}

// MARK: - 账本管理

struct LedgerCenterSheet: View {
    @ObservedObject var store: MoneyStore
    @ObservedObject private var ledger = LedgerState.shared

    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var isTrip = false
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(86400 * 5)
    @State private var renameTarget: String?
    @State private var renameText = ""

    private var names: [String] {
        var set = Set(store.txs.map(\.ledger))
        set.insert(LedgerState.defaultLedger)
        return set.sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    listCard
                    createCard
                }
                .padding(20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("账本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的账本", subtitle: "共 " + String(names.count) + " 本")
            Button {
                ledger.active = ""
                store.objectWillChange.send()
            } label: {
                row(name: "全部账本",
                    detail: String(store.txs.count) + " 笔 · " + store.money(total(of: nil)),
                    selected: ledger.isAll,
                    canDelete: false)
            }
            .buttonStyle(.plain)
            ForEach(names, id: \.self) { name in
                let list = store.txs.filter { $0.ledger == name }
                HStack(spacing: 10) {
                    Button {
                        ledger.active = name
                        store.objectWillChange.send()
                    } label: {
                        row(name: name,
                            detail: String(list.count) + " 笔 · " + store.money(total(of: name)),
                            selected: ledger.active == name,
                            canDelete: false)
                    }
                    .buttonStyle(.plain)
                    if let range = ledger.tripRanges[name] {
                        Text(range.replacingOccurrences(of: "|", with: " → "))
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.45))
                    }
                    Spacer(minLength: 0)
                    Button {
                        renameTarget = name
                        renameText = name
                    } label: {
                        Image(systemName: "pencil").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.primary)
                    if name != LedgerState.defaultLedger {
                        Button {
                            mergeToDefault(name)
                        } label: {
                            Image(systemName: "arrow.triangle.merge").font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.rose)
                        .help("删除并把账目并回「日常」")
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .alert("重命名账本", isPresented: Binding(get: { renameTarget != nil },
                                              set: { if !$0 { renameTarget = nil } })) {
            TextField("新名字", text: $renameText)
            Button("取消", role: .cancel) { renameTarget = nil }
            Button("保存") { rename() }
        }
    }

    private func row(name: String, detail: String, selected: Bool, canDelete: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Palette.primary : Palette.ink.opacity(0.3))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "新建账本", subtitle: "旅行账本可记起止日期")
            TextField("账本名（如：2026 云南）", text: $newName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .innerTile(Radius.chip, opacity: 0.10)
            Toggle(isOn: $isTrip) {
                Text("这是旅行账本")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.primary)
            if isTrip {
                DatePicker("出发", selection: $start, displayedComponents: .date)
                    .font(.system(.footnote, design: .rounded))
                DatePicker("返回", selection: $end, displayedComponents: .date)
                    .font(.system(.footnote, design: .rounded))
            }
            Button {
                create()
            } label: {
                Text("创建并切换过去")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: Radius.button))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    // MARK: 操作

    private func total(of name: String?) -> Double {
        store.txs
            .filter { name == nil || $0.ledger == name }
            .filter { $0.isExpense }
            .reduce(0) { $0 - $1.amountCNY }
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if isTrip {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            var map = ledger.tripRanges
            map[name] = formatter.string(from: start) + "|" + formatter.string(from: end)
            ledger.tripRanges = map
        }
        newName = ""
        ledger.active = name
        store.objectWillChange.send()
        Haptics.success()
    }

    private func rename() {
        guard let from = renameTarget else { return }
        let to = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        renameTarget = nil
        guard !to.isEmpty, to != from else { return }
        for index in store.txs.indices where store.txs[index].ledger == from {
            store.txs[index].ledger = to
        }
        if let range = ledger.tripRanges[from] {
            var map = ledger.tripRanges
            map.removeValue(forKey: from)
            map[to] = range
            ledger.tripRanges = map
        }
        if ledger.active == from { ledger.active = to }
        store.persist()
        Haptics.success()
    }

    /// 删除账本：把账目并回「日常」
    private func mergeToDefault(_ name: String) {
        for index in store.txs.indices where store.txs[index].ledger == name {
            store.txs[index].ledger = LedgerState.defaultLedger
        }
        var map = ledger.tripRanges
        map.removeValue(forKey: name)
        ledger.tripRanges = map
        if ledger.active == name { ledger.active = "" }
        store.persist()
        Haptics.warning()
    }
}
