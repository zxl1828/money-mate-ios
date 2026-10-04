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
        case .home: return "主页"
        case .list: return "详情"
        case .assets: return "资产"
        case .stats: return "统计"
        case .settings: return "我"
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
    var calendar: (() -> Void)? = nil
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
        .animation(.smooth(duration: 0.30), value: tab)
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
        if WidgetShared.consumeQuickAdd() {
            showAdd = true
        }
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

    /// 切屏：只做「轻微位移 + 淡入」，不再整页横移。
    ///
    /// 整页横移会让每张玻璃卡在移动过程中一帧帧重新采样背景，真机上看起来
    /// 就是「一闪一闪 + 切片」。小幅位移 + 淡入的观感更接近系统级丝滑转场。
    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(x: forward ? 18 : -18).combined(with: .opacity),
            removal: .offset(x: forward ? -18 : 18).combined(with: .opacity))
    }

    private func select(_ item: MoneyTab) {
        guard item != tab else { return }
        Haptics.tap()
        forward = item.rawValue > tab.rawValue
        withAnimation(.smooth(duration: 0.30)) { tab = item }
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
                    openList: { select(.list) },
                    calendar: { showNotify = true })
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

    // MARK: 悬浮层（通透液态玻璃胶囊 Dock + 激活标签琥珀暖金微光 + 中央 3D 切面紫晶加号）

    private var floatingLayer: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottom) {
                AmberHalo()
                    .offset(y: -2)

                tabBar

                DiamondJewelFab {
                    showAdd = true
                }
                .offset(y: -38)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            TabItem(tab: .home, isSelected: tab == .home, namespace: glassNS) {
                select(.home)
            }
            .frame(maxWidth: .infinity)

            TabItem(tab: .list, isSelected: tab == .list, namespace: glassNS) {
                select(.list)
            }
            .frame(maxWidth: .infinity)

            // 中央预留 58pt 独立镂空槽位专供悬浮菱形加号 (FAB)，彻底杜绝压盖
            Color.clear
                .frame(width: 58, height: 44)
                .allowsHitTesting(false)

            TabItem(tab: .stats, isSelected: tab == .stats, namespace: glassNS) {
                select(.stats)
            }
            .frame(maxWidth: .infinity)

            TabItem(tab: .settings, isSelected: tab == .settings, namespace: glassNS) {
                select(.settings)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .clearLiquidGlass(cornerRadius: 36)
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
                    .foregroundStyle(Palette.textSecondary)
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

// MARK: - 首页（通透液态玻璃 + 紫晶微拟物 + 列表元素交错弹性入场）

struct HomePage: View {
    @ObservedObject var store: MoneyStore
    var namespace: Namespace.ID
    var actions: HomeActions
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                    .springCascade(index: 0)

                LedgerBar(store: store)
                    .springCascade(index: 1)

                heroCard
                    .springCascade(index: 2)

                quickActions
                    .springCascade(index: 3)

                trendCard
                    .springCascade(index: 4)

                quickTemplates
                    .springCascade(index: 5)

                todayList
                    .springCascade(index: 6)
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
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(Palette.textPrimary)
                Text(greetingSub)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                if let cal = actions.calendar {
                    cal()
                } else {
                    actions.notify()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? LinearGradient(
                                    colors: [Palette.auroraPurple.opacity(0.35), Palette.amethystDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.88), Color(red: 0.94, green: 0.91, blue: 0.98).opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    colorScheme == .dark
                                        ? LinearGradient(
                                            colors: [Color.white.opacity(0.7), Palette.neonViolet.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.95), Palette.primarySoft.opacity(0.45)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                    lineWidth: 1.0
                                )
                        )
                        .shadow(
                            color: colorScheme == .dark
                                ? Palette.neonViolet.opacity(0.25)
                                : Color(red: 0.40, green: 0.20, blue: 0.60).opacity(0.12),
                            radius: colorScheme == .dark ? 10 : 8,
                            y: 3
                        )

                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? Palette.textPrimary : Palette.primaryDeep)
                }
                .frame(width: 48, height: 48)
            }
            .buttonStyle(GelPressButtonStyle(cornerRadius: 16))
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "夜深了，还在记账？" }
        if hour < 11 { return "早上好，" }
        if hour < 14 { return "中午好，" }
        if hour < 18 { return "下午好，" }
        return "晚上好，"
    }

    private var greetingSub: String {
        "看看今天花了啥"
    }

    // MARK: 结余主卡 (预算总览) - 通透液态玻璃 + Specular Rim + 双层发光环

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroHeaderRow
            heroGlassPlate
            heroChips
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clearLiquidGlass(cornerRadius: 30)
        .purpleBreathingBacklight(cornerRadius: 30)
    }

    private var heroHeaderRow: some View {
        HStack {
            Text("预算总览")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Text("K")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 26, height: 26)
                .background(Palette.neonViolet.opacity(0.18), in: Circle())
                .overlay(Circle().stroke(Palette.neonViolet.opacity(0.35), lineWidth: 1))

            Button(action: actions.budget) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(Palette.neonViolet.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(Palette.neonViolet.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(GelPressButtonStyle(cornerRadius: 13))
        }
    }

    private var heroGlassPlate: some View {
        HStack(spacing: 16) {
            GlowDoubleRing(progress: store.budgetProgress, size: 88, label: "已使用")

            VStack(alignment: .leading, spacing: 4) {
                Text(store.money(store.balance))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        store.toggleAmountMask()
                    }
                Text("本月预算 " + store.money(store.budget))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Text("剩余额度 " + store.money(store.budgetLeft))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }


            Spacer(minLength: 4)

            Button(action: actions.budget) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Palette.primarySoft, Palette.primaryDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Palette.neonViolet.opacity(0.4), radius: 8)
            }
            .buttonStyle(GelPressButtonStyle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .clearLiquidGlass(cornerRadius: 24)
    }

    private var heroChips: some View {
        HStack(spacing: 12) {
            heroMetricPill(title: "收入", value: store.money(store.income), icon: "arrow.down.left", color: Palette.mint)
            heroMetricPill(title: "支出", value: store.money(store.expense), icon: "arrow.up.right", color: Palette.rose)
        }
    }

    private func heroMetricPill(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(color)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Text(value)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .clearLiquidGlass(cornerRadius: 18)
    }

    // MARK: 四大金刚功能键（嵌套式晶石架构 + 液体凝胶回弹）

    private var quickActions: some View {
        QuickActionsKeypad(
            onAdd: actions.add,
            onScan: actions.scan,
            onBudget: actions.budget,
            onRecurring: actions.recurring
        )
    }

    // MARK: 支出趋势看板（平滑高光贝塞尔曲线 + 双层发光节点 + 面积流光渐变）

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("支出趋势")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                    Text("当前数值: " + store.money(store.dailyAverage))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.amberGlow)
                }
                Spacer()
                Button(action: actions.openList) {
                    Text("看明细")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .clearLiquidGlass(cornerRadius: 12)
                }
                .buttonStyle(GelPressButtonStyle(cornerRadius: 12))
            }

            TrendChart(
                points: store.last7Days().map { StatsPoint(label: $0.label, expense: $0.value, income: 0) },
                average: store.dailyAverage
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clearLiquidGlass(cornerRadius: 28)
        .purpleBreathingBacklight(cornerRadius: 28)
    }

    // MARK: 快捷模板

    private var quickTemplates: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷模板")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: 10) {
                quickTemplateCard(title: "早餐", amount: 12, symbol: "cup.and.saucer.fill", category: "餐饮")
                quickTemplateCard(title: "地铁", amount: 6, symbol: "tram.fill", category: "交通")
                quickTemplateCard(title: "公交", amount: 6, symbol: "bus.fill", category: "交通")
                quickTemplateCard(title: "咖啡", amount: 6, symbol: "takeoutbag.and.cup.and.straw.fill", category: "餐饮")
            }
        }
    }

    private func quickTemplateCard(title: String, amount: Double, symbol: String, category: String) -> some View {
        Button {
            let now = Date()
            var tx = Tx(title: title,
                        amount: -abs(amount),
                        category: category,
                        date: now,
                        merchant: title,
                        note: "快捷·" + title,
                        kind: .expense,
                        accountID: store.activeAccounts.first?.id,
                        updatedAt: now,
                        memberName: store.myName)
            if tx.accountID == nil { tx.accountID = store.activeAccounts.first?.id }
            store.add(tx)
            Haptics.success()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.primary)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Text("¥" + String(format: "%.0f", amount))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .clearLiquidGlass(cornerRadius: 20)
        }
        .buttonStyle(GelPressButtonStyle(cornerRadius: 20))
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
                .clearLiquidGlass(cornerRadius: Radius.tile)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(store.todayTxs.enumerated()), id: \.element.id) { index, tx in
                        TxRow(tx: tx, namespace: namespace) { actions.open(tx) }
                            .springCascade(index: index)
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
                    .foregroundStyle(Palette.textSecondary)
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
                    .foregroundStyle(Palette.textSecondary)
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
        .springButton(cornerRadius: Radius.tile)
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
                    .foregroundStyle(Palette.textSecondary)
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

// MARK: - 标签栏按钮（激活标签下方具有径向琥珀暖金微光，形成内蕴能量感）

struct TabItem: View {
    let tab: MoneyTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                // 当前激活标签下方径向琥珀暖金微光
                if isSelected {
                    RadialGradient(
                        colors: [Palette.amberGlow.opacity(0.70), Palette.amberWarm.opacity(0.20), Color.clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: 28
                    )
                    .frame(width: 46, height: 24)
                    .offset(y: 8)
                    .allowsHitTesting(false)
                }

                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 17, weight: isSelected ? .heavy : .medium))
                    Text(tab.title)
                        .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                }
                .foregroundStyle(isSelected ? Palette.amberGlow : Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }
}
