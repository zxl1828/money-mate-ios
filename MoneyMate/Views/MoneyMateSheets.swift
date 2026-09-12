import SwiftUI
import UIKit
import PhotosUI
import Foundation

// MARK: - 新增一笔（记账按钮 / 右下角 +）

struct AddSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amountText = ""
    @State private var isIncome = false
    @State private var category = "餐饮"

    var body: some View {
        NavigationStack {
            Form {
                Section("类型") {
                    Picker("类型", selection: typeBinding) {
                        Text("支出").tag(0)
                        Text("收入").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                Section("内容") {
                    TextField("名称，例如 星巴克", text: $title)
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("分类", selection: $category) {
                        ForEach(Tx.categories, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
            }
            .navigationTitle("新增一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!canSave)
                }
            }

        }
    }

    private var typeBinding: Binding<Int> {
        Binding(get: { isIncome ? 1 : 0 }, set: { isIncome = ($0 == 1) })
    }

    private var amountValue: Double {
        Double(amountText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var canSave: Bool { amountValue > 0 }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? category : trimmed
        let value = isIncome ? amountValue : -amountValue
        store.add(Tx(title: name, amount: value, category: category))
        dismiss()
    }
}

// MARK: - 预算

struct BudgetSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Text(store.money(store.budget))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Slider(value: $store.budget, in: 500...80000, step: 500)
                    .tint(.green)
                    .padding(.horizontal, 24)
                Text("本月已支出 " + store.money(store.expense) + "，剩余 " + store.money(store.budgetLeft))
                    .font(.subheadline)
                    .opacity(0.7)
                Spacer()
            }
            .padding(.top, 28)
            .navigationTitle("每月预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 扫描 / OCR 占位

struct ScanSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var status = "选择一张小票或账单截图"

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                preview
                PhotosPicker(selection: $item, matching: .images) {
                    Label("从相册选择图片", systemImage: "photo.on.rectangle.angled")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .liquidGlass(.regular.interactive(), in: Capsule())
                }
                Text(status).font(.footnote).opacity(0.75)
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("扫描记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onChange(of: item) { _, newValue in
            load(newValue)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 20)
        } else {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.06))
                .frame(height: 220)
                .overlay {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 44))
                        .opacity(0.5)
                }
                .padding(.horizontal, 20)
        }
    }

    private func load(_ picked: PhotosPickerItem?) {
        guard let picked else { return }
        status = "图片已载入，OCR 将在后续版本接入"
        Task { @MainActor in
            if let data = try? await picked.loadTransferable(type: Data.self),
               let decoded = UIImage(data: data) {
                image = decoded
            } else {
                status = "图片读取失败，请换一张试试"
            }
        }
    }
}

// MARK: - 通知中心

struct NotifyItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let icon: String
}

struct NotifySheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    private let items: [NotifyItem] = [
        NotifyItem(title: "今日支出提醒", body: "今天又花了一笔，记得看看预算", icon: "bell.badge.fill"),
        NotifyItem(title: "预算预警", body: "本月预算已用掉一部分，注意控制", icon: "exclamationmark.triangle.fill"),
        NotifyItem(title: "记账小提示", body: "每天睡前记一笔，账目更清楚", icon: "sparkles")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("开启提醒", isOn: $store.notifyEnabled).tint(.green)
                }
                Section("最近消息") {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.icon).foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.subheadline.weight(.semibold))
                                Text(item.body).font(.caption).opacity(0.7)
                            }
                        }
                    }
                }
            }
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 明细详情 / 删除

struct DetailSheet: View {
    @ObservedObject var store: MoneyStore
    let tx: Tx

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("名称", value: tx.title)
                LabeledContent("金额", value: store.money(tx.amount))
                LabeledContent("分类", value: tx.category)
                LabeledContent("时间", value: tx.date.formatted(date: .abbreviated, time: .shortened))
                Button(role: .destructive) {
                    store.delete(tx)
                    dismiss()
                } label: {
                    Label("删除这笔", systemImage: "trash")
                }
            }
            .navigationTitle("账单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}