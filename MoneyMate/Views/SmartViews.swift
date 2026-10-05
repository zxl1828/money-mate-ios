import SwiftUI

/// 隐私模式：整页模糊，点一下显示；切后台自动重新盖住
struct PrivacyWrapper<Content: View>: View {
    let content: Content

    @Environment(\.scenePhase) private var scenePhase
    @State private var revealed = false
    @ObservedObject private var privacy = PrivacyState.shared

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if privacy.enabled && !revealed {
                ZStack {
                    content
                        .blur(radius: 16)
                        .allowsHitTesting(false)
                    VStack(spacing: 8) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Palette.primary)
                        Text("隐私模式")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                        Text("点一下显示")
                            .font(.caption2)
                            .foregroundStyle(Palette.ink.opacity(0.6))
                    }
                    .padding(18)
                    .glassPanel(Radius.tile, strong: true)
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { revealed = true } }
            } else {
                content
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { revealed = false }
        }
    }
}

/// 快捷模板条：点一下记一笔，长按删除

/// 新建模板
