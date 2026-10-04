import SwiftUI
import UIKit

// MARK: - 紫色主题色板（全局统一，WCAG AA 双模式同构）

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

    // MARK: - WCAG AA 双模式语义色彩标准
    /// 主文本与核心金额：深色纯白 #FFFFFF，浅色深邃曜黑紫 #1A0F2E（对比度均 > 15:1，远超 7:1 规范）
    static let textPrimary = adaptive(
        light: (26/255.0, 15/255.0, 46/255.0),
        dark: (1.0, 1.0, 1.0)
    )

    /// 次级说明与标签：深色高明度淡紫罗兰 #D8B4FE，浅色浓郁深紫 #581C87（对比度均 > 8:1，远超 4.5:1 规范）
    static let textSecondary = adaptive(
        light: (88/255.0, 28/255.0, 135/255.0),
        dark: (216/255.0, 180/255.0, 254/255.0)
    )

    /// 辅助刻度与说明：深色冷中性灰 #94A3B8，浅色中深灰 #4B5563（对比度 > 5:1）
    static let textTertiary = adaptive(
        light: (75/255.0, 85/255.0, 99/255.0),
        dark: (148/255.0, 163/255.0, 184/255.0)
    )

    /// 保持向前兼容，ink 映射到高对比度主文本色
    static let ink = textPrimary

    static let primary = adaptive(
        light: (126/255.0, 34/255.0, 206/255.0), // #7E22CE
        dark: (168/255.0, 85/255.0, 247/255.0)  // #A855F7
    )
    static let primaryDeep = adaptive(
        light: (88/255.0, 28/255.0, 135/255.0),
        dark: (147/255.0, 51/255.0, 234/255.0)
    )
    static let primarySoft = adaptive(
        light: (147/255.0, 51/255.0, 234/255.0),
        dark: (192/255.0, 132/255.0, 252/255.0)
    )
    static let lilac = adaptive(light: (0.90, 0.87, 1.00), dark: (0.22, 0.19, 0.34))
    static let lavender = adaptive(light: (0.97, 0.96, 1.00), dark: (0.10, 0.08, 0.16))
    static let mint = adaptive(
        light: (16/255.0, 185/255.0, 129/255.0),
        dark: (52/255.0, 211/255.0, 153/255.0)
    )
    static let rose = adaptive(
        light: (244/255.0, 63/255.0, 94/255.0),
        dark: (251/255.0, 113/255.0, 133/255.0)
    )
    /// 玻璃叠加层
    static let glassTint = adaptive(light: (1, 1, 1), dark: (1, 1, 1), alpha: (0.14, 0.07))
    /// 背景光斑用的浅色块
    static let blobLight = adaptive(light: (1, 1, 1), dark: (0.34, 0.29, 0.55))

    // MARK: - 紫晶暗黑与白昼微拟物设计令牌
    static let obsidianBlack = Color(red: 11/255.0, green: 8/255.0, blue: 20/255.0) // #0B0814
    static let amethystDeep = Color(red: 23/255.0, green: 16/255.0, blue: 38/255.0)  // #171026
    static let neonViolet = Color(red: 168/255.0, green: 85/255.0, blue: 247/255.0) // #A855F7
    static let auroraPurple = Color(red: 139/255.0, green: 92/255.0, blue: 246/255.0)// #8B5CF6
    static let lightLilac = Color(red: 216/255.0, green: 180/255.0, blue: 254/255.0) // #D8B4FE
    static let amberGlow = Color(red: 245/255.0, green: 158/255.0, blue: 11/255.0)   // #F59E0B
    static let amberWarm = Color(red: 251/255.0, green: 191/255.0, blue: 36/255.0)   // #FBBF24

    /// 深色背景：深邃紫曜黑径向渐变（#0B0814 至 #171026）
    /// 浅色背景：纯净珠光浅紫雾白渐变（#F6F4FA 至 #EDE8F6）
    static let bgStart = adaptive(
        light: (246/255.0, 244/255.0, 250/255.0),
        dark: (11/255.0, 8/255.0, 20/255.0)
    )
    static let bgEnd = adaptive(
        light: (237/255.0, 232/255.0, 246/255.0),
        dark: (23/255.0, 16/255.0, 38/255.0)
    )

    static var dynamicBackground: some View {
        LinearGradient(
            colors: [bgStart, bgEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var amethystBg: some View {
        dynamicBackground
    }

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

// MARK: - 圆角刻度（连续曲率超椭圆）

enum Radius {
    static let hero: CGFloat = 42
    static let card: CGFloat = 34
    static let tile: CGFloat = 26
    static let chip: CGFloat = 18
    static let small: CGFloat = 13
    static let button: CGFloat = 22
}

extension View {
    func squircle(_ r: CGFloat = Radius.card) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: r, style: .continuous)
    }

    // MARK: - 通透液态玻璃规范容器 (Clear Liquid Glass Modifier)
    /// 严禁发灰、发脏单层磨砂雾面，基于原生薄层材质构建容器背景，
    /// 叠加极淡紫光渐变、1pt Specular Rim 顶光高光多段线性渐变边缘与双层悬浮阴影。
    func clearLiquidGlass(cornerRadius: CGFloat = Radius.card, interactive: Bool = false) -> some View {
        self.modifier(ClearLiquidGlassModifier(cornerRadius: cornerRadius, interactive: interactive))
    }

    /// 向前兼容玻璃面板接口，直接调用通透液态玻璃规范
    @ViewBuilder
    func glassPanel(_ r: CGFloat = Radius.card, strong: Bool = false, interactive: Bool = false, tiltable: Bool = false) -> some View {
        self.clearLiquidGlass(cornerRadius: r, interactive: interactive)
    }

    /// 玻璃卡内部的小色块
    func innerTile(_ r: CGFloat = Radius.chip, opacity: Double = 0.10) -> some View {
        self.background(Palette.primary.opacity(opacity), in: RoundedRectangle(cornerRadius: r, style: .continuous))
    }

    func cardTitle() -> some View {
        self.font(.system(.title3, design: .rounded).weight(.bold))
            .foregroundStyle(Palette.textPrimary)
    }

    func labelText() -> some View {
        self.font(.system(.footnote, design: .rounded).weight(.medium))
            .foregroundStyle(Palette.textSecondary)
    }
}

// MARK: - 通透液态玻璃容器修饰符 (ClearLiquidGlassModifier)

struct ClearLiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = Radius.card
    var interactive: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark
                                      ? Palette.neonViolet.opacity(0.08)
                                      : Color.white.opacity(0.40), location: 0.0),
                                .init(color: colorScheme == .dark
                                      ? Palette.neonViolet.opacity(0.02)
                                      : Palette.primarySoft.opacity(0.05), location: 0.5),
                                .init(color: Color.clear, location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                // 1pt Specular Rim 多段线性渐变高光边框模拟顶光折射
                shape
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: colorScheme == .dark
                                      ? Color.white.opacity(0.55)
                                      : Color.white.opacity(0.90), location: 0.0),
                                .init(color: colorScheme == .dark
                                      ? Color.white.opacity(0.20)
                                      : Color.white.opacity(0.50), location: 0.35),
                                .init(color: colorScheme == .dark
                                      ? Palette.neonViolet.opacity(0.35)
                                      : Palette.primarySoft.opacity(0.25), location: 0.75),
                                .init(color: colorScheme == .dark
                                      ? Palette.neonViolet.opacity(0.12)
                                      : Palette.primarySoft.opacity(0.10), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                    .allowsHitTesting(false)
            }
            // 立体投影：底层深景深柔和软阴影 + 表层小半径紫晶环境光晕
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.45)
                    : Color(red: 0.30, green: 0.20, blue: 0.45).opacity(0.12),
                radius: 18,
                x: 0,
                y: 8
            )
            .shadow(
                color: Palette.neonViolet.opacity(colorScheme == .dark ? 0.22 : 0.08),
                radius: 8,
                x: 0,
                y: 2
            )
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
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
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

