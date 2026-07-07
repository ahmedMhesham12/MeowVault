import CryptoKit
import Foundation

public final class ClipStore {
    public private(set) var items: [ClipItem]
    private let now: () -> Date

    public init(items: [ClipItem] = [], now: @escaping () -> Date = Date.init) {
        self.items = items
        self.now = now
    }

    @discardableResult
    public func capture(_ payload: ClipPayload) -> ClipItem {
        let fingerprint = Self.fingerprint(payload)
        var existing: ClipItem?
        var retainedItems: [ClipItem] = []
        retainedItems.reserveCapacity(items.count)

        for item in items {
            if Self.fingerprint(item.payload) == fingerprint {
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
        items = [item] + retainedItems
        trim(limit: 200)
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
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return visibleItems }

        return visibleItems.filter { item in
            item.preview.lowercased().contains(needle)
                || item.group.rawValue.lowercased().contains(needle)
        }
    }

    public func togglePin(_ id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
    }

    public func remove(_ id: ClipItem.ID) {
        items.removeAll { $0.id == id }
    }

    public func replaceItems(_ nextItems: [ClipItem]) {
        items = nextItems
    }

    private func trim(limit: Int) {
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
        items = Array((pinned + unpinned).prefix(limit))
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
