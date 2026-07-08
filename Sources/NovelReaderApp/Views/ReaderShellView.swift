import AppKit
import SwiftUI

struct ReaderShellView: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                if model.isBookshelfVisible {
                    BookShelfView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ReaderPaneView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if model.activePanel != nil, model.isBookshelfVisible == false {
                    Color.black.opacity(0.04)
                        .ignoresSafeArea()
                        .onTapGesture {
                            model.closePanel()
                        }
                        .transition(.opacity)

                    ReaderFloatingPanel()
                        .padding(.top, panelTopPadding(for: proxy.size.height))
                        .padding(.trailing, panelTrailingPadding(for: proxy.size.width))
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
                }

                if model.isBookshelfVisible == false {
                    if model.readingSettings.isEmergencyBossCornerEnabled {
                        EmergencyBossCorner()
                    }

                    ReaderGhostCapsule()
                        .environmentObject(model)
                        .padding(.top, 2)
                        .padding(.trailing, panelTrailingPadding(for: proxy.size.width))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.readerAccent, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .padding(14)
                        .overlay {
                            Image(systemName: "doc.text")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color.readerAccent)
                                .frame(width: 64, height: 64)
                                .background(Color.readerPaper.opacity(0.94))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .allowsHitTesting(false)
                }
            }
            .background(Color.readerPaper(for: model.readingSettings.theme))
            .animation(.easeInOut(duration: 0.16), value: model.isBookshelfVisible)
            .animation(.easeInOut(duration: 0.14), value: model.activePanel)
            .animation(.easeInOut(duration: 0.12), value: isDropTargeted)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else {
                    return false
                }

                return model.loadDroppedFile(from: url)
            } isTargeted: { isTargeted in
                isDropTargeted = isTargeted
            }
        }
        .preferredColorScheme(model.readingSettings.theme == .dark ? .dark : .light)
        .alert("打开失败", isPresented: errorBinding) {
            Button("知道了", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            model.readingTimer.handleWindowLostFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            model.readingTimer.handleWindowGainedFocus()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if $0 == false { model.errorMessage = nil } }
        )
    }

    private func panelTopPadding(for windowHeight: CGFloat) -> CGFloat {
        windowHeight < 560 ? 38 : 44
    }

    private func panelTrailingPadding(for windowWidth: CGFloat) -> CGFloat {
        windowWidth < 720 ? 11 : 15
    }
}

private struct EmergencyBossCorner: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Color.clear
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .onHover { isHovered in
                hideTask?.cancel()

                guard isHovered else {
                    hideTask = nil
                    return
                }

                hideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 110_000_000)

                    guard Task.isCancelled == false else {
                        return
                    }

                    model.performBossKeyAction()
                }
            }
            .onDisappear {
                hideTask?.cancel()
                hideTask = nil
            }
            .accessibilityHidden(true)
    }
}
