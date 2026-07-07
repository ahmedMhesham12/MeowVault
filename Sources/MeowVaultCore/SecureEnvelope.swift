import CryptoKit
import Foundation

public enum SecureEnvelopeError: Error {
    case invalidKey
    case invalidEnvelope
}

public struct SecureEnvelopePayload: Codable, Equatable {
    public let version: Int
    public let nonce: Data
    public let ciphertext: Data
    public let tag: Data
}

public enum SecureEnvelope {
    public static func encrypt(_ plaintext: Data, keyData: Data) throws -> Data {
        let key = try symmetricKey(from: keyData)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        let payload = SecureEnvelopePayload(
            version: 1,
            nonce: Data(sealed.nonce),
            ciphertext: sealed.ciphertext,
            tag: sealed.tag
        )
        return try JSONEncoder().encode(payload)
    }

    public static func decrypt(_ encrypted: Data, keyData: Data) throws -> Data {
        let key = try symmetricKey(from: keyData)
        let payload = try JSONDecoder().decode(SecureEnvelopePayload.self, from: encrypted)
        guard payload.version == 1 else { throw SecureEnvelopeError.invalidEnvelope }
        let sealed = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: payload.nonce),
            ciphertext: payload.ciphertext,
            tag: payload.tag
        )
        return try AES.GCM.open(sealed, using: key)
    }

    private static func symmetricKey(from keyData: Data) throws -> SymmetricKey {
        guard keyData.count == 32 else { throw SecureEnvelopeError.invalidKey }
        return SymmetricKey(data: keyData)
    }
}
