import AppKit
import SwiftUI

struct ReaderFloatingPanel: View {
    @EnvironmentObject private var model: ReaderModel

    private var panelWidth: CGFloat {
        switch model.activePanel {
        case .settings:
            420
        case .toc, .themes:
            270
        case .search:
            300
        case .onlineSearch:
            420
        case .sources:
            360
        case nil:
            0
        }
    }

    var body: some View {
        Group {
            switch model.activePanel {
            case .toc:
                ChapterDirectoryPanel()
            case .settings:
                ReadingSettingsPanel()
            case .themes:
                ThemeQuickPanel()
            case .search:
                SearchPanel()
            case .onlineSearch:
                OnlineSearchPanel {
                    model.closePanel()
                }
            case .sources:
                BookSourceManagePanel {
                    model.closePanel()
                }
            case nil:
                EmptyView()
            }
        }
        .frame(width: panelWidth)
        .padding(15)
        .background(Color.readerPanel(for: model.readingSettings.theme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.sidebarBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.20), radius: 28, x: 0, y: 14)
    }
}

private struct ChapterDirectoryPanel: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: "目录", subtitle: model.hasDocument ? "\(model.chapterCount) 章" : "等待 TXT")

            if model.hasDocument {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(model.chapterDirectoryItems) { chapter in
                            Button {
                                model.selectChapter(id: chapter.id)
                                model.closePanel()
                            } label: {
                                HStack(spacing: 10) {
                                    Text(chapter.title)
                                        .font(.system(size: 12, weight: chapter.id == model.selectedChapterIndex ? .semibold : .regular))
                                        .lineLimit(1)

                                    Spacer()

                                    if chapter.id == model.selectedChapterIndex {
                                        Circle()
                                            .fill(Color.readerAccent)
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                .foregroundStyle(chapter.id == model.selectedChapterIndex ? Color.readerInk : Color.secondary)
                                .padding(.horizontal, 9)
                                .frame(height: 32)
                                .background(chapter.id == model.selectedChapterIndex ? Color.readerAccent.opacity(0.12) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 340)
            }
        }
    }
}

private struct ThemeQuickPanel: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var newThemeName: String = ""
    @State private var isSavingTheme: Bool = false

    private var theme: ReadingTheme { model.readingSettings.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelHeader(title: "阅读主题")

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("预置")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)

                    HStack(spacing: 6) {
                        ForEach(ReadingTheme.allCases, id: \.self) { theme in
                            Button {
                                model.setTheme(theme)
                            } label: {
                                VStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(swatchColor(for: theme))
                                        .frame(height: 36)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(
                                                    model.readingSettings.theme == theme
                                                        ? Color.readerAccent.opacity(0.6)
                                                        : Color.sidebarBorder.opacity(0.4),
                                                    lineWidth: model.readingSettings.theme == theme ? 2 : 1
                                                )
                                        }

                                    Text(theme.label)
                                        .font(.system(size: 10, weight: model.readingSettings.theme == theme ? .semibold : .regular))
                                        .foregroundStyle(model.readingSettings.theme == theme ? Color.readerInk(for: self.theme) : .secondary)
                                        .padding(.top, 4)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if model.themes.contains(where: { $0.isBuiltIn == false }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("自定义")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.3)

                        VStack(spacing: 4) {
                            ForEach(model.themes.filter { $0.isBuiltIn == false }) { preset in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(preset.paperColorHex.toColor())
                                        .frame(width: 18, height: 18)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .stroke(Color.sidebarBorder, lineWidth: 0.5)
                                        }

                                    Text(preset.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.readerInk(for: theme))

                                    Spacer()

                                    Button {
                                        model.applyTheme(preset)
                                    } label: {
                                        Text("应用")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.readerAccent)
                                            .padding(.horizontal, 8)
                                            .frame(height: 22)
                                            .background(Color.readerAccent.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        model.deleteTheme(id: preset.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary.opacity(0.6))
                                            .frame(width: 20, height: 20)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .frame(height: 30)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("字体")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)

                    HStack(spacing: 6) {
                        ForEach(["Songti SC", "Kaiti SC", "STHeiti", "STFangsong"], id: \.self) { font in
                            Button {
                                model.readingSettings.fontFamily = font
                            } label: {
                                Text(fontLabel(font))
                                    .font(.custom(font, size: 12))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 28)
                                    .foregroundStyle(model.readingSettings.fontFamily == font ? Color.white : Color.readerInk(for: theme))
                                    .background(
                                        model.readingSettings.fontFamily == font
                                            ? Color.readerAccent
                                            : Color.readerPanel(for: theme).opacity(0.6)
                                    )
                                    .clipShape(Capsule())
                                    .overlay {
                                        if model.readingSettings.fontFamily != font {
                                            Capsule()
                                                .stroke(Color.sidebarBorder(for: theme), lineWidth: 0.5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("颜色")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)

                    VStack(spacing: 4) {
                        colorRow(label: "底色", hex: Binding(
                            get: { model.readingSettings.paperColorHex },
                            set: { model.readingSettings.paperColorHex = $0 }
                        ))
                        colorRow(label: "字色", hex: Binding(
                            get: { model.readingSettings.inkColorHex },
                            set: { model.readingSettings.inkColorHex = $0 }
                        ))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)

            HStack {
                if isSavingTheme {
                    TextField("主题名称", text: $newThemeName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background(Color.readerPanel(for: theme))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(Color.sidebarBorder, lineWidth: 1)
                        }

                    Button("保存") {
                        model.saveCurrentAsTheme(name: newThemeName)
                        newThemeName = ""
                        isSavingTheme = false
                    }
                    .buttonStyle(PanelActionButtonStyle(width: 52))

                    Button("取消") {
                        newThemeName = ""
                        isSavingTheme = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                } else {
                    Spacer()

                    Button("存为新主题") {
                        isSavingTheme = true
                    }
                    .buttonStyle(PanelActionButtonStyle(width: 100))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.sidebarBorder(for: theme).opacity(0.4))
                    .frame(height: 1)
            }
        }
    }

    private func fontLabel(_ font: String) -> String {
        switch font {
        case "Songti SC": "宋"
        case "Kaiti SC": "楷"
        case "STHeiti": "黑"
        case "STFangsong": "仿"
        default: font
        }
    }

    private func colorRow(label: String, hex: Binding<String>) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(hex.wrappedValue.toColor())
                .frame(width: 20, height: 20)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.sidebarBorder, lineWidth: 0.5)
                }

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .leading)

            TextField("#RRGGBB", text: hex)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.readerInk(for: theme))

            Spacer()

            Button {
                let panel = NSColorPanel.shared
                panel.setTarget(ColorPickerCoordinator.shared)
                ColorPickerCoordinator.shared.onColorChange = { nsColor in
                    let newHex = String(format: "#%02X%02X%02X",
                        Int(nsColor.redComponent * 255),
                        Int(nsColor.greenComponent * 255),
                        Int(nsColor.blueComponent * 255))
                    hex.wrappedValue = newHex
                }
                panel.makeKeyAndOrderFront(nil)
            } label: {
                Image(systemName: "eyedropper")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .frame(height: 32)
        .background(Color.readerPanel(for: theme).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func swatchColor(for theme: ReadingTheme) -> Color {
        switch theme {
        case .white:
            Color(nsColor: NSColor.white)
        case .light:
            Color(nsColor: NSColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1))
        case .sepia:
            Color(nsColor: NSColor(red: 0.914, green: 0.867, blue: 0.780, alpha: 1))
        case .dark:
            Color(nsColor: NSColor(red: 0.122, green: 0.126, blue: 0.114, alpha: 1))
        }
    }
}

@MainActor
private final class ColorPickerCoordinator: NSObject {
    static let shared = ColorPickerCoordinator()
    var onColorChange: ((NSColor) -> Void)?

    @objc func colorChanged(_ sender: NSColorPanel) {
        onColorChange?(sender.color)
    }
}

private struct SearchPanel: View {
    @EnvironmentObject private var model: ReaderModel
    @FocusState private var isSearchFieldFocused: Bool

    private var canSearchOnline: Bool {
        model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && model.bookSources.contains { $0.isEnabled }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader(title: "正文搜索", subtitle: model.hasDocument ? "\(model.chapterCount) 章" : "等待 TXT")

            if model.hasDocument {
                HStack(spacing: 8) {
                    TextField("输入关键词", text: $model.searchQuery)
                        .font(.system(size: 13, weight: .medium))
                        .textFieldStyle(.plain)
                        .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            model.performSearch()
                        }

                    if model.searchQuery.isEmpty == false {
                        Button {
                            model.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Color.readerPanel(for: model.readingSettings.theme))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
                }
                .onChange(of: model.searchQuery) { _, _ in
                    model.performSearch()
                }

                if model.searchResults.isEmpty {
                    VStack(spacing: 10) {
                        Text(searchEmptyHint)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)

                        if canSearchOnline {
                            Button {
                                model.openOnlineSearch(query: model.searchQuery)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "network")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("搜书源")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .buttonStyle(PanelActionButtonStyle(width: 86))
                        }
                    }
                    .padding(.vertical, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(model.searchResults) { result in
                                Button {
                                    model.jumpToSearchResult(result)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.chapterTitle)
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)

                                        Text(result.preview)
                                            .font(.system(size: 11, weight: .regular))
                                            .lineLimit(2)
                                            .foregroundStyle(Color.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 7)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }

                Text("仅搜索已下载章节")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color.secondary)
            }
        }
        .onAppear {
            isSearchFieldFocused = true
            if model.searchQuery.isEmpty == false {
                model.performSearch()
            }
        }
    }

    private var searchEmptyHint: String {
        model.searchQuery.isEmpty ? "输入关键词搜索正文" : "没有匹配的结果"
    }
}

private enum SettingsPanelTab: String, CaseIterable {
    case reading
    case stealth
    case file

    var label: String {
        switch self {
        case .reading:
            "阅读"
        case .stealth:
            "隐蔽"
        case .file:
            "文件"
        }
    }
}

private struct ReadingSettingsPanel: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var selectedTab: SettingsPanelTab = .reading

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            PanelHeader(title: "设置")

            HStack(spacing: 4) {
                ForEach(SettingsPanelTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.label)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(selectedTab == tab ? Color.readerPanel(for: model.readingSettings.theme) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? Color.readerInk : Color.secondary)
                }
            }
            .padding(4)
            .background(Color.black.opacity(model.readingSettings.theme == .dark ? 0.14 : 0.055))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            switch selectedTab {
            case .reading:
                ReadingSettingsContent()
            case .stealth:
                StealthSettingsContent()
            case .file:
                FileSettingsContent()
            }
        }
    }
}

