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
                // 光斑全部改用径向渐变：视觉与原来的大半径 blur 一致，
                // 但每秒 60 帧的模糊运算变成一次渐变绘制（安卓端同款修法，实测掉帧消失）。
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Palette.neonViolet.opacity(colorScheme == .dark ? 0.35 : 0.16),
                                Palette.neonViolet.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.56
                        )
                    )
                    .frame(width: w * 1.12)
                    .position(x: w * (drift ? 0.30 : 0.16), y: h * 0.16)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Palette.auroraPurple.opacity(colorScheme == .dark ? 0.28 : 0.14),
                                Palette.auroraPurple.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.47
                        )
                    )
                    .frame(width: w * 0.94)
                    .position(x: w * (drift ? 0.70 : 0.86), y: h * (drift ? 0.46 : 0.34))
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Palette.rose.opacity(colorScheme == .dark ? 0.20 : 0.10),
                                Palette.rose.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.39
                        )
                    )
                    .frame(width: w * 0.78)
                    .position(x: w * (drift ? 0.42 : 0.28), y: h * (drift ? 0.88 : 0.76))
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Palette.primary.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                Palette.primary.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: w * 0.36
                        )
                    )
                    .frame(width: w * 0.73)
                    .position(x: w * (drift ? 0.86 : 0.68), y: h * (drift ? 0.84 : 0.96))
            }

            DoodleLayer()
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 22).repeatForever(autoreverses: true), value: drift)
        .onAppear { drift = true }
    }
}