// MARK: - 1. 列表元素交错弹性入场系统 (Spring Cascade)
/// 物理参数标准：响应时长 0.52s，阻尼比 0.76，延迟索引递增 0.065s
/// 入场形变量：下沉 38pt，透明度 0，缩放 97% -> 归位 0，透明度 1.0，尺寸 1.0

struct SpringCascadeModifier: ViewModifier {
    let index: Int
    var trigger: AnyHashable = 0
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .offset(y: hasAppeared ? 0 : 38)
            .opacity(hasAppeared ? 1.0 : 0)
            .scaleEffect(hasAppeared ? 1.0 : 0.97)
            .onAppear {
                animateIn()
            }
            .onChange(of: trigger) { _, _ in
                hasAppeared = false
                animateIn()
            }
    }

    private func animateIn() {
        let delay = Double(index) * 0.065
        withAnimation(.spring(response: 0.52, dampingFraction: 0.76).delay(delay)) {
            hasAppeared = true
        }
    }
}

extension View {
    func springCascade(index: Int, trigger: AnyHashable = 0) -> some View {
        self.modifier(SpringCascadeModifier(index: index, trigger: trigger))
    }

    func staggeredSlideIn(index: Int) -> some View {
        self.springCascade(index: index)
    }
}

// MARK: - 2. 液体凝胶物理弹性按压样式 (GelPressButtonStyle)
/// 按压时触发微缩放与内阴影深度变化，释放时 Spring Overshoot 顺滑归位

