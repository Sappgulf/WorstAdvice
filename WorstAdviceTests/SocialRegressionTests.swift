import CloudKit
import XCTest
@testable import Badvice

@MainActor
final class SocialRegressionTests: XCTestCase {
    private func makeTestUser(handle: String = "friends_test_user") -> SocialUser {
        SocialUser(
            recordID: CKRecord.ID(recordName: "test_\(handle)"),
            handle: handle,
            displayName: "Test User",
            createdAt: Date()
        )
    }

    private func awaitFriendsLoadState(
        matching predicate: @escaping (SocialLoadState) -> Bool,
        timeout: TimeInterval = 1.2,
        for viewModel: SocialViewModel
    ) async -> SocialLoadState {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(viewModel.friendsLoadState) {
                return viewModel.friendsLoadState
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return viewModel.friendsLoadState
    }

    func testRetryFriendsLoadReconcilesStaleStateAfterICloudAuthLoss() async {
        let defaults = UserDefaults(suiteName: "SocialRegressionTests.AuthLost.\(UUID().uuidString)")!
        let queue = SocialActionQueueStore(
            userDefaults: defaults,
            storageKey: "social.queue.authLostRegression"
        )
        let staleUser = makeTestUser(handle: "legacy_friend")
        let backend = InspectableSocialBackend(
            storedUser: staleUser,
            incomingError: CKError(.notAuthenticated)
        )
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)

        viewModel.currentUser = staleUser
        viewModel.incomingRequests = [
            SocialFriendRequest(
                recordID: CKRecord.ID(recordName: "req-reg-1"),
                fromUserID: CKRecord.ID(recordName: "from"),
                toUserID: staleUser.recordID,
                status: .pending,
                createdAt: Date(),
                fromUser: staleUser,
                toUser: staleUser
            )
        ]
        viewModel.outgoingRequests = [
            SocialFriendRequest(
                recordID: CKRecord.ID(recordName: "req-reg-2"),
                fromUserID: staleUser.recordID,
                toUserID: CKRecord.ID(recordName: "to"),
                status: .pending,
                createdAt: Date(),
                fromUser: staleUser,
                toUser: staleUser
            )
        ]
        viewModel.friends = [staleUser]
        viewModel.blockedUsers = [makeTestUser(handle: "blocked_friend")]

        await viewModel.retryFriendsLoad()
        let terminalState = await awaitFriendsLoadState(
            matching: {
                if case .failed = $0 { return true }
                return false
            },
            for: viewModel
        )

        XCTAssertNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
        XCTAssertTrue(viewModel.outgoingRequests.isEmpty)
        XCTAssertTrue(viewModel.friends.isEmpty)
        XCTAssertTrue(viewModel.blockedUsers.isEmpty)
        XCTAssertFalse(viewModel.socialFeaturesEnabled)
        if case .failed(let message) = terminalState {
            XCTAssertEqual(
                message,
                "iCloud is not signed in. Open Settings, sign in to iCloud, then retry."
            )
        } else {
            XCTFail("Expected failed friends load after stale-auth loss. got: \(terminalState)")
        }
    }
}

@MainActor
final class SocialQueueLifecycleTests: XCTestCase {
    func testFirstAuthContextPreservesPersistedQueueAndICloudSwitchClearsIt() async throws {
        let name = "SocialQueueLifecycleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let queue = SocialActionQueueStore(userDefaults: defaults, storageKey: "queue")
        await queue.enqueue(SocialQueuedAction(id: UUID(), dedupeKey: nil, createdAt: Date(), nextRetryAt: Date(), attemptCount: 0, payload: .chaosScore(seasonId: "test", score: 12)))
        let backend = InspectableSocialBackend(storedUser: nil)
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: queue)
        await viewModel.applyAuthContext(email: "returning@badvice.test", linkedSocialRecordName: nil)
        let retained = await queue.totalCount()
        XCTAssertEqual(retained, 1, "Restoring a local account must not discard pending offline work")
        await viewModel.handleICloudAccountChange()
        let cleared = await queue.totalCount()
        XCTAssertEqual(cleared, 0, "Writes belonging to the previous iCloud identity must never replay")
        XCTAssertNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.friends.isEmpty)
    }
}

