import Foundation
import Testing
@testable import MeowVaultCore

@Test func classifiesLinksEmailsCodeAndText() {
    #expect(ClipClassifier.group(for: .text("https://example.com/a?q=1")) == .links)
    #expect(ClipClassifier.group(for: .text("hello@meowvault.dev")) == .emails)
    #expect(ClipClassifier.group(for: .text("let value = try await fetch()")) == .code)
    #expect(ClipClassifier.group(for: .text("plain meeting note")) == .text)
}

@Test func classifiesImagePayloads() {
    #expect(ClipClassifier.group(for: .image(data: Data([1, 2, 3]))) == .images)
    #expect(!ClipGroup.allCases.map(\.rawValue).contains("Files"))
}

@Test func trimsFormattingForPlainTextPaste() {
    #expect(PlainText.normalized("  hello\t\tworld\n\n\nagain  ") == "hello world\n\nagain")
}