private struct ReadingSettingsContent: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsRow(title: "字号") {
                MujianSlider(
                    value: Binding(
                        get: { model.readingSettings.fontSize },
                        set: { model.setFontSize($0) }
                    ),
                    range: 15...22,
                    step: 1,
                    width: 154
                )
            }

            SettingsRow(title: "行距") {
                MujianSlider(
                    value: Binding(
                        get: { model.readingSettings.lineHeight },
                        set: { model.setLineHeight($0) }
                    ),
                    range: 1.65...2.05,
                    step: 0.05,
                    width: 154
                )
            }

            SettingsRow(title: "主题") {
                MujianSegmentedControl(
                    options: ReadingTheme.allCases,
                    selection: Binding(
                        get: { model.readingSettings.theme },
                        set: { model.setTheme($0) }
                    ),
                    width: 214
                ) { theme in
                    theme.label
                }
            }

            SettingsRow(title: "书架样式") {
                MujianSegmentedControl(
                    options: BookshelfStyle.allCases,
                    selection: Binding(
                        get: { model.readingSettings.bookshelfStyle },
                        set: { model.setBookshelfStyle($0) }
                    ),
                    width: 178
                ) { style in
                    style.label
                }
            }

            SettingsRow(title: "阅读模式") {
                MujianSegmentedControl(
                    options: ReadingMode.allCases,
                    selection: Binding(
                        get: { model.readingSettings.readingMode },
                        set: { model.setReadingMode($0) }
                    ),
                    width: 178
                ) { mode in
                    mode.label
                }
            }
        }
    }
}

