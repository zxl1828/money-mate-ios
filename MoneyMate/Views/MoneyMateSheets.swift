import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

// MARK: - 记一笔 / 编辑

struct AddSheet: View {
    @ObservedObject var store: MoneyStore
    var editing: Tx? = nil
    /// 预填（深链 / 复记 / 剪贴板嗅探），仍然是「新增」
    var prefill: Tx? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var isIncome = false
    @State private var amountText = ""
    @State private var category = "餐饮"
    @State private var currency: Currency = .cny
    @State private var title = ""
    @State private var merchant = ""
    @State private var note = ""
    @State private var location = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var locationTouched = false
    @State private var autoLocated = false
    @State private var showMapPicker = false
    @State private var waitingForLocation = false
    @StateObject private var locator = LocationService()
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var date = Date()
    @State private var recurrence: Recurrence = .none
    @State private var errorText: String?
    @State private var accountID: UUID?
    @State private var attachments: [TxAttachment] = []
    @State private var categoryTouched = false

    init(store: MoneyStore, editing: Tx? = nil, prefill: Tx? = nil) {
        self.store = store
        self.editing = editing
        self.prefill = prefill
        let seed = editing ?? prefill
        _isIncome = State(initialValue: seed?.isIncome ?? false)
        _amountText = State(initialValue: seed.map { String(format: "%.2f", abs($0.amount)) } ?? "")
        _category = State(initialValue: seed?.category ?? "餐饮")
        _currency = State(initialValue: seed?.currency ?? .cny)
        _title = State(initialValue: seed?.title ?? "")
        _merchant = State(initialValue: seed?.merchant ?? "")
        _note = State(initialValue: seed?.note ?? "")
        _location = State(initialValue: seed?.location ?? "")
        _latitude = State(initialValue: seed?.latitude)
        _longitude = State(initialValue: seed?.longitude)
        _tags = State(initialValue: seed?.tags ?? [])
        _date = State(initialValue: seed?.date ?? Date())
        _recurrence = State(initialValue: seed?.recurrence ?? .none)
        _accountID = State(initialValue: seed?.accountID
            ?? store.activeAccounts.first(where: { $0.kind == .wallet })?.id
            ?? store.activeAccounts.first?.id)
        _attachments = State(initialValue: seed?.attachments ?? [])
    }

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    typeSegmented
                    amountCard
                    accountCard
                    categoryGrid
                    currencyCard
                    detailCard
                    receiptCard
                    locationCard
                    tagCard
                    scheduleCard
                    if let errorText {
                        Text(errorText)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Palette.rose)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    saveButton
                    if editing != nil { deleteButton }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle(editing == nil ? "记一笔" : "编辑账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showMapPicker) {
            MapPickerView(initialCoordinate: currentCoordinate, initialAddress: location) { name, lat, lon in
                locationTouched = true
                autoLocated = false
                location = name
                latitude = lat
                longitude = lon
            }
        }
        .task {
            // 没编辑过就默认用当时的定位
            guard location.isEmpty, latitude == nil else { return }
            locateNow()
        }
        .onChange(of: locator.address) { _, newValue in
            guard let coordinate = locator.coordinate, !newValue.isEmpty else { return }
            guard waitingForLocation || !locationTouched else { return }
            applyLocation(newValue, coordinate)
        }
        .onChange(of: isIncome) { _, newValue in
            let list = (newValue ? store.incomeCategories : store.expenseCategories).map(\.name)
            if !list.contains(category), let first = list.first { category = first }
        }
        .onChange(of: merchant) { _, newValue in
            guard !categoryTouched else { return }
            guard let remembered = SmartMemory.category(forMerchant: newValue) else { return }
            let list = (isIncome ? store.incomeCategories : store.expenseCategories).map(\.name)
            if list.contains(remembered), remembered != category { category = remembered }
        }
    }

    private var typeSegmented: some View {
        HStack(spacing: 8) {
            segment(title: "支出", active: !isIncome) { isIncome = false }
            segment(title: "收入", active: isIncome) { isIncome = true }
        }
    }

    private func segment(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(active ? Palette.primary : Palette.ink.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .liquidGlass(active ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isIncome ? "收入金额" : "支出金额")
                .font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(currency.symbol)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.primary)
                TextField("0.00", text: $amountText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
            }
            if currency != .cny {
                Text("1 " + currency.rawValue + " \u{2248} \u{00A5} " + String(format: "%.4f", currency.rateToCNY)
                     + " · 折合 \u{00A5} " + String(format: "%.2f", (Double(amountText) ?? 0) * currency.rateToCNY))
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(sourceCategories, id: \.self) { name in
                    Button {
                        category = name
                        categoryTouched = true
                        Haptics.select()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: store.categoryIcon(name))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(category == name ? .white : Palette.primary)
                                .frame(width: 34, height: 34)
                                .background(category == name ? AnyShapeStyle(Palette.categoryGradient(name))
                                                             : AnyShapeStyle(Palette.primary.opacity(0.12)),
                                            in: Circle())
                            Text(name)
                                .font(.system(size: 11, design: .rounded).weight(category == name ? .bold : .regular))
                                .foregroundStyle(Palette.ink.opacity(category == name ? 0.95 : 0.65))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(category == name ? .regular.tint(Palette.glassTint) : .clear,
                                 in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    /// 账户选择（信用卡会显示欠款）
    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("账户").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            if store.activeAccounts.isEmpty {
                Text("还没有账户，去「资产」页新建一个")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.55))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.activeAccounts) { account in
                            Button {
                                accountID = account.id
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: account.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(account.name)
                                        .font(.system(size: 12, design: .rounded).weight(.semibold))
                                    Text(store.money(store.balance(of: account.id)))
                                        .font(.system(size: 11, design: .rounded))
                                        .opacity(0.7)
                                }
                                .foregroundStyle(accountID == account.id ? .white : Palette.ink.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(accountID == account.id
                                            ? AnyShapeStyle(Palette.hero)
                                            : AnyShapeStyle(Palette.primary.opacity(0.10)),
                                            in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    /// 收据 / 发票附件
    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("收据 / 发票").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            AttachmentEditor(attachments: $attachments)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    /// 当前收支类型下可选的分类
    private var sourceCategories: [String] {
        let list = isIncome ? store.incomeCategories : store.expenseCategories
        let names = list.map(\.name)
        return names.isEmpty ? (isIncome ? ["工资"] : ["其他"]) : names
    }

    private var currencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("币种").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Currency.allCases) { item in
                        Button {
                            currency = item
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.symbol).font(.system(.subheadline, design: .rounded).weight(.bold))
                                Text(item.rawValue).font(.system(size: 9, design: .rounded))
                            }
                            .foregroundStyle(currency == item ? Palette.primary : Palette.ink.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .liquidGlass(currency == item ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var detailCard: some View {
        VStack(spacing: 12) {
            field(title: "名称", placeholder: "例如 午餐、地铁", text: $title)
            divider
            field(title: "商户", placeholder: "例如 星巴克", text: $merchant)
            divider
            field(title: "备注", placeholder: "记点什么", text: $note)
            divider
            HStack {
                Text("日期").font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.75))
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("地点").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                if autoLocated {
                    Text("自动定位")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Palette.primary.opacity(0.13), in: Capsule())
                }
                Spacer()
                if locator.busy { ProgressView().controlSize(.mini) }
            }

            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.primary)
                TextField("地址 / 地点名称", text: locationBinding)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .innerTile(Radius.chip, opacity: 0.10)

            if let latitude, let longitude {
                Map(initialPosition: .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                                                      distance: 700)),
                    interactionModes: []) {
                    Marker("地点", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                        .tint(Palette.primary)
                }
                .frame(height: 132)
                .clipShape(squircle(Radius.chip))
                .allowsHitTesting(false)
                .overlay(alignment: .bottomTrailing) {
                    Text(String(format: "%.5f, %.5f", latitude, longitude))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
            }

            HStack(spacing: 10) {
                locationAction(title: "使用当前定位", icon: "location.fill") { locateNow() }
                locationAction(title: "地图选点", icon: "map.fill") { showMapPicker = true }
            }

            if !locator.busy, latitude == nil, let text = locator.errorText {
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(Palette.rose)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func locationAction(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(title).font(.system(.footnote, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(Palette.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: Capsule())
    }

    private var locationBinding: Binding<String> {
        Binding(get: { location },
                set: { newValue in
                    location = newValue
                    locationTouched = true
                    autoLocated = false
                })
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        if let latitude, let longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        return locator.coordinate
    }

    /// 主动取一次定位（覆盖已有内容）
    private func locateNow() {
        locationTouched = false
        waitingForLocation = true
        locator.requestCurrent()
    }

    private func applyLocation(_ text: String, _ coordinate: CLLocationCoordinate2D) {
        location = text
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        autoLocated = true
        waitingForLocation = false
    }

    private var divider: some View {
        Rectangle().fill(Palette.ink.opacity(0.08)).frame(height: 1)
    }

    private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .frame(width: 44, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.ink)
        }
    }

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("标签").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            HStack(spacing: 8) {
                TextField("添加标签，例如 咖啡", text: $tagInput)
                    .textFieldStyle(.plain)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .innerTile(Radius.chip, opacity: 0.10)
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Palette.hero, in: Circle())
                }
                .buttonStyle(.plain)
            }
            if !tags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("#" + tag).font(.system(size: 11, design: .rounded).weight(.semibold))
                                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                }
                                .foregroundStyle(Palette.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(Palette.primary.opacity(0.13), in: Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            if !store.usedTags.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(store.usedTags.prefix(10), id: \.self) { tag in
                            Button {
                                if !tags.contains(tag) { tags.append(tag) }
                            } label: {
                                Text("#" + tag)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(Palette.ink.opacity(0.6))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(Palette.ink.opacity(0.06), in: Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("周期").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
            HStack(spacing: 8) {
                ForEach(Recurrence.allCases) { item in
                    Button {
                        recurrence = item
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.icon).font(.system(size: 13))
                            Text(item.title).font(.system(size: 11, design: .rounded).weight(.semibold))
                        }
                        .foregroundStyle(recurrence == item ? Palette.primary : Palette.ink.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .liquidGlass(recurrence == item ? .regular.tint(Palette.glassTint) : .clear, in: Capsule())
                }
            }
            if recurrence != .none {
                Text("保存后会按周期自动补录到期账单，可在「周期」里查看。")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(editing == nil ? "保存这笔账" : "保存修改")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.roundedRectangle(radius: Radius.button))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let editing { store.delete(editing) }
            dismiss()
        } label: {
            Label("删除这笔", systemImage: "trash")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.rose)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
    }

    private func addTag() {
        let value = tagInput.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, !tags.contains(value) else { tagInput = ""; return }
        tags.append(value)
        tagInput = ""
    }

    private func save() {
        let value = Double(amountText.trimmingCharacters(in: .whitespaces)) ?? 0
        guard value > 0 else {
            errorText = "请输入大于 0 的金额"
            Haptics.error()
            return
        }
        let signed = isIncome ? value : -value
        let name = title.trimmingCharacters(in: .whitespaces)
        let tx = Tx(id: editing?.id ?? UUID(),
                    title: name.isEmpty ? category : name,
                    amount: signed,
                    currency: currency,
                    rate: currency.rateToCNY,
                    category: category,
                    date: date,
                    merchant: merchant,
                    note: note,
                    tags: tags,
                    location: location,
                    latitude: latitude,
                    longitude: longitude,
                    recurrence: recurrence,
                    sourceID: editing?.sourceID,
                    autoPosted: false,
                    kind: isIncome ? .income : .expense,
                    accountID: accountID,
                    toAccountID: nil,
                    attachments: attachments,
                    updatedAt: Date(),
                    memberName: store.myName)
        if editing != nil {
            store.update(tx)
        } else {
            store.add(tx)
        }
        if recurrence != .none { store.processRecurring() }
        // 学到「商户 → 分类」，下次自动填
        let merchantKey = merchant.trimmingCharacters(in: .whitespaces)
        if !merchantKey.isEmpty {
            SmartMemory.remember(merchant: merchantKey, category: category)
        }
        Haptics.success()
        dismiss()
    }
}
// MARK: - 预算

struct BudgetSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var showCategory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    piggyCard
                    sliderCard
                    actionCard
                    breakdownCard
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showCategory) {
                CategoryBudgetSheet(store: store)
            }
        }
    }

    private var piggyCard: some View {
        VStack(spacing: 10) {
            PiggyBuddy(progress: store.budgetProgress, size: 120)
            Text(MascotMood.forBudget(store.budgetRatio).tip)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.ink.opacity(0.85))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                MetricChip(title: "剩余", value: store.money(store.budgetLeft), icon: "leaf.fill", gradient: Palette.income)
                MetricChip(title: "已用", value: store.money(store.expense), icon: "flame.fill", gradient: Palette.expense)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassPanel(Radius.card, strong: true)
    }

    private var sliderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "每月总预算", subtitle: store.money(store.budget))
            Slider(value: $store.budget, in: 500...80000, step: 500)
                .tint(Palette.primary)
            Text("预算会在每个月 1 号自动重新计算进度")
                .font(.caption2).foregroundStyle(Palette.ink.opacity(0.55))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var actionCard: some View {
        VStack(spacing: 10) {
            Button {
                let suggestion = store.budgetSuggestion()
                withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) { store.budget = suggestion }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Palette.hero, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("智能预算建议")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text("按近 30 天支出推算：" + store.money(store.budgetSuggestion()))
                            .font(.caption2).foregroundStyle(Palette.ink.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Palette.primary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))

            Button {
                showCategory = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Palette.income, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("分类预算")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text("给餐饮、购物等单独设上限")
                            .font(.caption2).foregroundStyle(Palette.ink.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Palette.primary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "本月分类消耗", subtitle: "已花 / 预算")
            let total = max(store.expense, 1)
            ForEach(store.categoryTotals().prefix(6)) { item in
                CategoryRow(item: item, total: total, budget: store.categoryBudget(item.label), money: store.money(item.value))
            }
            if store.categoryTotals().isEmpty {
                BuddyHint(mood: .happy, title: "本月还没有支出", size: 62)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }
}

// MARK: - 周期账单

struct RecurringSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    toggleCard
                    if store.recurringRules.isEmpty {
                        VStack {
                            BuddyHint(mood: .sleepy, title: "还没有周期账单", subtitle: "记账时把周期设为每周 / 每月，房租工资都会自动补录")
                                .padding(.vertical, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .glassPanel(Radius.card, strong: true)
                    } else {
                        ForEach(store.recurringRules) { rule in
                            ruleCard(rule)
                        }
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("周期账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var toggleCard: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $store.recurringEnabled) {
                Label {
                    Text("自动补录到期账单")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.9))
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Palette.primary)
                }
            }
            .tint(Palette.primary)
            Button {
                store.processRecurring()
            } label: {
                Label("立即补录", systemImage: "bolt.fill")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: Capsule())
            Text("补录的账单会标记箭头图标，可在明细里筛选。")
                .font(.caption2).foregroundStyle(Palette.ink.opacity(0.55))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private func ruleCard(_ rule: Tx) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: Tx.symbol(for: rule.category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Palette.categoryGradient(rule.category), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(rule.recurrence.title + " · " + rule.category)
                        .font(.caption2).foregroundStyle(Palette.ink.opacity(0.6))
                }
                Spacer(minLength: 0)
                Text(rule.shortAmount)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(rule.isIncome ? Palette.mint : Palette.rose)
            }
            HStack {
                Text("下次：" + nextDate(rule))
                    .font(.caption2).foregroundStyle(Palette.ink.opacity(0.65))
                Spacer()
                Button(role: .destructive) {
                    store.delete(rule)
                } label: {
                    Label("停止", systemImage: "stop.circle")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.rose)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.tile, strong: true)
    }

    private func nextDate(_ rule: Tx) -> String {
        let all = store.txs.filter { $0.id == rule.id || $0.sourceID == rule.id }
        let latest = all.map(\.date).max() ?? rule.date
        guard let next = rule.recurrence.advance(latest) else { return "不再重复" }
        return next.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - 扫描记账（苹果 Vision 离线 OCR）

struct ScanSheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var status = "选择一张微信 / 支付宝账单截图"
    @State private var working = false
    @State private var failed: String?
    @State private var drafts: [DraftTx] = []

    private var reviewing: Bool { !drafts.isEmpty || failed != nil }

    var body: some View {
        NavigationStack {
            Group {
                if reviewing {
                    OCRReviewView(store: store, drafts: $drafts, onDone: finish)
                } else {
                    picker
                }
            }
            .background(GlassBackground())
            .navigationTitle(reviewing ? "确认识别结果" : "扫描记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if reviewing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("重新选图") { reset() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: item) { _, newValue in
                guard let newValue else { return }
                recognize(newValue)
            }
        }
    }

    // MARK: 选图

    private var picker: some View {
        ScrollView {
            VStack(spacing: 16) {
                preview

                if working {
                    HStack(spacing: 10) {
                        ProgressView().tint(Palette.primary)
                        Text(status)
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(Palette.ink.opacity(0.75))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassPanel(Radius.chip, strong: true)
                    .transition(.opacity)
                } else {
                    Text(status)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Palette.ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                PhotosPicker(selection: $item, matching: .images) {
                    Label("从相册选择图片", systemImage: "photo.on.rectangle.angled")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .disabled(working)

                info
            }
            .padding(20)
            .animation(.easeOut(duration: 0.2), value: working)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        } else {
            VStack(spacing: 12) {
                CoinBuddy(mood: .cool, size: 72)
                Text("把账单截图放这里")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .glassPanel(Radius.card)
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关于 OCR").font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.ink)
            Text("识别用苹果系统自带的 Vision 引擎在本机离线完成，图片不会上传，也不需要联网。识别结果会先列出来，你说要哪几笔再入库。")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.tile)
    }

    private func reset() {
        drafts = []
        failed = nil
        image = nil
        status = "选择一张微信 / 支付宝账单截图"
    }

    private func finish(_ count: Int) {
        if count > 0 { dismiss() } else { reset() }
    }

    // MARK: 识别

    private func recognize(_ picked: PhotosPickerItem) {
        working = true
        failed = nil
        status = "正在读取图片…"
        Task { @MainActor in
            do {
                guard let data = try await picked.loadTransferable(type: Data.self),
                      let decoded = UIImage(data: data) else { throw OCRError.invalidImage }
                image = decoded
                status = "正在识别文字…"
                let lines = try await OCRService.recognize(image: decoded)
                status = "正在整理账单…"
                let parsed = await Task.detached(priority: .userInitiated) { BillParser.parse(lines) }.value
                drafts = parsed
                if parsed.isEmpty {
                    failed = "这张图里没找到账单明细，换一张更清晰的截图试试"
                }
            } catch {
                failed = (error as? LocalizedError)?.errorDescription ?? "识别失败，请再试一次"
            }
            working = false
            item = nil
        }
    }
}
// MARK: - 消息中心

struct NotifyItem: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let icon: String
    let tint: Color
}

struct NotifySheet: View {
    @ObservedObject var store: MoneyStore
    @Environment(\.dismiss) private var dismiss

    private var items: [NotifyItem] {
        var list: [NotifyItem] = []
        if store.budgetRatio >= 1 {
            list.append(NotifyItem(title: "预算已超支",
                                   body: "本月已花 " + store.money(store.expense) + "，超出预算 " + store.money(store.expense - store.budget),
                                   icon: "exclamationmark.triangle.fill",
                                   tint: Palette.rose))
        } else if store.budgetRatio >= 0.8 {
            list.append(NotifyItem(title: "预算预警",
                                   body: "预算已用 " + String(Int(store.budgetRatio * 100)) + "%，还剩 " + store.money(store.budgetLeft),
                                   icon: "exclamationmark.circle.fill",
                                   tint: Palette.rose))
        } else {
            list.append(NotifyItem(title: "预算状态良好",
                                   body: "已用 " + String(Int(store.budgetRatio * 100)) + "%，剩余 " + store.money(store.budgetLeft),
                                   icon: "checkmark.seal.fill",
                                   tint: Palette.mint))
        }
        list.append(NotifyItem(title: "今日支出",
                               body: store.todayTxs.isEmpty ? "今天还没有记账，睡前记一笔吧" : "今天记了 " + String(store.todayTxs.count) + " 笔，支出 " + store.money(store.todayTxs.filter { !$0.isIncome }.reduce(0) { $0 - $1.amountCNY }),
                               icon: "bell.badge.fill",
                               tint: Palette.primary))
        if !store.recurringRules.isEmpty {
            list.append(NotifyItem(title: "周期账单",
                                   body: "有 " + String(store.recurringRules.count) + " 条周期账单会自动补录",
                                   icon: "arrow.triangle.2.circlepath",
                                   tint: Palette.primarySoft))
        }
        list.append(NotifyItem(title: "记账小提示",
                               body: "每天睡前记一笔，账目更清楚",
                               icon: "sparkles",
                               tint: Palette.primary))
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Toggle(isOn: $store.notifyEnabled) {
                        Label {
                            Text("开启记账提醒")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Palette.ink.opacity(0.9))
                        } icon: {
                            Image(systemName: "bell.fill").foregroundStyle(Palette.primary)
                        }
                    }
                    .tint(Palette.primary)
                    .padding(16)
                    .glassPanel(Radius.tile, strong: true)

                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(LinearGradient(colors: [item.tint, item.tint.opacity(0.65)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                                            in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(Palette.ink)
                                Text(item.body)
                                    .font(.caption)
                                    .foregroundStyle(Palette.ink.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassPanel(Radius.tile)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
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

// MARK: - 账单详情

struct DetailSheet: View {
    @ObservedObject var store: MoneyStore
    let tx: Tx
    var onEdit: (Tx) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headCard
                    infoCard
                    receiptCard
                    mapCard
                    actionRow
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(GlassBackground())
            .navigationTitle("账单详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var headCard: some View {
        VStack(spacing: 10) {
            Image(systemName: tx.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Palette.categoryGradient(tx.category), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            Text(tx.title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Palette.ink)
            Text(tx.displayAmount)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(tx.isIncome ? Palette.mint : Palette.rose)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if !tx.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tx.tags, id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassPanel(Radius.card, strong: true)
    }

    /// 所属账户 / 转账双方
    private var accountLine: String {
        if tx.kind == .transfer {
            return store.accountName(tx.accountID) + " \u{2192} " + store.accountName(tx.toAccountID)
        }
        return store.accountName(tx.accountID)
    }

    @ViewBuilder
    private var receiptCard: some View {
        if !tx.attachments.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("收据 / 发票").font(.caption).foregroundStyle(Palette.ink.opacity(0.6))
                AttachmentGallery(attachments: tx.attachments)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel(Radius.card, strong: true)
        }
    }

    @ViewBuilder
    private var mapCard: some View {
        if let coordinate = tx.coordinate {
            Map(initialPosition: .camera(MapCamera(centerCoordinate: coordinate, distance: 700)),
                interactionModes: [.pan, .zoom]) {
                Marker(tx.location.isEmpty ? "记账地点" : tx.location, coordinate: coordinate)
                    .tint(Palette.primary)
            }
            .frame(height: 196)
            .clipShape(squircle(Radius.card))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    let name = tx.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(name)") {
                        openURL(url)
                    }
                } label: {
                    Label("在地图中打开", systemImage: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Palette.ink.opacity(0.06), lineWidth: 1)
            }
        }
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            row(label: "分类", value: tx.category)
            divider
            row(label: "账户", value: accountLine)
            divider
            row(label: "时间", value: tx.date.formatted(date: .abbreviated, time: .shortened))
            if !tx.merchant.isEmpty {
                divider
                row(label: "商户", value: tx.merchant)
            }
            if !tx.location.isEmpty {
                divider
                row(label: "地点", value: tx.location)
            }
            if !tx.note.isEmpty {
                divider
                row(label: "备注", value: tx.note)
            }
            divider
            row(label: "币种", value: tx.currency.rawValue + " · 1 " + tx.currency.rawValue + " \u{2248} \u{00A5} " + String(format: "%.4f", tx.rate))
            if tx.currency != .cny {
                divider
                row(label: "折合", value: store.money(abs(tx.amountCNY)))
            }
            if tx.recurrence != .none {
                divider
                row(label: "周期", value: tx.recurrence.title)
            }
            if tx.autoPosted {
                divider
                row(label: "来源", value: "周期账单自动补录")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(Radius.card, strong: true)
    }

    private var divider: some View {
        Rectangle().fill(Palette.ink.opacity(0.08)).frame(height: 1)
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.ink.opacity(0.6))
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            Button {
                let target = tx
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onEdit(target)
                }
            } label: {
                Label("编辑这笔", systemImage: "square.and.pencil")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))

            Button(role: .destructive) {
                store.deleteWithUndo(tx)
                Haptics.warning()
                dismiss()
            } label: {
                Label("删除这笔", systemImage: "trash")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.rose)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))

            Button {
                let copy = store.duplicateAsNew(tx)
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onEdit(copy)
                }
            } label: {
                Label("再记一笔（复记）", systemImage: "arrow.clockwise")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
    }
}
