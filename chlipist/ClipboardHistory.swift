struct ClipboardHistory {
  static func updatedHistory(afterRecording text: String, in history: [String], maxCount: Int)
    -> [String]
  {
    guard !text.isEmpty else { return history }
    guard text != history.first else { return history }

    var updatedHistory = history.filter { $0 != text }
    updatedHistory.insert(text, at: 0)

    if updatedHistory.count > maxCount {
      updatedHistory.removeLast(updatedHistory.count - maxCount)
    }

    return updatedHistory
  }

  static func sanitizedPersistedHistory(_ history: [String], maxCount: Int) -> [String] {
    Array(history.prefix(maxCount)).filter { !$0.isEmpty }
  }
}
