import SwiftUI

enum MascotKind: String, CaseIterable, Identifiable {
    case amethystPixiu
    case lavenderHamster
    case liquidDroplet
    case prismCat

    var id: String { rawValue }
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

struct CoinBuddy: View {
    var mood: MascotMood = .happy
    var size: CGFloat = 92
    var kindOverride: MascotKind? = nil
    @AppStorage("moneymate.mascot.kind") private var rawKind = MascotKind.amethystPixiu.rawValue
    @State private var pressed = false
    @Environment(\.colorScheme) private var scheme

    private var kind: MascotKind { kindOverride ?? MascotKind(rawValue: rawKind) ?? .amethystPixiu }
    private var light: Bool { scheme == .light }
    private var glow: Color { mood == .worried || mood == .panic ? Palette.rose : Palette.amberGlow }

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [glow.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: size * 0.78))
            crystalBody
            specular
        }
        .frame(width: size * 1.45, height: size * 1.45)
        .scaleEffect(pressed ? 0.92 : 1)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.68)) { pressed = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 160_000_000)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { pressed = false }
            }
            Haptics.tap()
        }
    }

    @ViewBuilder private var crystalBody: some View {
        Image(kind.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.16, height: size * 1.16)
            .accessibilityLabel(kind.name)
    }

    private var specular: some View { Capsule().fill(LinearGradient(colors: [.white.opacity(light ? 0.82 : 0.25), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: size * 0.12, height: size * 0.52).rotationEffect(.degrees(25)).offset(x: -size * 0.22, y: -size * 0.18).allowsHitTesting(false) }
}

struct MascotPicker: View {
    @AppStorage("moneymate.mascot.kind") private var rawKind = MascotKind.amethystPixiu.rawValue
    private var selection: Binding<MascotKind> { Binding(get: { MascotKind(rawValue: rawKind) ?? .amethystPixiu }, set: { rawKind = $0.rawValue }) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "吉祥物伴侣", subtitle: "选择一个陪你管理每一笔钱")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MascotKind.allCases) { kind in
                    Button { selection.wrappedValue = kind; Haptics.select() } label: {
                        VStack(spacing: 3) { CoinBuddy(size: 52, kindOverride: kind).allowsHitTesting(false); Text(kind.name).font(.system(.footnote, design: .rounded).weight(.semibold)); Text(kind.tagline).font(.caption2).foregroundStyle(Palette.textSecondary) }
                            .frame(maxWidth: .infinity).padding(.vertical, 10).overlay(alignment: .topTrailing) { if selection.wrappedValue == kind { Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.amberGlow).padding(8) } }
                            .background(selection.wrappedValue == kind ? Palette.primary.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selection.wrappedValue == kind ? Palette.primary : Palette.textSecondary.opacity(0.16), lineWidth: selection.wrappedValue == kind ? 1.5 : 1))
                    }.buttonStyle(.plain)
                }
            }
        }.padding(16).glassPanel(Radius.card, strong: true)
    }
}
