import SwiftUI

struct BookSourceManagePanel: View {
    @EnvironmentObject private var model: ReaderModel
    let dismiss: () -> Void

    @State private var urlInput = ""
    @State private var showURLInput = false
    @State private var filterText = ""

    private var theme: ReadingTheme { model.readingSettings.theme }
    private var enabledCount: Int { model.bookSources.filter { $0.isEnabled }.count }
    private var filteredSources: [BookSource] {
        if filterText.isEmpty { return model.bookSources }
        return model.bookSources.filter {
            $0.name.localizedCaseInsensitiveContains(filterText) || $0.url.localizedCaseInsensitiveContains(filterText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("书源")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.readerInk(for: theme))

                    Text(model.bookSources.isEmpty ? "还没有书源" : "\(model.bookSources.count) 个 · \(enabledCount) 个已启用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.sidebarBorder(for: theme).opacity(0.5))
                    .frame(height: 1)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            model.importBookSourcesViaPicker()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                            Text("本地导入")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(LocalImportButtonStyle())

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showURLInput.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "link")
                            Text("网络导入")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(RemoteImportButtonStyle())
                }

                if showURLInput {
                    HStack(spacing: 8) {
                        TextField("输入书源 JSON 链接", text: $urlInput)
                            .font(.system(size: 12, weight: .medium))
                            .textFieldStyle(.plain)
                            .foregroundStyle(Color.readerInk(for: theme))
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Color.readerPaper(for: theme))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(Color.sidebarBorder(for: theme), lineWidth: 1)
                            }

                        Button {
                            if let url = URL(string: urlInput) {
                                model.importBookSourcesFromURL(url)
                                urlInput = ""
                                showURLInput = false
                            }
                        } label: {
                            Text("导入")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 48, height: 32)
                        }
                        .buttonStyle(PanelActionButtonStyle(width: 48))
                        .disabled(urlInput.isEmpty)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.sidebarBorder(for: theme).opacity(0.5))
                    .frame(height: 1)
            }

            if model.isLoadingOnline {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在导入…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if model.bookSources.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.readerAccent)
                        .frame(width: 56, height: 56)
                        .background(Color.readerAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("还没有书源")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.readerInk(for: theme))

                    Text("导入 Legado 书源 JSON 后即可搜索在线书籍")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    TextField("筛选书源", text: $filterText)
                        .font(.system(size: 12, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.readerInk(for: theme))
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.readerPaper(for: theme).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 10)

                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(filteredSources) { source in
                            BookSourceRow(source: source)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 360)
            }
        }
        .background(Color.readerPanel(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(width: 380)
    }
}

private struct LocalImportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(Color.readerAccent.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct RemoteImportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.readerAccent)
            .background(Color.readerAccent.opacity(configuration.isPressed ? 0.12 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.readerAccent.opacity(0.2), lineWidth: 1)
            }
    }
}

private struct BookSourceRow: View {
    @EnvironmentObject private var model: ReaderModel
    let source: BookSource

    private var theme: ReadingTheme { model.readingSettings.theme }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.readerInk(for: theme))
                    .lineLimit(1)

                Text(source.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            MujianToggle(isOn: Binding(
                get: { source.isEnabled },
                set: { _ in model.toggleSourceEnabled(source) }
            ))

            Button {
                model.deleteSource(id: source.id)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.red.opacity(0.7))
            .help("删除书源")
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color.readerPaper(for: theme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.sidebarBorder(for: theme).opacity(0.5), lineWidth: 1)
        }
    }
}

struct OnlineSearchPanel: View {
    @EnvironmentObject private var model: ReaderModel
    let dismiss: () -> Void

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var theme: ReadingTheme { model.readingSettings.theme }
    private var enabledSourceCount: Int { model.bookSources.filter { $0.isEnabled }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("找书")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.readerInk(for: theme))

                    Text(model.bookSources.isEmpty ? "先导入书源" : "\(enabledSourceCount) 个书源可用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            HStack(spacing: 8) {
                TextField("输入书名或作者", text: $query)
                    .font(.system(size: 13, weight: .medium))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.readerInk(for: theme))
                    .focused($isFocused)
                    .onSubmit {
                        model.searchOnline(query: query)
                    }

                Button {
                    model.searchOnline(query: query)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(PrimaryIconButtonStyle())
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.readerPaper(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.sidebarBorder(for: theme), lineWidth: 1)
            }

            if model.isLoadingOnline {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("搜索中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if model.onlineSearchResults.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.readerAccent)
                        .frame(width: 52, height: 52)
                        .background(Color.readerAccent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(query.isEmpty ? "输入关键词搜索在线书籍" : "没有找到结果")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.onlineSearchResults) { result in
                            OnlineSearchResultRow(result: result)
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(16)
        .background(Color.readerPanel(for: theme))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
    }
}

private struct OnlineSearchResultRow: View {
    @EnvironmentObject private var model: ReaderModel
    let result: OnlineSearchResult

    private var theme: ReadingTheme { model.readingSettings.theme }
    @State private var isAdded = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.readerInk(for: theme))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let author = result.author, author.isEmpty == false {
                        Text(author)
                    }
                    if result.author?.isEmpty == false {
                        Text("·")
                    }
                    Text(result.sourceName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let intro = result.intro, intro.isEmpty == false {
                    Text(intro)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.86))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 6) {
                Button {
                    model.addOnlineBookToShelf(result)
                    isAdded = true
                } label: {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isAdded ? Color.readerAccent : .secondary)
                .help("加入书架")

                Button {
                    model.downloadOnlineBook(result)
                } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("下载到本地")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 52, alignment: .top)
        .background(Color.readerPaper(for: theme).opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.sidebarBorder(for: theme), lineWidth: 1)
        }
    }
}

struct BookShelfOverlay<Content: View>: View {
    @ViewBuilder let content: Content
    let onTapOutside: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onTapOutside()
                }

            content
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.sidebarBorder, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.20), radius: 28, x: 0, y: 14)
        }
        .transition(.opacity)
    }
}
