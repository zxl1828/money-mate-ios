import SwiftUI

/// 分类管理：新增 / 改名 / 换图标 / 隐藏 / 删除
struct CategoryManagerSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var editing: TxCategory?
    @State private var showNew = false
    @State private var hint: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    group(title: "支出分类", income: false)
                    group(title: "收入分类", income: true)
                    Button {
                        store.restoreCategories()
                        hint = "已恢复内置分类"
                    } label: {
                        Label("恢复内置分类", systemImage: "arrow.counterclockwise")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .innerTile(Radius.button, opacity: 0.10)

                    if let hint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.6))
                    }
                }
                .padding(20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showNew) {
            CategoryEditorSheet(store: store, editing: nil)
        }
        .sheet(item: $editing) { item in
            CategoryEditorSheet(store: store, editing: item)
        }
    }

    private func group(title: String, income: Bool) -> some View {
        let items = store.categories
            .filter { $0.isIncome == income }
            .sorted { $0.sortIndex < $1.sortIndex }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, subtitle: "共 " + String(items.count) + " 个")
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.primary)
                        .frame(width: 34, height: 34)
                        .background(Palette.primary.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.ink.opacity(item.hidden ? 0.45 : 0.95))
                        if item.builtin || item.hidden {
                            Text(item.builtin ? "内置" : "自定义")
                                .font(.caption2)
                                .foregroundStyle(Palette.ink.opacity(0.45))
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        store.setCategoryHidden(item, hidden: !item.hidden)
                    } label: {
                        Image(systemName: item.hidden ? "eye" : "eye.slash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.ink.opacity(0.55))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    Button {
                        editing = item
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    if !item.builtin {
                        Button {
                            store.deleteCategory(item)
                            hint = "已删除「" + item.name + "」"
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Palette.rose)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                if item.id != items.last?.id { divider }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.ink.opacity(0.06))
            .frame(height: 1)
    }
}

// MARK: - 新增 / 编辑分类

struct CategoryEditorSheet: View {
    @ObservedObject var store: MoneyStore
    var editing: TxCategory?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var isIncome = false
    @State private var error: String?

    private let icons = ["fork.knife", "tram.fill", "bag.fill", "house.fill", "gamecontroller.fill",
                         "cross.case.fill", "book.fill", "airplane", "pawprint.fill", "banknote.fill",
                         "chart.line.uptrend.xyaxis", "gift.fill", "cart.fill", "cup.and.saucer.fill",
                         "figure.walk", "phone.fill", "wifi", "bolt.fill", "tshirt.fill", "fuelpump.fill"]

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 10)]

    init(store: MoneyStore, editing: TxCategory?) {
        self.store = store
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _icon = State(initialValue: editing?.icon ?? "tag.fill")
        _isIncome = State(initialValue: editing?.isIncome ?? false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("名称").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        TextField("例如：咖啡", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(.subheadline, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .innerTile(Radius.chip, opacity: 0.10)
                        if editing == nil {
                            Picker("类型", selection: $isIncome) {
                                Text("支出").tag(false)
                                Text("收入").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(Radius.card, strong: true)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("图标").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(icons, id: \.self) { symbol in
                                Button {
                                    icon = symbol
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(icon == symbol ? .white : Palette.primary)
                                        .frame(width: 44, height: 44)
                                        .background(icon == symbol
                                                    ? AnyShapeStyle(Palette.hero)
                                                    : AnyShapeStyle(Palette.primary.opacity(0.12)),
                                                    in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(Radius.card, strong: true)

                    if let error {
                        Text(error)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Palette.rose)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: save) {
                        Text(editing == nil ? "新增分类" : "保存修改")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: Radius.button))
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle(editing == nil ? "新增分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "请填写分类名称"
            return
        }
        if var item = editing {
            item.name = trimmed
            item.icon = icon
            store.updateCategory(item)
            dismiss()
            return
        }
        guard store.addCategory(name: trimmed, icon: icon, isIncome: isIncome) else {
            error = "名称重复或为空"
            return
        }
        dismiss()
    }
}