private struct StealthSettingsContent: View {
    @EnvironmentObject private var model: ReaderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(title: "隐藏动作") {
                Text("隐藏窗口")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.readerAccent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            SettingsRow(title: "应急老板角") {
                MujianToggle(isOn: Binding(
                    get: { model.readingSettings.isEmergencyBossCornerEnabled },
                    set: { model.setEmergencyBossCornerEnabled($0) }
                ))
            }

            SettingsRow(title: "老板键快捷键") {
                Text(model.bossKeyShortcut.display)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.readerPanel(for: model.readingSettings.theme))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.sidebarBorder, lineWidth: 1)
                    }
            }

            SettingsRow(title: "录制新快捷键") {
                Button(model.isBossKeyRecording ? "录制中" : "录制") {
                    model.startBossKeyRecording()
                }
                .buttonStyle(PanelActionButtonStyle(width: 84))
            }

            if model.isBossKeyRecording {
                HotKeyRecorderView { shortcut in
                    model.updateBossKeyShortcut(shortcut)
                }
                .frame(height: 42)
                .background(Color.readerAccent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.readerAccent.opacity(0.32), lineWidth: 1)
                }
            }

            if let message = model.bossKeyMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.readerAccent)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.readerAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct FileSettingsContent: View {
    @EnvironmentObject private var model: ReaderModel
    @State private var patternText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsRow(title: "打开 TXT") {
                Button("选择") {
                    model.openTextFile()
                }
                .buttonStyle(PanelActionButtonStyle(width: 72))
            }

            SettingsRow(title: "编码") {
                Text("自动")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("自定义章节正则")
                    .font(.system(size: 13, weight: .semibold))

                TextField("如 ^第\\\\d+话", text: $patternText)
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.readerInk(for: model.readingSettings.theme))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.readerPanel(for: model.readingSettings.theme))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
                    }
                    .onChange(of: patternText) { _, newValue in
                        model.setCustomChapterPattern(newValue.isEmpty ? nil : newValue)
                    }

                if model.hasDocument {
                    Text("识别到 \(previewChapterCount) 章")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                if let error = model.chapterPatternError {
                    Text(error)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            }
            .padding(.top, 9)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.sidebarBorder)
                    .frame(height: 1)
            }
        }
        .onAppear {
            patternText = model.readingSettings.customChapterPattern ?? ""
        }
    }

    private var previewChapterCount: Int {
        guard let document = model.document else { return 0 }
        let previewSource = document.chapters
            .map { $0.title + "\n" + $0.body }
            .joined(separator: "\n")
        let pattern = patternText.isEmpty ? nil : patternText
        return ChapterDetector().detectChapters(in: previewSource, customPattern: pattern).count
    }
}

