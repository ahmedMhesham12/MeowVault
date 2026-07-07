import Foundation
import Testing
@testable import MeowVaultCore

@Test func storeDeduplicatesByContentAndKeepsNewestFirst() {
    let store = ClipStore(now: Date.init)
    store.capture(.text("alpha"))
    store.capture(.text("beta"))
    store.capture(.text("alpha"))

    #expect(store.items.map(\.preview) == ["alpha", "beta"])
    #expect(store.items.count == 2)
}

@Test func pinnedItemsStayAboveUnpinnedItems() {
    let store = ClipStore(now: Date.init)
    let first = store.capture(.text("first"))
    store.capture(.text("second"))
    store.togglePin(first.id)

    #expect(store.visibleItems.map(\.preview) == ["first", "second"])
}

@Test func limitKeepsPinnedItemsFirstAndTrimsOldUnpinnedItems() {
    var tick = 0
    let store = ClipStore(limit: 3) {
        defer { tick += 1 }
        return Date(timeIntervalSince1970: TimeInterval(tick))
    }

    let first = store.capture(.text("first"))
    store.togglePin(first.id)
    store.capture(.text("second"))
    store.capture(.text("third"))
    store.capture(.text("fourth"))

    #expect(store.visibleItems.map(\.preview) == ["first", "fourth", "third"])
}

@Test func changingLimitImmediatelyTrimsHistory() {
    var tick = 0
    let store = ClipStore(limit: 5) {
        defer { tick += 1 }
        return Date(timeIntervalSince1970: TimeInterval(tick))
    }

    store.capture(.text("first"))
    store.capture(.text("second"))
    store.capture(.text("third"))
    store.setLimit(2)

    #expect(store.visibleItems.map(\.preview) == ["third", "second"])
}

@Test func searchMatchesPreviewAndGroups() {
    let store = ClipStore(now: Date.init)
    store.capture(.text("https://meowvault.dev"))
    store.capture(.text("let token = value"))

    #expect(store.search("links").map(\.preview) == ["https://meowvault.dev"])
    #expect(store.search("token").map(\.preview) == ["let token = value"])
}

@Test func pinnedStateSurvivesJSONRoundTrip() throws {
    let store = ClipStore(now: Date.init)
    let item = store.capture(.text("keep me"))
    store.togglePin(item.id)

    let data = try JSONEncoder().encode(store.visibleItems)
    let decoded = try JSONDecoder().decode([ClipItem].self, from: data)

    #expect(decoded.first?.preview == "keep me")
    #expect(decoded.first?.isPinned == true)
}
