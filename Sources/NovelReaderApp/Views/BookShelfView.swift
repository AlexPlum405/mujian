import SwiftUI

struct BookShelfView: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isSearchPresented = false
    @State private var isSourcesPresented = false
    @State private var isSettingsPresented = false
    @State private var pendingDeleteBook: Book?

    private var theme: ReadingTheme { model.readingSettings.theme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BookShelfHeader(
                    isSettingsPresented: $isSettingsPresented,
                    isSearchPresented: $isSearchPresented,
                    isSourcesPresented: $isSourcesPresented
                )

                if model.books.isEmpty {
                    EmptyBookShelfView()
                        .frame(maxWidth: .infinity, minHeight: 330)
                } else {
                    switch model.readingSettings.bookshelfStyle {
                    case .desk:
                        DeskBookShelfLayout(books: model.books) { book in
                            pendingDeleteBook = book
                        }
                    case .spines:
                        SpineBookShelfLayout(books: model.books) { book in
                            pendingDeleteBook = book
                        }
                    case .drawer:
                        DrawerBookShelfLayout(books: model.books) { book in
                            pendingDeleteBook = book
                        }
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 38)
            .padding(.bottom, 48)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.readerPaper(for: theme))
        .overlay {
            if isSearchPresented {
                BookShelfOverlay {
                    OnlineSearchPanel { isSearchPresented = false }
                        .frame(width: 420)
                } onTapOutside: {
                    isSearchPresented = false
                }
            }
            if isSourcesPresented {
                BookShelfOverlay {
                    BookSourceManagePanel { isSourcesPresented = false }
                } onTapOutside: {
                    isSourcesPresented = false
                }
            }
            if isSettingsPresented {
                BookShelfOverlay {
                    BookShelfSettingsPanel {
                        isSettingsPresented = false
                    }
                    .frame(width: 320)
                } onTapOutside: {
                    isSettingsPresented = false
                }
            }
            if let pendingDeleteBook {
                BookShelfOverlay {
                    BookDeleteConfirmPanel(book: pendingDeleteBook) {
                        self.pendingDeleteBook = nil
                    }
                    .frame(width: 340)
                } onTapOutside: {
                    self.pendingDeleteBook = nil
                }
            }
        }
    }
}

private struct BookShelfHeader: View {
    @EnvironmentObject private var model: ReaderModel
    @Binding var isSettingsPresented: Bool
    @Binding var isSearchPresented: Bool
    @Binding var isSourcesPresented: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                titleBlock

                Spacer()

                toolbarButtons
            }

            VStack(alignment: .leading, spacing: 14) {
                titleBlock

                toolbarButtons
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("书架")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))

            HStack(spacing: 6) {
                Text(model.books.isEmpty ? "还没有书" : "\(model.books.count) 本")

                if model.todayReadingMinutes > 0 {
                    Text("·")
                    Text("今日 \(model.todayReadingMinutes) 分钟")
                }

                if model.totalReadingMinutes >= 60 {
                    Text("·")
                    Text("总计 \(model.totalReadingMinutes / 60) 小时")
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
    }

    private var toolbarButtons: some View {
        HStack(spacing: 8) {
            searchButton
            sourcesButton
            settingsButton
            addButton
        }
        .padding(4)
        .background(Color.readerPanel(for: model.readingSettings.theme).opacity(0.40))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.sidebarBorder(for: model.readingSettings.theme).opacity(0.54), lineWidth: 1)
        }
    }

    private var searchButton: some View {
        Button {
            isSettingsPresented = false
            isSourcesPresented = false
            isSearchPresented = true
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(SecondarySidebarButtonStyle())
        .help("找书")
    }

    private var sourcesButton: some View {
        Button {
            isSettingsPresented = false
            isSearchPresented = false
            isSourcesPresented = true
        } label: {
            Image(systemName: "network")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(SecondarySidebarButtonStyle())
        .help("书源")
    }

    private var settingsButton: some View {
        Button {
            isSearchPresented = false
            isSourcesPresented = false
            isSettingsPresented.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(SecondarySidebarButtonStyle())
        .help("书架设置")
    }

    private var addButton: some View {
        Button {
            model.openTextFile()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(PrimaryIconButtonStyle())
        .help("打开 TXT")
    }
}

private struct BookShelfStylePicker: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        MujianSegmentedControl(
            options: BookshelfStyle.allCases,
            selection: Binding(
                get: { model.readingSettings.bookshelfStyle },
                set: { model.setBookshelfStyle($0) }
            ),
            width: 190
        ) { style in
            style.label
        }
    }
}

private struct BookShelfSettingsPanel: View {
    @EnvironmentObject private var model: ReaderModel

    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("书架设置")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                }

                Spacer()

                BookShelfPanelIconButton(systemName: "xmark", action: dismiss)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("书架样式")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                BookShelfStylePicker()
            }

            VStack(spacing: 7) {
                ForEach(BookshelfStyle.allCases, id: \.self) { style in
                    BookShelfStyleOption(
                        style: style,
                        isSelected: model.readingSettings.bookshelfStyle == style
                    ) {
                        model.setBookshelfStyle(style)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.readerPanel(for: model.readingSettings.theme))
    }
}

