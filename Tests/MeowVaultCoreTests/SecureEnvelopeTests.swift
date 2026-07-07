import Foundation
import Testing
@testable import MeowVaultCore

@Test func encryptedEnvelopeRoundTripsWithoutPlaintext() throws {
    let key = Data((0..<32).map { UInt8($0) })
    let plaintext = Data("secret clipboard text".utf8)

    let encrypted = try SecureEnvelope.encrypt(plaintext, keyData: key)
    #expect(!String(decoding: encrypted, as: UTF8.self).contains("secret clipboard text"))

    let decrypted = try SecureEnvelope.decrypt(encrypted, keyData: key)
    #expect(decrypted == plaintext)
}

@Test func encryptedEnvelopeRejectsWrongKey() throws {
    let key = Data((0..<32).map { UInt8($0) })
    let wrongKey = Data((32..<64).map { UInt8($0) })
    let encrypted = try SecureEnvelope.encrypt(Data("secret".utf8), keyData: key)

    #expect(throws: Error.self) {
        try SecureEnvelope.decrypt(encrypted, keyData: wrongKey)
    }
}
