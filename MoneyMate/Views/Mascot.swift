import SwiftUI

// MARK: - 吉祥物心情

enum MascotMood {
    case happy, cheer, cool, worried, panic, sleepy

    static func forBudget(_ ratio: Double) -> MascotMood {
        // 与安卓一致：≤80% 笑脸，80%~100% 平嘴，>100% 哭脸
        if ratio > 1.0 { return .panic }
        if ratio >= 0.8 { return .worried }
        return .happy
    }

    var tip: String {
        switch self {
        case .happy: return "本月预算还很宽裕，慢慢花"
        case .cheer: return "记一笔，攒钱更有成就感"
        case .cool: return "花钱节奏刚刚好，继续保持"
        case .worried: return "预算快见底啦，悠着点"
        case .panic: return "预算已经超支，看看分类排行吧"
        case .sleepy: return "今天还没有记账，记一笔吧"
        }
    }
}

// MARK: - 小紫：3D 紫晶智慧猫头鹰（博士帽 + 金色流苏 + 金丝眼镜 + 纯 SwiftUI 绘制）

struct CoinBuddy: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 92

    @State private var blink = false
    @State private var breathe = false

    @Environment(\.colorScheme) private var scheme

    private var s: CGFloat { size }
    private let gold = Color(red: 0.96, green: 0.62, blue: 0.04)

    // MARK: 双模式配色（浅色=淡紫罗兰/珠光白/金丝，深色=紫晶深调）
    private var isLight: Bool { scheme == .light }
    private var bodyLight: Color { isLight ? Color(red: 0.86, green: 0.81, blue: 1.00) : Color(red: 0.66, green: 0.33, blue: 0.97) }
    private var bodyMid: Color { isLight ? Color(red: 0.72, green: 0.62, blue: 0.98) : Color(red: 0.49, green: 0.13, blue: 0.81) }
    private var bodyEdge: Color { isLight ? Color(red: 0.55, green: 0.45, blue: 0.88) : Color(red: 0.23, green: 0.03, blue: 0.39) }
    private var wingFill: Color { isLight ? Color(red: 0.79, green: 0.72, blue: 0.99) : Color(red: 0.30, green: 0.11, blue: 0.58) }
    private var bellyFill: Color { isLight ? Color.white.opacity(0.85) : Color(red: 0.75, green: 0.52, blue: 0.99).opacity(0.45) }
    private var bellyFillLow: Color { isLight ? Color(red: 0.90, green: 0.86, blue: 1.00).opacity(0.65) : Color(red: 0.58, green: 0.20, blue: 0.92).opacity(0.20) }
    private var lensFill: Color { isLight ? Color(red: 0.95, green: 0.94, blue: 1.00) : Color(red: 0.10, green: 0.05, blue: 0.20).opacity(0.7) }
    private var capFill: Color { isLight ? Color(red: 0.64, green: 0.55, blue: 0.93) : Color(red: 0.12, green: 0.07, blue: 0.22) }
    private var pupilInk: Color { isLight ? Color(red: 0.30, green: 0.22, blue: 0.55) : Color(red: 0.08, green: 0.04, blue: 0.15) }
    private var softShadow: Color { isLight ? Color(red: 0.42, green: 0.34, blue: 0.72).opacity(0.26) : Color.black.opacity(0.45) }

    var body: some View {
        ZStack {
            haloGlow
            feetRow
            wingsRow
            owlBody
            glassesAndEyes
            beak
            mortarboardCap
        }
        .frame(width: s * 1.5, height: s * 1.5)
        .scaleEffect(breathe ? 1.02 : 0.98)
        .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
        .task { await blinkLoop() }
    }

    private var haloGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        bodyLight.opacity(isLight ? 0.45 : 0.40),
                        bodyLight.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: s * 0.62
                )
            )
            .frame(width: s * 1.24, height: s * 1.24)
    }

    private var feetRow: some View {
        HStack(spacing: s * 0.16) {
            foot
            foot
        }
        .offset(y: s * 0.36)
    }

    private var foot: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { _ in
                Capsule()
                    .fill(gold)
                    .frame(width: s * 0.05, height: s * 0.09)
            }
        }
    }

    private var wingsRow: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.06)
                    .fill(wingFill)
                    .frame(width: s * 0.24, height: s * 0.28)
                    .overlay(
                        RoundedRectangle(cornerRadius: s * 0.06)
                            .stroke(gold.opacity(0.7), lineWidth: 1.2)
                    )
                Image(systemName: "plus.forwardslash.minus")
                    .font(.system(size: s * 0.13, weight: .bold))
                    .foregroundStyle(gold)
            }
            .offset(x: -s * 0.06, y: s * 0.08)

            Spacer()

            RoundedRectangle(cornerRadius: s * 0.08)
                .fill(LinearGradient(colors: [bodyMid,
                                              bodyEdge],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.20, height: s * 0.26)
                .rotationEffect(.degrees(breathe ? -12 : -5))
                .offset(x: s * 0.06, y: s * 0.08)
        }
        .frame(width: s * 1.02)
    }

    private var owlBody: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [bodyLight,
                                           bodyMid,
                                           bodyEdge],
                                   center: .init(x: 0.4, y: 0.35),
                                   startRadius: 2,
                                   endRadius: s * 0.5)
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(isLight ? 0.65 : 0.28), lineWidth: 1.2)
                )
                .shadow(color: softShadow, radius: s * 0.06, y: s * 0.035)

            Capsule()
                .fill(
                    LinearGradient(colors: [bellyFill,
                                           bellyFillLow],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: s * 0.52, height: s * 0.40)
                .offset(y: s * 0.16)
        }
        .frame(width: s * 0.82, height: s * 0.84)
    }

    private var glassesAndEyes: some View {
        HStack(spacing: 0) {
            eyeGlassesUnit
            Rectangle()
                .fill(gold)
                .frame(width: s * 0.06, height: 1.8)
            eyeGlassesUnit
        }
        .offset(y: -s * 0.06)
    }

    private var eyeGlassesUnit: some View {
        ZStack {
            Circle()
                .stroke(gold, lineWidth: 1.8)
                .frame(width: s * 0.26, height: s * 0.26)
                .background(Circle().fill(lensFill))

            eyeView
        }
    }

    @ViewBuilder
    private var eyeView: some View {
        switch mood {
        case .panic:
            ZStack {
                Circle().fill(Color.white).frame(width: s * 0.18)
                Circle().fill(pupilInk).frame(width: s * 0.09)
            }
        case .worried:
            Capsule()
                .fill(Color.white)
                .frame(width: s * 0.16, height: s * 0.06)
        case .sleepy:
            Capsule()
                .fill(gold)
                .frame(width: s * 0.14, height: s * 0.04)
        default:
            ZStack {
                Circle().fill(pupilInk).frame(width: s * 0.18)
                if !blink {
                    Circle()
                        .fill(Color.white)
                        .frame(width: s * 0.06)
                        .offset(x: -s * 0.03, y: -s * 0.03)
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: s * 0.03)
                        .offset(x: s * 0.02, y: s * 0.02)
                }
            }
        }
    }

    private var beak: some View {
        RoundedRectangle(cornerRadius: s * 0.02)
            .fill(gold)
            .frame(width: s * 0.09, height: s * 0.07)
            .shadow(color: gold.opacity(0.6), radius: 3)
            .offset(y: s * 0.06)
    }

    private var mortarboardCap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: s * 0.03)
                .fill(capFill)
                .frame(width: s * 0.65, height: s * 0.22)
                .overlay(
                    RoundedRectangle(cornerRadius: s * 0.03)
                        .stroke(Color(red: 0.55, green: 0.36, blue: 0.96), lineWidth: 1.2)
                )
                .shadow(color: softShadow, radius: 3, y: 2)
                .rotationEffect(.degrees(-4))

            Circle()
                .fill(gold)
                .frame(width: s * 0.06, height: s * 0.06)

            Capsule()
                .fill(gold)
                .frame(width: s * 0.028, height: s * 0.16)
                .offset(x: s * 0.24, y: s * 0.06)
        }
        .offset(y: -s * 0.40)
    }

    @MainActor
    private func blinkLoop() async {
        while !Task.isCancelled {
            let wait = Double.random(in: 2.2...4.6)
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.08)) { blink = true }
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.easeInOut(duration: 0.14)) { blink = false }
        }
    }
}

