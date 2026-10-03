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

// MARK: - 1. 跟随触摸位置的 3D 透视倾斜与镜像反射流光（松手带 spring 阻尼回正）

struct TiltAndSheenModifier: ViewModifier {
    var maxAngle: Double = 7.0
    var cornerRadius: CGFloat = Radius.card

    @State private var dragOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var isTouching: Bool = false

    func body(content: Content) -> some View {
        let halfW = max(viewSize.width / 2, 1)
        let halfH = max(viewSize.height / 2, 1)
        let normX = min(max(Double(dragOffset.width / halfW), -1.0), 1.0)
        let normY = min(max(Double(dragOffset.height / halfH), -1.0), 1.0)
        let pitch = -normY * maxAngle
        let roll = normX * maxAngle
        let unitX = (normX + 1.0) / 2.0
        let unitY = (normY + 1.0) / 2.0

        content
            .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(roll), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .overlay {
                if isTouching {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.36), Color.white.opacity(0.08), Color.clear],
                                center: UnitPoint(x: unitX, y: unitY),
                                startRadius: 0,
                                endRadius: max(viewSize.width, viewSize.height) * 0.75
                            )
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: TiltSizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(TiltSizeKey.self) { size in
                viewSize = size
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        isTouching = true
                        dragOffset = CGSize(
                            width: val.location.x - halfW,
                            height: val.location.y - halfH
                        )
                    }
                    .onEnded { _ in
                        withAnimation(.interpolatingSpring(stiffness: 280, damping: 20)) {
                            isTouching = false
                            dragOffset = .zero
                        }
                    }
            )
    }
}

private struct TiltSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func tiltAndSheen(maxAngle: Double = 7.0, cornerRadius: CGFloat = Radius.card) -> some View {
        self.modifier(TiltAndSheenModifier(maxAngle: maxAngle, cornerRadius: cornerRadius))
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
