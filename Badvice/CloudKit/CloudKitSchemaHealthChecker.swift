import CloudKit
import Foundation

struct CloudKitSchemaHealthReport: Sendable {
    let isHealthy: Bool
    let message: String
    let containerIdentifier: String
    let environmentName: String
    let signedIntoICloud: Bool
}

struct CloudKitSchemaHealthCheckFailed: LocalizedError {
    let report: CloudKitSchemaHealthReport
    let underlyingError: Error?

    var errorDescription: String? {
        report.message
    }
}

struct CloudKitSchemaHealthChecker {
    let container: CKContainer
    let publicDatabase: CKDatabase
    let containerIdentifier: String
    let environmentName: String

    func validateFriendsSchema() async throws -> CloudKitSchemaHealthReport {
        let ownerUserRecordName: String
        do {
            ownerUserRecordName = try await fetchCurrentUserRecordName()
        } catch {
            throw failure(
                signedIntoICloud: true,
                reason:
                    "Could not fetch `CKCurrentUserDefaultName` for the signed-in iCloud account.",
                underlyingError: error
            )
        }

        let probeRecord = makeProbeUserProfile(ownerUserRecordName: ownerUserRecordName)
        do {
            _ = try await save(record: probeRecord)
        } catch {
            throw failure(
                signedIntoICloud: true,
                reason:
                    "Could not write a `UserProfile` record to the Public database. This usually means the type, fields, or public permissions are missing.",
                underlyingError: error
            )
        }

        do {
            _ = try await fetchRecord(recordID: probeRecord.recordID)
        } catch {
            try? await delete(recordID: probeRecord.recordID)
            throw failure(
                signedIntoICloud: true,
                reason: "Wrote a `UserProfile` record but could not read it back from the Public database.",
                underlyingError: error
            )
        }

        do {
            _ = try await queryProbeRecord(handle: probeRecord.recordID.recordName)
        } catch {
            try? await delete(recordID: probeRecord.recordID)
            throw failure(
                signedIntoICloud: true,
                reason:
                    "A safe `UserProfile` query failed. This usually means the `handle` field is not marked Queryable in CloudKit Dashboard.",
                underlyingError: error
            )
        }

        try? await delete(recordID: probeRecord.recordID)

        return CloudKitSchemaHealthReport(
            isHealthy: true,
            message: "",
            containerIdentifier: containerIdentifier,
            environmentName: environmentName,
            signedIntoICloud: true
        )
    }

    private func fetchCurrentUserRecordName() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            container.fetchUserRecordID { recordID, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let recordID else {
                    continuation.resume(throwing: CKError(.notAuthenticated))
                    return
                }
                continuation.resume(returning: recordID.recordName)
            }
        }
    }

    private func makeProbeUserProfile(ownerUserRecordName: String) -> CKRecord {
        let uniqueSuffix = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let handle = String("schemaprobe\(uniqueSuffix)".prefix(16))
        let recordID = CloudKitSocialSchema.userProfileRecordID(forHandle: handle)
        let record = CKRecord(
            recordType: CloudKitSocialSchema.RecordType.userProfile,
            recordID: recordID
        )
        record[CloudKitSocialSchema.Field.handle] = handle
        record[CloudKitSocialSchema.Field.displayName] = "Schema Probe"
        record[CloudKitSocialSchema.Field.createdAt] = Date()
        record[CloudKitSocialSchema.Field.ownerUserRecordName] = ownerUserRecordName
        return record
    }

    private func queryProbeRecord(handle: String) async throws -> [CKRecord] {
        let query = CKQuery(
            recordType: CloudKitSocialSchema.RecordType.userProfile,
            predicate: NSPredicate(
                format: "%K == %@",
                CloudKitSocialSchema.Field.handle,
                handle
            )
        )
        let operation = CKQueryOperation(query: query)
        operation.desiredKeys = [CloudKitSocialSchema.Field.handle]
        operation.resultsLimit = 1

        return try await withCheckedThrowingContinuation { continuation in
            var records: [CKRecord] = []
            var firstError: Error?
            operation.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    if firstError == nil {
                        firstError = error
                    }
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    if let firstError {
                        continuation.resume(throwing: firstError)
                        return
                    }
                    continuation.resume(returning: records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            publicDatabase.add(operation)
        }
    }

    private func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            publicDatabase.fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let record else {
                    continuation.resume(throwing: CKError(.unknownItem))
                    return
                }
                continuation.resume(returning: record)
            }
        }
    }

    private func save(record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            publicDatabase.save(record) { savedRecord, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let savedRecord else {
                    continuation.resume(throwing: CKError(.serverRecordChanged))
                    return
                }
                continuation.resume(returning: savedRecord)
            }
        }
    }

    private func delete(recordID: CKRecord.ID) async throws {
        let _: CKRecord.ID = try await withCheckedThrowingContinuation { continuation in
            publicDatabase.delete(withRecordID: recordID) { deletedRecordID, error in
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    continuation.resume(returning: deletedRecordID ?? recordID)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: deletedRecordID ?? recordID)
            }
        }
    }

    private func failure(
        signedIntoICloud: Bool,
        reason: String,
        underlyingError: Error?
    ) -> CloudKitSchemaHealthCheckFailed {
        CloudKitSchemaHealthCheckFailed(
            report: CloudKitSchemaHealthReport(
                isHealthy: false,
                message: makeFailureMessage(
                    signedIntoICloud: signedIntoICloud,
                    reason: reason,
                    underlyingError: underlyingError
                ),
                containerIdentifier: containerIdentifier,
                environmentName: environmentName,
                signedIntoICloud: signedIntoICloud
            ),
            underlyingError: underlyingError
        )
    }

    private func makeFailureMessage(
        signedIntoICloud: Bool,
        reason: String,
        underlyingError: Error?
    ) -> String {
        #if DEBUG
            let expectedRecordTypes = CloudKitSocialSchema.coreFriendsRecordTypes
                .map { "- \($0)" }
                .joined(separator: "\n")
            let expectedFields = CloudKitSocialSchema.coreFriendsFieldsByRecordType
                .map { "- \($0.recordType): \($0.fields.joined(separator: ", "))" }
                .joined(separator: "\n")
            let errorDetails = underlyingError.map { "\nCloudKit error: \($0.localizedDescription)" } ?? ""

            return """
            Social beta is unavailable because the CloudKit Friends schema check failed.

            Reason: \(reason)
            Container: \(containerIdentifier)
            Environment: \(environmentName)
            Database: Public
            Signed into iCloud: \(signedIntoICloud ? "Yes" : "No")

            Missing or mismatched record types expected:
            \(expectedRecordTypes)

            Missing or mismatched fields expected:
            \(expectedFields)

            Fix steps: \(CloudKitSocialConfig.schemaSetupDocPath)\(errorDetails)
            """
        #else
            return "Social beta is unavailable right now. Check iCloud sign-in and CloudKit setup."
        #endif
    }
}