// MARK: - 存钱罐（预算页吉祥物）

struct PiggyBuddy: View {
    var progress: Double = 0.4
    var size: CGFloat = 120

    @State private var bob = false

    private var s: CGFloat { size }

    var body: some View {
        ZStack {
            tail
            legs
            pigBody
            ears
            snout
            eyes
            slot
            dropCoin
        }
        .frame(width: s * 1.3, height: s * 1.2)
        .offset(y: bob ? -s * 0.02 : s * 0.025)
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: bob)
        .onAppear { bob = true }
    }

    private var pigBody: some View {
        Ellipse()
            .fill(Palette.hero)
            .frame(width: s, height: s * 0.80)
            .overlay(Ellipse().stroke(Color.white.opacity(0.65), lineWidth: s * 0.028))
            .shadow(color: Palette.primaryDeep.opacity(0.28), radius: s * 0.10, y: s * 0.05)
    }

    private var ears: some View {
        HStack(spacing: s * 0.42) {
            ear
            ear
        }
        .offset(y: -s * 0.30)
    }

    private var ear: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: s * 0.14))
            path.addLine(to: CGPoint(x: s * 0.09, y: 0))
            path.addLine(to: CGPoint(x: s * 0.17, y: s * 0.14))
            path.closeSubpath()
        }
        .fill(Palette.primarySoft)
        .frame(width: s * 0.17, height: s * 0.14)
    }

    private var snout: some View {
        Ellipse()
            .fill(Palette.rose.opacity(0.45))
            .frame(width: s * 0.34, height: s * 0.24)
            .overlay(
                HStack(spacing: s * 0.05) {
                    Circle().fill(Palette.ink.opacity(0.55)).frame(width: s * 0.045)
                    Circle().fill(Palette.ink.opacity(0.55)).frame(width: s * 0.045)
                }
            )
            .offset(y: s * 0.10)
    }

    private var eyes: some View {
        HStack(spacing: s * 0.20) {
            Circle().fill(Palette.ink).frame(width: s * 0.07)
                .overlay(Circle().fill(Color.white.opacity(0.9)).frame(width: s * 0.025).offset(x: -s * 0.012, y: -s * 0.012))
            Circle().fill(Palette.ink).frame(width: s * 0.07)
                .overlay(Circle().fill(Color.white.opacity(0.9)).frame(width: s * 0.025).offset(x: -s * 0.012, y: -s * 0.012))
        }
        .offset(y: -s * 0.06)
    }

    private var slot: some View {
        Capsule()
            .fill(Palette.ink.opacity(0.55))
            .frame(width: s * 0.26, height: s * 0.05)
            .offset(y: -s * 0.18)
    }

    private var legs: some View {
        HStack(spacing: s * 0.45) {
            Capsule().fill(Palette.primary.opacity(0.85)).frame(width: s * 0.13, height: s * 0.20)
            Capsule().fill(Palette.primary.opacity(0.85)).frame(width: s * 0.13, height: s * 0.20)
        }
        .offset(y: s * 0.40)
    }

    private var tail: some View {
        Circle()
            .stroke(Palette.primary.opacity(0.7), lineWidth: s * 0.035)
            .frame(width: s * 0.14)
            .offset(x: -s * 0.50, y: -s * 0.02)
    }

    private var dropCoin: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(red: 1.00, green: 0.86, blue: 0.46),
                                          Color(red: 0.98, green: 0.66, blue: 0.20)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: s * 0.18)
            .overlay(
                Text("\u{00A5}")
                    .font(.system(size: s * 0.10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.62, green: 0.36, blue: 0.05))
            )
            .offset(y: (-s * 0.30) + s * 0.22 * CGFloat(min(max(progress, 0), 1)))
    }
}

