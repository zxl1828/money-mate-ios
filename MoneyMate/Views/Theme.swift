import SwiftUI
import UIKit

// MARK: - 紫色主题色板（全局统一）

enum Palette {
    /// 深浅色自适应颜色：浅色分支与原有配色完全一致，只额外提供深色变体
    static func adaptive(light: (Double, Double, Double),
                         dark: (Double, Double, Double),
                         alpha: (Double, Double) = (1, 1)) -> Color {
        Color(uiColor: UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            let rgb = isDark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: isDark ? alpha.1 : alpha.0)
        })
    }

    static let primary = adaptive(light: (0.58, 0.47, 0.99), dark: (0.70, 0.62, 1.00))
    static let primaryDeep = adaptive(light: (0.45, 0.34, 0.88), dark: (0.58, 0.48, 1.00))
    static let primarySoft = adaptive(light: (0.74, 0.66, 1.00), dark: (0.60, 0.53, 0.96))
    static let lilac = adaptive(light: (0.90, 0.87, 1.00), dark: (0.22, 0.19, 0.34))
    static let lavender = adaptive(light: (0.97, 0.96, 1.00), dark: (0.10, 0.08, 0.16))
    static let mint = adaptive(light: (0.42, 0.89, 0.79), dark: (0.38, 0.84, 0.74))
    static let rose = adaptive(light: (1.00, 0.55, 0.74), dark: (1.00, 0.60, 0.78))
    static let ink = adaptive(light: (0.24, 0.20, 0.40), dark: (0.95, 0.94, 0.99))
    /// 玻璃叠加层：调得更透（原来是 0.30 / 0.12，白雾感重）。
    static let glassTint = adaptive(light: (1, 1, 1), dark: (1, 1, 1), alpha: (0.14, 0.07))
    /// 背景光斑用的浅色块（深色下改为偏紫的暗光）
    static let blobLight = adaptive(light: (1, 1, 1), dark: (0.34, 0.29, 0.55))

    // MARK: - 紫晶暗黑微拟物设计令牌
    static let obsidianBlack = Color(red: 0.04, green: 0.03, blue: 0.06)
    static let amethystDeep = Color(red: 0.06, green: 0.05, blue: 0.11)
    static let amethystGlow = Color(red: 0.14, green: 0.09, blue: 0.26)
    static let neonViolet = Color(red: 0.66, green: 0.33, blue: 0.97)
    static let auroraPurple = Color(red: 0.55, green: 0.36, blue: 0.96)
    static let lightLilac = Color(red: 0.75, green: 0.52, blue: 0.99)
    static let amberGlow = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let amberWarm = Color(red: 0.98, green: 0.57, blue: 0.24)

    static let amethystBg = RadialGradient(
        colors: [amethystGlow, amethystDeep, obsidianBlack],
        center: .top,
        startRadius: 0,
        endRadius: 650
    )

    static let hero = LinearGradient(colors: [primarySoft, primary, primaryDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    static let heroSoft = LinearGradient(colors: [blobLight.opacity(0.95), lilac],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let income = LinearGradient(colors: [mint, Color(red: 0.32, green: 0.72, blue: 0.98)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    static let expense = LinearGradient(colors: [Color(red: 1.00, green: 0.68, blue: 0.58), rose],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)

    static func categoryColor(_ name: String) -> Color {
        switch name {
        case "餐饮": return Color(red: 1.00, green: 0.65, blue: 0.47)
        case "交通": return Color(red: 0.42, green: 0.72, blue: 1.00)
        case "购物": return Color(red: 0.85, green: 0.57, blue: 0.99)
        case "居家": return Color(red: 0.42, green: 0.84, blue: 0.78)
        case "娱乐": return Color(red: 1.00, green: 0.44, blue: 0.70)
        case "医疗": return Color(red: 0.98, green: 0.55, blue: 0.57)
        case "学习": return Color(red: 0.67, green: 0.71, blue: 1.00)
        case "旅行": return Color(red: 0.36, green: 0.80, blue: 0.92)
        case "宠物": return Color(red: 0.98, green: 0.71, blue: 0.42)
        case "工资": return Palette.mint
        case "理财": return Color(red: 0.73, green: 0.64, blue: 1.00)
        default: return Palette.primarySoft
        }
    }

    static func categoryGradient(_ name: String) -> LinearGradient {
        LinearGradient(colors: [categoryColor(name), categoryColor(name).opacity(0.55)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - 圆角刻度（连续曲率超椭圆，观感更顺滑）

enum Radius {
    static let hero: CGFloat = 42
    static let card: CGFloat = 34
    static let tile: CGFloat = 26
    static let chip: CGFloat = 18
    static let small: CGFloat = 13
    static let button: CGFloat = 22
}

extension View {
    /// 连续曲率圆角（Apple 超椭圆），替代默认圆角更顺滑
    func squircle(_ r: CGFloat = Radius.card) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: r, style: .continuous)
    }

    /// 液态玻璃面板：用 iOS 26 原生 glassEffect，并加一层顶缘镜面高光。
    ///
    /// 透亮度靠「低不透明度 + 镜面高光 + 内缘折射」做出来，而不是靠加白色雾。
    @ViewBuilder
    func glassPanel(_ r: CGFloat = Radius.card, strong: Bool = false, interactive: Bool = false, tiltable: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        let base = Group {
            if strong {
                self.glassEffect(interactive ? .regular.tint(Palette.glassTint).interactive()
                                            : .regular.tint(Palette.glassTint), in: shape)
                    .overlay(specularRim(shape, opacity: 0.50))
            } else {
                self.glassEffect(interactive ? .clear.interactive() : .clear, in: shape)
                    .overlay(specularRim(shape, opacity: 0.34))
            }
        }
        if tiltable || interactive {
            base.tiltAndSheen(maxAngle: 7.0, cornerRadius: r)
        } else {
            base
        }
    }

    /// 顶缘镜面高光 + 内缘折射（液态玻璃的「亮边」就在这里）。
    private func specularRim(_ shape: RoundedRectangle, opacity: Double) -> some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(opacity), Color.white.opacity(opacity * 0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.1
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    /// 玻璃卡内部的小色块
    func innerTile(_ r: CGFloat = Radius.chip, opacity: Double = 0.10) -> some View {
        self.background(Palette.primary.opacity(opacity), in: RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    func cardTitle() -> some View {
        self.font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(Palette.ink)
    }

    func labelText() -> some View {
        self.font(.system(.footnote, design: .rounded).weight(.medium))
            .foregroundStyle(Palette.ink.opacity(0.65))
    }
}

// MARK: - 区块标题

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionTitle: String = "全部"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).cardTitle()
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(Palette.ink.opacity(0.55))
                }
            }
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Palette.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}


// ============================================================================
// 7 项高级流体/物理/拟态交互动效组件 (iOS 26 液态玻璃进阶)
// ============================================================================

// MARK: - 1. 平稳微拟态卡片容器（已完全移除 3D 透视倾斜与手指镜像光斑，杜绝抖动，保持平稳高级沉浸感）

struct TiltAndSheenModifier: ViewModifier {
    var maxAngle: Double = 7.0
    var cornerRadius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func tiltAndSheen(maxAngle: Double = 7.0, cornerRadius: CGFloat = Radius.card) -> some View {
        self
    }
}

// MARK: - 紫晶呼吸弥散背光
struct PurpleBreathingBacklight: ViewModifier {
    @State private var breathe = false
    var cornerRadius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Palette.neonViolet.opacity(breathe ? 0.32 : 0.12))
                    .blur(radius: breathe ? 26 : 14)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
    }
}

extension View {
    func purpleBreathingBacklight(cornerRadius: CGFloat = Radius.card) -> some View {
        self.modifier(PurpleBreathingBacklight(cornerRadius: cornerRadius))
    }
}

// MARK: - 双层紫晶发光环形进度仪表盘 (GlowDoubleRing)
struct GlowDoubleRing: View {
    var progress: Double
    var size: CGFloat = 88
    var label: String = "已使用"

    var body: some View {
        let pct = Int((progress * 100).rounded())
        ZStack {
            Circle()
                .fill(Palette.neonViolet.opacity(0.35))
                .frame(width: size * 0.9, height: size * 0.9)
                .blur(radius: 12)

            Circle()
                .stroke(Color(red: 0.23, green: 0.12, blue: 0.39).opacity(0.6), lineWidth: 6)
                .frame(width: size * 0.88, height: size * 0.88)

            Circle()
                .trim(from: 0, to: max(0.02, CGFloat(min(progress, 1.0))))
                .stroke(
                    AngularGradient(
                        colors: [Palette.auroraPurple, Palette.neonViolet, Color(red: 0.75, green: 0.52, blue: 0.99), Color(red: 0.22, green: 0.74, blue: 0.97), Palette.auroraPurple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.88, height: size * 0.88)

            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                .frame(width: size * 0.70, height: size * 0.70)

            Circle()
                .trim(from: 0, to: max(0.04, CGFloat(min(progress * 0.7, 0.7))))
                .stroke(Color(red: 0.75, green: 0.52, blue: 0.99).opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size * 0.70, height: size * 0.70)

            VStack(spacing: 1) {
                Text("\(pct)%")
                    .font(.system(size: size * 0.22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: size * 0.12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.85, green: 0.71, blue: 1.0).opacity(0.9))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 3D 凸起切面紫晶按键 (JewelTileButton)
struct JewelTileButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.35, green: 0.16, blue: 0.58), Color(red: 0.22, green: 0.08, blue: 0.38), Color(red: 0.14, green: 0.05, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Palette.neonViolet.opacity(0.45), lineWidth: 1.2)
                        )
                        .shadow(color: Palette.neonViolet.opacity(0.35), radius: 10, y: 5)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 3)

                    VStack {
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 4)
                        .padding(.top, 1)
                        Spacer()
                    }

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Palette.primaryDeep.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: symbol)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 1.0))
                        )
                }
                .frame(width: 66, height: 66)

                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.91, green: 0.84, blue: 1.0))
            }
        }
        .springButton()
    }
}

