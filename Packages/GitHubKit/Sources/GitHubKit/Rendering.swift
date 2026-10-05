import Foundation

public struct DiffLine: Sendable, Identifiable, Equatable {
    public enum Kind: String, Sendable { case context, addition, deletion, hunk, metadata }
    public let id: Int
    public let text: String
    public let kind: Kind
    public let oldLine: Int?
    public let newLine: Int?
    public static func parse(_ patch: String) -> [DiffLine] {
        var old = 0; var new = 0; var inHunk = false
        return patch.components(separatedBy: .newlines).enumerated().map { index, text in
            var kind: Kind = .metadata; var oldLine: Int?; var newLine: Int?
            if text.hasPrefix("@@") {
                kind = .hunk; inHunk = true
                let words = text.split(separator: " ")
                if words.count > 2 {
                    old = Int(words[1].dropFirst().split(separator: ",")[0]) ?? 0
                    new = Int(words[2].dropFirst().split(separator: ",")[0]) ?? 0
                }
            } else if inHunk && text.hasPrefix("+") { kind = .addition; newLine = new; new += 1 }
            else if inHunk && text.hasPrefix("-") { kind = .deletion; oldLine = old; old += 1 }
            else if inHunk && text.hasPrefix(" ") { kind = .context; oldLine = old; newLine = new; old += 1; new += 1 }
            return DiffLine(id: index, text: text, kind: kind, oldLine: oldLine, newLine: newLine)
        }
    }
}

public struct ANSISpan: Sendable, Identifiable, Equatable {
    public let id: Int
    public let text: String
    public let color: Int?
    public let bold: Bool
}

public enum ANSI {
    public static func parse(_ source: String) -> [ANSISpan] {
        guard let regex = try? NSRegularExpression(pattern: "\u{001B}\\[([0-9;]*)m") else { return [] }
        let ns = source as NSString; let matches = regex.matches(in: source, range: NSRange(location: 0, length: ns.length))
        var spans: [ANSISpan] = []; var position = 0; var color: Int?; var bold = false
        for match in matches {
            if match.range.location > position { spans.append(ANSISpan(id: spans.count, text: ns.substring(with: NSRange(location: position, length: match.range.location - position)), color: color, bold: bold)) }
            let codes = ns.substring(with: match.range(at: 1)).split(separator: ";").compactMap { Int($0) }
            if codes.isEmpty { color = nil; bold = false }
            for code in codes {
                if code == 0 { color = nil; bold = false }
                else if code == 1 { bold = true }
                else if code == 22 { bold = false }
                else if code == 39 { color = nil }
                else if (30...37).contains(code) { color = code - 30 }
                else if (90...97).contains(code) { color = code - 90 }
            }
            position = match.range.location + match.range.length
        }
        if position < ns.length { spans.append(ANSISpan(id: spans.count, text: ns.substring(from: position), color: color, bold: bold)) }
        return spans
    }
}
