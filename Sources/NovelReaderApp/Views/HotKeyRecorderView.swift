import AppKit
import Carbon.HIToolbox
import SwiftUI

struct HotKeyRecorderView: NSViewRepresentable {
    let onRecord: (BossKeyShortcut) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onRecord = onRecord
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onRecord = onRecord
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class RecorderNSView: NSView {
    var onRecord: ((BossKeyShortcut) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        let shortcut = BossKeyShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: event.modifierFlags.carbonModifierFlags
        )
        onRecord?(shortcut)
    }
}

private extension NSEvent.ModifierFlags {
    var carbonModifierFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}
