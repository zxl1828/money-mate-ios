import SwiftUI

/// 吉祥物：全局唯一（金鳞小财龙），由用户提供的两张图构成
/// （浅色白底 / 深色黑底，Asset Catalog 按外观自动切换），不再提供多选。
enum MascotKind: String, CaseIterable, Identifiable {
    case goldenDragon

    var id: String { rawValue }

    /// 历史存档里可能存的是旧吉祥物 key，一律映射到小龙。
    init(key: String) {
        self = .goldenDragon
    }

    var name: String {
        switch self {
        case .goldenDragon: return "金鳞小财龙"
        }
    }

    var tagline: String {
        switch self {
        case .goldenDragon: return "抱币同行"
        }
    }

    var symbol: String {
        switch self {
        case .goldenDragon: return "sparkles"
        }
    }

    var assetName: String {
        switch self {
        case .goldenDragon: return "mascot_dragon"
        }
    }
}

// MARK: - 全局原生 Image 驱动吉祥物单例组件
struct CoinBuddy: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 92
    /// 是否在身后叠一层琥珀色呼吸光晕（大尺寸展示时打开）。
    var showGlow: Bool = false

    @State private var floating = false
    @State private var breathing = false
    @State private var pressed = false
    @Environment(\.colorScheme) private var scheme

    private var isLight: Bool { scheme == .light }

    var body: some View {
        ZStack(alignment: .center) {
            // 底部极淡接触阴影（与上下悬浮自闭环微呼吸）
            Ellipse()
                .fill(Color.black.opacity(isLight ? 0.10 : 0.28))
                .frame(width: size * 0.68, height: size * 0.12)
                .scaleEffect(floating ? 0.90 : 1.08)
                .blur(radius: size * 0.05)
                .offset(y: size * 0.44)

            // 琥珀金呼吸光晕
            if showGlow {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Palette.amberGlow.opacity(breathing ? 0.42 : 0.18),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.72
                        )
                    )
                    .frame(width: size * 1.4, height: size * 1.4)
                    .allowsHitTesting(false)
            }

            // 原生高清 Image 吉祥物（圆形裁切 + 微呼吸 + 上下悬浮）
            Image(MascotKind.goldenDragon.assetName)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .scaleEffect(breathing ? 1.025 : 1.0)
                .offset(y: floating ? -2.5 : 2.5)
                .accessibilityLabel(MascotKind.goldenDragon.name)
        }
        .frame(width: size * 1.30, height: size * 1.30)
        .scaleEffect(pressed ? 0.93 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.60)) {
                pressed = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 140_000_000)
                withAnimation(.spring(response: 0.26, dampingFraction: 0.75)) {
                    pressed = false
                }
            }
            Haptics.tap()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                floating = true
            }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

// MARK: - 设置页吉祥物展示卡（只有一个，不再做多选宫格）
struct MascotPicker: View {
    @Environment(\.colorScheme) private var scheme
    private var isLight: Bool { scheme == .light }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "吉祥物伙伴", subtitle: "金鳞小财龙，抱着你的每一枚金币")

            HStack(spacing: 14) {
                CoinBuddy(size: 76, showGlow: true)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 4) {
                    Text(MascotKind.goldenDragon.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)

                    Text(MascotKind.goldenDragon.tagline)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)

                    Text("已启用")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isLight ? Palette.primaryDeep : Palette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                Palette.primary.opacity(isLight ? 0.12 : 0.16)
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                Palette.primary.opacity(isLight ? 0.32 : 0.42),
                                lineWidth: 0.8
                            )
                        )
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .glassPanel(Radius.card, strong: true)
    }
}
