import SwiftUI

/// 紫色流光背景：明亮通透，让液态玻璃的高通透感成立
struct GlassBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.lavender, Palette.lilac, Palette.lilac],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                Circle()
                    .fill(Palette.primarySoft.opacity(0.60))
                    .frame(width: w * 0.86)
                    .blur(radius: 80)
                    .position(x: w * (drift ? 0.30 : 0.16), y: h * 0.16)
                Circle()
                    .fill(Palette.blobLight.opacity(0.75))
                    .frame(width: w * 0.72)
                    .blur(radius: 70)
                    .position(x: w * (drift ? 0.70 : 0.86), y: h * (drift ? 0.46 : 0.34))
                Circle()
                    .fill(Palette.rose.opacity(0.32))
                    .frame(width: w * 0.60)
                    .blur(radius: 85)
                    .position(x: w * (drift ? 0.42 : 0.28), y: h * (drift ? 0.88 : 0.76))
                Circle()
                    .fill(Palette.primary.opacity(0.32))
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
