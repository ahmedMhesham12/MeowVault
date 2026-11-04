import CryptoKit
import Foundation

public final class ClipStore {
    public private(set) var items: [ClipItem]
    public private(set) var limit: Int
    private let now: () -> Date
    private var fingerprintCache: [UUID: String] = [:]

    public init(items: [ClipItem] = [], limit: Int = 200, now: @escaping () -> Date = Date.init) {
        self.items = items
        self.limit = Self.clampedLimit(limit)
        self.now = now
        trimToLimit()
    }

    @discardableResult
    public func capture(_ payload: ClipPayload) -> ClipItem {
        let fingerprint = Self.fingerprint(payload)
        var existing: ClipItem?
        var retainedItems: [ClipItem] = []
        retainedItems.reserveCapacity(items.count)

        for item in items {
            if cachedFingerprint(of: item) == fingerprint {
                existing = existing ?? item
            } else {
                retainedItems.append(item)
            }
        }

        let item = ClipItem(
            payload: payload,
            preview: Self.preview(for: payload),
            group: ClipClassifier.group(for: payload),
            createdAt: now(),
            isPinned: existing?.isPinned ?? false
        )
        fingerprintCache[item.id] = fingerprint
        items = [item] + retainedItems
        trimToLimit()
        return item
    }

    public var visibleItems: [ClipItem] {
        items.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.createdAt > $1.createdAt
        }
    }

    public func items(in group: ClipGroup) -> [ClipItem] {
        guard group != .all else { return visibleItems }
        return visibleItems.filter { $0.group == group }
    }

    public func search(_ query: String) -> [ClipItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return visibleItems }
        return visibleItems.filter { $0.matches(needle) }
    }

    public func togglePin(_ id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        trimToLimit()
    }

    public func remove(_ id: ClipItem.ID) {
        items.removeAll { $0.id == id }
    }

    public func replaceItems(_ nextItems: [ClipItem]) {
        items = nextItems
        trimToLimit()
    }

    public func setLimit(_ nextLimit: Int) {
        limit = Self.clampedLimit(nextLimit)
        trimToLimit()
    }

    private func trimToLimit() {
        items = Array(visibleItems.prefix(limit))
        if fingerprintCache.count > items.count {
            let liveIDs = Set(items.map(\.id))
            fingerprintCache = fingerprintCache.filter { liveIDs.contains($0.key) }
        }
    }

    /// Hashing image payloads is the expensive part of dedupe, so each item is fingerprinted once.
    private func cachedFingerprint(of item: ClipItem) -> String {
        if let cached = fingerprintCache[item.id] { return cached }
        let value = Self.fingerprint(item.payload)
        fingerprintCache[item.id] = value
        return value
    }

    private static func clampedLimit(_ value: Int) -> Int {
        min(max(value, 1), 5_000)
    }

    private static func preview(for payload: ClipPayload) -> String {
        switch payload {
        case .text(let value):
            return PlainText.normalized(value).prefixString(240)
        case .image(let data):
            return "Image (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))"
        }
    }

    private static func fingerprint(_ payload: ClipPayload) -> String {
        switch payload {
        case .text(let value):
            return "text:\(PlainText.normalized(value))"
        case .image(let data):
            return "image:\(SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined())"
        }
    }
}

private extension StringProtocol {
    func prefixString(_ maxLength: Int) -> String {
        String(prefix(maxLength))
    }
}
