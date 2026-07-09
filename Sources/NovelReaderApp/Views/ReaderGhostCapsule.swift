import SwiftUI

struct ReaderGhostCapsule: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    private var isRevealed: Bool {
        isHovered || model.activePanel != nil
    }

    var body: some View {
        ZStack {
            HStack(spacing: 4) {
                GhostCapsuleButton(
                    help: "目录",
                    isActive: model.activePanel == .toc
                ) {
                    model.togglePanel(.toc)
                } label: {
                    Image(systemName: "list.bullet")
                }
                .disabled(model.hasDocument == false)

                GhostCapsuleButton(
                    help: "正文搜索",
                    isActive: model.activePanel == .search
                ) {
                    model.togglePanel(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(model.hasDocument == false)

                GhostCapsuleButton(help: "返回书架") {
                    model.showBookshelf()
                } label: {
                    Image(systemName: "books.vertical")
                }

                GhostCapsuleButton(
                    help: "阅读设置",
                    isActive: model.activePanel == .settings
                ) {
                    model.togglePanel(.settings)
                } label: {
                    Text("Aa")
                        .font(.system(size: 13, weight: .bold))
                }

                GhostCapsuleButton(
                    help: "阅读主题",
                    isActive: model.activePanel == .themes
                ) {
                    model.togglePanel(.themes)
                } label: {
                    Image(systemName: "circle.lefthalf.filled")
                }

                GhostCapsuleButton(help: "老板键隐藏窗口") {
                    model.performBossKeyAction()
                } label: {
                    ArchiveBossKeyIcon()
                        .frame(width: 18, height: 16)
                }
            }
            .opacity(isRevealed ? 1 : 0)
        }
        .frame(width: 224, height: 38)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.16), value: isRevealed)
    }
}

private struct GhostCapsuleButton<Label: View>: View {
    @EnvironmentObject private var model: ReaderModel

    let help: String
    var isActive = false
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isActive ? Color.readerInk : Color.secondary)
                .frame(width: 32, height: 32)
                .background(isActive ? Color.readerAccent.opacity(0.14) : Color.readerPanel(for: model.readingSettings.theme).opacity(0.86))
                .clipShape(Circle())
                .contentShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.sidebarBorder.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ArchiveBossKeyIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(lineWidth: 2)

            Capsule()
                .frame(width: 7, height: 3)
        }
        .foregroundStyle(Color.secondary)
        .accessibilityHidden(true)
    }
}
