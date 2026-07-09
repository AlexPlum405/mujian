import SwiftUI

struct ReaderPaneView: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isScrollHovered = false
    @State private var restoreOffset: CGFloat = 0
    @State private var saveTask: Task<Void, Never>?
    @State private var currentPage = 0
    @State private var pageRanges: [PageRange] = []
    @State private var viewportSize: CGSize = .zero

    private var isPaged: Bool {
        model.readingSettings.readingMode == .paged
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.hasDocument {
                if isPaged {
                    pagedContent
                } else {
                    scrollContent
                }
            } else {
                ReaderHeaderView()
                EmptyReaderStateView()
            }
        }
        .background(Color.readerPaper(for: model.readingSettings.theme))
        .onChange(of: model.searchJumpScrollOffset) { _, offset in
            guard let offset else { return }
            if isPaged {
                let pageIndex = Int(offset / max(viewportSize.height, 1))
                currentPage = min(max(pageIndex, 0), max(pageRanges.count - 1, 0))
            } else {
                restoreOffset = offset
            }
            model.searchJumpScrollOffset = nil
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("章节 \(model.selectedChapterIndex + 1)")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.readerAccent)

                Text(model.chapterTitle)
                    .font(.custom(model.readingSettings.fontFamily, size: 34, relativeTo: .title))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))

                if model.documentText.isEmpty && model.isReadingOnline {
                    onlineLoadingView
                } else {
                    Text(model.documentText)
                        .font(.custom(model.readingSettings.fontFamily, size: model.readingSettings.fontSize, relativeTo: .body))
                        .lineSpacing(max((model.readingSettings.lineHeight - 1) * model.readingSettings.fontSize, 0))
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ChapterNavigationFooter()
            }
            .frame(maxWidth: 730, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 42)
            .padding(.bottom, 80)
            .frame(maxWidth: .infinity)
            .background {
                ScrollPositionTracker(
                    onScroll: { offset in
                        saveTask?.cancel()
                        saveTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if Task.isCancelled == false {
                                model.saveScrollOffset(offset)
                            }
                        }
                    },
                    restoreOffset: restoreOffset
                )
                .frame(width: 0, height: 0)
            }
        }
        .scrollIndicators(isScrollHovered ? .visible : .hidden)
        .background {
            ScrollIndicatorVisibilityBridge(isVisible: isScrollHovered)
        }
        .onAppear {
            restoreOffset = model.loadScrollOffset()
        }
        .onChange(of: model.selectedChapterIndex) { _, _ in
            restoreOffset = model.loadScrollOffset()
        }
        .onHover { isScrollHovered = $0 }
    }

    private var pagedContent: some View {
        GeometryReader { geometry in
            let calculator = PaginationCalculator()
            let ranges = calculator.paginate(
                text: model.documentText,
                fontSize: model.readingSettings.fontSize,
                lineHeight: model.readingSettings.lineHeight,
                viewportWidth: geometry.size.width - 64,
                viewportHeight: geometry.size.height - 80
            )

            let safePage = min(currentPage, max(ranges.count - 1, 0))
            let pageText = ranges.isEmpty ? "" : calculator.pageContent(text: model.documentText, range: ranges[safePage])

            ZStack(alignment: .topLeading) {
                Color.readerPaper(for: model.readingSettings.theme)

                VStack(alignment: .leading, spacing: 20) {
                    Text(model.chapterTitle)
                        .font(.custom(model.readingSettings.fontFamily, size: 28, relativeTo: .title))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))

                    if model.documentText.isEmpty && model.isReadingOnline {
                        onlineLoadingView
                    } else {
                        Text(pageText)
                            .font(.custom(model.readingSettings.fontFamily, size: model.readingSettings.fontSize, relativeTo: .body))
                            .lineSpacing(max((model.readingSettings.lineHeight - 1) * model.readingSettings.fontSize, 0))
                            .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 42)

                HStack {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { goToPreviousPage(ranges: ranges) }

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { goToNextPage(ranges: ranges) }
                }
            }
            .onAppear {
                viewportSize = geometry.size
                if pageRanges != ranges {
                    pageRanges = ranges
                    currentPage = 0
                }
            }
            .onChange(of: model.selectedChapterIndex) { _, _ in
                pageRanges = ranges
                currentPage = 0
            }
            .onChange(of: model.readingSettings.fontSize) { _, _ in
                pageRanges = ranges
                currentPage = 0
            }
            .onChange(of: model.readingSettings.lineHeight) { _, _ in
                pageRanges = ranges
                currentPage = 0
            }
            .onKeyPress(.space) {
                goToNextPage(ranges: ranges)
                return .handled
            }
            .onKeyPress(.rightArrow) {
                goToNextPage(ranges: ranges)
                return .handled
            }
            .onKeyPress(.leftArrow) {
                goToPreviousPage(ranges: ranges)
                return .handled
            }
        }
    }

    private func goToNextPage(ranges: [PageRange]) {
        if currentPage + 1 < ranges.count {
            currentPage += 1
        } else if model.selectedChapterIndex + 1 < model.chapterCount {
            model.selectNextChapter()
            currentPage = 0
        }
    }

    private func goToPreviousPage(ranges: [PageRange]) {
        if currentPage > 0 {
            currentPage -= 1
        } else if model.selectedChapterIndex > 0 {
            model.selectPreviousChapter()
            currentPage = 0
        }
    }

    private var onlineLoadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(model.isLoadingOnline ? "正在加载…" : "加载失败，请稍后重试")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct ReaderHeaderView: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.bookTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(model.chapterTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(model.chapterProgressText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.readerPaper)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(Color.sidebarBorder, lineWidth: 1)
                }
        }
        .padding(.horizontal, 52)
        .frame(minHeight: 54)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.sidebarBorder)
                .frame(height: 1)
        }
    }
}

private struct ChapterNavigationFooter: View {
    @EnvironmentObject private var model: ReaderModel

    private var hasPreviousChapter: Bool {
        model.selectedChapterIndex > 0
    }

    private var hasNextChapter: Bool {
        model.selectedChapterIndex + 1 < model.chapterCount
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                model.selectPreviousChapter()
            } label: {
                Text("上一章")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChapterNavigationButtonStyle())
            .disabled(hasPreviousChapter == false)

            Button {
                model.selectNextChapter()
            } label: {
                Text("下一章")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChapterNavigationButtonStyle())
            .disabled(hasNextChapter == false)
        }
        .padding(.top, 36)
    }
}

private struct ChapterNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.readerAccent.opacity(configuration.isPressed ? 0.72 : 1))
            .frame(height: 42)
            .background(Color.readerAccent.opacity(configuration.isPressed ? 0.16 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.readerAccent.opacity(0.26), lineWidth: 1)
            }
    }
}

private struct EmptyReaderStateView: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(Color.readerAccent)
                .frame(width: 58, height: 58)
                .background(Color.readerAccent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("打开一本 TXT")
                .font(.system(size: 22, weight: .semibold))

            Button {
                model.openTextFile()
            } label: {
                Label("打开 TXT", systemImage: "folder")
            }
            .buttonStyle(PrimarySidebarButtonStyle())
            .controlSize(.large)
        }
        .padding(42)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
