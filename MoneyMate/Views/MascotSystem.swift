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
    private var primary: Color { light ? Color(red: 0.46, green: 0.30, blue: 0.80) : Color(red: 0.72, green: 0.54, blue: 1.0) }
    private var pearl: Color { light ? Color(red: 0.98, green: 0.97, blue: 1.0) : Color(red: 0.16, green: 0.10, blue: 0.28) }
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
        switch kind {
        case .amethystPixiu:
            ZStack {
                Capsule().fill(LinearGradient(colors: [pearl, primary.opacity(0.84), primary.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: size * 0.78, height: size * 0.82)
                HStack(spacing: size * 0.42) { horn; horn }.offset(y: -size * 0.40)
                Circle().fill(Color.white.opacity(0.85)).frame(width: size * 0.18).overlay(Circle().fill(primary).frame(width: size * 0.08)).offset(x: -size * 0.16, y: -size * 0.08)
                Circle().fill(Color.white.opacity(0.85)).frame(width: size * 0.18).overlay(Circle().fill(primary).frame(width: size * 0.08)).offset(x: size * 0.16, y: -size * 0.08)
                Circle().fill(Palette.amberGlow).frame(width: size * 0.20).offset(y: size * 0.20)
            }
        case .lavenderHamster:
            ZStack {
                Circle().fill(pearl).frame(width: size * 0.82).overlay(Circle().stroke(primary.opacity(0.5), lineWidth: 1.3))
                HStack(spacing: size * 0.48) { ear; ear }.offset(y: -size * 0.34)
                HStack(spacing: size * 0.18) { eye; eye }.offset(y: -size * 0.08)
                Capsule().fill(Palette.amberGlow).frame(width: size * 0.28, height: size * 0.16).overlay(Text("¥").font(.system(size: size * 0.10, weight: .bold)).foregroundStyle(Palette.textPrimary)).offset(y: size * 0.26)
            }
        case .liquidDroplet:
            ZStack {
                ShapeDroplet().fill(LinearGradient(colors: [Color.white.opacity(0.9), primary.opacity(0.5), primary.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: size * 0.72, height: size * 0.92)
                Image(systemName: "sparkles").font(.system(size: size * 0.22, weight: .semibold)).foregroundStyle(Palette.amberGlow.opacity(0.85)).offset(y: size * 0.12)
                Circle().fill(Color.white.opacity(0.82)).frame(width: size * 0.10).offset(x: -size * 0.18, y: -size * 0.26)
            }
        case .prismCat:
            ZStack {
                CatShape().fill(LinearGradient(colors: [pearl, primary.opacity(0.78), light ? Palette.primarySoft.opacity(0.34) : Palette.obsidianBlack.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: size * 0.82, height: size * 0.86)
                HStack(spacing: size * 0.28) { Circle().fill(Palette.mint).frame(width: size * 0.10); Circle().fill(Palette.mint).frame(width: size * 0.10) }.offset(y: -size * 0.08)
                Capsule().fill(Color.white.opacity(0.78)).frame(width: size * 0.28, height: size * 0.06).offset(y: size * 0.28)
            }
        }
    }

    private var specular: some View { Capsule().fill(LinearGradient(colors: [.white.opacity(light ? 0.82 : 0.25), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: size * 0.12, height: size * 0.52).rotationEffect(.degrees(25)).offset(x: -size * 0.22, y: -size * 0.18).allowsHitTesting(false) }
    private var horn: some View { Capsule().fill(LinearGradient(colors: [.white, Palette.amberGlow.opacity(0.65)], startPoint: .top, endPoint: .bottom)).frame(width: size * 0.10, height: size * 0.28).rotationEffect(.degrees(-12)) }
    private var ear: some View { Circle().fill(Color.white.opacity(light ? 0.76 : 0.24)).frame(width: size * 0.22).overlay(Circle().stroke(primary.opacity(0.55), lineWidth: 1)) }
    private var eye: some View { Circle().fill(Color.white).frame(width: size * 0.15).overlay(Circle().fill(Color(red: 0.12, green: 0.08, blue: 0.20)).frame(width: size * 0.07)) }
}

struct ShapeDroplet: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: rect.midX, y: rect.minY)); p.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY * 1.15), control1: CGPoint(x: rect.maxX * 0.92, y: rect.height * 0.28), control2: CGPoint(x: rect.maxX, y: rect.height * 0.78)); p.addCurve(to: CGPoint(x: rect.minX, y: rect.midY * 1.15), control1: CGPoint(x: 0, y: rect.height * 0.78), control2: CGPoint(x: rect.width * 0.08, y: rect.height * 0.28)); p.closeSubpath(); return p
    }
}

struct CatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: rect.width * 0.20, y: rect.height * 0.28)); p.addLine(to: CGPoint(x: rect.width * 0.28, y: 0)); p.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.18)); p.addLine(to: CGPoint(x: rect.width * 0.72, y: 0)); p.addLine(to: CGPoint(x: rect.width * 0.80, y: rect.height * 0.28)); p.addCurve(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.88), control1: CGPoint(x: rect.width * 0.98, y: rect.height * 0.40), control2: CGPoint(x: rect.width * 0.94, y: rect.height * 0.92)); p.addCurve(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.88), control1: CGPoint(x: rect.width * 0.06, y: rect.height * 0.92), control2: CGPoint(x: rect.width * 0.02, y: rect.height * 0.40)); p.closeSubpath(); return p
    }
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
