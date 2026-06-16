import CryptoKit
import Foundation
import Security
import UIKit

/// Stores the user's single full-body try-on photo **encrypted at rest** with CryptoKit AES-GCM
/// (spec §5.3 / §10). The symmetric key lives in the Keychain; the ciphertext is a file in
/// Application Support. The plaintext photo only ever leaves the device for the Replicate
/// inference call (disclosed in the privacy policy).
struct UserPhotoStore {
    static let shared = UserPhotoStore()

    private let fileName = "user-photo.enc"
    private let keychainAccount = "com.yourname.wardrobe.userphoto.key"

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    var hasPhoto: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func save(_ image: UIImage) throws {
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw PhotoStoreError.encoding }
        let key = try loadOrCreateKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw PhotoStoreError.encryption }
        try combined.write(to: fileURL, options: .completeFileProtection)
    }

    func load() -> UIImage? {
        guard let combined = try? Data(contentsOf: fileURL),
              let key = try? loadOrCreateKey(),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let data = try? AES.GCM.open(box, using: key) else {
            return nil
        }
        return UIImage(data: data)
    }

    func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Keychain-backed symmetric key

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try readKey() { return existing }
        let key = SymmetricKey(size: .bits256)
        try storeKey(key)
        return key
    }

    private func readKey() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw PhotoStoreError.keychain(status) }
        return SymmetricKey(data: data)
    }

    private func storeKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw PhotoStoreError.keychain(status) }
    }
}

enum PhotoStoreError: Error {
    case encoding
    case encryption
    case keychain(OSStatus)
}
