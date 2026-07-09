import SwiftUI

extension Color {
    static let readerPaper = Color(nsColor: NSColor.dynamicColor(
        light: NSColor(red: 0.984, green: 0.973, blue: 0.945, alpha: 1),
        dark: NSColor(red: 0.122, green: 0.126, blue: 0.114, alpha: 1)
    ))
    static let readerPanel = Color(nsColor: NSColor.dynamicColor(
        light: NSColor(red: 1.000, green: 0.980, blue: 0.945, alpha: 1),
        dark: NSColor(red: 0.157, green: 0.169, blue: 0.145, alpha: 1)
    ))
    static let sidebarBackground = Color(nsColor: NSColor.dynamicColor(
        light: NSColor(red: 0.949, green: 0.953, blue: 0.941, alpha: 1),
        dark: NSColor(red: 0.141, green: 0.145, blue: 0.125, alpha: 1)
    ))
    static let sidebarBorder = Color(nsColor: NSColor.dynamicColor(
        light: NSColor.black.withAlphaComponent(0.12),
        dark: NSColor.white.withAlphaComponent(0.10)
    ))
    static let readerInk = Color(nsColor: NSColor.dynamicColor(
        light: NSColor(red: 0.149, green: 0.129, blue: 0.106, alpha: 1),
        dark: NSColor(red: 0.898, green: 0.875, blue: 0.827, alpha: 1)
    ))
    static let readerAccent = Color(nsColor: NSColor.dynamicColor(
        light: NSColor(red: 0.561, green: 0.310, blue: 0.180, alpha: 1),
        dark: NSColor(red: 0.831, green: 0.604, blue: 0.447, alpha: 1)
    ))

    static func readerPaper(for theme: ReadingTheme) -> Color {
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

    static func readerInk(for theme: ReadingTheme) -> Color {
        switch theme {
        case .white, .light, .sepia:
            Color(nsColor: NSColor(red: 0.149, green: 0.129, blue: 0.106, alpha: 1))
        case .dark:
            Color(nsColor: NSColor(red: 0.898, green: 0.875, blue: 0.827, alpha: 1))
        }
    }

    static func readerPanel(for theme: ReadingTheme) -> Color {
        switch theme {
        case .white:
            Color(nsColor: NSColor(red: 0.976, green: 0.976, blue: 0.972, alpha: 1))
        case .light:
            Color(nsColor: NSColor(red: 1.000, green: 0.980, blue: 0.945, alpha: 1))
        case .sepia:
            Color(nsColor: NSColor(red: 0.949, green: 0.906, blue: 0.827, alpha: 1))
        case .dark:
            Color(nsColor: NSColor(red: 0.157, green: 0.169, blue: 0.145, alpha: 1))
        }
    }

    static func sidebarBackground(for theme: ReadingTheme) -> Color {
        switch theme {
        case .white:
            Color(nsColor: NSColor(red: 0.956, green: 0.958, blue: 0.955, alpha: 1))
        case .light:
            Color(nsColor: NSColor(red: 0.949, green: 0.953, blue: 0.941, alpha: 1))
        case .sepia:
            Color(nsColor: NSColor(red: 0.949, green: 0.906, blue: 0.827, alpha: 1))
        case .dark:
            Color(nsColor: NSColor(red: 0.141, green: 0.145, blue: 0.125, alpha: 1))
        }
    }

    static func sidebarBorder(for theme: ReadingTheme) -> Color {
        switch theme {
        case .white, .light, .sepia:
            Color(nsColor: NSColor.black.withAlphaComponent(0.12))
        case .dark:
            Color(nsColor: NSColor.white.withAlphaComponent(0.10))
        }
    }
}

private extension NSColor {
    static func dynamicColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return bestMatch == .darkAqua ? dark : light
        }
    }
}

struct PrimarySidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(height: 34)
            .padding(.horizontal, 12)
            .background(
                LinearGradient(
                    colors: [
                        Color.readerAccent.opacity(configuration.isPressed ? 0.82 : 0.94),
                        Color.readerAccent.opacity(configuration.isPressed ? 0.74 : 0.84)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color.readerAccent.opacity(configuration.isPressed ? 0.06 : 0.14), radius: 8, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SecondarySidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.readerInk.opacity(configuration.isPressed ? 0.62 : 0.72))
            .background(Color.readerPanel.opacity(configuration.isPressed ? 0.56 : 0.42))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.sidebarBorder.opacity(configuration.isPressed ? 0.86 : 0.58), lineWidth: 1)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.02 : 0.05), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct PanelActionButtonStyle: ButtonStyle {
    let width: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.readerAccent)
            .frame(width: width, height: 30)
            .background(Color.readerAccent.opacity(configuration.isPressed ? 0.15 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.readerAccent.opacity(configuration.isPressed ? 0.30 : 0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct MujianSegmentedControl<Option: Hashable>: View {
    @EnvironmentObject private var model: ReaderModel

    let options: [Option]
    @Binding var selection: Option
    let width: CGFloat
    let label: (Option) -> String

    init(
        options: [Option],
        selection: Binding<Option>,
        width: CGFloat,
        label: @escaping (Option) -> String
    ) {
        self.options = options
        _selection = selection
        self.width = width
        self.label = label
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection

                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .foregroundStyle(isSelected ? Color.white : Color.readerInk(for: model.readingSettings.theme).opacity(0.76))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(isSelected ? Color.readerAccent : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(width: width, height: 34)
        .background(Color.primary.opacity(model.readingSettings.theme == .dark ? 0.13 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.sidebarBorder(for: model.readingSettings.theme).opacity(0.52), lineWidth: 1)
        }
    }
}

struct PrimaryIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.readerAccent.opacity(configuration.isPressed ? 0.76 : 1))
            .background(Color.readerAccent.opacity(configuration.isPressed ? 0.17 : 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.readerAccent.opacity(configuration.isPressed ? 0.30 : 0.22), lineWidth: 1)
            }
            .shadow(color: Color.readerAccent.opacity(configuration.isPressed ? 0.03 : 0.10), radius: 6, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct FloatingIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.readerInk.opacity(configuration.isPressed ? 0.62 : 0.72))
            .background(Color.readerPanel.opacity(configuration.isPressed ? 0.70 : 0.88))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.sidebarBorder.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.10), radius: 10, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}