// MARK: - 45 度旋转紫晶切面菱形 FAB (DiamondJewelFab)
struct DiamondJewelFab: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.75, green: 0.52, blue: 0.99), Color(red: 0.49, green: 0.13, blue: 0.81), Color(red: 0.30, green: 0.11, blue: 0.58)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.65), lineWidth: 1.4)
                    )
                    .rotationEffect(.degrees(45))
                    .frame(width: 52, height: 52)
                    .shadow(color: Palette.neonViolet.opacity(0.65), radius: 14, y: 4)
                    .shadow(color: Palette.amberGlow.opacity(0.35), radius: 16, y: 6)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .springButton()
    }
}

// MARK: - 底部 Dock 后方琥珀金橙色弧形背光 (AmberHalo)
struct AmberHalo: View {
    var body: some View {
        RadialGradient(
            colors: [Palette.amberGlow.opacity(0.65), Color(red: 0.85, green: 0.47, blue: 0.02).opacity(0.35), Color.clear],
            center: .bottom,
            startRadius: 0,
            endRadius: 90
        )
        .frame(width: 180, height: 60)
        .clipShape(Capsule())
        .allowsHitTesting(false)
    }
}


// MARK: - 2. 胶囊按钮向弹窗面板流体形态变换

struct FluidMorphCapsuleView<Collapsed: View, Expanded: View>: View {
    let collapsed: Collapsed
    let expanded: Expanded
    var collapsedSize: CGSize = CGSize(width: 58, height: 58)
    var expandedSize: CGSize = CGSize(width: 340, height: 460)
    var collapsedRadius: CGFloat = 29
    var expandedRadius: CGFloat = Radius.card
    var onToggle: ((Bool) -> Void)? = nil

