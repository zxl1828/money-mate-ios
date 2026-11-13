import SwiftUI

// MARK: - 瀑布图（净资产归因）

struct WaterfallEntry: Identifiable {
    var id: String { label }
    let label: String
    let value: Double
}

struct WaterfallChart: View {
    let entries: [WaterfallEntry]
    var height: CGFloat = 170
    var format: (Double) -> String = { money($0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let count = max(entries.count, 1)
                let slot = width / CGFloat(count)
                let totals = runningTotals()
                let maxAbs = max(totals.map { abs($0.1) }.max() ?? 1, 1)
                ZStack(alignment: .bottomLeading) {
                    // 零轴
                    Rectangle()
                        .fill(Palette.ink.opacity(0.10))
                        .frame(height: 1)
                        .offset(y: proxy.size.height / 2)

                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let total = totals[index].1
                        let isTotal = index == entries.count - 1
                        let barHeight = max(proxy.size.height / 2 * CGFloat(abs(total) / maxAbs), 3)
                        let positive = total >= 0
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                isTotal
                                    ? LinearGradient(colors: [Palette.primary, Palette.primaryDeep], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: positive ? [Palette.mint, Palette.mint.opacity(0.65)] : [Palette.rose, Palette.rose.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: slot * 0.52, height: barHeight)
                            .offset(
                                x: slot * CGFloat(index) + slot * 0.24,
                                y: positive ? proxy.size.height / 2 - barHeight : proxy.size.height / 2
                            )
                    }
                }
            }
            .frame(height: height)

            HStack(spacing: 0) {
                ForEach(entries) { entry in
                    Text(entry.label)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
            }
        }
    }

    private func runningTotals() -> [(String, Double)] {
        var running = 0.0
        var out: [(String, Double)] = []
        for (index, entry) in entries.enumerated() {
            if index == entries.count - 1 {
                out.append((entry.label, entry.value))
            } else {
                running += entry.value
                out.append((entry.label, entry.value))
            }
        }
        return out
    }
}

// MARK: - 子弹图（预算 / 目标达标）

struct BulletChart: View {
    let value: Double
    let target: Double
    var maxValue: Double? = nil
    var height: CGFloat = 14
    var tint: Color = Palette.primary

    var body: some View {
        let top = max(maxValue ?? max(value, target) * 1.15, 1)
        GeometryReader { proxy in
            let width = proxy.size.width
            let fill = min(max(value / top, 0), 1) * width
            let mark = min(max(target / top, 0), 1) * width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Palette.ink.opacity(0.07))
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.85), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(fill, 2))
                Rectangle()
                    .fill(Palette.ink.opacity(0.55))
                    .frame(width: 1.6, height: height + 4)
                    .offset(x: mark)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 哑铃图（预算 vs 实际）

struct DumbbellRow: Identifiable {
    var id: String { label }
    let label: String
    let left: Double
    let right: Double
}

struct DumbbellChart: View {
    let rows: [DumbbellRow]
    var height: CGFloat = 120
    var format: (Double) -> String = { money($0) }

    var body: some View {
        let maxAbs = max(rows.flatMap { [abs($0.left), abs($0.right)] }.max() ?? 1, 1)
        VStack(spacing: 12) {
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(row.label)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text("\(format(row.left)) → \(format(row.right))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        let x1 = CGFloat(min(abs(row.left) / maxAbs, 1)) * width
                        let x2 = CGFloat(min(abs(row.right) / maxAbs, 1)) * width
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Palette.ink.opacity(0.08))
                                .frame(height: 3)
                                .offset(y: 5)
                            Path { path in
                                path.move(to: CGPoint(x: min(x1, x2), y: 6.5))
                                path.addLine(to: CGPoint(x: max(x1, x2), y: 6.5))
                            }
                            .stroke(Palette.ink.opacity(0.25), lineWidth: 1.4)
                            Circle().fill(Palette.rose).frame(width: 9, height: 9).offset(x: max(x1 - 4.5, 0))
                            Circle().fill(Palette.mint).frame(width: 9, height: 9).offset(x: max(x2 - 4.5, 0))
                        }
                    }
                    .frame(height: 13)
                }
            }
        }
    }
}

// MARK: - 热力日历

struct HeatCalendar: View {
    let values: [Double]
    var weeks: Int = 14
    var height: CGFloat = 84

    var body: some View {
        let maxValue = max(values.max() ?? 1, 1)
        let cells = Array(values.suffix(weeks * 7))
        GeometryReader { proxy in
            let gap: CGFloat = 3
            let size = (proxy.size.width - gap * CGFloat(weeks - 1)) / CGFloat(weeks)
            let perColumn = 7
            ZStack(alignment: .topLeading) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, value in
                    let column = index / perColumn
                    let row = index % perColumn
                    let ratio = value / maxValue
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(value <= 0 ? Palette.ink.opacity(0.05) : Palette.primary.opacity(0.16 + 0.74 * ratio))
                        .frame(width: size, height: size)
                        .offset(x: CGFloat(column) * (size + gap), y: CGFloat(row) * (size + gap))
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - 堆叠柱

struct StackedBar: Identifiable {
    var id: String { label }
    let label: String
    let parts: [Double]
}

struct StackedBarChart: View {
    let bars: [StackedBar]
    var height: CGFloat = 140
    var colors: [Color] = [Palette.primary, Palette.mint, Palette.amberGlow, Palette.rose]

    var body: some View {
        let maxTotal = max(bars.map { $0.parts.reduce(0, +) }.max() ?? 1, 1)
        GeometryReader { proxy in
            let count = max(bars.count, 1)
            let slot = proxy.size.width / CGFloat(count)
            ZStack(alignment: .bottomLeading) {
                ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                    let total = bar.parts.reduce(0, +)
                    let barHeight = max(proxy.size.height * CGFloat(total / maxTotal), 3)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(spacing: 0) {
                            ForEach(Array(bar.parts.enumerated()), id: \.offset) { partIndex, part in
                                Rectangle()
                                    .fill(colors[partIndex % colors.count])
                                    .frame(height: max(barHeight * CGFloat(part / max(total, 1)), 0))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .frame(width: slot * 0.5)
                        .offset(x: 0, y: -CGFloat(0))
                    }
                    .frame(width: slot, height: proxy.size.height, alignment: .bottom)
                    .offset(x: slot * CGFloat(index))
                }
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                ForEach(bars) { bar in
                    Text(bar.label)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                }
            }
            .offset(y: 16)
        }
        .padding(.bottom, 18)
    }
}
