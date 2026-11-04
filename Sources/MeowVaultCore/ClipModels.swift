import Foundation

public enum ClipGroup: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case all = "All"
    case links = "Links"
    case code = "Code"
    case images = "Images"
    case emails = "Emails"
    case text = "Text"

    public var id: String { rawValue }
}

public enum ClipPayload: Codable, Equatable, Hashable, Sendable {
    case text(String)
    case image(data: Data)
}

public struct ClipItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let payload: ClipPayload
    public let preview: String
    public let group: ClipGroup
    public let createdAt: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        payload: ClipPayload,
        preview: String,
        group: ClipGroup,
        createdAt: Date,
        isPinned: Bool = false
    ) {
        self.id = id
        self.payload = payload
        self.preview = preview
        self.group = group
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}

extension ClipItem {
    /// Case-insensitive match against the preview, the group name and the full clip text.
    /// `query` must already be trimmed and non-empty.
    public func matches(_ query: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        if preview.range(of: query, options: options) != nil
            || group.rawValue.range(of: query, options: options) != nil {
            return true
        }
        if case .text(let value) = payload {
            return value.range(of: query, options: options) != nil
        }
        return false
    }
}

public enum ClipClassifier {
    public static func group(for payload: ClipPayload) -> ClipGroup {
        switch payload {
        case .image:
            return .images
        case .text(let value):
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if isEmail(text) { return .emails }
            if URL(string: text)?.scheme?.hasPrefix("http") == true { return .links }
            if looksLikeCode(text) { return .code }
            return .text
        }
    }

    private static func isEmail(_ value: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func looksLikeCode(_ value: String) -> Bool {
        let markers = ["func ", "let ", "var ", "class ", "struct ", "import ", "return ", "await ", "try ", "{", "};", "=>", "</"]
        return markers.contains { value.contains($0) }
    }
}

public enum PlainText {
    public static func normalized(_ value: String) -> String {
        let collapsedLines = value
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line
                    .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return collapsedLines.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
    }
}
