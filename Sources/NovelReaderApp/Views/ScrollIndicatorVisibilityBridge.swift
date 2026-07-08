import AppKit
import SwiftUI

struct ScrollIndicatorVisibilityBridge: NSViewRepresentable {
    let isVisible: Bool

    func makeNSView(context: Context) -> ScrollIndicatorVisibilityView {
        ScrollIndicatorVisibilityView()
    }

    func updateNSView(_ nsView: ScrollIndicatorVisibilityView, context: Context) {
        nsView.isIndicatorVisible = isVisible
        nsView.scheduleApply()
    }
}

final class ScrollIndicatorVisibilityView: NSView {
    var isIndicatorVisible = false
    private weak var targetScrollView: NSScrollView?
    private var applyAttempts = 0

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        targetScrollView = nil
        scheduleApply()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        targetScrollView = nil
        scheduleApply()
    }

    func scheduleApply() {
        DispatchQueue.main.async { [weak self] in
            self?.applyVisibility()
        }
    }

    private func applyVisibility() {
        guard let scrollView = targetScrollView ?? findTargetScrollView() else {
            if applyAttempts < 8 {
                applyAttempts += 1
                scheduleApply()
            }
            return
        }

        applyAttempts = 0
        targetScrollView = scrollView
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = false
        scrollView.hasVerticalScroller = isIndicatorVisible
        scrollView.verticalScroller?.isHidden = isIndicatorVisible == false
        scrollView.verticalScroller?.alphaValue = isIndicatorVisible ? 1 : 0
    }

    private func findTargetScrollView() -> NSScrollView? {
        if let enclosingScrollView {
            return enclosingScrollView
        }

        var view = superview
        while let currentView = view {
            if let scrollView = currentView as? NSScrollView {
                return scrollView
            }

            view = currentView.superview
        }

        return nil
    }
}