private struct BookShelfStyleOption: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    let style: BookshelfStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.readerAccent : Color.readerInk(for: model.readingSettings.theme).opacity(0.56))
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color.readerAccent.opacity(0.11) : Color.primary.opacity(isHovered ? 0.06 : 0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                }

                Spacer()

                Circle()
                    .fill(isSelected ? Color.readerAccent : Color.clear)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(optionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.readerAccent.opacity(0.24) : Color.sidebarBorder(for: model.readingSettings.theme).opacity(isHovered ? 0.80 : 0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var optionBackground: Color {
        if isSelected {
            return Color.readerAccent.opacity(0.09)
        }

        return Color.readerPaper(for: model.readingSettings.theme).opacity(isHovered ? 0.58 : 0.36)
    }

    private var iconName: String {
        switch style {
        case .desk:
            "rectangle.stack"
        case .spines:
            "books.vertical"
        case .drawer:
            "list.bullet.rectangle"
        }
    }
}

private struct DeskBookShelfLayout: View {
    @EnvironmentObject private var model: ReaderModel

    let books: [Book]
    let requestDelete: (Book) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 156, maximum: 230), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let firstBook = books.first {
                DeskContinueCard(book: firstBook)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                    DeskBookCard(book: book, index: index, requestDelete: requestDelete)
                }
            }
        }
    }
}

private struct DeskContinueCard: View {
    @EnvironmentObject private var model: ReaderModel

    let book: Book

    var body: some View {
        Button {
            Task { await model.openBook(book) }
        } label: {
            HStack(spacing: 18) {
                BookCoverArtwork(book: book, index: 0, size: .large, progress: progressValue)

                VStack(alignment: .leading, spacing: 8) {
                    Text("继续阅读「\(book.title)」")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                        .lineLimit(1)

                    Text("\(chapterText) · \(book.locationLabel)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    ProgressStrip(progress: progressValue, color: Color.readerAccent)
                        .frame(maxWidth: 260)
                        .padding(.top, 4)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.readerAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.readerAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color.readerPanel(for: model.readingSettings.theme).opacity(0.82),
                        Color.readerPaper(for: model.readingSettings.theme).opacity(0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.readerAccent.opacity(0.20), lineWidth: 1)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.readerAccent.opacity(0.72))
                    .frame(width: 3)
            }
        }
        .buttonStyle(.plain)
        .help(book.helpPath)
    }

    private var chapterText: String {
        let chapter = savedChapterNumber(for: book, model: model)
        return chapter > 1 ? "第 \(chapter) 章" : "从头开始"
    }

    private var progressValue: Double {
        model.readingProgress(for: book)
    }
}

private struct DeskBookCard: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    let book: Book
    let index: Int
    let requestDelete: (Book) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Task { await model.openBook(book) }
            } label: {
                VStack(alignment: .leading, spacing: 11) {
                    BookCoverArtwork(book: book, index: index, size: .grid, progress: progressValue)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(.custom("Songti SC", size: 16, relativeTo: .body))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(minHeight: 42, alignment: .topLeading)

                        BookAuthorLabel(author: book.author)
                    }

                    Spacer(minLength: 8)

                    HStack {
                        Text(chapterText)
                            .lineLimit(1)
                        Spacer()
                        Text(book.locationLabel)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(11)
                .frame(maxWidth: .infinity, minHeight: 188, alignment: .leading)
                .background(Color.readerPanel(for: model.readingSettings.theme).opacity(isHovered ? 0.56 : 0.42))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isHovered ? Color.readerAccent.opacity(0.22) : Color.sidebarBorder(for: model.readingSettings.theme).opacity(0.76),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(isHovered ? 0.07 : 0.03), radius: isHovered ? 9 : 4, x: 0, y: isHovered ? 4 : 2)
            }
            .buttonStyle(.plain)
            .help(book.helpPath)

            if isHovered {
                BookCardDeleteButton {
                    requestDelete(book)
                }
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var chapterText: String {
        let chapter = savedChapterNumber(for: book, model: model)
        return chapter > 1 ? "第 \(chapter) 章" : "未开始"
    }

    private var progressValue: Double {
        model.readingProgress(for: book)
    }
}

