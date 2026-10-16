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

// MARK: - 预算页存钱伴侣（无缝对齐当前选中的唯一吉祥物资产）

struct PiggyBuddy: View {
    var progress: Double = 0.4
    var size: CGFloat = 108

    var body: some View {
        CoinBuddy(mood: MascotMood.forBudget(progress), size: size)
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
