import CloudKit
import XCTest
@testable import Badvice

final class CloudKitSchemaTests: XCTestCase {
    func testHandleNormalizerNormalize() {
        XCTAssertEqual(
            SocialHandleNormalizer.normalize(" @WORST_ADVICE_Test "),
            "worst_advice_test"
        )
        XCTAssertEqual(
            SocialHandleNormalizer.normalize("@@doubleprefix"),
            "doubleprefix"
        )
    }

    func testHandleNormalizerIsValidRejectsInvalidCharactersAndLength() {
        XCTAssertTrue(SocialHandleNormalizer.isValid("abc"))
        XCTAssertTrue(SocialHandleNormalizer.isValid("user.name_01"))

        XCTAssertFalse(SocialHandleNormalizer.isValid("ab"))
        XCTAssertFalse(SocialHandleNormalizer.isValid("averyveryverylonghandle"))
        XCTAssertFalse(SocialHandleNormalizer.isValid("HAS-UPPERCASE"))
        XCTAssertFalse(SocialHandleNormalizer.isValid("spaces not"))
        XCTAssertFalse(SocialHandleNormalizer.isValid("dash-handle"))
    }

    func testHandleNormalizerDisplayNameUsesFallbackAndTrims() {
        XCTAssertEqual(
            SocialHandleNormalizer.displayName("  ", fallbackHandle: "fallback"),
            "fallback"
        )
        XCTAssertEqual(
            SocialHandleNormalizer.displayName("  Short Name  ", fallbackHandle: "fallback"),
            "Short Name"
        )
    }

    func testDisplayNameTruncatesToFortyCharacters() {
        let longDisplayName = "This display name is intentionally too long and should be clipped"
        XCTAssertEqual(
            SocialHandleNormalizer.displayName(longDisplayName, fallbackHandle: "fallback").count,
            40
        )
        XCTAssertEqual(
            SocialHandleNormalizer.displayName(longDisplayName, fallbackHandle: "fallback"),
            String(longDisplayName.prefix(40))
        )
    }

    func testUserProfileRecordIDUsesExpectedPrefix() {
        let recordID = CloudKitSocialSchema.userProfileRecordID(forOwnerUserRecordName: "owner-123")
        XCTAssertEqual(recordID.recordName, "UserProfile_owner-123")
    }

    func testCoreFriendsRecordDefinitionsMatchProjectionShape() {
        XCTAssertEqual(CloudKitSocialSchema.coreFriendsRecordTypes.count, 3)
        XCTAssertEqual(CloudKitSocialSchema.coreFriendsRecordTypes, [
            CloudKitSocialSchema.RecordType.userProfile,
            CloudKitSocialSchema.RecordType.friendRequest,
            CloudKitSocialSchema.RecordType.friendEdge,
        ])

        XCTAssertEqual(CloudKitSocialSchema.coreFriendsFieldsByRecordType.count, 3)
        XCTAssertEqual(
            CloudKitSocialSchema.coreFriendsFieldsByRecordType[1].recordType,
            CloudKitSocialSchema.RecordType.friendRequest
        )
        XCTAssertTrue(CloudKitSocialSchema.coreFriendsFieldsByRecordType[1].fields.count >= 3)
    }

    func testCloudKitContainerDefaults() {
        XCTAssertEqual(CloudKitSocialConfig.containerIdentifier, "iCloud.com.worstadvice.app")
        XCTAssertTrue(CloudKitSocialConfig.schemaSetupDocPath.hasSuffix("cloudkit_schema_setup.md"))
        XCTAssertEqual(CloudKitManager.socialDatabaseScope, "Public")
    }

    func testHealthSchemaReportDefaultContainerValues() {
        let report = CloudKitSchemaHealthReport(
            isHealthy: false,
            message: "nope",
            containerIdentifier: CloudKitSocialConfig.containerIdentifier,
            environmentName: CloudKitSocialConfig.environmentName,
            signedIntoICloud: false
        )
        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(report.signedIntoICloud, false)
        XCTAssertEqual(report.containerIdentifier, "iCloud.com.worstadvice.app")
    }
}

final class CloudKitReadRegressionTests: XCTestCase {
    func testOptionalFetchAcceptsOnlyMissingRecordFailures() {
        XCTAssertTrue(CloudKitFetchPolicy.isOnlyMissingRecords(CKError(.unknownItem)))
        let missing = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "missing"): CKError(.unknownItem)]])
        XCTAssertTrue(CloudKitFetchPolicy.isOnlyMissingRecords(missing))
        let mixed = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [CKRecord.ID(recordName: "missing"): CKError(.unknownItem), CKRecord.ID(recordName: "offline"): CKError(.networkFailure)]])
        XCTAssertFalse(CloudKitFetchPolicy.isOnlyMissingRecords(mixed))
        XCTAssertFalse(CloudKitFetchPolicy.isOnlyMissingRecords(CKError(.permissionFailure)))
        XCTAssertFalse(CloudKitFetchPolicy.isOnlyMissingRecords(CKError(.partialFailure)))
    }

    func testProfileNetworkFailurePropagatesWithoutLookingUpOrResettingIdentity() async {
        var performedFallback = false
        do {
            _ = try await CloudKitProfileResolver.resolve(
                storedRecordName: "saved-profile", ownerRecordName: "owner",
                fetchRecord: { _ in throw CKError(.networkFailure) },
                findByOwner: { performedFallback = true; return nil }
            )
            XCTFail("A failed read must not become a missing profile")
        } catch {
            XCTAssertEqual((error as? CKError)?.code, .networkFailure)
        }
        XCTAssertFalse(performedFallback)
    }

    func testStoredProfileFromPreviousICloudIdentityIsNeverReturned() async throws {
        let old = CKRecord(recordType: CloudKitSocialSchema.RecordType.userProfile)
        old[CloudKitSocialSchema.Field.ownerUserRecordName] = "previous-owner"
        let current = CKRecord(recordType: CloudKitSocialSchema.RecordType.userProfile)
        current[CloudKitSocialSchema.Field.ownerUserRecordName] = "current-owner"
        let resolved = try await CloudKitProfileResolver.resolve(
            storedRecordName: old.recordID.recordName, ownerRecordName: "current-owner",
            fetchRecord: { _ in old }, findByOwner: { current }
        )
        XCTAssertEqual(resolved?.recordID, current.recordID)
    }

    func testDeletedProfileResolvesByOwnerAndInvalidFallbackIsRejected() async throws {
        let owned = CKRecord(recordType: CloudKitSocialSchema.RecordType.userProfile)
        owned[CloudKitSocialSchema.Field.ownerUserRecordName] = "owner"
        let found = try await CloudKitProfileResolver.resolve(storedRecordName: "deleted", ownerRecordName: "owner", fetchRecord: { _ in nil }, findByOwner: { owned })
        XCTAssertEqual(found?.recordID, owned.recordID)
        do {
            _ = try await CloudKitProfileResolver.resolve(storedRecordName: nil, ownerRecordName: "other", fetchRecord: { _ in nil }, findByOwner: { owned })
            XCTFail("Wrong owner must be rejected")
        } catch {
            guard case SocialError.permissionDenied = error else { return XCTFail("Expected permission denial, got \(error)") }
        }
    }
}