private enum BookCoverArtworkSize: Equatable {
    case grid
    case large
    case feature
    case detail

    var dimensions: CGSize? {
        switch self {
        case .grid:
            nil
        case .large:
            CGSize(width: 72, height: 96)
        case .feature:
            CGSize(width: 218, height: 260)
        case .detail:
            CGSize(width: 224, height: 170)
        }
    }

    var height: CGFloat {
        dimensions?.height ?? 88
    }

    var cornerRadius: CGFloat {
        switch self {
        case .grid:
            7
        case .large, .feature, .detail:
            8
        }
    }

    var titleSize: CGFloat {
        switch self {
        case .grid:
            23
        case .large:
            18
        case .feature:
            34
        case .detail:
            28
        }
    }

    var titleLimit: Int {
        switch self {
        case .grid, .large:
            4
        case .feature, .detail:
            6
        }
    }

    var textPadding: CGFloat {
        switch self {
        case .grid:
            14
        case .large:
            10
        case .feature, .detail:
            22
        }
    }

    var spineWidth: CGFloat {
        switch self {
        case .grid:
            9
        case .large:
            10
        case .feature, .detail:
            12
        }
    }
}

private struct BookCoverArtwork: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var image: NSImage?

    let book: Book
    let index: Int
    let size: BookCoverArtworkSize
    let progress: Double

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.dimensions?.width, height: size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [
                                .black.opacity(0.10),
                                .clear,
                                .black.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                GeneratedBookCover(
                    title: book.title,
                    author: book.author,
                    kind: book.contentKindLabel,
                    color: bookshelfColor(for: book, fallbackIndex: index),
                    size: size
                )
            }
        }
        .frame(width: size.dimensions?.width, height: size.height)
        .frame(maxWidth: size.dimensions == nil ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.black.opacity(image == nil ? 0.18 : 0.24))
                .frame(width: size.spineWidth)
        }
        .overlay(alignment: .bottomLeading) {
            Text(book.contentKindLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 8)
                .frame(height: 21)
                .background(.black.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(8)
        }
        .overlay(alignment: .bottomLeading) {
            if progress > 0 {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(.white.opacity(image == nil ? 0.42 : 0.64))
                        .frame(width: max(proxy.size.width * progress, 12), height: 3)
                }
                .frame(height: 3)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .stroke(Color.sidebarBorder(for: model.readingSettings.theme).opacity(0.34), lineWidth: 1)
        }
        .shadow(color: .black.opacity(size == .grid ? 0.06 : 0.14), radius: size == .grid ? 5 : 18, x: 0, y: size == .grid ? 2 : 10)
        .task(id: book.coverTaskID) {
            image = await localCoverImage(for: book)
        }
    }

    private func localCoverImage(for book: Book) async -> NSImage? {
        guard let coverURL = BookCoverResolver.localCoverURL(for: book) else {
            return nil
        }

        return await Task.detached(priority: .utility) {
            NSImage(contentsOf: coverURL)
        }.value
    }
}

