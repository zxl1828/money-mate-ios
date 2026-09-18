import SwiftUI
import Foundation
import LocalAuthentication

// MARK: - 液态玻璃工具
// 部署目标 iOS 26.0，只使用 Apple 官方 SwiftUI API：
//   glassEffect(_:in:) / GlassEffectContainer / glassEffectID(_:in:) / glassEffectUnion(id:namespace:)
extension View {
    func liquidGlass(_ glass: Glass, in shape: some Shape) -> some View {
        glassEffect(glass, in: shape)
    }
}

// MARK: - 生物识别

enum Biometrics {
    @MainActor
    static func authenticate(reason: String = "解锁 MoneyMate 账本") async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return true   // 设备不支持生物识别时直接放行
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

// MARK: - 标签

enum MoneyTab: Int, CaseIterable, Identifiable {
    case home = 0, list, assets, stats, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .list: return "明细"
        case .assets: return "资产"
        case .stats: return "统计"
        case .settings: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .list: return "list.bullet.rectangle.fill"
        case .assets: return "banknote.fill"
        case .stats: return "chart.bar.xaxis"
        case .settings: return "person.crop.circle.fill"
        }
    }
}

/// 首页按钮对应的真实动作
struct HomeActions {
    var add: () -> Void
    var scan: () -> Void
    var budget: () -> Void
    var notify: () -> Void
    var recurring: () -> Void
    var open: (Tx) -> Void
    var openList: () -> Void
}

// MARK: - 根视图

struct ContentView: View {
    @StateObject private var store = MoneyStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: MoneyTab = .home
    @State private var forward = true
    @Namespace private var glassNS

    @State private var showAdd = false
    @State private var showScan = false
    @State private var showBudget = false
    @State private var showNotify = false
    @State private var showRecurring = false
    @State private var editing: Tx?
    @State private var detail: Tx?
    @State private var toast: String?

    @State private var locked = false
    @State private var deepLinkPrefill: Tx?

