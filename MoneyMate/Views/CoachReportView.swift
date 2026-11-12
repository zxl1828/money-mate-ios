import SwiftUI

/// 「财务体检报告」：把资产负债表 / 跑道 / 四象限 / 现金流 / 负债这些指标
/// 翻译成人话，像 AI 那样一段一段打出来，并给出下一步具体动作。
///
/// 全部在本地用规则拼装（`ReportWriter`），不联网、不调模型、不上传任何数据。
struct CoachReportPage: View {
    @ObservedObject var store: MoneyStore
    @ObservedObject private var planning = PlanningBook.shared
    @ObservedObject private var accounting = AccountingBook.shared

    @State private var report: CoachingReport?
    @State private var revealed = 0
    @State private var done = false
    @State private var score = 0
    @State private var copied = false

    private let ticker = Timer.publish(every: 0.024, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            GlassBackground()
            if let report {
                content(report)
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .navigationTitle("财务体检报告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        compose()
                    } label: {
                        Label("重新生成", systemImage: "arrow.clockwise")
                    }
                    Button {
                        copyText()
                    } label: {
                        Label("复制全文", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            if report == nil { compose() }
        }
        .onReceive(ticker) { _ in
            guard let report, !done else { return }
            let total = totalLength(report)
            if revealed >= total {
                done = true
                return
            }
            revealed = min(total, revealed + step)
        }
        .overlay(alignment: .bottom) {
            if !done, report != nil {
                Button {
                    Haptics.tap()
                    if let report {
                        revealed = totalLength(report)
                        done = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "forward.fill").font(.system(size: 12, weight: .semibold))
                        Text("跳过打字，直接看全文").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Palette.primaryDeep)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.92), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1))
                    .shadow(color: Palette.ink.opacity(0.12), radius: 14, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 22)
            }
        }
        .alert("已复制", isPresented: $copied) {
            Button("好", role: .cancel) {}
        } message: {
            Text("报告全文已复制，可以粘贴到备忘录或发给家人。")
        }
    }

    // MARK: - 打字节奏

    private var step: Int {
        if revealed > 1400 { return 7 }
        if revealed > 600 { return 5 }
        return 3
    }

    private func totalLength(_ report: CoachingReport) -> Int {
        report.greeting.count + report.priority.count + report.closing.count
            + report.blocks.reduce(0) { $0 + $1.body.count }
    }

    // MARK: - 组装

    private func compose() {
        let txs = store.scopedTxs
        let accounts = store.activeAccounts
        var balances: [UUID: Double] = [:]
        for account in accounts {
            balances[account.id] = FinanceMath.balance(account, txs: txs)
        }
        let macro = planning.macro
        let runway = PlanningEngine.buildRunway(
            accounts: accounts, balances: balances, items: accounting.items, txs: txs, macro: macro
        )
        let allocation = PlanningEngine.buildAllocation(accounts: accounts, balances: balances, items: accounting.items)
        let income = PlanningEngine.averageIncome(txs)
        let surplus = income - PlanningEngine.averageExpense(txs)
        let netWorth = FinanceMath.netWorth(accounts: accounts, txs: txs).net
        let projection = PlanningEngine.projectCashFlow(
            currentCash: runway.tier1,
            monthlySurplus: surplus,
            milestones: planning.milestones,
            months: 24,
            safeFloor: max(macro.safeCashFloorMonths * runway.rigidMonthly, 0),
            netWorth: netWorth,
            investedAssets: PlanningEngine.investedAssets(of: allocation),
            macro: macro
        )
        let mortgage = accounting.items.first { $0.kind == .mortgage && $0.value > 0 }
        let compass = PlanningEngine.mortgageCompass(
            balance: mortgage?.value ?? 1_000_000,
            rate: (mortgage?.rate ?? 0) > 0 ? (mortgage!.rate ?? 0) : macro.mortgageRate,
            termMonths: (mortgage?.termMonths ?? 0) > 0 ? (mortgage!.termMonths ?? 240) : 240,
            equalInstallment: mortgage?.equalInstallment ?? true,
            idleCash: 100_000,
            expectedReturn: 3.5
        )
        let debtList = PlanningEngine.debts(accounts: accounts, balances: balances, items: accounting.items, macro: macro)
        let avalanche = PlanningEngine.avalanche(debtList, extraMonthly: 1000)
        let stress = PlanningEngine.stressTest(
            monthlyIncome: income,
            debts: debtList,
            tier1: runway.tier1,
            rigidMonthly: runway.rigidMonthly,
            factor: 1,
            rateShock: 0
        )

        let built = ReportWriter.build(
            runway: runway,
            allocation: allocation,
            projection: projection,
            compass: compass,
            avalanche: avalanche,
            stress: stress,
            monthlyIncome: income,
            monthlySurplus: surplus,
            netWorth: netWorth,
            hasMortgage: mortgage != nil,
            mortgageName: mortgage?.name ?? "假设房贷"
        )

        let runwayScore = min(max(runway.runwayMonths / 12, 0), 1)
        let debtScore: Double
        if stress.dsr <= 0.35 { debtScore = 1 }
        else if stress.dsr <= 0.4 { debtScore = 0.8 }
        else if stress.dsr <= 0.5 { debtScore = 0.55 }
        else { debtScore = 0.3 }
        score = min(max(Int(Double(allocation.score) * 0.4 + runwayScore * 40 + debtScore * 20), 0), 100)

        report = built
        revealed = 0
        done = false
    }

    private func copyText() {
        guard let report else { return }
        var lines: [String] = ["MoneyMate 财务体检报告", ""]
        lines.append("【一句话】\(report.priority)")
        lines.append("")
        lines.append(report.greeting)
        lines.append("")
        for block in report.blocks {
            lines.append("— \(block.title) —")
            lines.append(block.body)
            if let note = block.footnote { lines.append("（\(note)）") }
            lines.append("")
        }
        lines.append(report.closing)
        UIPasteboard.general.string = lines.joined(separator: "\n")
        Haptics.success()
        copied = true
    }

    // MARK: - 视图

    private func content(_ report: CoachingReport) -> some View {
        // 每段在「总字数」里的起点，边打字边按比例裁剪
        var cursor = report.greeting.count
        let priorityStart = cursor
        cursor += report.priority.count
        var starts: [Int] = []
        for block in report.blocks {
            starts.append(cursor)
            cursor += block.body.count
        }
        let closingStart = cursor
        let revealedCount = revealed

        func slice(_ text: String, _ start: Int) -> String {
            let shown = min(max(revealedCount - start, 0), text.count)
            return String(text.prefix(shown))
        }

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    priorityCard(slice(report.priority, priorityStart))
                    greetingCard(slice(report.greeting, 0))
                    ForEach(Array(report.blocks.enumerated()), id: \.element.id) { pair in
                        let index = pair.offset
                        let block = pair.element
                        if revealedCount > starts[index] {
                            blockCard(block, slice(block.body, starts[index]))
                        }
                    }
                    if revealedCount >= closingStart {
                        closingCard(slice(report.closing, closingStart))
                    }
                    Color.clear.frame(height: 70).id("bottom")
                }
                .padding(.horizontal, Radius.chip + 2)
                .padding(.top, 4)
            }
            .onChange(of: revealed) { _, _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: done) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.10))
                Circle()
                    .stroke(scoreColor.opacity(0.35), lineWidth: 1.1)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text("分")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(scoreColor.opacity(0.9))
                }
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(report?.blocks.count ?? 0) 个维度体检完成")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("本地生成 · 不上传数据 · 结论可复现")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            if done {
                Text("已完成")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.mint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Palette.mint.opacity(0.12), in: Capsule())
            } else {
                CursorBar(color: scoreColor)
            }
        }
    }

    private func priorityCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill").font(.system(size: 11, weight: .bold))
                Text("现在最该做的一件事").font(.system(size: 11.5, weight: .bold))
            }
            .foregroundStyle(Color.white.opacity(0.9))

            Text(text)
                .font(.system(size: 14.5, weight: .semibold))
                .lineSpacing(4)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Palette.hero, in: squircle(Radius.chip + 2))
    }

    private func greetingCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5))
            .lineSpacing(5)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .glassPanel(Radius.tile, strong: true)
    }

    private func blockCard(_ block: ReportBlock, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.primary)
                    .frame(width: 4, height: 13)
                Text(block.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 0)
            }
            Text(text)
                .font(.system(size: 13.5))
                .lineSpacing(5.5)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let note = block.footnote, text.count >= block.body.count {
                Text(note)
                    .font(.system(size: 10.5))
                    .lineSpacing(3.4)
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.ink.opacity(0.04), in: squircle(Radius.small))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassPanel(Radius.tile, strong: true)
    }

    private func closingCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(size: 12))
                .lineSpacing(4.6)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if done {
                Text("看完就去做第一条，其它的下个月再说")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Palette.primaryDeep)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.primarySoft.opacity(0.30), in: squircle(Radius.chip))
    }

    private var scoreColor: Color {
        if score >= 80 { return Palette.mint }
        if score >= 60 { return Palette.primary }
        if score >= 40 { return Palette.amberGlow }
        return Palette.rose
    }
}

/// 打字时闪烁的光标。
private struct CursorBar: View {
    let color: Color
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1.2)
            .fill(color.opacity(visible ? 1 : 0.15))
            .frame(width: 2.4, height: 15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