@MainActor
final class SocialQueueIdentityTests: XCTestCase {
    func testQueuePreservesIdentityBindingAcrossPersistence() async throws {
        let name = "SocialQueueIdentityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let queue = SocialActionQueueStore(userDefaults: defaults, storageKey: "queue")
        let action = SocialQueuedAction(id: UUID(), dedupeKey: nil, createdAt: Date(), nextRetryAt: Date(), attemptCount: 0, payload: .sharePost(type: .advice, text: "The same post"), ownerProfileRecordName: "owner-A")
        await queue.enqueue(action)
        let restored = SocialActionQueueStore(userDefaults: defaults, storageKey: "queue")
        let entries = await restored.readyActions()
        XCTAssertEqual(entries.first?.ownerProfileRecordName, "owner-A")
        XCTAssertEqual(entries.first?.id, action.id)
        await restored.reschedule(id: action.id, retryAt: Date())
        let retried = await restored.readyActions()
        XCTAssertEqual(retried.first?.id, action.id)
        XCTAssertEqual(retried.first?.ownerProfileRecordName, "owner-A")
    }
}

@MainActor
final class SocialIdentityRaceTests: XCTestCase {
    func testOldIdentityResponseCannotRepopulateNewIdentityCollections() async throws {
        let name = "SocialIdentityRaceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let previous = SocialUser(recordID: CKRecord.ID(recordName: "previous-profile"), handle: "previous", displayName: "Previous", createdAt: Date())
        let backend = InspectableSocialBackend(storedUser: previous, friendsValue: [previous], friendsDelay: .milliseconds(150))
        let viewModel = SocialViewModel(cloudStore: backend, actionQueue: SocialActionQueueStore(userDefaults: defaults, storageKey: "queue"))
        viewModel.availability = .available
        viewModel.currentUser = previous
        let refresh = Task { await viewModel.refreshSocialData() }
        for _ in 0..<50 {
            if await backend.friendsCallCount() > 0 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        await viewModel.handleICloudAccountChange()
        await refresh.value
        XCTAssertNil(viewModel.currentUser)
        XCTAssertTrue(viewModel.friends.isEmpty, "A delayed response for the old identity must not populate the new one")
        XCTAssertTrue(viewModel.incomingRequests.isEmpty)
    }

    func testFreshAvailabilityFailureIsNotErasedByRetry() async throws {
        let diagnostic = try XCTUnwrap(SocialCloudKitErrorDiagnostic.make(from: CKError(.networkFailure), context: .generic(operation: "accountStatus"), isRetryable: true))
        let backend = InspectableSocialBackend(storedUser: nil, availabilityValue: .available.withLastError(diagnostic))
        let viewModel = SocialViewModel(cloudStore: backend)
        await viewModel.refreshAvailability(preservingLastError: false)
        XCTAssertEqual(viewModel.availability.diagnostics.lastError?.operation, "accountStatus")
        XCTAssertEqual(viewModel.availability.diagnostics.lastError?.code, diagnostic.code)
    }
}

extension SocialRegressionTests {
    func testUnsignedBuildBackendRejectsWritesWithoutInventingProfiles() async {
        let backend = UnavailableSocialBackend()
        let state = await backend.availabilityState()
        XCTAssertFalse(state.isAccountAvailable)
        XCTAssertEqual(state.diagnostics.lastError?.code, "unsigned_build")
        do {
            _ = try await backend.getOrCreateCurrentUser(handle: "tester", displayName: "Tester")
            XCTFail("An unsigned build must not invent an iCloud profile")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("unsigned"))
        }
        do {
            _ = try await backend.createPost(type: .advice, text: "An imaginary committee.")
            XCTFail("An unavailable backend must not claim successful publication")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("unsigned"))
        }
    }
}