private struct GeneratedBookCover: View {
    @EnvironmentObject private var model: ReaderModel

    let title: String
    let author: String?
    let kind: String
    let color: Color
    let size: BookCoverArtworkSize

    var body: some View {
        RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.94),
                        color.opacity(0.76),
                        Color.readerInk(for: model.readingSettings.theme).opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                Text(shortCoverTitle(from: title, maxCharacters: size.titleLimit))
                    .font(.custom("Songti SC", size: size.titleSize, relativeTo: .title3))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(size == .grid ? 2 : 3)
                    .multilineTextAlignment(.center)
                    .padding(.top, size.textPadding)
                    .padding(.trailing, size.textPadding)
            }
            .overlay(alignment: .bottomTrailing) {
                if let author, author.isEmpty == false, size != .grid {
                    Text(author)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                        .padding(.trailing, size.textPadding)
                        .padding(.bottom, size.textPadding)
                }
            }
    }
}

private struct SpineBookShelfLayout: View {
    @EnvironmentObject private var model: ReaderModel

    let books: [Book]
    let requestDelete: (Book) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                if let firstBook = books.first {
                    SpineFeatureCard(book: firstBook, requestDelete: requestDelete)
                        .frame(width: 270)
                }

                SpineShelfRows(books: books)
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 18) {
                if let firstBook = books.first {
                    SpineFeatureCard(book: firstBook, requestDelete: requestDelete)
                }

                SpineShelfRows(books: books)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.readerPanel(for: model.readingSettings.theme).opacity(0.58),
                    Color.readerPaper(for: model.readingSettings.theme).opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
        }
    }
}

private struct SpineFeatureCard: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    let book: Book
    let requestDelete: (Book) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Task { await model.openBook(book) }
            } label: {
                VStack(alignment: .leading, spacing: 13) {
                    BookCoverArtwork(book: book, index: 0, size: .feature, progress: progressValue)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.custom("Songti SC", size: 22, relativeTo: .title3))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                            .lineLimit(2)

                        BookAuthorLabel(author: book.author)
                    }

                    HStack(spacing: 8) {
                        Text(book.contentKindLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.readerAccent)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Color.readerAccent.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        Text(chapterText)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    ProgressStrip(progress: progressValue, color: bookshelfColor(2))

                    ContinuePill()
                }
                .padding(14)
                .background(Color.readerPaper(for: model.readingSettings.theme).opacity(isHovered ? 0.62 : 0.50))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isHovered ? Color.readerAccent.opacity(0.22) : Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
                }
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 10 : 4, x: 0, y: isHovered ? 5 : 2)
            }
            .buttonStyle(.plain)
            .help(book.helpPath)

            if isHovered {
                BookCardDeleteButton {
                    requestDelete(book)
                }
                    .padding(10)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var chapterText: String {
        let chapter = savedChapterNumber(for: book, model: model)
        return chapter > 1 ? "第 \(chapter) 章" : "从头开始"
    }

    private var progressValue: Double {
        model.readingProgress(for: book)
    }
}

private struct SpineShelfRows: View {
    let books: [Book]

    private var rows: [[IndexedBook]] {
        let indexed = books.enumerated().map { IndexedBook(index: $0.offset, book: $0.element) }
        return stride(from: 0, to: indexed.count, by: 8).map { start in
            Array(indexed[start..<min(start + 8, indexed.count)])
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                SpineShelfRow(items: row)
            }
        }
    }
}

private struct SpineShelfRow: View {
    let items: [IndexedBook]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(items, id: \.book.id) { item in
                    SpineButton(book: item.book, index: item.index)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)

            ShelfPlank()
        }
    }
}

