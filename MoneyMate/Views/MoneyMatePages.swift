import SwiftUI
import Foundation

// MARK: - 统计页

struct StatsPage: View {
    @ObservedObject var store: MoneyStore
    var namespace: Namespace.ID

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("本月统计")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                summary
                weekCard
                categoryCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
    }

    private var summary: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                summaryCard(title: "收入",
                            value: store.money(store.income),
                            symbol: "arrow.down.right",
                            color: .green)
                summaryCard(title: "支出",
                            value: store.money(store.expense),
                            symbol: "arrow.up.right",
                            color: .red)
            }
        }
    }

    private func summaryCard(title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(title).font(.caption).opacity(0.65)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: 20))
        .glassEffectUnion(id: "summary", namespace: namespace)
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("近 7 日支出").font(.headline)
            BarChart(data: store.last7Days())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Color.white.opacity(0.2)),
                     in: RoundedRectangle(cornerRadius: 26))
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("支出分类").font(.headline)
            if store.categoryTotals().isEmpty {
                Text("本月还没有支出记录").font(.subheadline).opacity(0.7)
            } else {
                ForEach(store.categoryTotals(), id: \.label) { item in
                    CategoryRow(label: item.label,
                                value: item.value,
                                total: max(store.expense, 1),
                                money: store.money(item.value))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Color.white.opacity(0.2)),
                     in: RoundedRectangle(cornerRadius: 26))
    }
}

struct BarChart: View {
    let data: [(label: String, value: Double)]

    var body: some View {
        let peak = max(data.map { $0.value }.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(data.enumerated()), id: \.offset) { entry in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(LinearGradient(colors: [.white, Color(red: 0.35, green: 0.85, blue: 0.75)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(height: max(6, 110 * (entry.element.value / peak)))
                    Text(entry.element.label)
                        .font(.caption2)
                        .opacity(0.65)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 140, alignment: .bottom)
    }
}

struct CategoryRow: View {
    let label: String
    let value: Double
    let total: Double
    let money: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: Tx.symbol(for: label))
                Text(label).font(.subheadline)
                Spacer()
                Text(money).font(.subheadline.weight(.semibold)).minimumScaleFactor(0.7)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10))
                    Capsule()
                        .fill(Color(red: 0.35, green: 0.7, blue: 1.0))
                        .frame(width: max(6, proxy.size.width * min(value / total, 1)))
                }
            }
            .frame(height: 7)
        }
    }
}

// MARK: - 设置页

struct SettingsPage: View {
    @ObservedObject var store: MoneyStore
    var namespace: Namespace.ID
    var toast: (String) -> Void

    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("设置")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                prefsCard
                budgetCard
                dataCard
                aboutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog("确定清空全部账单？此操作不可撤销。",
                            isPresented: $confirmClear,
                            titleVisibility: .visible) {
            Button("清空全部", role: .destructive) {
                store.clearAll()
                toast("已清空全部账单")
            }
            Button("取消", role: .cancel) { }
        }
    }

    private var prefsCard: some View {
        VStack(spacing: 4) {
            Toggle("账单通知提醒", isOn: $store.notifyEnabled).tint(.green)
            Divider().opacity(0.4)
            Toggle("启动隐私锁", isOn: $store.privacyLock).tint(.green)
            Divider().opacity(0.4)
            Toggle("震动反馈", isOn: $store.hapticsEnabled).tint(.green)
            Divider().opacity(0.4)
            Toggle("云端同步（占位）", isOn: $store.cloudSync).tint(.green)
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Color.white.opacity(0.2)),
                     in: RoundedRectangle(cornerRadius: 26))
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("每月预算").font(.headline)
                Spacer()
                Text(store.money(store.budget)).font(.subheadline.weight(.semibold))
            }
            Slider(value: $store.budget, in: 500...80000, step: 500)
                .tint(.green)
            Text("剩余可用 " + store.money(store.budgetLeft))
                .font(.caption)
                .opacity(0.7)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Color.white.opacity(0.2)),
                     in: RoundedRectangle(cornerRadius: 26))
    }

    private var dataCard: some View {
        VStack(spacing: 12) {
            Button {
                store.restoreSamples()
                toast("已恢复示例数据")
            } label: {
                Label("恢复示例数据", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                confirmClear = true
            } label: {
                Label("清空全部账单", systemImage: "trash")
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .font(.subheadline)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Color.white.opacity(0.2)),
                     in: RoundedRectangle(cornerRadius: 26))
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关于 MoneyMate").font(.headline)
            Text("版本 1.0 · iOS 26 Liquid Glass")
            Text("共 \(store.txs.count) 笔记录（本地保存）")
            Text("OCR 识别将在后续版本接入。")
        }
        .font(.caption)
        .opacity(0.85)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: 26))
    }
}