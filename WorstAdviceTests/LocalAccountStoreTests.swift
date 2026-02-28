import XCTest
@testable import Badvice

final class LocalAccountStoreTests: XCTestCase {
    func testSignUpRestoreAndSignInRoundTrip() throws {
        let defaults = UserDefaults(suiteName: "LocalAccountStoreTests.RoundTrip.\(UUID().uuidString)")!
        let store = LocalAccountStore(userDefaults: defaults)

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
        let defaults = UserDefaults(suiteName: "LocalAccountStoreTests.LinkedProfile.\(UUID().uuidString)")!
        let store = LocalAccountStore(userDefaults: defaults)

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
        let defaults = UserDefaults(suiteName: "LocalAccountStoreTests.AccountLifecycle.\(UUID().uuidString)")!
        let store = LocalAccountStore(userDefaults: defaults)

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
}
