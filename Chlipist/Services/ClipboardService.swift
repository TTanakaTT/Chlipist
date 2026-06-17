import Cocoa
import Combine

protocol ClipboardServiceProtocol {
  var history: [String] { get }
  var historyPublisher: AnyPublisher<[String], Never> { get }

  func add(_ text: String)
  func setClipboard(_ text: String)
  func clearHistory()
}

final class ClipboardService: ClipboardServiceProtocol {
  private let maxHistoryCount = 50
  private let persistenceService: PersistenceServiceProtocol

  @Published private(set) var history: [String] = []
  var historyPublisher: AnyPublisher<[String], Never> {
    $history.eraseToAnyPublisher()
  }

  init(persistenceService: PersistenceServiceProtocol) {
    self.persistenceService = persistenceService
    self.history = persistenceService.load()
  }

  func add(_ text: String) {
    guard !text.isEmpty else { return }

    let updatedHistory = ClipboardHistory.updatedHistory(
      afterRecording: text,
      in: history,
      maxCount: maxHistoryCount
    )

    guard updatedHistory != history else { return }
    history = updatedHistory
    persistenceService.save(history)
  }

  func setClipboard(_ text: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(text, forType: .string)
  }

  func clearHistory() {
    history = []
    persistenceService.save(history)
  }
}