struct GelPressButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.black.opacity(0.40), Palette.neonViolet.opacity(0.25)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2.2
                        )
                        .blur(radius: 1.2)
                        .allowsHitTesting(false)
                }
            }
            .animation(
                configuration.isPressed
                    ? .easeOut(duration: 0.08)
                    : .interpolatingSpring(stiffness: 340, damping: 16),
                value: configuration.isPressed
            )
    }
}

// MARK: - 3. 四大金刚功能键（嵌套式晶石架构）
/// 外层托盘：横向通透液态玻璃胶囊基座
/// 内层按键：4 个独立微晶体按键悬浮于基座内，分层双色高对比度图标渲染

struct KeypadItemButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? LinearGradient(
                                    colors: [Color.white.opacity(0.12), Palette.neonViolet.opacity(0.16), Color(red: 0.12, green: 0.06, blue: 0.22).opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.95), Color(red: 0.95, green: 0.91, blue: 0.99), Color.white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(colorScheme == .dark ? 0.50 : 0.95), Palette.neonViolet.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.0
                                )
                        )
                        .shadow(
                            color: Palette.neonViolet.opacity(colorScheme == .dark ? 0.25 : 0.10),
                            radius: 6,
                            y: 3
                        )

                    // 图标采用高对比度双色分层模式：次级霓虹紫底圈 + 主轮廓实体色
                    ZStack {
                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Palette.neonViolet)
                            .offset(x: 0.6, y: 0.6)

                        Image(systemName: symbol)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
                .frame(width: 58, height: 58)

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GelPressButtonStyle(cornerRadius: 18))
    }
}

struct QuickActionsKeypad: View {
    var onAdd: () -> Void
    var onScan: () -> Void
    var onBudget: () -> Void
    var onRecurring: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            KeypadItemButton(title: "记账", symbol: "square.and.pencil", action: onAdd)
            KeypadItemButton(title: "扫描", symbol: "camera.viewfinder", action: onScan)
            KeypadItemButton(title: "预算", symbol: "chart.pie.fill", action: onBudget)
            KeypadItemButton(title: "周期", symbol: "arrow.triangle.2.circlepath", action: onRecurring)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .clearLiquidGlass(cornerRadius: 28)
    }
}

/// 兼容老接口
struct JewelTileButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        KeypadItemButton(title: title, symbol: symbol, action: action)
    }
}

// MARK: - 4. 3D 立体切面紫晶宝石按键 (DiamondJewelFab)
/// 顶部边缘清晰镜面高光，中心纯白符号微凸，按键四周投射扩散的紫罗兰色背光阴影

struct DiamondJewelFab: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // 四周扩散的紫罗兰色背光阴影
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.neonViolet.opacity(0.55))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(45))
                    .blur(radius: 12)

                // 3D 切面紫晶宝石主体
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.82, green: 0.60, blue: 1.00), location: 0.0),
                                .init(color: Color(red: 0.60, green: 0.28, blue: 0.95), location: 0.45),
                                .init(color: Color(red: 0.38, green: 0.12, blue: 0.70), location: 0.85),
                                .init(color: Color(red: 0.22, green: 0.06, blue: 0.45), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(45))
                    .frame(width: 52, height: 52)
                    .overlay(
                        // 顶部边缘清晰镜面高光
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color.white.opacity(0.95), location: 0.0),
                                        .init(color: Color.white.opacity(0.40), location: 0.30),
                                        .init(color: Palette.neonViolet.opacity(0.20), location: 0.70),
                                        .init(color: Color.clear, location: 1.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.6
                            )
                            .rotationEffect(.degrees(45))
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 10, y: 6)

                // 中心纯白微凸加号图标
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
            }
        }
        .buttonStyle(GelPressButtonStyle(cornerRadius: 16))
    }
}

// MARK: - 5. 底部 Dock 后方琥珀金橙色弧形背光 (AmberHalo)
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

// MARK: - 6. 双层紫晶发光环形进度仪表盘 (GlowDoubleRing)
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
                    .foregroundStyle(Palette.textPrimary)
                Text(label)
                    .font(.system(size: size * 0.12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(width: size, height: size)
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
                    .fill(Palette.neonViolet.opacity(breathe ? 0.30 : 0.10))
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

// MARK: - 7. 阻尼橡皮筋回弹底部抽屉
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

// MARK: - 8. 旋转渐变描边与呼吸弥散背光
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

// MARK: - 9. 物理弹性压缩与 Spring Overshoot 按钮样式
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

struct TiltAndSheenModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

extension View {
    func tiltAndSheen(maxAngle: Double = 7.0, cornerRadius: CGFloat = Radius.card) -> some View { self }
}