private struct SpineButton: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    let book: Book
    let index: Int

    private var height: CGFloat {
        104 + CGFloat((index * 17) % 42)
    }

    private var width: CGFloat {
        34 + CGFloat((index * 7) % 10)
    }

    private var titleCharacterLimit: Int {
        max(4, Int((height - 22) / 14))
    }

    var body: some View {
        Button {
            Task { await model.openBook(book) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                bookshelfColor(for: book, fallbackIndex: index).opacity(0.96),
                                bookshelfColor(for: book, fallbackIndex: index).opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(.black.opacity(0.16))
                        .frame(width: 4)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(.white.opacity(0.10))
                        .frame(width: 2)
                }

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(.white.opacity(0.18))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(.black.opacity(0.12))
                        .frame(height: 9)
                }

                VerticalSpineTitle(
                    title: book.title,
                    maxCharacters: titleCharacterLimit
                )
                .frame(width: width - 8, height: height - 18)

                if book.isOnline {
                    VStack {
                        Circle()
                            .fill(.white.opacity(0.56))
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Spacer(minLength: 0)
                    }
                }

                if progressValue > 0 {
                    VStack {
                        Spacer(minLength: 0)
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(.white.opacity(0.42))
                                .frame(width: max(width * progressValue, 6), height: 3)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isHovered ? .white.opacity(0.26) : .white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 6 : 3, x: 0, y: isHovered ? 3 : 2)
            .scaleEffect(isHovered ? 1.014 : 1, anchor: .bottom)
        }
        .buttonStyle(.plain)
        .help("\(book.title)\n\(book.helpPath)")
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var progressValue: Double {
        model.readingProgress(for: book)
    }
}

private struct ShelfPlank: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: NSColor(red: 0.72, green: 0.55, blue: 0.35, alpha: 1)),
                            Color(nsColor: NSColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 5)
        }
        .frame(height: 11)
        .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 3)
    }
}

private struct VerticalSpineTitle: View {
    let title: String
    let maxCharacters: Int

    private var displayCharacters: [Character] {
        let title = spineDisplayTitle(from: title)
        let characters = Array(title)

        guard characters.count > maxCharacters else {
            return characters
        }

        return Array(characters.prefix(max(maxCharacters - 1, 1))) + ["…"]
    }

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(displayCharacters.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.custom("Songti SC", size: 12, relativeTo: .caption))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct DrawerBookShelfLayout: View {
    @EnvironmentObject private var model: ReaderModel

    let books: [Book]
    let requestDelete: (Book) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                DrawerSidebar(books: books)
                    .frame(width: 210)

                DrawerBookList(books: books, requestDelete: requestDelete)
                    .frame(minWidth: 420)

                if let firstBook = books.first {
                    DrawerDetailCard(book: firstBook, requestDelete: requestDelete)
                        .frame(width: 260)
                }
            }

            VStack(spacing: 0) {
                DrawerBookList(books: books, requestDelete: requestDelete)
            }
        }
        .background(Color.readerPanel(for: model.readingSettings.theme).opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
        }
    }
}

private struct DrawerSidebar: View {
    @EnvironmentObject private var model: ReaderModel

    let books: [Book]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("木")
                    .font(.custom("Songti SC", size: 18, relativeTo: .body))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.readerPaper(for: model.readingSettings.theme))
                    .frame(width: 34, height: 34)
                    .background(Color.readerInk(for: model.readingSettings.theme))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("木简")
                        .font(.custom("Songti SC", size: 19, relativeTo: .body))
                        .fontWeight(.semibold)
                }
            }

            DrawerSourceRow(title: "全部书籍", systemImage: "books.vertical", count: books.count, isActive: true)
            DrawerSourceRow(title: "正在读", systemImage: "bookmark", count: min(books.count, 6), isActive: false)
            DrawerSourceRow(title: "最近添加", systemImage: "clock", count: min(books.count, 4), isActive: false)

            Spacer(minLength: 24)

            Button {
                model.openTextFile()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(PrimaryIconButtonStyle())
            .help("打开 TXT")
        }
        .padding(16)
        .background(Color.sidebarBackground(for: model.readingSettings.theme).opacity(0.76))
    }
}

