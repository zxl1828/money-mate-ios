import SwiftUI

/// 明亮、有光的渐变背景：让玻璃的“高通透、可见背景内容”效果成立。
struct GlassBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.62, green: 0.78, blue: 0.95),
                    Color(red: 0.95, green: 0.83, blue: 0.72),
                    Color(red: 0.80, green: 0.90, blue: 0.86)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: proxy.size.width * 0.7)
                    .blur(radius: 70)
                    .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.2)

                Circle()
                    .fill(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.55))
                    .frame(width: proxy.size.width * 0.6)
                    .blur(radius: 80)
                    .position(x: proxy.size.width * 0.8, y: proxy.size.height * 0.55)

                Circle()
                    .fill(Color(red: 1.0, green: 0.5, blue: 0.4).opacity(0.45))
                    .frame(width: proxy.size.width * 0.55)
                    .blur(radius: 75)
                    .position(x: proxy.size.width * 0.35, y: proxy.size.height * 0.85)
            }
        }
        .ignoresSafeArea()
    }
}