// MARK: - 空状态 / 提示

struct BuddyHint: View {
    var mood: MascotMood
    var title: String
    var subtitle: String? = nil
    var size: CGFloat = 76

    var body: some View {
        VStack(spacing: 8) {
            CoinBuddy(mood: mood, size: size)
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Palette.ink.opacity(0.85))
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 背景卡通贴纸

struct DoodleLayer: View {
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                sticker("star.fill", Palette.primarySoft, 18)
                    .position(x: w * 0.13, y: h * 0.09)
                    .offset(y: drift ? -9 : 9)
                sticker("sparkle", Palette.rose, 15)
                    .position(x: w * 0.87, y: h * 0.16)
                    .offset(y: drift ? 10 : -7)
                sticker("circle.fill", Palette.mint, 9)
                    .position(x: w * 0.19, y: h * 0.40)
                    .offset(y: drift ? 12 : -12)
                sticker("star.fill", Palette.primary.opacity(0.55), 12)
                    .position(x: w * 0.83, y: h * 0.60)
                    .offset(y: drift ? -10 : 10)
                sticker("sparkles", Palette.primarySoft, 20)
                    .position(x: w * 0.09, y: h * 0.72)
                    .offset(y: drift ? 8 : -8)
                sticker("circle.fill", Palette.primarySoft.opacity(0.7), 7)
                    .position(x: w * 0.92, y: h * 0.80)
                    .offset(y: drift ? -11 : 11)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }

    private func sticker(_ name: String, _ color: Color, _ size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size))
            .foregroundStyle(color.opacity(0.60))
    }
}
