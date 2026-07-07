import Foundation

public enum LocalKeyFileStoreError: Error {
    case invalidExistingKey
}

public enum LocalKeyFileStore {
    public static func key(at url: URL) throws -> Data {
        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try Data(contentsOf: url)
            guard existing.count == 32 else { throw LocalKeyFileStoreError.invalidExistingKey }
            try protect(url)
            return existing
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
        let key = Data(bytes)
        try key.write(to: url, options: .atomic)
        try protect(url)
        return key
    }

    private static func protect(_ url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
