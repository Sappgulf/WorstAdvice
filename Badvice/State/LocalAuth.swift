import CryptoKit
import Foundation
import Observation
import Security
import UIKit

struct LocalAccountSession: Codable, Equatable, Sendable {
    let accountID: UUID
    let email: String
    let displayName: String
    let signedInAt: Date
    let linkedSocialProfileRecordName: String?
}

struct LocalAccountRecord: Equatable, Identifiable, Sendable, Codable {
    let id: UUID
    let email: String
    let displayName: String
    let passwordSaltBase64: String
    let passwordHashBase64: String
    let createdAt: Date
    let lastSignedInAt: Date
    let linkedSocialProfileRecordName: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case passwordSaltBase64
        case passwordHashBase64
        case createdAt
        case lastSignedInAt
        case linkedSocialProfileRecordName
    }

    init(
        id: UUID,
        email: String,
        displayName: String,
        passwordSaltBase64: String,
        passwordHashBase64: String,
        createdAt: Date,
        lastSignedInAt: Date,
        linkedSocialProfileRecordName: String?
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.passwordSaltBase64 = passwordSaltBase64
        self.passwordHashBase64 = passwordHashBase64
        self.createdAt = createdAt
        self.lastSignedInAt = lastSignedInAt
        self.linkedSocialProfileRecordName = linkedSocialProfileRecordName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.passwordSaltBase64 = try container.decodeIfPresent(String.self, forKey: .passwordSaltBase64) ?? ""
        self.passwordHashBase64 = try container.decodeIfPresent(String.self, forKey: .passwordHashBase64) ?? ""
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.lastSignedInAt = try container.decode(Date.self, forKey: .lastSignedInAt)
        self.linkedSocialProfileRecordName = try container.decodeIfPresent(
            String.self,
            forKey: .linkedSocialProfileRecordName
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastSignedInAt, forKey: .lastSignedInAt)
        try container.encodeIfPresent(linkedSocialProfileRecordName, forKey: .linkedSocialProfileRecordName)
    }

    var hasStoredCredentials: Bool {
        !passwordSaltBase64.isEmpty && !passwordHashBase64.isEmpty
    }

    func withCredentials(saltBase64: String, hashBase64: String) -> LocalAccountRecord {
        LocalAccountRecord(
            id: id,
            email: email,
            displayName: displayName,
            passwordSaltBase64: saltBase64,
            passwordHashBase64: hashBase64,
            createdAt: createdAt,
            lastSignedInAt: lastSignedInAt,
            linkedSocialProfileRecordName: linkedSocialProfileRecordName
        )
    }
}

struct LocalAccountCredentials: Codable, Sendable {
    let saltBase64: String
    let hashBase64: String
}

protocol LocalAccountCredentialsStore {
    func loadCredentials(for accountID: UUID) throws -> LocalAccountCredentials?
    func saveCredentials(_ credentials: LocalAccountCredentials, for accountID: UUID) throws
    func deleteCredentials(for accountID: UUID)
    func removeAllCredentials()
}

final class LocalAccountKeychainStore: LocalAccountCredentialsStore {
    private let service = "com.worstadvice.app.localAccounts.credentials"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    func loadCredentials(for accountID: UUID) throws -> LocalAccountCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw LocalAuthError.persistenceFailure
            }
            return try decoder.decode(LocalAccountCredentials.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw LocalAuthError.persistenceFailure
        }
    }

    func saveCredentials(_ credentials: LocalAccountCredentials, for accountID: UUID) throws {
        let data = try encoder.encode(credentials)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
        let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            throw LocalAuthError.persistenceFailure
        }
        let addQuery: [String: Any] = baseQuery.merging([
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ], uniquingKeysWith: { _, new in new })
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw LocalAuthError.persistenceFailure
        }
    }

    func deleteCredentials(for accountID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }

    func removeAllCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class LocalAccountInMemoryStore: LocalAccountCredentialsStore {
    private var credentialsByAccountID: [UUID: LocalAccountCredentials] = [:]

    func loadCredentials(for accountID: UUID) throws -> LocalAccountCredentials? {
        credentialsByAccountID[accountID]
    }

    func saveCredentials(_ credentials: LocalAccountCredentials, for accountID: UUID) throws {
        credentialsByAccountID[accountID] = credentials
    }

    func deleteCredentials(for accountID: UUID) {
        credentialsByAccountID.removeValue(forKey: accountID)
    }

    func removeAllCredentials() {
        credentialsByAccountID.removeAll()
    }
}

