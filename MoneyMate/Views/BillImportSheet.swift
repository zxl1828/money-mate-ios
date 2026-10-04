import SwiftUI
import UniformTypeIdentifiers

// MARK: - 微信 / 支付宝账单导入确认抽屉

struct BillImportSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var result: BillParseResult?
    @State private var selectedAccountID: UUID?
    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let res = result {
                        summaryCard(res)
                        accountPickerCard
                        itemsListCard(res)
                    } else {
                        emptyState
                    }
                }
                .padding(20)
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("账单 CSV 导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                if let res = result, !res.items.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确认入账") {
                            importSelected()
                        }
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundStyle(Palette.primary)
                        .disabled(selectedCount == 0)
                    }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText, .data],
                allowsMultipleSelection: false
            ) { fileRes in
                handleFileSelection(fileRes)
            }
            .onAppear {
                if selectedAccountID == nil {
                    selectedAccountID = store.activeAccounts.first?.id
                }
            }
        }
    }

    private var selectedCount: Int {
        result?.items.filter(\.isSelected).count ?? 0
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Palette.auroraPurple.opacity(0.18))
                    .frame(width: 80, height: 80)
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Palette.primary)
            }
            .padding(.top, 40)

            VStack(spacing: 6) {
                Text("导入微信 / 支付宝账单")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("支持官方导出的 CSV 流水文件，自动智能清洗去重、解析商户并匹配分类")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Palette.rose)
                    .padding(.horizontal, 16)
            }

            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("选择 CSV 账单文件")
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Palette.auroraPurple, Palette.primaryDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
                .shadow(color: Palette.neonViolet.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(GelPressButtonStyle(cornerRadius: 24))
            .padding(.top, 10)
        }
        .padding(24)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }

    // MARK: - 统计总览卡
    private func summaryCard(_ res: BillParseResult) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label(res.platform, systemImage: "checkmark.seal.fill")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.mint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Palette.mint.opacity(0.16), in: Capsule())
                Spacer()
                Button("重新选文件") {
                    showFilePicker = true
                }
                .font(.caption2)
                .foregroundStyle(Palette.primary)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("待入账笔数")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                    Text("\(selectedCount) / \(res.items.count)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("待入账支出")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                    Text(store.money(res.items.filter { $0.isSelected && $0.kind == .expense }.reduce(0) { $0 + abs($1.amount) }))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.rose)
                }
            }

            if res.duplicateCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Palette.amberGlow)
                    Text("自动识别并跳过 \(res.duplicateCount) 笔已存在重复账单")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Palette.amberGlow.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(18)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }

    // MARK: - 入账账户选择
    private var accountPickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("入账至账户")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.activeAccounts) { acc in
                        accountChip(acc)
                    }
                }
            }
        }
        .padding(16)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }

    private func accountChip(_ acc: Account) -> some View {
        let isSelected = (selectedAccountID == acc.id)
        return Button {
            selectedAccountID = acc.id
            Haptics.select()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: acc.icon)
                    .font(.system(size: 11))
                Text(acc.name)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(isSelected ? Palette.primary : Palette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Palette.primary.opacity(0.22) : Color.white.opacity(0.06),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Palette.primary : Color.clear, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }


    // MARK: - 明细列表
    private func itemsListCard(_ res: BillParseResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("账单流水明细")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Button(allSelected ? "取消全选" : "全选全部") {
                    toggleSelectAll()
                }
                .font(.caption2)
                .foregroundStyle(Palette.primary)
            }

            VStack(spacing: 6) {
                ForEach(res.items.indices, id: \.self) { idx in
                    let item = res.items[idx]
                    HStack(spacing: 12) {
                        Button {
                            toggleItem(idx)
                        } label: {
                            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(item.isSelected ? Palette.primary : Palette.textTertiary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text(item.category)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.primary)
                                Text("·")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.textTertiary)
                                Text(item.date.formatted(date: .numeric, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }

                        Spacer()

                        Text(store.money(item.amount))
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(item.kind == .expense ? Palette.rose : Palette.mint)
                    }
                    .padding(10)
                    .background(Color.white.opacity(item.isSelected ? 0.05 : 0.02), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .clearLiquidGlass(cornerRadius: Radius.card)
    }

    private var allSelected: Bool {
        guard let items = result?.items, !items.isEmpty else { return false }
        return items.allSatisfy(\.isSelected)
    }

    private func toggleSelectAll() {
        guard var res = result else { return }
        let target = !allSelected
        for i in res.items.indices {
            res.items[i].isSelected = target
        }
        result = res
        Haptics.tap()
    }

    private func toggleItem(_ idx: Int) {
        guard var res = result, idx < res.items.count else { return }
        res.items[idx].isSelected.toggle()
        result = res
        Haptics.select()
    }

    private func handleFileSelection(_ fileRes: Result<[URL], Error>) {
        switch fileRes {
        case .success(let urls):
            guard let url = urls.first else { return }
            let ok = url.startAccessingSecurityScopedResource()
            defer { if ok { url.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: url),
                  let text = BillCSVParser.decodeCSVData(data) else {
                errorMessage = "无法识别该文件编码（请上传微信或支付宝导出的 CSV 账单）"
                return
            }

            if let parsed = BillCSVParser.parse(csvText: text, existingTxs: store.txs) {
                if parsed.items.isEmpty {
                    errorMessage = "未能从文件中识别到有效交易流水"
                } else {
                    result = parsed
                    errorMessage = nil
                    Haptics.success()
                }
            } else {
                errorMessage = "不支持的账单格式，请确认是微信支付或支付宝官方导出的 CSV 文件"
            }
        case .failure(let err):
            errorMessage = "选择文件失败: \(err.localizedDescription)"
        }
    }

    private func importSelected() {
        guard let res = result else { return }
        let selected = res.items.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        for item in selected {
            let tx = Tx(
                title: item.title,
                amount: item.amount,
                category: item.category,
                date: item.date,
                merchant: item.merchant,
                note: item.note,
                kind: item.kind,
                accountID: selectedAccountID,
                updatedAt: Date()
            )
            store.add(tx)
        }

        Haptics.success()
        dismiss()
    }
}
