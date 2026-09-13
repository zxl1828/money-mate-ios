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
    static let glassTint = adaptive(light: (1, 1, 1), dark: (1, 1, 1), alpha: (0.30, 0.12))
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

    /// 液态玻璃面板：材质与透明度保持 iOS 26 原生 glassEffect
    @ViewBuilder
    func glassPanel(_ r: CGFloat = Radius.card, strong: Bool = false, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        if strong {
            self.glassEffect(interactive ? .regular.tint(Palette.glassTint).interactive()
                                        : .regular.tint(Palette.glassTint), in: shape)
        } else {
            self.glassEffect(interactive ? .clear.interactive() : .clear, in: shape)
        }
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
