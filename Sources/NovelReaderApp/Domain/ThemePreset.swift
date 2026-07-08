import SwiftUI

struct ThemePreset: Identifiable, Equatable {
    let id: UUID
    var name: String
    var baseTheme: ReadingTheme
    var paperColorHex: String
    var inkColorHex: String
    var accentColorHex: String
    var fontFamily: String
    var fontSize: Double
    var lineHeight: Double
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        baseTheme: ReadingTheme,
        paperColorHex: String,
        inkColorHex: String,
        accentColorHex: String,
        fontFamily: String = "Songti SC",
        fontSize: Double = 17,
        lineHeight: Double = 1.82,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseTheme = baseTheme
        self.paperColorHex = paperColorHex
        self.inkColorHex = inkColorHex
        self.accentColorHex = accentColorHex
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.isBuiltIn = isBuiltIn
    }

    static let builtIn: [ThemePreset] = [
        ThemePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "纯白", baseTheme: .white,
            paperColorHex: "#FFFFFF", inkColorHex: "#26211A", accentColorHex: "#8F4F2E",
            isBuiltIn: true
        ),
        ThemePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "纸白", baseTheme: .light,
            paperColorHex: "#FBF8F1", inkColorHex: "#26211A", accentColorHex: "#8F4F2E",
            isBuiltIn: true
        ),
        ThemePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "护眼", baseTheme: .sepia,
            paperColorHex: "#E9DCC7", inkColorHex: "#26211A", accentColorHex: "#8F4F2E",
            isBuiltIn: true
        ),
        ThemePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "夜读", baseTheme: .dark,
            paperColorHex: "#1F2019", inkColorHex: "#E5E0D3", accentColorHex: "#D49A72",
            isBuiltIn: true
        )
    ]
}

extension ReadingSettings {
    func apply(preset: ThemePreset) -> ReadingSettings {
        var copy = self
        copy.theme = preset.baseTheme
        copy.paperColorHex = preset.paperColorHex
        copy.inkColorHex = preset.inkColorHex
        copy.accentColorHex = preset.accentColorHex
        copy.fontFamily = preset.fontFamily
        copy.fontSize = preset.fontSize
        copy.lineHeight = preset.lineHeight
        return copy
    }
}

extension String {
    func toColor() -> Color {
        let hex = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard let int = UInt32(cleaned, radix: 16) else {
            return Color.gray
        }
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