enum LocalAuthError: LocalizedError, Equatable {
    case invalidEmail
    case invalidDisplayName
    case weakPassword
    case passwordMismatch
    case emailTaken
    case invalidCredentials
    case invalidCurrentPassword
    case accountUnavailable
    case persistenceFailure

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Enter a valid email address."
        case .invalidDisplayName:
            return "Display name must be 2-40 characters."
        case .weakPassword:
            return "Password must be at least 8 characters and include a letter and a number."
        case .passwordMismatch:
            return "Passwords do not match."
        case .emailTaken:
            return "That email is already being used on this device."
        case .invalidCredentials:
            return "Incorrect email or password."
        case .invalidCurrentPassword:
            return "Current password is incorrect."
        case .accountUnavailable:
            return "That account is no longer available."
        case .persistenceFailure:
            return "Badvice could not save account data on this device."
        }
    }
}

@MainActor
@Observable
final class AuthViewModel {
    private let store: LocalAccountStore

    private(set) var currentSession: LocalAccountSession?
    private(set) var hasAccounts = false
    private(set) var isSubmitting = false
    var statusMessage: String?

    init(store: LocalAccountStore = LocalAccountStore()) {
        self.store = store
        reload()
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    var signedInEmail: String? {
        currentSession?.email
    }

    var displayName: String {
        currentSession?.displayName ?? UIDevice.current.name
    }

    var linkedSocialProfileRecordName: String? {
        currentSession?.linkedSocialProfileRecordName
    }

    func reload() {
        currentSession = store.restoreSession()
        hasAccounts = store.hasAccounts()
    }

    func resetForUITesting() {
        store.removeAllAccounts()
        statusMessage = nil
        reload()
    }

    func seedUITestSessionIfNeeded(
        email: String = "ui-test@badvice.local",
        displayName: String = "UI Test User",
        password: String = "Badvice123"
    ) {
        guard currentSession == nil else { return }
        guard !hasAccounts else { return }
        do {
            currentSession = try store.signUp(
                email: email,
                displayName: displayName,
                password: password
            )
            hasAccounts = true
        } catch {
            statusMessage = error.localizedDescription
            reload()
        }
    }

    @discardableResult
    func signUp(
        email: String,
        displayName: String,
        password: String,
        confirmPassword: String
    ) async -> Bool {
        guard password == confirmPassword else {
            statusMessage = LocalAuthError.passwordMismatch.localizedDescription
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            currentSession = try store.signUp(
                email: email,
                displayName: displayName,
                password: password
            )
            hasAccounts = true
            statusMessage = "Account created."
            return true
        } catch {
            statusMessage = error.localizedDescription
            reload()
            return false
        }
    }

    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            currentSession = try store.signIn(email: email, password: password)
            hasAccounts = true
            statusMessage = "Signed in."
            return true
        } catch {
            statusMessage = error.localizedDescription
            reload()
            return false
        }
    }

    func signOut() {
        store.signOut()
        statusMessage = "Signed out."
        reload()
    }

    func resetAllAccounts() {
        store.removeAllAccounts()
        statusMessage = "All local accounts cleared from this device."
        reload()
    }

    @discardableResult
    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async -> Bool {
        guard newPassword == confirmPassword else {
            statusMessage = LocalAuthError.passwordMismatch.localizedDescription
            return false
        }
        guard let session = currentSession else {
            statusMessage = LocalAuthError.accountUnavailable.localizedDescription
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try store.changePassword(
                for: session.accountID,
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            statusMessage = "Password updated."
            reload()
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deleteCurrentAccount(password: String) async -> Bool {
        guard let session = currentSession else {
            statusMessage = LocalAuthError.accountUnavailable.localizedDescription
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try store.deleteAccount(accountID: session.accountID, password: password)
            statusMessage = "Account deleted."
            reload()
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    func setLinkedSocialProfileRecordName(_ recordName: String?) {
        guard let session = currentSession else { return }
        do {
            currentSession = try store.updateLinkedSocialProfileRecordName(
                recordName,
                for: session.accountID
            )
        } catch {
            statusMessage = error.localizedDescription
            reload()
        }
    }
}

struct LocalAccountValidation {
    static func normalizedEmail(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedDisplayName(_ input: String, fallbackEmail: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let prefix = fallbackEmail.split(separator: "@").first.map(String.init) ?? "Badvice User"
            return String(prefix.prefix(40))
        }
        return String(trimmed.prefix(40))
    }

    static func isValidEmail(_ input: String) -> Bool {
        let normalized = normalizedEmail(input)
        let parts = normalized.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        guard parts[0].count >= 1, parts[1].count >= 3 else { return false }
        guard parts[1].contains(".") else { return false }
        guard !normalized.contains(" ") else { return false }
        return true
    }

    static func isValidDisplayName(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return (2...40).contains(trimmed.count)
    }

    static func isStrongPassword(_ input: String) -> Bool {
        guard input.count >= 8 else { return false }
        let containsLetter = input.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let containsDigit = input.range(of: "[0-9]", options: .regularExpression) != nil
        return containsLetter && containsDigit
    }
}

struct LocalAccountPasswordHasher {
    private static let iterations = 12_000
    private static let saltByteCount = 16

    static func hash(password: String) throws -> (salt: String, hash: String) {
        let saltData = try randomSalt()
        let digest = derivedKey(password: password, salt: saltData)
        return (saltData.base64EncodedString(), digest.base64EncodedString())
    }

    static func verify(password: String, saltBase64: String, expectedHashBase64: String) -> Bool {
        guard let saltData = Data(base64Encoded: saltBase64),
            let expectedHash = Data(base64Encoded: expectedHashBase64)
        else {
            return false
        }
        let candidate = derivedKey(password: password, salt: saltData)
        return constantTimeEquals(candidate, expectedHash)
    }

    private static func derivedKey(password: String, salt: Data) -> Data {
        var buffer = Data(password.utf8) + salt
        for _ in 0..<iterations {
            buffer = Data(SHA256.hash(data: buffer + salt))
        }
        return buffer
    }

    private static func randomSalt() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: saltByteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw LocalAuthError.persistenceFailure
        }
        return Data(bytes)
    }

    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in lhs.indices {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }
}

final class LocalAccountStore {
    static let accountsKey = "auth.localAccounts.v1"
    static let currentAccountIDKey = "auth.localAccounts.currentAccountID.v1"

    private let userDefaults: UserDefaults
    private let credentialsStore: any LocalAccountCredentialsStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        userDefaults: UserDefaults = .standard,
        credentialsStore: any LocalAccountCredentialsStore = LocalAccountKeychainStore()
    ) {
        self.userDefaults = userDefaults
        self.credentialsStore = credentialsStore
    }

    func restoreSession() -> LocalAccountSession? {
        guard let currentAccountID = userDefaults.string(forKey: Self.currentAccountIDKey),
            let accountID = UUID(uuidString: currentAccountID),
            let account = loadAccounts().first(where: { $0.id == accountID })
        else {
            return nil
        }

        return LocalAccountSession(
            accountID: account.id,
            email: account.email,
            displayName: account.displayName,
            signedInAt: account.lastSignedInAt,
            linkedSocialProfileRecordName: account.linkedSocialProfileRecordName
        )
    }

    func hasAccounts() -> Bool {
        !loadAccounts().isEmpty
    }

    func signUp(email: String, displayName: String, password: String) throws -> LocalAccountSession {
        let normalizedEmail = LocalAccountValidation.normalizedEmail(email)
        let normalizedDisplayName = LocalAccountValidation.normalizedDisplayName(
            displayName,
            fallbackEmail: normalizedEmail
        )

        guard LocalAccountValidation.isValidEmail(normalizedEmail) else {
            throw LocalAuthError.invalidEmail
        }
        guard LocalAccountValidation.isValidDisplayName(normalizedDisplayName) else {
            throw LocalAuthError.invalidDisplayName
        }
        guard LocalAccountValidation.isStrongPassword(password) else {
            throw LocalAuthError.weakPassword
        }

        var accounts = loadAccounts()
        guard !accounts.contains(where: { $0.email == normalizedEmail }) else {
            throw LocalAuthError.emailTaken
        }

        let passwordPayload = try LocalAccountPasswordHasher.hash(password: password)
        let sessionDate = Date()
        let account = LocalAccountRecord(
            id: UUID(),
            email: normalizedEmail,
            displayName: normalizedDisplayName,
            passwordSaltBase64: passwordPayload.salt,
            passwordHashBase64: passwordPayload.hash,
            createdAt: sessionDate,
            lastSignedInAt: sessionDate,
            linkedSocialProfileRecordName: nil
        )
        accounts.append(account)
        try saveAccounts(accounts)
        userDefaults.set(account.id.uuidString, forKey: Self.currentAccountIDKey)
        return LocalAccountSession(
            accountID: account.id,
            email: account.email,
            displayName: account.displayName,
            signedInAt: sessionDate,
            linkedSocialProfileRecordName: account.linkedSocialProfileRecordName
        )
    }

    func signIn(email: String, password: String) throws -> LocalAccountSession {
        let normalizedEmail = LocalAccountValidation.normalizedEmail(email)
        guard LocalAccountValidation.isValidEmail(normalizedEmail) else {
            throw LocalAuthError.invalidEmail
        }

        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.email == normalizedEmail }) else {
            throw LocalAuthError.invalidCredentials
        }

        let account = accounts[index]
        guard LocalAccountPasswordHasher.verify(
            password: password,
            saltBase64: account.passwordSaltBase64,
            expectedHashBase64: account.passwordHashBase64
        ) else {
            throw LocalAuthError.invalidCredentials
        }

        let signedInAt = Date()
        let updatedAccount = LocalAccountRecord(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            passwordSaltBase64: account.passwordSaltBase64,
            passwordHashBase64: account.passwordHashBase64,
            createdAt: account.createdAt,
            lastSignedInAt: signedInAt,
            linkedSocialProfileRecordName: account.linkedSocialProfileRecordName
        )
        accounts[index] = updatedAccount
        try saveAccounts(accounts)
        userDefaults.set(updatedAccount.id.uuidString, forKey: Self.currentAccountIDKey)
        return LocalAccountSession(
            accountID: updatedAccount.id,
            email: updatedAccount.email,
            displayName: updatedAccount.displayName,
            signedInAt: signedInAt,
            linkedSocialProfileRecordName: updatedAccount.linkedSocialProfileRecordName
        )
    }

    func signOut() {
        userDefaults.removeObject(forKey: Self.currentAccountIDKey)
    }

    func removeAllAccounts() {
        credentialsStore.removeAllCredentials()
        userDefaults.removeObject(forKey: Self.accountsKey)
        userDefaults.removeObject(forKey: Self.currentAccountIDKey)
    }

    func storedAccounts() -> [LocalAccountRecord] {
        loadAccounts()
    }

    func changePassword(
        for accountID: UUID,
        currentPassword: String,
        newPassword: String
    ) throws {
        guard LocalAccountValidation.isStrongPassword(newPassword) else {
            throw LocalAuthError.weakPassword
        }

        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            throw LocalAuthError.accountUnavailable
        }
        let account = accounts[index]
        guard LocalAccountPasswordHasher.verify(
            password: currentPassword,
            saltBase64: account.passwordSaltBase64,
            expectedHashBase64: account.passwordHashBase64
        ) else {
            throw LocalAuthError.invalidCurrentPassword
        }

        let passwordPayload = try LocalAccountPasswordHasher.hash(password: newPassword)
        accounts[index] = LocalAccountRecord(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            passwordSaltBase64: passwordPayload.salt,
            passwordHashBase64: passwordPayload.hash,
            createdAt: account.createdAt,
            lastSignedInAt: account.lastSignedInAt,
            linkedSocialProfileRecordName: account.linkedSocialProfileRecordName
        )
        try saveAccounts(accounts)
    }

    func deleteAccount(accountID: UUID, password: String) throws {
        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            throw LocalAuthError.accountUnavailable
        }
        let account = accounts[index]
        guard LocalAccountPasswordHasher.verify(
            password: password,
            saltBase64: account.passwordSaltBase64,
            expectedHashBase64: account.passwordHashBase64
        ) else {
            throw LocalAuthError.invalidCurrentPassword
        }
        credentialsStore.deleteCredentials(for: accountID)
        accounts.remove(at: index)
        try saveAccounts(accounts)
        if userDefaults.string(forKey: Self.currentAccountIDKey) == accountID.uuidString {
            userDefaults.removeObject(forKey: Self.currentAccountIDKey)
        }
    }

    func updateLinkedSocialProfileRecordName(
        _ recordName: String?,
        for accountID: UUID
    ) throws -> LocalAccountSession {
        var accounts = loadAccounts()
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            throw LocalAuthError.accountUnavailable
        }

        let account = accounts[index]
        let updatedAccount = LocalAccountRecord(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            passwordSaltBase64: account.passwordSaltBase64,
            passwordHashBase64: account.passwordHashBase64,
            createdAt: account.createdAt,
            lastSignedInAt: account.lastSignedInAt,
            linkedSocialProfileRecordName: recordName
        )
        accounts[index] = updatedAccount
        try saveAccounts(accounts)
        if userDefaults.string(forKey: Self.currentAccountIDKey) == updatedAccount.id.uuidString {
            userDefaults.set(updatedAccount.id.uuidString, forKey: Self.currentAccountIDKey)
        }
        return LocalAccountSession(
            accountID: updatedAccount.id,
            email: updatedAccount.email,
            displayName: updatedAccount.displayName,
            signedInAt: updatedAccount.lastSignedInAt,
            linkedSocialProfileRecordName: updatedAccount.linkedSocialProfileRecordName
        )
    }

    private func loadAccounts() -> [LocalAccountRecord] {
        guard let data = userDefaults.data(forKey: Self.accountsKey) else { return [] }
        let decoded = (try? decoder.decode([LocalAccountRecord].self, from: data)) ?? []
        var didMigrateLegacyCredentials = false
        var migrationFailed = false
        let hydrated = decoded.map { record in
            if let credentials = try? credentialsStore.loadCredentials(for: record.id) {
                return record.withCredentials(
                    saltBase64: credentials.saltBase64,
                    hashBase64: credentials.hashBase64
                )
            }

            guard record.hasStoredCredentials else { return record }

            do {
                try credentialsStore.saveCredentials(
                    LocalAccountCredentials(
                        saltBase64: record.passwordSaltBase64,
                        hashBase64: record.passwordHashBase64
                    ),
                    for: record.id
                )
                didMigrateLegacyCredentials = true
            } catch {
                migrationFailed = true
                return record
            }
            return record
        }

        if didMigrateLegacyCredentials && !migrationFailed {
            try? saveAccounts(hydrated)
        }
        return hydrated
    }

    private func saveAccounts(_ accounts: [LocalAccountRecord]) throws {
        do {
            for account in accounts where account.hasStoredCredentials {
                try credentialsStore.saveCredentials(
                    LocalAccountCredentials(
                        saltBase64: account.passwordSaltBase64,
                        hashBase64: account.passwordHashBase64
                    ),
                    for: account.id
                )
            }
            let data = try encoder.encode(accounts)
            userDefaults.set(data, forKey: Self.accountsKey)
        } catch {
            throw LocalAuthError.persistenceFailure
        }
    }
}