    var body: some View {
        PrivacyWrapper {
            ZStack {
                GlassBackground()
                pageArea
                floatingLayer
                toastLayer
                if locked {
                    LockScreen {
                        Task { await unlock() }
                    }
                    .transition(.opacity)
                }
            }
        }
        .fontDesign(.rounded)
        .tint(Palette.primary)
        .animation(.spring(response: 0.22, dampingFraction: 0.93), value: tab)
        .animation(.easeInOut(duration: 0.25), value: locked)
        .sheet(isPresented: $showAdd) { AddSheet(store: store) }
        .sheet(item: $editing) { tx in AddSheet(store: store, editing: tx) }
        .sheet(item: $deepLinkPrefill) { tx in AddSheet(store: store, prefill: tx) }
        .sheet(isPresented: $showScan) { ScanSheet(store: store) }
        .sheet(isPresented: $showBudget) { BudgetSheet(store: store) }
        .sheet(isPresented: $showNotify) { NotifySheet(store: store) }
        .sheet(isPresented: $showRecurring) { RecurringSheet(store: store) }
        .sheet(item: $detail) { tx in
            DetailSheet(store: store, tx: tx, onEdit: { editing = $0 }, onToast: { push($0) })
        }
        .preferredColorScheme(colorScheme)
        .overlay(alignment: .bottom) {
            if store.hasUndoableDelete {
                Button {
                    if store.undoDelete() { push("已恢复这笔记账") }
                } label: {
                    Label("已删除 · 点此撤销", systemImage: "arrow.uturn.backward")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .glassPanel(Radius.chip, strong: true)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 112)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: store.hasUndoableDelete)
        .task { await bootstrap() }
        .onOpenURL { url in handle(url) }
        .onReceive(NotificationCenter.default.publisher(for: .moneyMateRemoteChanged)) { _ in
            push("iCloud 上有新账本，可在「我的」里恢复")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await bootstrap() }
                if locked { Task { await unlock() } }
            }
            if phase == .background && store.privacyLock { locked = true }
        }
    }

    /// 深色 / 浅色 / 跟随系统
    private var colorScheme: ColorScheme? {
        switch store.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// 深链：moneymate://add?amount=32&merchant=星巴克&category=餐饮&note=xxx
    private func handle(_ url: URL) {
        guard url.scheme == "moneymate" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? {
            items.first { $0.name == key }?.value
        }
        let merchantName = value("merchant") ?? ""
        guard let amountText = value("amount"), let amount = Double(amountText), amount > 0 else {
            showAdd = true
            return
        }
        let category = value("category")
            ?? SmartMemory.category(forMerchant: merchantName)
            ?? "其他"
        deepLinkPrefill = Tx(title: merchantName.isEmpty ? "快捷记账" : merchantName,
                             amount: -abs(amount),
                             category: category,
                             date: Date(),
                             merchant: merchantName,
                             note: value("note") ?? "",
                             kind: .expense,
                             accountID: store.activeAccounts.first?.id,
                             updatedAt: Date(),
                             memberName: store.myName)
    }

    /// 启动与回前台：解锁、合并快捷指令记账、重建本地提醒
    @MainActor
    private func bootstrap() async {
        await unlock()
        let merged = store.consumePendingQuickItems()
        if merged > 0 { push("已从快捷指令记下 \(merged) 笔") }
        NotificationService.shared.reschedule(store: store)
    }

    @MainActor
    private func unlock() async {
        guard store.privacyLock else { locked = false; return }
        locked = true
        let ok = await Biometrics.authenticate()
        if ok {
            Haptics.success()
            withAnimation(.easeInOut(duration: 0.25)) { locked = false }
        }
        if !ok {
            Haptics.error()
            push("已取消解锁")
        }
    }

    // MARK: 页面

    private var pageArea: some View {
        page
            .id(tab)
            .transition(pageTransition)
    }

    /// 左右切屏：方向跟着标签顺序走，弹簧收紧到 0.22s，出手更利落
    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    private func select(_ item: MoneyTab) {
        guard item != tab else { return }
        Haptics.tap()
        forward = item.rawValue > tab.rawValue
        withAnimation(.spring(response: 0.22, dampingFraction: 0.93)) { tab = item }
    }

    @ViewBuilder
    private var page: some View {
        switch tab {
        case .home:
            HomePage(store: store, namespace: glassNS, actions: homeActions)
        case .list:
            TransactionsPage(store: store, namespace: glassNS, onOpen: { detail = $0 })
        case .assets:
            NetWorthPage(store: store)
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
                    recurring: { showRecurring = true },
                    open: { detail = $0 },
                    openList: { select(.list) })
    }

    // MARK: 轻提示

    private func push(_ text: String) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.92)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeOut(duration: 0.18)) { toast = nil }
        }
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let text = toast {
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle").font(.caption)
                    Text(text).font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .glassPanel(Radius.chip, strong: true)
                .padding(.top, 8)
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
                        select(item)
                    }
                }
            }
            .padding(6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - 锁屏

struct LockScreen: View {
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                CoinBuddy(mood: .cool, size: 96)
                Text("MoneyMate 已锁定")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text("用面容 / 指纹解锁你的账本")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.6))
                Button {
                    onUnlock()
                } label: {
                    Label("解锁", systemImage: "faceid")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
            }
            .padding(28)
        }
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
                heroCard
                quickActions
                TemplateStrip(store: store)
                trendCard
                todayList
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 220)
        }
        .scrollIndicators(.hidden)
    }

    private var mood: MascotMood {
        MascotMood.forBudget(store.budgetRatio)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CoinBuddy(mood: mood, size: 40)
                .frame(width: 62, height: 62)
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                Text(mood.tip)
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: actions.notify) {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.primary)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .liquidGlass(.clear.interactive(), in: Circle())
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "夜深了，还在记账？" }
        if hour < 11 { return "早上好，今天也要省钱" }
        if hour < 14 { return "中午好，记得记一笔" }
        if hour < 18 { return "下午好，账本很清楚" }
        return "晚上好，看看今天花了啥"
    }

    // MARK: 结余主卡

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroTop
            heroAmount
            heroBudget
            heroChips
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Palette.glassTint), in: RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
    }

    private var heroTop: some View {
        HStack {
            Text("本月结余")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.ink.opacity(0.75))
            Spacer()
            Text(store.baseCurrency.rawValue + " · " + store.baseCurrency.name)
                .font(.caption2)
                .foregroundStyle(Palette.ink.opacity(0.55))
        }
    }

    private var heroAmount: some View {
        Text(store.money(store.balance))
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundStyle(Palette.ink)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .contentTransition(.numericText())
    }

    private var heroBudget: some View {
        HStack(spacing: 14) {
            BudgetRing(progress: store.budgetProgress,
                       size: 66,
                       label: String(Int(store.budgetProgress * 100)) + "%")
            VStack(alignment: .leading, spacing: 6) {
                Text("本月预算 " + store.money(store.budget))
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink.opacity(0.85))
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(height: 9)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Palette.hero)
                                .frame(width: max(9, proxy.size.width * store.budgetProgress))
                        }
                        .frame(height: 9)
                    }
                Text("还剩 " + store.money(store.budgetLeft))
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.6))
            }
        }
    }

    private var heroChips: some View {
        HStack(spacing: 10) {
            MetricChip(title: "收入", value: store.money(store.income), icon: "arrow.down.left", gradient: Palette.income)
            MetricChip(title: "支出", value: store.money(store.expense), icon: "arrow.up.right", gradient: Palette.expense)
        }
    }

    // MARK: 快捷操作

    private var quickActions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                quickAction(title: "记账", symbol: "square.and.pencil", action: actions.add)
                quickAction(title: "扫描", symbol: "camera.viewfinder", action: actions.scan)
                quickAction(title: "预算", symbol: "target", action: actions.budget)
                quickAction(title: "周期", symbol: "arrow.triangle.2.circlepath", action: actions.recurring)
            }
        }
    }

    private func quickAction(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.primary)
                    .frame(width: 42, height: 42)
                    .innerTile(Radius.chip, opacity: 0.14)
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .glassEffectUnion(id: "quickActions", namespace: namespace)
    }

    // MARK: 支出趋势

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "近 7 日支出",
                          subtitle: "日均 " + store.money(store.dailyAverage),
                          action: actions.openList,
                          actionTitle: "看明细")
            MiniBarChart(points: store.last7Days())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.regular.tint(Palette.glassTint), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: 今日明细

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "今日明细",
                          subtitle: "共 " + String(store.todayTxs.count) + " 笔",
                          action: actions.openList,
                          actionTitle: "全部")
            if store.todayTxs.isEmpty {
                VStack {
                    BuddyHint(mood: .sleepy, title: "今天还没有记账", subtitle: "点右下角 + 记一笔，小紫帮你攒钱")
                        .padding(.vertical, 18)
                }
                .frame(maxWidth: .infinity)
                .liquidGlass(.clear, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
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


// MARK: - 指标小卡

struct MetricChip: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(gradient, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                Text(value)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .innerTile(Radius.chip, opacity: 0.12)
    }
}

// MARK: - 预算进度环

struct BudgetRing: View {
    var progress: Double
    var size: CGFloat = 66
    var label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: size * 0.13)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.02))
                .stroke(AngularGradient(colors: [Palette.mint, Palette.primarySoft, Palette.primary, Palette.rose],
                                        center: .center),
                        style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text(label)
                    .font(.system(size: size * 0.26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("已用")
                    .font(.system(size: size * 0.16, design: .rounded))
                    .foregroundStyle(Palette.ink.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 明细行

struct TxRow: View {
    let tx: Tx
    var namespace: Namespace.ID
    var showsTags: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: tx.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Palette.categoryGradient(tx.category), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                info
                Spacer(minLength: 6)
                Text(tx.shortAmount)
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(tx.isIncome ? Palette.mint : Palette.rose)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(13)
            .contentShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidGlass(.clear.interactive(), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .glassEffectID(tx.id, in: namespace)
        .glassEffectUnion(id: "txRow", namespace: namespace)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(tx.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if tx.autoPosted {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.primary)
                }
            }
            HStack(spacing: 4) {
                if !tx.location.isEmpty {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.primary.opacity(0.85))
                }
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .lineLimit(1)
            }
            if showsTags && !tx.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(tx.tags.prefix(3), id: \.self) { tag in
                        TagChip(text: tag)
                    }
                }
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = [tx.category]
        if !tx.merchant.isEmpty { parts.append(tx.merchant) }
        if tx.currency != .cny { parts.append(tx.currency.rawValue) }
        parts.append(tx.date.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: " · ")
    }
}


struct TagChip: View {
    let text: String

    var body: some View {
        Text("#" + text)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(Palette.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Palette.primary.opacity(0.13), in: Capsule())
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
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
            }
            .foregroundStyle(isSelected ? Palette.primary : Palette.ink.opacity(0.55))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .liquidGlass(glass, in: Capsule())
        .glassEffectID(glassID, in: namespace)
        .glassEffectUnion(id: "tabBar", namespace: namespace)
    }

    private var glass: Glass {
        isSelected ? .regular.tint(Palette.glassTint).interactive() : .clear.interactive()
    }

    private var glassID: String {
        isSelected ? "tab-selected-" + String(tab.id) : "tab-" + String(tab.id)
    }
}
