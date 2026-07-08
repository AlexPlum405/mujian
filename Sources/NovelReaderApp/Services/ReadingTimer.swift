import Foundation

@MainActor
final class ReadingTimer: ObservableObject {
    @Published private(set) var isCounting = false

    private var timer: Timer?
    private var bookId: UUID?
    private weak var repository: BookRepository?
    private var accumulatedSeconds: Double = 0
    private var lastTickDate: Date?
    private var focusLossPauseWork: DispatchWorkItem?
    private let interval: TimeInterval = 5

    init(repository: BookRepository) {
        self.repository = repository
    }

    func start(for bookId: UUID) {
        stopTimer()
        flush()
        self.bookId = bookId
        accumulatedSeconds = 0
        lastTickDate = Date()
        isCounting = true
        startTimer()
    }

    func pause() {
        flush()
        stopTimer()
        lastTickDate = nil
        isCounting = false
    }

    func resume() {
        guard isCounting == false, bookId != nil else { return }
        lastTickDate = Date()
        isCounting = true
        startTimer()
    }

    func handleWindowLostFocus() {
        guard isCounting else { return }
        focusLossPauseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pause()
        }
        focusLossPauseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    func handleWindowGainedFocus() {
        focusLossPauseWork?.cancel()
        focusLossPauseWork = nil
        resume()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        flush()
        lastTickDate = Date()
    }

    private func flush() {
        guard let repository, let bookId, let last = lastTickDate else { return }
        let elapsed = Date().timeIntervalSince(last)
        guard elapsed > 0 else { return }
        accumulatedSeconds += elapsed
        repository.addReadingSeconds(accumulatedSeconds, for: bookId)
        let daily = repository.loadDailyReadingSeconds()
        repository.saveDailyReadingSeconds(daily + accumulatedSeconds)
        accumulatedSeconds = 0
    }
}
