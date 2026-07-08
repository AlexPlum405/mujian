import Carbon.HIToolbox
import Foundation

struct BossKeyShortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    var display: String {
        modifierPrefix + keyLabel(for: keyCode)
    }

    static let `default` = BossKeyShortcut(
        keyCode: UInt32(kVK_ANSI_H),
        modifiers: UInt32(controlKey | optionKey | cmdKey)
    )

    private var modifierPrefix: String {
        var prefix = ""
        if modifiers & UInt32(controlKey) != 0 { prefix += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { prefix += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { prefix += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { prefix += "⌘" }
        return prefix
    }
}

private func keyLabel(for keyCode: UInt32) -> String {
    switch Int(keyCode) {
    case kVK_Space:
        return "Space"
    case kVK_Escape:
        return "Esc"
    case kVK_Return:
        return "Return"
    case kVK_Tab:
        return "Tab"
    case kVK_Delete:
        return "⌫"
    case kVK_LeftArrow:
        return "←"
    case kVK_RightArrow:
        return "→"
    case kVK_UpArrow:
        return "↑"
    case kVK_DownArrow:
        return "↓"
    default:
        break
    }

    guard let layoutSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let layoutDataOpaque = TISGetInputSourceProperty(layoutSource, kTISPropertyUnicodeKeyLayoutData) else {
        return "Key \(keyCode)"
    }

    let data = Unmanaged<CFData>.fromOpaque(layoutDataOpaque).takeUnretainedValue() as Data
    var deadKeyState: UInt32 = 0
    var actualLength = 0
    var chars = [UniChar](repeating: 0, count: 4)

    let status = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> OSStatus in
        guard let base = buffer.baseAddress else { return OSStatus(paramErr) }
        let keyboardLayout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
        return UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &actualLength,
            &chars
        )
    }

    guard status == noErr, actualLength > 0 else {
        return "Key \(keyCode)"
    }

    return String(utf16CodeUnits: chars, count: actualLength).uppercased()
}
