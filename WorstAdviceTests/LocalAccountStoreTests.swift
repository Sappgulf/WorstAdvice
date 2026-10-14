import XCTest
@testable import Badvice

final class LocalAccountStoreTests: XCTestCase {
    func testPersistentStoreDirectoryPreparerCreatesNestedDirectoryIdempotently() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BadviceStorePreparationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nestedDirectory = root
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try PersistentStoreDirectoryPreparer.prepareDirectory(at: nestedDirectory)
        try PersistentStoreDirectoryPreparer.prepareDirectory(at: nestedDirectory)

        var isDirectory: ObjCBool = false
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: nestedDirectory.path,
                isDirectory: &isDirectory
            )
        )
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testSignUpRestoreAndSignInRoundTrip() throws {
        let (store, _) = makeLocalAccountStore(suiteName: "LocalAccountStoreTests.RoundTrip")

        let created = try store.signUp(
            email: "Captain@Badvice.test",
            displayName: "Captain Chaos",
            password: "Badvice123"
        )
        XCTAssertEqual(created.email, "captain@badvice.test")

        let restored = try XCTUnwrap(store.restoreSession())
        XCTAssertEqual(restored.email, "captain@badvice.test")
        XCTAssertNil(restored.linkedSocialProfileRecordName)

        store.signOut()
        XCTAssertNil(store.restoreSession())

        let signedIn = try store.signIn(email: "captain@badvice.test", password: "Badvice123")
        XCTAssertEqual(signedIn.email, "captain@badvice.test")
    }

    func testUpdatingLinkedSocialProfilePersistsToSession() throws {
        let (store, _) = makeLocalAccountStore(suiteName: "LocalAccountStoreTests.LinkedProfile")

        let created = try store.signUp(
            email: "crew@badvice.test",
            displayName: "Crew",
            password: "Badvice123"
        )

        let updated = try store.updateLinkedSocialProfileRecordName(
            "mock_user_crew",
            for: created.accountID
        )

        XCTAssertEqual(updated.linkedSocialProfileRecordName, "mock_user_crew")
        XCTAssertEqual(store.restoreSession()?.linkedSocialProfileRecordName, "mock_user_crew")
    }

    func testChangePasswordAndDeleteAccountLifecycle() throws {
        let (store, _) = makeLocalAccountStore(suiteName: "LocalAccountStoreTests.AccountLifecycle")

        let created = try store.signUp(
            email: "owner@badvice.test",
            displayName: "Owner",
            password: "Badvice123"
        )

        try store.changePassword(
            for: created.accountID,
            currentPassword: "Badvice123",
            newPassword: "Chaos456"
        )

        store.signOut()
        XCTAssertThrowsError(try store.signIn(email: "owner@badvice.test", password: "Badvice123"))
        XCTAssertNoThrow(try store.signIn(email: "owner@badvice.test", password: "Chaos456"))

        try store.deleteAccount(accountID: created.accountID, password: "Chaos456")

        XCTAssertTrue(store.storedAccounts().isEmpty)
        XCTAssertNil(store.restoreSession())
    }

    private func makeLocalAccountStore(suiteName: String) -> (LocalAccountStore, UserDefaults) {
        let fullSuiteName = "\(suiteName).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: fullSuiteName)!
        defaults.removePersistentDomain(forName: fullSuiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: fullSuiteName)
        }
        return (
            LocalAccountStore(
                userDefaults: defaults,
                credentialsStore: LocalAccountInMemoryStore()
            ),
            defaults
        )
    }
}

final class GuestSessionTests: XCTestCase {
    @MainActor
    func testUITestAuthSeedUsesGuestSessionWithoutCreatingPasswordAccount() throws {
        let name = "GuestSessionTests.UITestSeed.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LocalAccountStore(
            userDefaults: defaults,
            credentialsStore: LocalAccountInMemoryStore()
        )
        let auth = AuthViewModel(store: store)

        auth.seedUITestSessionIfNeeded()

        XCTAssertTrue(auth.isAuthenticated)
        XCTAssertTrue(auth.isGuest)
        XCTAssertFalse(auth.hasAccounts)
        XCTAssertTrue(store.storedAccounts().isEmpty)
    }

    func testGuestRestoresAndResumesSeparatelyFromProtectedAccounts() throws {
        let name = "GuestSessionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let credentials = LocalAccountInMemoryStore()
        let store = LocalAccountStore(userDefaults: defaults, credentialsStore: credentials)
        let guest = try store.startGuestSession()
        XCTAssertTrue(guest.isGuest)
        XCTAssertFalse(store.hasAccounts())
        XCTAssertEqual(store.restoreSession()?.accountID, guest.accountID)
        let linked = try store.updateLinkedSocialProfileRecordName("guest-social", for: guest.accountID)
        XCTAssertEqual(linked.linkedSocialProfileRecordName, "guest-social")
        store.signOut()
        XCTAssertNil(store.restoreSession())
        let protected = try store.signUp(email: "protected@badvice.test", displayName: "Protected", password: "Badvice123")
        XCTAssertFalse(protected.isGuest)
        XCTAssertNotEqual(protected.accountID, guest.accountID)
        store.signOut()
        let restored = LocalAccountStore(userDefaults: defaults, credentialsStore: credentials)
        XCTAssertEqual(try restored.startGuestSession().accountID, guest.accountID)
        XCTAssertEqual(try restored.signIn(email: protected.email, password: "Badvice123").accountID, protected.accountID)
        restored.removeAllAccounts()
        XCTAssertNil(restored.restoreSession())
        XCTAssertNotEqual(try restored.startGuestSession().accountID, guest.accountID)
    }
}
