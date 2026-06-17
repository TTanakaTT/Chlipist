import Foundation

extension String {
  var normalizedMenuDisplayText: String {
    collapsingLineBreakMarkers()
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  var menuDisplayTitle: String {
    let normalized = normalizedMenuDisplayText
    guard !normalized.isEmpty else { return "…" }

    let maxCharacters = 30
    if normalized.count > maxCharacters {
      return String(normalized.prefix(maxCharacters - 1)) + "…"
    }
    return normalized
  }

  var menuDisplayToolTip: String {
    let maxCharacters = 200
    if self.count > maxCharacters {
      return String(self.prefix(maxCharacters - 1)) + "…"
    }
    return self
  }

  private func collapsingLineBreakMarkers() -> String {
    self.replacingOccurrences(of: "\r\n", with: " ↵ ")
      .replacingOccurrences(of: "\n", with: " ↵ ")
      .replacingOccurrences(of: "\r", with: " ↵ ")
  }
}
