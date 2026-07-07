import Foundation
import Testing
@testable import MeowVaultCore

@Test func localKeyFileStoreCreatesStablePrivateKey() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("storage.key")
    let first = try LocalKeyFileStore.key(at: url)
    let second = try LocalKeyFileStore.key(at: url)
    let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber

    #expect(first.count == 32)
    #expect(first == second)
    #expect((permissions?.intValue ?? 0) & 0o077 == 0)
}

@Test func localKeyFileStoreCreatesDifferentKeysForDifferentStores() throws {
    let firstDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let secondDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: firstDirectory)
        try? FileManager.default.removeItem(at: secondDirectory)
    }

    let first = try LocalKeyFileStore.key(at: firstDirectory.appendingPathComponent("storage.key"))
    let second = try LocalKeyFileStore.key(at: secondDirectory.appendingPathComponent("storage.key"))

    #expect(first.count == 32)
    #expect(second.count == 32)
    #expect(first != second)
}