private struct DrawerSourceRow: View {
    let title: String
    let systemImage: String
    let count: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(isActive ? Color.primary : Color.secondary)
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(isActive ? Color.readerAccent.opacity(0.13) : Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isActive ? Color.readerAccent.opacity(0.18) : Color.clear, lineWidth: 1)
        }
    }
}

private struct DrawerBookList: View {
    @EnvironmentObject private var model: ReaderModel

    let books: [Book]
    let requestDelete: (Book) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("全部书籍")
                    .font(.custom("Songti SC", size: 25, relativeTo: .title3))
                    .fontWeight(.semibold)

                Spacer()

                Text("\(books.count) 本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .frame(height: 58)

            DrawerHeaderRow()

            ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                DrawerBookRow(book: book, index: index, requestDelete: requestDelete)
            }
        }
        .background(Color.readerPaper(for: model.readingSettings.theme).opacity(0.18))
    }
}

private struct DrawerHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .frame(width: 26)
            Text("书名")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("章节")
                .frame(width: 64, alignment: .leading)
            Text("大小")
                .frame(width: 92, alignment: .leading)
            Text("")
                .frame(width: 38)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .frame(height: 34)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.sidebarBorder)
                .frame(height: 1)
        }
    }
}

private struct DrawerBookRow: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    let book: Book
    let index: Int
    let requestDelete: (Book) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button {
                Task { await model.openBook(book) }
            } label: {
                HStack(spacing: 12) {
                    FileBadge(isOnline: book.isOnline)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(.custom("Songti SC", size: 16, relativeTo: .body))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let author = book.author, author.isEmpty == false {
                                Text(author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(book.locationLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(chapterText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 64, alignment: .leading)

                    Text(sizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .leading)
                }
                .padding(.leading, 20)
                .padding(.trailing, 12)
                .frame(height: 58)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(book.helpPath)

            Group {
                if isHovered {
                    BookCardDeleteButton {
                        requestDelete(book)
                    }
                    .transition(.opacity)
                } else {
                    Color.clear
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 38, height: 58)
            .padding(.trailing, 20)
        }
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if index == 0 {
                Rectangle()
                    .fill(Color.readerAccent)
                    .frame(width: 3)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.sidebarBorder.opacity(0.58))
                .frame(height: 1)
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var rowBackground: Color {
        if isHovered {
            return Color.readerAccent.opacity(index == 0 ? 0.12 : 0.06)
        }

        return index == 0 ? Color.readerAccent.opacity(0.09) : Color.clear
    }

    private var chapterText: String {
        let chapter = savedChapterNumber(for: book, model: model)
        return chapter > 1 ? "\(chapter)" : "-"
    }

    private var sizeText: String {
        guard let url = book.localURL else { return "在线" }
        return fileSizeLabel(for: url)
    }
}

private struct DrawerDetailCard: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    let book: Book
    let requestDelete: (Book) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                BookCoverArtwork(book: book, index: 2, size: .detail, progress: progressValue)

                VStack(alignment: .leading, spacing: 7) {
                    Text(book.title)
                        .font(.custom("Songti SC", size: 24, relativeTo: .title3))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                        .lineLimit(2)

                    BookAuthorLabel(author: book.author)

                    Text(chapterText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                ProgressStrip(progress: progressValue, color: bookshelfColor(2))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    DetailStat(title: "章节", value: chapterText)
                    DetailStat(title: "类型", value: book.contentKindLabel)
                    DetailStat(title: "位置", value: book.locationLabel)
                    DetailStat(title: "大小", value: fileSizeText)
                }

                Button {
                    Task { await model.openBook(book) }
                } label: {
                    Text("继续阅读")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimarySidebarButtonStyle())
            }
            .padding(18)
            .background(Color.sidebarBackground(for: model.readingSettings.theme).opacity(0.62))

            if isHovered {
                BookCardDeleteButton {
                    requestDelete(book)
                }
                    .padding(10)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var chapterText: String {
        let chapter = savedChapterNumber(for: book, model: model)
        return chapter > 1 ? "第 \(chapter) 章" : "从头开始"
    }

    private var progressValue: Double {
        model.readingProgress(for: book)
    }

    private var fileSizeText: String {
        guard let url = book.localURL else { return "在线" }
        return fileSizeLabel(for: url)
    }
}

private struct DetailStat: View {
    @EnvironmentObject private var model: ReaderModel

    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.readerPanel(for: model.readingSettings.theme).opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
        }
    }
}

private struct EmptyBookShelfView: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Color.readerAccent)
                .frame(width: 72, height: 72)
                .background(Color.readerAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("书架为空")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))

            Button {
                model.openTextFile()
            } label: {
                Label("选择 TXT", systemImage: "folder")
            }
            .buttonStyle(PrimarySidebarButtonStyle())
        }
        .padding(28)
    }
}

