import SwiftUI

enum MascotKind: String, CaseIterable, Identifiable {
    case amethystPixiu
    case lavenderHamster
    case liquidDroplet
    case prismCat

    var id: String { rawValue }

    init(key: String) {
        switch key {
        case "mascot_pixiu", "amethystPixiu", "pixiu": self = .amethystPixiu
        case "mascot_hamster", "lavenderHamster", "hamster": self = .lavenderHamster
        case "mascot_droplet", "liquidDroplet", "droplet": self = .liquidDroplet
        case "mascot_cat", "prismCat", "cat": self = .prismCat
        default: self = .amethystPixiu
        }
    }

    var name: String {
        switch self {
        case .amethystPixiu: return "招财幼貔貅"
        case .lavenderHamster: return "紫雾小仓鼠"
        case .liquidDroplet: return "星露水滴精灵"
        case .prismCat: return "棱镜灵猫"
        }
    }

    var tagline: String {
        switch self {
        case .amethystPixiu: return "聚财守护"
        case .lavenderHamster: return "精算拾穗"
        case .liquidDroplet: return "灵动未来"
        case .prismCat: return "敏锐洞察"
        }
    }

    var symbol: String {
        switch self {
        case .amethystPixiu: return "sparkles"
        case .lavenderHamster: return "eyeglasses"
        case .liquidDroplet: return "drop.fill"
        case .prismCat: return "diamond.fill"
        }
    }

    var assetName: String {
        switch self {
        case .amethystPixiu: return "mascot_pixiu"
        case .lavenderHamster: return "mascot_hamster"
        case .liquidDroplet: return "mascot_droplet"
        case .prismCat: return "mascot_cat"
        }
    }
}

// MARK: - 全局原生 Image 驱动吉祥物单例组件
struct CoinBuddy: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 92
    var kindOverride: MascotKind? = nil

    @AppStorage("moneymate.mascot.kind") private var rawKind = MascotKind.amethystPixiu.rawValue
    @State private var floating = false
    @State private var pressed = false
    @Environment(\.colorScheme) private var scheme

    private var kind: MascotKind {
        kindOverride ?? MascotKind(key: rawKind)
    }

    private var isLight: Bool { scheme == .light }

    var body: some View {
        ZStack(alignment: .center) {
            // 底部极淡接触阴影（与上下悬浮自闭环微呼吸）
            Ellipse()
                .fill(Color.black.opacity(isLight ? 0.10 : 0.28))
                .frame(width: size * 0.74, height: size * 0.13)
                .scaleEffect(floating ? 0.90 : 1.08)
                .blur(radius: size * 0.05)
                .offset(y: size * 0.44)

            // 原生高清 Image 吉祥物（深浅模式由 Asset Catalog 自动无缝渲染）
            Image(kind.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.14, height: size * 1.14)
                .offset(y: floating ? -2.5 : 2.5)
                .accessibilityLabel(kind.name)
        }
        .frame(width: size * 1.30, height: size * 1.30)
        .scaleEffect(pressed ? 0.94 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
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
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floating = true
            }
        }
    }
}

// MARK: - 设置页 2×2 晶石选择器
struct MascotPicker: View {
    @AppStorage("moneymate.mascot.kind") private var rawKind = MascotKind.amethystPixiu.rawValue
    @Environment(\.colorScheme) private var scheme

    private var currentKind: MascotKind {
        MascotKind(key: rawKind)
    }

    private var isLight: Bool { scheme == .light }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "吉祥物伴侣", subtitle: "选择一个陪你管理每一笔钱")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(MascotKind.allCases) { kind in
                    MascotCardItem(
                        kind: kind,
                        isSelected: currentKind == kind,
                        onSelect: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                rawKind = kind.rawValue
                            }
                            Haptics.select()
                        }
                    )
                }
            }
        }
        .padding(16)
        .glassPanel(Radius.card, strong: true)
    }
}

private struct MascotCardItem: View {
    let kind: MascotKind
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isPressed = false
    @Environment(\.colorScheme) private var scheme
    private var isLight: Bool { scheme == .light }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.60)) {
                isPressed = true
            }
            onSelect()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    isPressed = false
                }
            }
        }) {
            ZStack(alignment: .topTrailing) {
                // 选中态背后琥珀金柔和漫反射光晕
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.amberGlow.opacity(isLight ? 0.22 : 0.32))
                        .blur(radius: 10)
                        .padding(-2)
                }

                // 卡片主体
                VStack(spacing: 8) {
                    CoinBuddy(size: 56, kindOverride: kind)
                        .allowsHitTesting(false)
                        .padding(.top, 4)

                    VStack(spacing: 3) {
                        Text(kind.name)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(isLight ? Color(red: 0.12, green: 0.08, blue: 0.20) : Color.white)

                        Text(kind.tagline)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(isLight ? Color(red: 0.42, green: 0.36, blue: 0.54) : Color(red: 0.82, green: 0.76, blue: 0.94))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)
                .background(
                    // 卡片底板：浅色珠光白高透玻璃，深色曜黑紫晶玻璃
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isSelected
                                ? (isLight ? Color.white.opacity(0.88) : Color(red: 0.16, green: 0.10, blue: 0.28).opacity(0.85))
                                : (isLight ? Color.white.opacity(0.55) : Color(red: 0.10, green: 0.07, blue: 0.18).opacity(0.50))
                        )
                )
                .overlay(
                    // 边框描边：选中态 1.5pt 极光紫渐变高光，未选中态淡白/淡紫描边
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isSelected
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.80, green: 0.55, blue: 1.0),
                                        Color(red: 0.60, green: 0.40, blue: 0.98),
                                        Color(red: 0.42, green: 0.25, blue: 0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(isLight ? 0.45 : 0.15),
                                        Color.white.opacity(isLight ? 0.15 : 0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ),
                            lineWidth: isSelected ? 1.5 : 1.0
                        )
                )

                // 右上角晶体勾选标识
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [
                                    Palette.amberGlow,
                                    Color(red: 1.0, green: 0.82, blue: 0.42)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 20, height: 20)
                            .shadow(color: Palette.amberGlow.opacity(0.6), radius: 3)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color(red: 0.35, green: 0.20, blue: 0.02))
                    }
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
