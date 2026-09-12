import SwiftUI
import Foundation

// MARK: - 液态玻璃工具
// 部署目标 iOS 26.0，只使用 Apple 官方 SwiftUI API：
//   glassEffect(_:in:) / GlassEffectContainer / glassEffectID(_:in:) / glassEffectUnion(id:namespace:)
extension View {
    /// 统一入口：把液态玻璃材质应用到任意形状。
    func liquidGlass(_ glass: Glass, in shape: some Shape) -> some View {
        glassEffect(glass, in: shape)
    }
}

// MARK: - 标签

enum MoneyTab: Int, CaseIterable, Identifiable {
    case home = 0
    case stats
    case settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .stats: return "统计"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .stats: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// 首页按钮对应的真实动作。
struct HomeActions {
    var add: () -> Void
    var scan: () -> Void
    var budget: () -> Void
    var notify: () -> Void
    var open: (Tx) -> Void
}

// MARK: - 根视图

struct ContentView: View {
    @StateObject private var store = MoneyStore()
    @State private var tab: MoneyTab = .home
    @Namespace private var glassNS

    @State private var showAdd = false
    @State private var showScan = false
    @State private var showBudget = false
    @State private var showNotify = false
    @State private var detail: Tx?
    @State private var toast: String?

    var body: some View {
        ZStack {
            GlassBackground()
            page
            floatingLayer
            toastLayer
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: tab)
        .sheet(isPresented: $showAdd) { AddSheet(store: store) }
        .sheet(isPresented: $showScan) { ScanSheet() }
        .sheet(isPresented: $showBudget) { BudgetSheet(store: store) }
        .sheet(isPresented: $showNotify) { NotifySheet(store: store) }
        .sheet(item: $detail) { tx in DetailSheet(store: store, tx: tx) }
    }

    @ViewBuilder
    private var page: some View {
        switch tab {
        case .home:
            HomePage(store: store, namespace: glassNS, actions: homeActions)
        case .stats:
            StatsPage(store: store, namespace: glassNS)
        case .settings:
            SettingsPage(store: store, namespace: glassNS, toast: { push($0) })
        }
    }

    private var homeActions: HomeActions {
        HomeActions(add: { showAdd = true },
                    scan: { showScan = true },
                    budget: { showBudget = true },
                    notify: { showNotify = true },
                    open: { detail = $0 })
    }

    /// 轻提示
    private func push(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let text = toast {
            VStack {
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .liquidGlass(.regular.tint(Color.white.opacity(0.35)), in: Capsule())
                    .padding(.top, 10)
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: 悬浮层

    private var floatingLayer: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                Spacer()
                addButton
            }
            .padding(.trailing, 22)
            .padding(.bottom, 12)
            tabBar
        }
    }

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .frame(width: 58, height: 58)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
    }

    private var tabBar: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(MoneyTab.allCases) { item in
                    TabItem(tab: item, isSelected: tab == item, namespace: glassNS) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            tab = item
                        }
                    }
                }
            }
            .padding(6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - 首页

struct HomePage: View {
    @ObservedObject var store: MoneyStore
    var namespace: Namespace.ID
    var actions: HomeActions

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                balanceCard
                quickActions
                todayList
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 顶部

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("本月账单").font(.title2.weight(.semibold))
                Text("Hi，今天也要省着点").font(.subheadline).opacity(0.7)
            }
            Spacer()
            Button(action: actions.notify) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: Circle())
        }
    }

    // MARK: 余额卡

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("本月结余").font(.headline)
                Spacer()
                Text("人民币").font(.caption).opacity(0.6)
            }
            Text(store.money(store.balance))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
            budgetBar
            balanceStats
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Color.white.opacity(0.25)),
                     in: RoundedRectangle(cornerRadius: 28))
    }

    private var budgetBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("预算已用 \(Int(store.budgetProgress * 100))%").font(.caption).opacity(0.75)
                Spacer()
                Text("预算 " + store.money(store.budget)).font(.caption).opacity(0.75)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [.white, Color(red: 0.35, green: 0.85, blue: 0.75)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, proxy.size.width * store.budgetProgress))
                }
            }
            .frame(height: 8)
        }
    }

    private var balanceStats: some View {
        HStack(spacing: 8) {
            statChip(label: "收入", value: store.money(store.income), symbol: "arrow.down.right", color: .green)
            statChip(label: "支出", value: store.money(store.expense), symbol: "arrow.up.right", color: .red)
        }
    }

    private func statChip(label: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).opacity(0.6)
                Text(value).font(.subheadline.weight(.semibold)).minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 快捷操作

    private var quickActions: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                quickAction(title: "记账", symbol: "plus", color: .blue, action: actions.add)
                quickAction(title: "扫描", symbol: "camera.viewfinder", color: .orange, action: actions.scan)
                quickAction(title: "预算", symbol: "target", color: .green, action: actions.budget)
            }
        }
    }

    private func quickAction(title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 20))
        .glassEffectUnion(id: "quickActions", namespace: namespace)
    }

    // MARK: 今日明细

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日明细").font(.title3.weight(.semibold))
                Spacer()
                Text("\(store.todayTxs.count) 笔").font(.caption).opacity(0.6)
            }
            if store.todayTxs.isEmpty {
                Text("今天还没有记账，点右下角 + 试试")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: 18))
            } else {
                GlassEffectContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        ForEach(store.todayTxs) { tx in
                            TxRow(tx: tx, namespace: namespace) { actions.open(tx) }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 明细行

struct TxRow: View {
    let tx: Tx
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: tx.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.08), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(tx.title).font(.body.weight(.medium))
                    Text(tx.category).font(.caption).opacity(0.6)
                }
                Spacer()
                Text(amountText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tx.isIncome ? Color.green : Color.red)
            }
            .padding(14)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 18))
        .glassEffectID(tx.id, in: namespace)
        .glassEffectUnion(id: "todayList", namespace: namespace)
    }

    private var amountText: String {
        let text = String(format: "%.2f", abs(tx.amount))
        return (tx.amount >= 0 ? "+ " : "- ") + "\u{00A5} " + text
    }
}

// MARK: - 标签栏按钮

struct TabItem: View {
    let tab: MoneyTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                Text(tab.title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .liquidGlass(glass, in: Capsule())
        .glassEffectID(glassID, in: namespace)
        .glassEffectUnion(id: "tabBar", namespace: namespace)
    }

    private var glass: Glass {
        isSelected ? .regular.interactive() : .clear.interactive()
    }

    private var glassID: String {
        isSelected ? "tab-selected-\(tab.id)" : "tab-\(tab.id)"
    }
}