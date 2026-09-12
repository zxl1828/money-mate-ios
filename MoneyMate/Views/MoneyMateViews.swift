import SwiftUI

// MARK: - Liquid Glass 工具
// 部署目标 iOS 26.0，只使用 Apple 官方 SwiftUI API：
//   glassEffect(_:in:) / GlassEffectContainer / glassEffectID(_:in:) / glassEffectUnion(id:namespace:)

extension View {
    /// 统一入口：把液态玻璃材质应用到任意形状。
    func liquidGlass(_ glass: Glass, in shape: some Shape) -> some View {
        glassEffect(glass, in: shape)
    }
}

// MARK: - 数据

private struct MoneyTx: Identifiable {
    let id = UUID()
    let title: String
    let amount: String
    let symbol: String
    let income: Bool
}

private enum MoneyTab: Int, CaseIterable, Identifiable {
    case home = 0
    case chart
    case settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .chart: return "统计"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .chart: return "chart.pie.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - 根视图

struct ContentView: View {
    @State private var selection: Int = 0
    @Namespace private var glassNS

    private let today: [MoneyTx] = [
        MoneyTx(title: "星巴克", amount: "-32.00", symbol: "cup.and.saucer.fill", income: false),
        MoneyTx(title: "早餐", amount: "-15.00", symbol: "fork.knife", income: false),
        MoneyTx(title: "工资", amount: "+12,000.00", symbol: "banknote.fill", income: true)
    ]

    var body: some View {
        ZStack {
            GlassBackground()
            scrollingContent
            floatingLayer
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: selection)
    }

    // MARK: 滚动内容

    private var scrollingContent: some View {
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

    // MARK: 顶部

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("8月账单").font(.title2.weight(.semibold))
                Text("Hi，今天也要省着点").font(.subheadline).opacity(0.7)
            }
            Spacer()
            bellButton
        }
    }

    private var bellButton: some View {
        Button {
        } label: {
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: Circle())
    }

    // MARK: 余额卡

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            balanceTitle
            Text("\u{00A5} 128,640.00")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
            balanceStats
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(
            .regular.tint(Color.white.opacity(0.25)),
            in: RoundedRectangle(cornerRadius: 28)
        )
    }

    private var balanceTitle: some View {
        HStack {
            Text("本月余额").font(.headline)
            Spacer()
            Text("人民币").font(.caption).opacity(0.6)
        }
    }

    private var balanceStats: some View {
        HStack(spacing: 8) {
            statChip(label: "收入", value: "\u{00A5} 45,000", symbol: "arrow.down.right", color: .green)
            statChip(label: "支出", value: "\u{00A5} 12,330", symbol: "arrow.up.right", color: .red)
        }
    }

    private func statChip(label: String, value: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).opacity(0.6)
                Text(value).font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 快捷操作（同一 union id -> 融合为连续玻璃表面）

    private var quickActions: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                quickAction(title: "记账", symbol: "plus", color: .blue)
                quickAction(title: "扫描", symbol: "camera.viewfinder", color: .orange)
                quickAction(title: "预算", symbol: "target", color: .green)
            }
        }
    }

    private func quickAction(title: String, symbol: String, color: Color) -> some View {
        Button {
        } label: {
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
        .glassEffectUnion(id: "quickActions", namespace: glassNS)
    }

    // MARK: 今日明细（相邻玻璃自动融合）

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日明细").font(.title3.weight(.semibold))
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(today) { tx in
                        TxRow(tx: tx, namespace: glassNS)
                    }
                }
            }
        }
    }

    // MARK: 底部

    private var tabBar: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(MoneyTab.allCases) { tab in
                    TabItem(tab: tab, isSelected: selection == tab.id, namespace: glassNS) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            selection = tab.id
                        }
                    }
                }
            }
            .padding(6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var addButton: some View {
        Button {
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .frame(width: 58, height: 58)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
    }
}

// MARK: - 明细行

private struct TxRow: View {
    let tx: MoneyTx
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 12) {
            icon
            Text(tx.title).font(.body.weight(.medium))
            Spacer()
            amount
        }
        .padding(14)
        .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: 18))
        .glassEffectID(tx.id, in: namespace)
        .glassEffectUnion(id: "todayList", namespace: namespace)
    }

    private var icon: some View {
        Image(systemName: tx.symbol)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 40, height: 40)
            .background(Color.black.opacity(0.08), in: Circle())
    }

    private var amount: some View {
        Text(tx.amount)
            .font(.callout.weight(.semibold))
            .foregroundStyle(tx.income ? Color.green : Color.red)
    }
}

// MARK: - 标签栏按钮

private struct TabItem: View {
    let tab: MoneyTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
        .liquidGlass(glass, in: Capsule())
        .glassEffectID(glassID, in: namespace)
        .glassEffectUnion(id: "tabBar", namespace: namespace)
    }

    private var label: some View {
        VStack(spacing: 4) {
            Image(systemName: tab.systemImage)
            Text(tab.title).font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var glass: Glass {
        isSelected ? .regular.interactive() : .clear.interactive()
    }

    private var glassID: String {
        isSelected ? "tab-selected-\(tab.id)" : "tab-\(tab.id)"
    }
}