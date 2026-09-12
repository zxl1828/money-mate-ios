import SwiftUI

// MARK: - Liquid Glass helpers

extension View {
    /// iOS 26 原生玻璃；在更低系统上回退为毛玻璃材质。
    @ViewBuilder
    func liquidGlass<S: Shape>(_ glass: Glass, in shape: S) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(glass, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Data

private struct MoneyTx: Identifiable {
    let id = UUID()
    let title: String
    let amount: String
    let symbol: String
    let income: Bool
}

private enum MoneyTab: Int, CaseIterable, Identifiable {
    case home = 0, chart, settings
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: "首页"
        case .chart: "统计"
        case .settings: "设置"
        }
    }
    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .chart: "chart.pie.fill"
        case .settings: "gearshape.fill"
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @State private var selection = 0
    @Namespace private var glassNS

    private let today = [
        MoneyTx(title: "星巴克", amount: "-32.00", symbol: "cup.and.saucer.fill", income: false),
        MoneyTx(title: "早餐", amount: "-15.00", symbol: "fork.knife", income: false),
        MoneyTx(title: "工资", amount: "+12,000.00", symbol: "banknote.fill", income: true)
    ]

    var body: some View {
        ZStack {
            GlassBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    balanceCard
                    quickActions
                    todayList
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            glassTabBar
            addButton
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("8月账单").font(.title2.weight(.semibold))
                Text("Hi, 今天也要省着点").font(.subheadline).opacity(0.7)
            }
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .padding(12)
                .liquidGlass(.clear.interactive(), in: .circle)
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("本月余额").font(.headline)
                Spacer()
                Text("·人民币").font(.caption).opacity(0.6)
            }
            Text("¥ 128,640.00")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
            HStack(spacing: 8) {
                smallStat("收入", "¥ 45,000", "arrow.down.right", Color.green)
                smallStat("支出", "¥ 12,330", "arrow.up.right", Color.red)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Color.white.opacity(0.2)), in: .rect(cornerRadius: 28))
    }

    private func smallStat(_ label: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
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

    private var quickActions: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                quickAction("记账", "plus", .blue)
                quickAction("扫描", "camera.viewfinder", .orange)
                quickAction("预算", "target", .green)
            }
        }
    }

    private func quickAction(_ title: String, _ symbol: String, _ color: Color) -> some View {
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
        .liquidGlass(.clear.interactive(), in: .rect(cornerRadius: 20))
        .glassEffectUnion(id: "quick", namespace: glassNS)
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日明细").font(.title3.weight(.semibold))
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(today) { tx in
                        let row = HStack(spacing: 12) {
                            Image(systemName: tx.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.08), in: Circle())
                            Text(tx.title).font(.body.weight(.medium))
                            Spacer()
                            Text(tx.amount)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(tx.income ? Color.green : Color.red)
                        }
                        .padding(14)
                        .liquidGlass(.clear, in: .rect(cornerRadius: 18))
                        .glassEffectID("tx-\(tx.id.uuidString)", in: glassNS)
                        row
                    }
                }
            }
        }
    }

    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.glassProminent)
                .padding(.bottom, 16)
                .padding(.trailing, 20)
            }
        }
    }

    private var glassTabBar: some View {
        VStack {
            Spacer()
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(MoneyTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                selection = tab.id
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab.systemImage)
                                Text(tab.title).font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .liquidGlass(
                            selection == tab.id
                                ? .regular.interactive()
                                : .clear.interactive(),
                            in: .capsule
                        )
                        .glassEffectID(
                            selection == tab.id ? "tab-on-\(tab.id)" : "tab-off-\(tab.id)",
                            in: glassNS
                        )
                        .glassEffectUnion(id: "tabbar", namespace: glassNS)
                    }
                }
                .padding(6)
            }
            .padding(.horizontal, 16)
        }
    }
}
