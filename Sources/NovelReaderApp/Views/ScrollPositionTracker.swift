import AppKit
import SwiftUI

struct ScrollPositionTracker: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void
    let restoreOffset: CGFloat

    func makeNSView(context: Context) -> ScrollPositionTrackerView {
        let view = ScrollPositionTrackerView()
        view.onScroll = onScroll
        view.restoreOffset = restoreOffset
        view.scheduleRestore()
        return view
    }

    func updateNSView(_ nsView: ScrollPositionTrackerView, context: Context) {
        nsView.onScroll = onScroll
        nsView.restoreOffset = restoreOffset
        nsView.scheduleRestore()
    }
}

final class ScrollPositionTrackerView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    var restoreOffset: CGFloat = 0
    nonisolated(unsafe) private var observer: NSObjectProtocol?
    private weak var scrollView: NSScrollView?
    private var restoreAttempts = 0

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attach()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attach()
    }

    private func attach() {
        let next = findScrollView()
        if scrollView !== next {
            detach()
            scrollView = next
            if let scrollView {
                scrollView.contentView.postsBoundsChangedNotifications = true
                observer = NotificationCenter.default.addObserver(
                    forName: NSView.boundsDidChangeNotification,
                    object: scrollView.contentView,
                    queue: .main
                ) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.reportOffset()
                    }
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.reportOffset()
            self?.scheduleRestore()
        }
    }

    private func detach() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func reportOffset() {
        guard let scrollView else { return }
        onScroll?(scrollView.contentView.bounds.origin.y)
    }

    func scheduleRestore() {
        DispatchQueue.main.async { [weak self] in
            self?.applyRestore()
        }
    }

    private func applyRestore() {
        guard let scrollView = scrollView ?? findScrollView() else {
            if restoreAttempts < 10 {
                restoreAttempts += 1
                scheduleRestore()
            }
            return
        }

        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        let visibleHeight = scrollView.bounds.height
        guard documentHeight > 0, visibleHeight > 0 else {
            if restoreAttempts < 10 {
                restoreAttempts += 1
                scheduleRestore()
            }
            return
        }

        restoreAttempts = 0
        let maxOffset = max(documentHeight - visibleHeight, 0)
        let clamped = max(0, min(restoreOffset, maxOffset))
        var bounds = scrollView.contentView.bounds
        bounds.origin.y = clamped
        scrollView.contentView.bounds = bounds
    }

    private func findScrollView() -> NSScrollView? {
        if let enclosingScrollView {
            return enclosingScrollView
        }

        var view = superview
        while let currentView = view {
            if let found = currentView as? NSScrollView {
                return found
            }

            view = currentView.superview
        }

        return nil
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
