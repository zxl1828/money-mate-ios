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

// MARK: - 小紫：一枚爱记账的紫色小钱币（纯 SwiftUI 形状绘制）

struct CoinBuddy: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 92

    @State private var blink = false
    @State private var breathe = false

    private var s: CGFloat { size }

    var body: some View {
        ZStack {
            arms
            coinBody
            gloss
            antenna
            cheeks
            eyesRow
            mouth
            accessory
        }
        .frame(width: s * 1.5, height: s * 1.5)
        .scaleEffect(breathe ? 1.02 : 0.98)
        .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
        .task { await blinkLoop() }
    }

    // MARK: 部件

    private var coinBody: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.55))
            Circle().fill(Palette.hero).padding(s * 0.08)
            Circle().stroke(Color.white.opacity(0.70), lineWidth: s * 0.03).padding(s * 0.08)
        }
        .frame(width: s, height: s)
        .shadow(color: Palette.primaryDeep.opacity(0.28), radius: s * 0.12, y: s * 0.06)
    }

    private var gloss: some View {
        Ellipse()
            .fill(Color.white.opacity(0.48))
            .frame(width: s * 0.30, height: s * 0.15)
            .rotationEffect(.degrees(-28))
            .offset(x: -s * 0.21, y: -s * 0.24)
            .blur(radius: s * 0.015)
    }

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Palette.mint)
                .frame(width: s * 0.13)
                .shadow(color: Palette.mint.opacity(0.6), radius: s * 0.05)
            Capsule()
                .fill(Palette.primary.opacity(0.55))
                .frame(width: s * 0.035, height: s * 0.16)
        }
        .offset(y: -s * 0.58)
        .rotationEffect(.degrees(mood == .cheer ? 14 : 0))
    }

    private var arms: some View {
        HStack(spacing: s * 0.72) {
            arm(angle: mood == .cheer ? -58 : 18)
            arm(angle: mood == .cheer ? 58 : -18)
        }
        .offset(y: s * 0.10)
    }

    private func arm(angle: Double) -> some View {
        Capsule()
            .fill(Palette.primary.opacity(0.85))
            .frame(width: s * 0.10, height: s * 0.24)
            .rotationEffect(.degrees(angle), anchor: .top)
    }

    private var cheeks: some View {
        HStack(spacing: s * 0.30) {
            Circle().fill(Palette.rose.opacity(0.45)).frame(width: s * 0.11)
            Circle().fill(Palette.rose.opacity(0.45)).frame(width: s * 0.11)
        }
        .offset(y: s * 0.07)
    }

    private var eyesRow: some View {
        HStack(spacing: s * 0.15) {
            eye
            eye
        }
        .offset(y: -s * 0.05)
    }

    @ViewBuilder
    private var eye: some View {
        switch mood {
        case .sleepy:
            Capsule()
                .fill(Palette.ink.opacity(0.85))
                .frame(width: s * 0.16, height: s * 0.035)
        case .panic:
            Circle()
                .fill(Color.white)
                .frame(width: s * 0.15)
                .overlay(Circle().fill(Palette.ink).frame(width: s * 0.075))
        default:
            Capsule()
                .fill(Palette.ink)
                .frame(width: s * 0.12, height: s * (blink ? 0.03 : 0.17))
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: s * 0.038)
                        .offset(x: s * 0.022, y: s * 0.03)
                }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .cheer:
            Ellipse()
                .fill(Palette.ink.opacity(0.85))
                .frame(width: s * 0.22, height: s * 0.15)
                .offset(y: s * 0.14)
        case .cool, .worried:
            Capsule()
                .fill(Palette.ink.opacity(0.85))
                .frame(width: s * 0.17, height: s * 0.05)
                .rotationEffect(.degrees(mood == .cool ? -8 : 0))
                .offset(y: s * 0.15)
        case .panic:
            Circle()
                .fill(Palette.ink.opacity(0.85))
                .frame(width: s * 0.12)
                .offset(y: s * 0.15)
        case .sleepy:
            Circle()
                .fill(Palette.ink.opacity(0.70))
                .frame(width: s * 0.07)
                .offset(y: s * 0.14)
        case .happy:
            Capsule()
                .fill(Palette.ink.opacity(0.85))
                .frame(width: s * 0.20, height: s * 0.07)
                .offset(y: s * 0.15)
        }
    }

    private var goldCoin: some View {
        Circle()
            .fill(LinearGradient(colors: [Color(red: 1.00, green: 0.86, blue: 0.46),
                                          Color(red: 0.98, green: 0.66, blue: 0.20)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: s * 0.26)
            .overlay(
                Text("\u{00A5}")
                    .font(.system(size: s * 0.15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.62, green: 0.36, blue: 0.05))
            )
            .shadow(color: Color(red: 0.98, green: 0.66, blue: 0.20).opacity(0.5), radius: s * 0.06, y: s * 0.02)
    }

    @ViewBuilder
    private var accessory: some View {
        switch mood {
        case .cheer:
            ZStack {
                Image(systemName: "sparkle")
                    .font(.system(size: s * 0.22))
                    .foregroundStyle(Palette.rose)
                    .offset(x: s * 0.54, y: -s * 0.50)
                Image(systemName: "sparkle")
                    .font(.system(size: s * 0.16))
                    .foregroundStyle(Palette.mint)
                    .offset(x: -s * 0.56, y: -s * 0.30)
                goldCoin.offset(x: s * 0.50, y: s * 0.42)
            }
        case .panic:
            Text("!")
                .font(.system(size: s * 0.40, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.rose)
                .offset(x: s * 0.44, y: -s * 0.44)
        case .sleepy:
            Text("z z")
                .font(.system(size: s * 0.20, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.primary.opacity(0.7))
                .offset(x: s * 0.50, y: -s * 0.46)
        case .worried:
            Ellipse()
                .fill(Color(red: 0.56, green: 0.78, blue: 1.00))
                .frame(width: s * 0.13, height: s * 0.18)
                .offset(x: s * 0.44, y: -s * 0.36)
        default:
            EmptyView()
        }
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
                    .foregroundStyle(Palette.ink.opacity(0.55))
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
