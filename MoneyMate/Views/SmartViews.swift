import SwiftUI

/// 隐私模式：整页模糊，点一下显示；切后台自动重新盖住
struct PrivacyWrapper<Content: View>: View {
    let content: Content

    @Environment(\.scenePhase) private var scenePhase
    @State private var revealed = false
    @ObservedObject private var privacy = PrivacyState.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if privacy.enabled && !revealed {
                ZStack {
                    content
                        .blur(radius: 16)
                        .allowsHitTesting(false)
                    VStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                        Text("隐私模式")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("点一下显示")
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.6))
                    }
                    .padding(18)
                    .glassPanel(Radius.tile, strong: true)
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { revealed = true } }
            } else {
                content
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { revealed = false }
        }
    }
}

/// 快捷模板条：点一下记一笔，长按删除
struct TemplateStrip: View {
    @ObservedObject var store: MoneyStore
    var toast: (String) -> Void = { _ in }

    @State private var templates: [TxTemplate] = SmartMemory.templates()
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "快捷模板", subtitle: templates.isEmpty ? "把每天都要记的账存成模板" : "点一下即记一笔") {
                showEditor = true
            }
            if templates.isEmpty {
                Text("例：早餐 ¥12、地铁 ¥6 —— 存成模板后一点就行")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates) { item in
                            Button {
                                apply(item)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(item.label)
                                        .font(.system(size: 12, design: .rounded).weight(.semibold))
                                }
                                .foregroundStyle(Palette.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .innerTile(Radius.chip, opacity: 0.12)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("删除模板", role: .destructive) {
                                    templates.removeAll { $0.id == item.id }
                                    SmartMemory.saveTemplates(templates)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
        .sheet(isPresented: $showEditor) {
            TemplateEditorSheet(store: store) { created in
                templates.append(created)
                SmartMemory.saveTemplates(templates)
                toast("模板已保存：" + created.name)
            }
        }
    }

    private func apply(_ item: TxTemplate) {
        let now = Date()
        var tx = Tx(title: item.name,
                    amount: item.isIncome ? abs(item.amount) : -abs(item.amount),
                    category: item.category,
                    date: now,
                    merchant: item.name,
                    note: "来自模板",
                    kind: item.isIncome ? .income : .expense,
                    accountID: store.activeAccounts.first?.id,
                    updatedAt: now,
                    memberName: store.myName)
        if tx.accountID == nil { tx.accountID = store.activeAccounts.first?.id }
        store.add(tx)
        toast("已记一笔：" + item.label)
    }
}

/// 新建模板
struct TemplateEditorSheet: View {
    @ObservedObject var store: MoneyStore
    var onSaved: (TxTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amountText = ""
    @State private var category = "餐饮"
    @State private var isIncome = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("名称").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        TextField("如：早餐", text: $name)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .innerTile(Radius.chip, opacity: 0.10)
                        Text("金额").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        TextField("12", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .innerTile(Radius.chip, opacity: 0.10)
                        Picker("类型", selection: $isIncome) {
                            Text("支出").tag(false)
                            Text("收入").tag(true)
                        }
                        .pickerStyle(.segmented)
                        Text("分类").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                        Picker("分类", selection: $category) {
                            ForEach((isIncome ? store.incomeCategories : store.expenseCategories)) { item in
                                Text(item.name).tag(item.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Palette.primary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel(Radius.card, strong: true)

                    Button {
                        let value = Double(amountText.trimmingCharacters(in: .whitespaces)) ?? 0
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, value > 0 else { return }
                        onSaved(TxTemplate(name: name.trimmingCharacters(in: .whitespaces),
                                           amount: value,
                                           category: category,
                                           isIncome: isIncome))
                        dismiss()
                    } label: {
                        Text("保存模板")
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
            .navigationTitle("新建模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
