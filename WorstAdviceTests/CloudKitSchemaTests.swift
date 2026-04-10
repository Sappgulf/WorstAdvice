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
        XCTAssertFalse(report.signedIntoICloud)
        XCTAssertEqual(report.containerIdentifier, "iCloud.com.worstadvice.app")
    }
}