    @State private var isExpanded = false

    init(
        collapsedSize: CGSize = CGSize(width: 58, height: 58),
        expandedSize: CGSize = CGSize(width: 340, height: 460),
        collapsedRadius: CGFloat = 29,
        expandedRadius: CGFloat = Radius.card,
        onToggle: ((Bool) -> Void)? = nil,
        @ViewBuilder collapsed: () -> Collapsed,
        @ViewBuilder expanded: () -> Expanded
    ) {
        self.collapsedSize = collapsedSize
        self.expandedSize = expandedSize
        self.collapsedRadius = collapsedRadius
        self.expandedRadius = expandedRadius
        self.onToggle = onToggle
        self.collapsed = collapsed()
        self.expanded = expanded()
    }

    var body: some View {
        let currentWidth = isExpanded ? expandedSize.width : collapsedSize.width
        let currentHeight = isExpanded ? expandedSize.height : collapsedSize.height
        let currentRadius = isExpanded ? expandedRadius : collapsedRadius

        ZStack {
            if isExpanded {
                expanded
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                collapsed
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
        .frame(width: currentWidth, height: currentHeight)
        .glassPanel(currentRadius, strong: true, interactive: true)
        .contentShape(RoundedRectangle(cornerRadius: currentRadius, style: .continuous))
        .onTapGesture {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) {
                isExpanded.toggle()
                onToggle?(isExpanded)
            }
        }
    }
}

// MARK: - 4. 阻尼橡皮筋回弹底部抽屉（根据手势滑动速度自动计算吸附）

struct RubberBandSheetModifier: ViewModifier {
    var onDismiss: () -> Void
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        let dy = val.translation.height
                        if dy < 0 {
                            let over = -dy
                            offset = -18.0 * log(1.0 + Double(over) / 18.0)
                        } else {
                            offset = dy
                        }
                    }
                    .onEnded { val in
                        let velocity = val.predictedEndTranslation.height
                        if velocity > 180 || val.translation.height > 140 {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                onDismiss()
                            }
                        } else {
                            withAnimation(.interpolatingSpring(stiffness: 320, damping: 24)) {
                                offset = 0
                            }
                        }
                    }
            )
    }
}

