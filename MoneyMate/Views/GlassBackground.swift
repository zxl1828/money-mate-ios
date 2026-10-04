import SwiftUI

/// 紫色流光背景：明亮通透，深浅模式同构自适应，确保液态玻璃高通透感
struct GlassBackground: View {
    @State private var drift = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Palette.dynamicBackground

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                Circle()
                    .fill(Palette.neonViolet.opacity(colorScheme == .dark ? 0.35 : 0.16))
                    .frame(width: w * 0.86)
                    .blur(radius: 80)
                    .position(x: w * (drift ? 0.30 : 0.16), y: h * 0.16)
                Circle()
                    .fill(Palette.auroraPurple.opacity(colorScheme == .dark ? 0.28 : 0.14))
                    .frame(width: w * 0.72)
                    .blur(radius: 70)
                    .position(x: w * (drift ? 0.70 : 0.86), y: h * (drift ? 0.46 : 0.34))
                Circle()
                    .fill(Palette.rose.opacity(colorScheme == .dark ? 0.20 : 0.10))
                    .frame(width: w * 0.60)
                    .blur(radius: 85)
                    .position(x: w * (drift ? 0.42 : 0.28), y: h * (drift ? 0.88 : 0.76))
                Circle()
                    .fill(Palette.primary.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    .frame(width: w * 0.56)
                    .blur(radius: 90)
                    .position(x: w * (drift ? 0.86 : 0.68), y: h * (drift ? 0.84 : 0.96))
            }

            DoodleLayer()
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 22).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }
}
