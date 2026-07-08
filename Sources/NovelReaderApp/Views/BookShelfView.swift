import SwiftUI

struct BookShelfView: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isSearchPresented = false
    @State private var isSourcesPresented = false

    private var theme: ReadingTheme { model.readingSettings.theme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BookShelfHeader(
                    isSearchPresented: $isSearchPresented,
                    isSourcesPresented: $isSourcesPresented
                )

                if model.books.isEmpty {
                    EmptyBookShelfView()
                        .frame(maxWidth: .infinity, minHeight: 330)
                } else {
                    switch model.readingSettings.bookshelfStyle {
                    case .desk:
                        DeskBookShelfLayout(books: model.books)
                    case .spines:
                        SpineBookShelfLayout(books: model.books)
                    case .drawer:
                        DrawerBookShelfLayout(books: model.books)
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
                        .frame(width: 380)
                } onTapOutside: {
                    isSourcesPresented = false
                }
            }
        }
    }
}

private struct BookShelfHeader: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isSettingsPresented = false
    @Binding var isSearchPresented: Bool
    @Binding var isSourcesPresented: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                titleBlock

                Spacer()

                searchButton
                sourcesButton
                settingsButton
                addButton
            }

            VStack(alignment: .leading, spacing: 14) {
                titleBlock

                HStack(spacing: 10) {
                    searchButton
                    sourcesButton
                    settingsButton
                    addButton
                }
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

    private var searchButton: some View {
        Button {
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
            isSettingsPresented.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(SecondarySidebarButtonStyle())
        .help("书架设置")
        .popover(isPresented: $isSettingsPresented, arrowEdge: .top) {
            BookShelfSettingsPanel {
                isSettingsPresented = false
            }
            .frame(width: 306)
        }
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("书架设置")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
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
        .padding(16)
        .background(Color.readerPanel(for: model.readingSettings.theme))
    }
}

private struct BookShelfStyleOption: View {
    @EnvironmentObject private var model: ReaderModel

    let style: BookshelfStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.readerAccent : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(isSelected ? Color.readerAccent.opacity(0.12) : Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.readerAccent)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(isSelected ? Color.readerAccent.opacity(0.10) : Color.readerPaper(for: model.readingSettings.theme).opacity(0.42))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.readerAccent.opacity(0.28) : Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
                    DeskBookCard(book: book, index: index)
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
            HStack(spacing: 16) {
                BookCoverMark(title: book.title, color: bookshelfColor(0), size: .large)

                VStack(alignment: .leading, spacing: 7) {
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
                    .background(Color.readerAccent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.readerPanel(for: model.readingSettings.theme).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.readerAccent.opacity(0.20), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(book.helpPath)
    }

    private var chapterText: String {
        guard let url = book.localURL else { return "从头开始" }
        let chapter = model.savedChapterIndex(for: url) + 1
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Task { await model.openBook(book) }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(bookshelfColor(index))
                        .frame(height: 42)
                        .overlay(alignment: .bottomLeading) {
                            Text("TXT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(9)
                        }

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
                        Spacer()
                        Text(book.locationLabel)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if progressValue > 0 {
                        ProgressStrip(progress: progressValue, color: Color.readerAccent, height: 3)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
                .background(Color.readerPanel(for: model.readingSettings.theme).opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help(book.helpPath)

            if isHovered {
                BookCardDeleteButton(bookId: book.id)
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var chapterText: String {
        guard let url = book.localURL else { return "未开始" }
        let chapter = model.savedChapterIndex(for: url) + 1
        return chapter > 1 ? "第 \(chapter) 章" : "未开始"
    }

    private var progressValue: Double {
        model.readingProgress(for: book)
    }
}

private struct SpineBookShelfLayout: View {
    @EnvironmentObject private var model: ReaderModel

    let books: [Book]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                if let firstBook = books.first {
                    SpineFeatureCard(book: firstBook)
                        .frame(width: 270)
                }

                SpineShelfRows(books: books)
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 18) {
                if let firstBook = books.first {
                    SpineFeatureCard(book: firstBook)
                }

                SpineShelfRows(books: books)
            }
        }
        .padding(18)
        .background(Color.readerPanel(for: model.readingSettings.theme).opacity(0.38))
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                Task { await model.openBook(book) }
            } label: {
                VStack(alignment: .leading, spacing: 13) {
                    BookCoverMark(title: book.title, color: bookshelfColor(0), size: .feature)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .font(.custom("Songti SC", size: 22, relativeTo: .title3))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                            .lineLimit(2)

                        BookAuthorLabel(author: book.author)
                    }

                    Text(chapterText)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)

                    ProgressStrip(progress: progressValue, color: bookshelfColor(2))

                    Text("继续阅读")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color.readerAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(14)
                .background(Color.readerPaper(for: model.readingSettings.theme).opacity(0.50))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help(book.helpPath)

            if isHovered {
                BookCardDeleteButton(bookId: book.id)
                    .padding(10)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var chapterText: String {
        guard let url = book.localURL else { return "从头开始" }
        let chapter = model.savedChapterIndex(for: url) + 1
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

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: NSColor(red: 0.75, green: 0.58, blue: 0.36, alpha: 1)),
                            Color(nsColor: NSColor(red: 0.48, green: 0.33, blue: 0.19, alpha: 1))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 10)
                .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
        }
    }
}

private struct SpineButton: View {
    @EnvironmentObject private var model: ReaderModel

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
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(bookshelfColor(index))
                .frame(width: width, height: height)
                .overlay {
                    VerticalSpineTitle(
                        title: book.title,
                        maxCharacters: titleCharacterLimit
                    )
                    .frame(width: width - 8, height: height - 14)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .help("\(book.title)\n\(book.helpPath)")
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

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                DrawerSidebar(books: books)
                    .frame(width: 210)

                DrawerBookList(books: books)
                    .frame(minWidth: 420)

                if let firstBook = books.first {
                    DrawerDetailCard(book: firstBook)
                        .frame(width: 260)
                }
            }

            VStack(spacing: 0) {
                DrawerBookList(books: books)

                if let firstBook = books.first {
                    DrawerDetailCard(book: firstBook)
                }
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

            DrawerSourceRow(title: "全部书籍", count: books.count, isActive: true)
            DrawerSourceRow(title: "正在读", count: min(books.count, 6), isActive: false)
            DrawerSourceRow(title: "最近添加", count: min(books.count, 4), isActive: false)

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
    let count: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(.secondary.opacity(0.55), lineWidth: 1)
                .frame(width: 14, height: 14)

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(isActive ? Color.primary : Color.secondary)
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(isActive ? Color.readerAccent.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct DrawerBookList: View {
    @EnvironmentObject private var model: ReaderModel

    let books: [Book]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("全部书籍")
                    .font(.custom("Songti SC", size: 25, relativeTo: .title3))
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 58)

            DrawerHeaderRow()

            ForEach(Array(books.enumerated()), id: \.element.id) { index, book in
                DrawerBookRow(book: book, index: index)
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
            Text("位置")
                .frame(width: 92, alignment: .leading)
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

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                Task { await model.openBook(book) }
            } label: {
                HStack(spacing: 12) {
                    FileBadge()

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

                    Text(fileSizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(index == 0 ? Color.readerAccent.opacity(0.09) : Color.clear)
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
            }
            .buttonStyle(.plain)
            .help(book.helpPath)

            if isHovered {
                BookCardDeleteButton(bookId: book.id)
                    .padding(.trailing, 10)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var chapterText: String {
        guard let url = book.localURL else { return "-" }
        let chapter = model.savedChapterIndex(for: url) + 1
        return chapter > 1 ? "\(chapter)" : "-"
    }

    private var fileSizeText: String {
        guard let url = book.localURL else { return "在线" }
        return fileSizeLabel(for: url)
    }
}

private struct DrawerDetailCard: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var isHovered = false

    let book: Book

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                BookCoverMark(title: book.title, color: bookshelfColor(2), size: .detail)

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
                    DetailStat(title: "类型", value: "TXT")
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
                BookCardDeleteButton(bookId: book.id)
                    .padding(10)
                    .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var chapterText: String {
        guard let url = book.localURL else { return "从头开始" }
        let chapter = model.savedChapterIndex(for: url) + 1
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

private struct BookCoverMark: View {
    enum Size {
        case large
        case feature
        case detail

        var dimensions: CGSize {
            switch self {
            case .large:
                CGSize(width: 72, height: 96)
            case .feature:
                CGSize(width: 218, height: 260)
            case .detail:
                CGSize(width: 224, height: 170)
            }
        }

        var titleSize: CGFloat {
            switch self {
            case .large:
                18
            case .feature:
                34
            case .detail:
                28
            }
        }
    }

    let title: String
    let color: Color
    let size: Size

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.92), color.opacity(0.62), Color.readerAccent.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.dimensions.width, height: size.dimensions.height)
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(.black.opacity(0.16))
                    .frame(width: 12)
            }
            .overlay(alignment: .topTrailing) {
                Text(shortTitle(title))
                    .font(.custom("Songti SC", size: size.titleSize, relativeTo: .title))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(size == .large ? 10 : 22)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 10)
    }

    private func shortTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 4 else {
            return trimmed
        }

        return String(trimmed.prefix(4))
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

private struct BookCardDeleteButton: View {
    @EnvironmentObject private var model: ReaderModel
    let bookId: UUID

    var body: some View {
        Button {
            model.deleteBook(id: bookId)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.red.opacity(0.88))
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(.white.opacity(0.6), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .help("移除")
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
            .overlay(alignment: .topTrailing) {
                TriangleFold()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 8, height: 8)
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

    var helpPath: String {
        switch origin {
        case .local(let url):
            return url.path
        case .online(_, let bookUrl):
            return bookUrl
        }
    }
}

private func bookshelfColor(_ index: Int) -> Color {
    let colors: [NSColor] = [
        NSColor(red: 0.561, green: 0.310, blue: 0.180, alpha: 1),
        NSColor(red: 0.184, green: 0.435, blue: 0.384, alpha: 1),
        NSColor(red: 0.322, green: 0.376, blue: 0.467, alpha: 1),
        NSColor(red: 0.420, green: 0.243, blue: 0.357, alpha: 1),
        NSColor(red: 0.451, green: 0.365, blue: 0.239, alpha: 1),
        NSColor(red: 0.247, green: 0.349, blue: 0.392, alpha: 1),
        NSColor(red: 0.600, green: 0.294, blue: 0.220, alpha: 1),
        NSColor(red: 0.349, green: 0.318, blue: 0.290, alpha: 1)
    ]

    return Color(nsColor: colors[index % colors.count])
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