extension View {
    func rubberBandSheet(onDismiss: @escaping () -> Void) -> some View {
        self.modifier(RubberBandSheetModifier(onDismiss: onDismiss))
    }
}

// MARK: - 5. 旋转渐变描边与呼吸弥散背光

struct AuraBorderModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.card
    var borderWidth: CGFloat = 1.6
    var colors: [Color] = [Palette.primary, Palette.lilac, Palette.rose, Palette.mint, Palette.primary]

    @State private var rotation: Double = 0
    @State private var breathing: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                shape
                    .strokeBorder(
                        AngularGradient(
                            colors: colors,
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: borderWidth
                    )
                    .allowsHitTesting(false)
            }
            .background {
                shape
                    .fill(colors.first ?? Palette.primary)
                    .opacity(breathing ? 0.32 : 0.14)
                    .blur(radius: breathing ? 28 : 18)
                    .scaleEffect(breathing ? 1.03 : 0.98)
                    .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}

extension View {
    func auraBorder(cornerRadius: CGFloat = Radius.card, borderWidth: CGFloat = 1.6) -> some View {
        self.modifier(AuraBorderModifier(cornerRadius: cornerRadius, borderWidth: borderWidth))
    }
}

// MARK: - 6. 列表元素交错弹性向上滑入

struct StaggeredSlideInModifier: ViewModifier {
    let index: Int
    var offsetY: CGFloat = 20
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : offsetY)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                let delay = Double(min(index, 8)) * 0.035
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 22).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func staggeredSlideIn(index: Int, offsetY: CGFloat = 20) -> some View {
        self.modifier(StaggeredSlideInModifier(index: index, offsetY: offsetY))
    }
}

// MARK: - 7. 物理弹性压缩与 Spring Overshoot 按钮样式

struct SpringOvershootButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = Radius.button

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.black.opacity(0.30), Color.black.opacity(0.12)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2.5
                        )
                        .blur(radius: 1.5)
                        .allowsHitTesting(false)
                }
            }
            .animation(
                configuration.isPressed
                    ? .easeOut(duration: 0.10)
                    : .interpolatingSpring(stiffness: 350, damping: 14),
                value: configuration.isPressed
            )
    }
}

extension View {
    func springButton(cornerRadius: CGFloat = Radius.button) -> some View {
        self.buttonStyle(SpringOvershootButtonStyle(cornerRadius: cornerRadius))
    }
}