private struct ProgressStrip: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.10))

                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.width * progress, 10))
            }
        }
        .frame(height: height)
    }
}

private struct ContinuePill: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("继续阅读")
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.readerAccent)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(Color.readerAccent.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.readerAccent.opacity(0.20), lineWidth: 1)
        }
    }
}

private struct BookShelfPanelIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(SecondarySidebarButtonStyle())
    }
}

private struct BookCardDeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(deleteColor.opacity(0.82))
                .frame(width: 24, height: 24)
                .background(Color.readerPanel.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(deleteColor.opacity(0.22), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help("移除")
    }

    private var deleteColor: Color {
        Color(nsColor: NSColor(red: 0.620, green: 0.180, blue: 0.130, alpha: 1))
    }
}

private struct BookDeleteConfirmPanel: View {
    @EnvironmentObject private var model: ReaderModel

    let book: Book
    let dismiss: () -> Void

    private var isLocal: Bool {
        book.localURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(deleteColor)
                    .frame(width: 30, height: 30)
                    .background(deleteColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("删除《\(book.title)》")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(isLocal ? "保留 TXT，或一起删除文件。" : "从书架移除这本在线书。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    dismiss()
                } label: {
                    Text("取消")
                        .frame(width: 70, height: 32)
                }
                .buttonStyle(DeletePanelButtonStyle(kind: .quiet))

                Spacer(minLength: 0)

                Button {
                    model.removeFromShelf(id: book.id)
                    dismiss()
                } label: {
                    Text(isLocal ? "仅移除" : "移除")
                        .frame(width: 76, height: 32)
                }
                .buttonStyle(DeletePanelButtonStyle(kind: .secondary))

                if isLocal {
                    Button {
                        model.deleteBook(id: book.id)
                        dismiss()
                    } label: {
                        Text("删除文件")
                            .frame(width: 86, height: 32)
                    }
                    .buttonStyle(DeletePanelButtonStyle(kind: .destructive))
                }
            }
        }
        .padding(16)
        .background(Color.readerPanel(for: model.readingSettings.theme))
    }

    private var deleteColor: Color {
        Color(nsColor: NSColor(red: 0.620, green: 0.180, blue: 0.130, alpha: 1))
    }
}

private struct DeletePanelButtonStyle: ButtonStyle {
    enum Kind {
        case quiet
        case secondary
        case destructive
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: 1)
            }
    }

    private var foregroundColor: Color {
        switch kind {
        case .quiet:
            .secondary
        case .secondary:
            .readerAccent
        case .destructive:
            .white
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch kind {
        case .quiet:
            Color.primary.opacity(isPressed ? 0.10 : 0.06)
        case .secondary:
            Color.readerAccent.opacity(isPressed ? 0.16 : 0.10)
        case .destructive:
            Color(nsColor: NSColor(red: 0.620, green: 0.180, blue: 0.130, alpha: isPressed ? 0.86 : 1))
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch kind {
        case .quiet:
            Color.sidebarBorder.opacity(isPressed ? 0.9 : 0.64)
        case .secondary:
            Color.readerAccent.opacity(isPressed ? 0.34 : 0.22)
        case .destructive:
            Color.clear
        }
    }
}

private struct BookAuthorLabel: View {
    let author: String?

    var body: some View {
        if let author, author.isEmpty == false {
            Text(author)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct FileBadge: View {
    let isOnline: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.82), Color.primary.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 28, height: 34)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.sidebarBorder, lineWidth: 1)
            }
            .overlay {
                if isOnline {
                    Image(systemName: "network")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.readerAccent.opacity(0.86))
                }
            }
            .overlay(alignment: .topTrailing) {
                if isOnline == false {
                    TriangleFold()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 8, height: 8)
                }
            }
    }
}