struct PanelHeader: View {
    @EnvironmentObject private var model: ReaderModel

    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            PanelTitle(title: title, subtitle: subtitle)

            Spacer()

            Button {
                model.closePanel()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}

private struct PanelTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MujianSlider: View {
    @EnvironmentObject private var model: ReaderModel
    @Binding var value: Double

    let range: ClosedRange<Double>
    let step: Double
    let width: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = proxy.size.width
            let progress = progress(in: trackWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(model.readingSettings.theme == .dark ? 0.18 : 0.10))
                    .frame(height: 8)

                Capsule()
                    .fill(Color.readerAccent)
                    .frame(width: max(progress, 8), height: 8)

                Circle()
                    .fill(Color.readerPaper(for: model.readingSettings.theme))
                    .frame(width: 20, height: 20)
                    .overlay {
                        Circle()
                            .stroke(Color.sidebarBorder(for: model.readingSettings.theme), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.14), radius: 5, x: 0, y: 2)
                    .offset(x: thumbOffset(in: trackWidth))
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        setValue(for: gesture.location.x, trackWidth: trackWidth)
                    }
            )
        }
        .frame(width: width, height: 30)
    }

    private func progress(in trackWidth: CGFloat) -> CGFloat {
        guard range.upperBound > range.lowerBound else {
            return 0
        }

        let ratio = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return min(max(CGFloat(ratio), 0), 1) * trackWidth
    }

    private func thumbOffset(in trackWidth: CGFloat) -> CGFloat {
        min(max(progress(in: trackWidth) - 10, 0), max(trackWidth - 20, 0))
    }

    private func setValue(for locationX: CGFloat, trackWidth: CGFloat) {
        guard trackWidth > 0 else {
            return
        }

        let ratio = min(max(Double(locationX / trackWidth), 0), 1)
        let rawValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
        let steps = ((rawValue - range.lowerBound) / step).rounded()
        value = min(max(range.lowerBound + steps * step, range.lowerBound), range.upperBound)
    }
}

struct MujianToggle: View {
    @EnvironmentObject private var model: ReaderModel
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.readerAccent : Color.primary.opacity(model.readingSettings.theme == .dark ? 0.16 : 0.10))

                Circle()
                    .fill(Color.readerPaper(for: model.readingSettings.theme))
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.13), radius: 4, x: 0, y: 2)
                    .padding(3)
            }
            .frame(width: 44, height: 24)
            .overlay {
                Capsule()
                    .stroke(Color.sidebarBorder(for: model.readingSettings.theme).opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsRow<Accessory: View>: View {
    let title: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Spacer(minLength: 10)
            accessory
        }
        .padding(.top, 9)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.sidebarBorder)
                .frame(height: 1)
        }
    }
}
