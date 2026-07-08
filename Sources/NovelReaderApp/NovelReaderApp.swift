import AppKit
import SwiftUI

@main
struct NovelReaderApp: App {
    @StateObject private var model = ReaderModel()

    var body: some Scene {
        WindowGroup {
            ReaderShellView()
                .environmentObject(model)
                .frame(minWidth: 680, minHeight: 520)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.shutdown()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("打开 TXT...") {
                    model.openTextFile()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("阅读设置") {
                    model.togglePanel(.settings)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])

                Button("返回书架") {
                    model.showBookshelf()
                }
                .keyboardShortcut("b", modifiers: [.command])
            }

            CommandMenu("阅读") {
                Button("上一章") {
                    model.selectPreviousChapter()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .disabled(model.selectedChapterIndex == 0)

                Button("下一章") {
                    model.selectNextChapter()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .disabled(model.selectedChapterIndex + 1 >= model.chapters.count)

                Divider()

                Button("老板键隐藏窗口") {
                    model.performBossKeyAction()
                }
            }
        }
    }
}
