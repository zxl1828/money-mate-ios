import SwiftUI
import Foundation

// MARK: - OCR 结果确认（勾选 / 改金额 / 改分类 / 改日期，再批量入库）

struct OCRReviewView: View {
    @ObservedObject var store: MoneyStore
    @Binding var drafts: [DraftTx]
    var onDone: (Int) -> Void

    private var picked: [DraftTx] { drafts.filter { $0.included } }
    private var allPicked: Bool { !drafts.isEmpty && picked.count == drafts.count }

    var body: some View {
        Group {
            if drafts.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !drafts.isEmpty { bottomBar }
        }
    }

    // MARK: 列表

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                summaryCard
                ForEach($drafts) { $draft in
                    row($draft)
                }
            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            CoinBuddy(mood: picked.isEmpty ? .sleepy : .cheer, size: 62)
            VStack(alignment: .leading, spacing: 3) {
                Text("识别到 " + String(drafts.count) + " 笔")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("已选 " + String(picked.count) + " 笔 · 合计支出 " + store.money(abs(picked.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount })))
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
            Spacer(minLength: 0)
            Button(allPicked ? "取消全选" : "全选") {
                let target = !allPicked
                for index in drafts.indices { drafts[index].included = target }
            }
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .tint(Palette.primary)
        }
        .padding(16)
        .glassPanel(Radius.card, strong: true)
    }

    private func row(_ draft: Binding<DraftTx>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    draft.wrappedValue.included.toggle()
                } label: {
                    Image(systemName: draft.wrappedValue.included ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(draft.wrappedValue.included ? Palette.primary : Palette.ink.opacity(0.3))
                }
                .buttonStyle(.plain)

                TextField("名称", text: draft.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .textFieldStyle(.plain)

                Spacer(minLength: 0)

                Menu {
                    ForEach(MoneyStore.categories, id: \.self) { name in
                        Button {
                            draft.wrappedValue.category = name
                        } label: {
                            if name == draft.wrappedValue.category {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: Tx.symbol(for: draft.wrappedValue.category))
                        Text(draft.wrappedValue.category)
                    }
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .innerTile(Radius.small)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text(draft.wrappedValue.isIncome ? "+" : "-")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(draft.wrappedValue.isIncome ? Palette.mint : Palette.rose)
                    Text("\u{00A5}")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.ink.opacity(0.5))
                    TextField("0.00", text: amountText(draft))
                        .keyboardType(.decimalPad)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.ink)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 110, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .innerTile(Radius.small)

                Button {
                    draft.wrappedValue.amount = -draft.wrappedValue.amount
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.primary)
                        .padding(9)
                        .innerTile(Radius.small)
                }
                .buttonStyle(.plain)

                DatePicker("", selection: draft.date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(Palette.primary)

                Spacer(minLength: 0)

                Button {
                    let target = draft.wrappedValue.id
                    DispatchQueue.main.async { drafts.removeAll { $0.id == target } }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.rose.opacity(0.85))
                        .padding(9)
                        .innerTile(Radius.small)
                }
                .buttonStyle(.plain)
            }

            Text(draft.wrappedValue.rawLine)
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(15)
        .glassPanel(Radius.tile)
        .opacity(draft.wrappedValue.included ? 1 : 0.55)
        .animation(.spring(response: 0.24, dampingFraction: 0.92), value: draft.wrappedValue.included)
    }

    // MARK: 底部操作

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                drafts.removeAll()
                onDone(0)
            } label: {
                Text("全部不要")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .tint(Palette.ink)

            Button {
                let count = importAll()
                onDone(count)
            } label: {
                Label("导入 " + String(picked.count) + " 笔", systemImage: "tray.and.arrow.down.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.primary)
            .disabled(picked.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            BuddyHint(mood: .worried,
                      title: "没认出账单明细",
                      subtitle: "换一张更清晰的账单截图，或用「记一笔」手动录入")
            Button {
                drafts.removeAll()
                onDone(0)
            } label: {
                Text("返回重新选图")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(Palette.primary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 工具

    private func amountText(_ draft: Binding<DraftTx>) -> Binding<String> {
        Binding(
            get: {
                let value = abs(draft.wrappedValue.amount)
                return value == 0 ? "" : String(format: "%.2f", value)
            },
            set: { newValue in
                let cleaned = newValue.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "\u{00A5}", with: "")
                guard let value = Double(cleaned) else { return }


                draft.wrappedValue.amount = draft.wrappedValue.isIncome ? abs(value) : -abs(value)
            }
        )
    }

    @discardableResult
    private func importAll() -> Int {
        let items = BillParser.merge(drafts)
        for tx in items { store.add(tx) }
        return items.count
    }
}