private struct TriangleFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct IndexedBook {
    let index: Int
    let book: Book
}

private extension Book {
    var localURL: URL? {
        if case .local(let url) = origin { return url }
        return nil
    }

    var locationLabel: String {
        if case .local(let url) = origin {
            return url.deletingLastPathComponent().lastPathComponent
        }
        return "在线书源"
    }

    var isOnline: Bool {
        if case .online = origin { return true }
        return false
    }

    var contentKindLabel: String {
        isOnline ? "在线" : "TXT"
    }

    var helpPath: String {
        switch origin {
        case .local(let url):
            return url.path
        case .online(_, let bookUrl):
            return bookUrl
        }
    }

    var coverTaskID: String {
        switch origin {
        case .local(let url):
            return url.path
        case .online(let sourceId, let bookUrl):
            return "\(sourceId)|\(bookUrl)"
        }
    }

    var coverSeed: String {
        "\(title)|\(author ?? "")|\(coverTaskID)"
    }
}

@MainActor
private func savedChapterNumber(for book: Book, model: ReaderModel) -> Int {
    switch book.origin {
    case .local(let url):
        model.savedChapterIndex(for: url) + 1
    case .online:
        model.savedOnlineChapterIndex(for: book) + 1
    }
}

private func bookshelfColor(_ index: Int) -> Color {
    Color(nsColor: bookshelfColors[index % bookshelfColors.count])
}

private func bookshelfColor(for book: Book, fallbackIndex: Int) -> Color {
    let seed = book.coverSeed
    guard seed.isEmpty == false else {
        return bookshelfColor(fallbackIndex)
    }

    return bookshelfColor(deterministicIndex(for: seed))
}

private var bookshelfColors: [NSColor] {
    [
        NSColor(red: 0.561, green: 0.310, blue: 0.180, alpha: 1),
        NSColor(red: 0.184, green: 0.435, blue: 0.384, alpha: 1),
        NSColor(red: 0.322, green: 0.376, blue: 0.467, alpha: 1),
        NSColor(red: 0.420, green: 0.243, blue: 0.357, alpha: 1),
        NSColor(red: 0.451, green: 0.365, blue: 0.239, alpha: 1),
        NSColor(red: 0.247, green: 0.349, blue: 0.392, alpha: 1),
        NSColor(red: 0.600, green: 0.294, blue: 0.220, alpha: 1),
        NSColor(red: 0.349, green: 0.318, blue: 0.290, alpha: 1)
    ]
}

private func deterministicIndex(for seed: String) -> Int {
    var hash: UInt64 = 1469598103934665603
    for scalar in seed.unicodeScalars {
        hash ^= UInt64(scalar.value)
        hash &*= 1099511628211
    }
    return Int(hash % UInt64(bookshelfColors.count))
}

private func fileSizeLabel(for url: URL) -> String {
    guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
          let fileSize = values.fileSize else {
        return "TXT"
    }

    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(fileSize))
}

private func shortCoverTitle(from title: String, maxCharacters: Int) -> String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > maxCharacters else {
        return trimmed
    }

    return String(trimmed.prefix(maxCharacters))
}

private func spineDisplayTitle(from title: String) -> String {
    let trimmed = title
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard trimmed.count > 1 else {
        return trimmed.isEmpty ? "TXT" : trimmed
    }

    let separators: [Character] = ["：", ":", "·", "-", "—", "_"]

    for separator in separators {
        guard let separatorIndex = trimmed.firstIndex(of: separator) else {
            continue
        }

        let prefix = String(trimmed[..<separatorIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if prefix.count >= 2 {
            return prefix
        }
    }

    return trimmed
}
