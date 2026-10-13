import CloudKit
import Foundation

struct CloudKitSchemaHealthReport: Sendable {
    let isHealthy: Bool
    let message: String
    let containerIdentifier: String
    let environmentName: String
    let signedIntoICloud: Bool?
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
        let accountStatus: CKAccountStatus
        do {
            accountStatus = try await container.accountStatus()
        } catch {
            throw failure(
                signedIntoICloud: nil,
                reason: "Could not determine iCloud account status.",
                underlyingError: error
            )
        }
        guard accountStatus == .available else {
            throw failure(
                signedIntoICloud: false,
                reason: "The iCloud account is not available (status: \(accountStatus.rawValue)).",
                underlyingError: nil
            )
        }

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
            let savedRecord = try await save(record: probeRecord)
            guard savedRecord.recordID == probeRecord.recordID,
                savedRecord[CloudKitSocialSchema.Field.handle] as? String
                    == probeRecord[CloudKitSocialSchema.Field.handle] as? String
            else {
                throw CKError(.serverRecordChanged)
            }
        } catch {
            throw await failureAfterCleaningProbe(
                probeRecord,
                signedIntoICloud: true,
                reason:
                    "Could not write a `UserProfile` record to the Public database. This usually means the type, fields, or public permissions are missing.",
                underlyingError: error
            )
        }

        do {
            let fetchedRecord = try await fetchRecord(recordID: probeRecord.recordID)
            guard fetchedRecord.recordID == probeRecord.recordID,
                fetchedRecord[CloudKitSocialSchema.Field.handle] as? String
                    == probeRecord[CloudKitSocialSchema.Field.handle] as? String
            else {
                throw CKError(.unknownItem)
            }
        } catch {
            throw await failureAfterCleaningProbe(
                probeRecord,
                signedIntoICloud: true,
                reason: "Wrote a `UserProfile` record but could not read it back from the Public database.",
                underlyingError: error
            )
        }

        do {
            let queryMatches = try await queryProbeRecord(
                handle: (probeRecord[CloudKitSocialSchema.Field.handle] as? String) ?? ""
            )
            guard queryMatches.contains(where: { record in
                record.recordID == probeRecord.recordID
                    && (record[CloudKitSocialSchema.Field.handle] as? String)
                        == (probeRecord[CloudKitSocialSchema.Field.handle] as? String)
            }) else {
                throw CKError(.unknownItem)
            }
        } catch {
            throw await failureAfterCleaningProbe(
                probeRecord,
                signedIntoICloud: true,
                reason:
                    "A safe `UserProfile` query could not find the temporary profile. Check that `handle` is Queryable in CloudKit Dashboard.",
                underlyingError: error
            )
        }

        do {
            try await delete(recordID: probeRecord.recordID)
        } catch {
            throw failure(
                signedIntoICloud: true,
                reason: "CloudKit checks passed, but the temporary schema probe could not be deleted.",
                underlyingError: error
            )
        }

        return CloudKitSchemaHealthReport(
            isHealthy: true,
            message: "",
            containerIdentifier: containerIdentifier,
            environmentName: environmentName,
            signedIntoICloud: true
        )
    }

    private func fetchCurrentUserRecordName() async throws -> String {
        try await container.userRecordID().recordName
    }

    private func makeProbeUserProfile(ownerUserRecordName: String) -> CKRecord {
        let uniqueSuffix = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        let handle = "sp\(uniqueSuffix.prefix(14))"
        let recordID = CKRecord.ID(recordName: "UserProfile_schema_probe_\(uniqueSuffix)")
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
        let retryDelays: [Duration] = [.milliseconds(400), .milliseconds(800), .seconds(1), .seconds(2), .seconds(3), .seconds(3)]

        for (attempt, retryDelay) in retryDelays.enumerated() {
            let (matches, _) = try await publicDatabase.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: [CloudKitSocialSchema.Field.handle],
                resultsLimit: 1
            )
            var records: [CKRecord] = []
            records.reserveCapacity(matches.count)
            for (_, result) in matches {
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    throw error
                }
            }

            if !records.isEmpty || attempt == retryDelays.count - 1 {
                return records
            }
            try await Task.sleep(for: retryDelay)
        }

        return []
    }

    private func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord {
        try await publicDatabase.record(for: recordID)
    }

    private func save(record: CKRecord) async throws -> CKRecord {
        try await publicDatabase.save(record)
    }

    private func delete(recordID: CKRecord.ID) async throws {
        do {
            try await publicDatabase.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            // A concurrent cleanup can remove the uniquely named probe first.
        }
    }

    private func failureAfterCleaningProbe(
        _ probeRecord: CKRecord,
        signedIntoICloud: Bool?,
        reason: String,
        underlyingError: Error
    ) async -> CloudKitSchemaHealthCheckFailed {
        do {
            // A save can reach CloudKit even when its response is lost. The unique ID
            // lets cleanup safely attempt deletion after every save attempt.
            try await delete(recordID: probeRecord.recordID)
            return failure(
                signedIntoICloud: signedIntoICloud,
                reason: reason,
                underlyingError: underlyingError
            )
        } catch {
            return failure(
                signedIntoICloud: signedIntoICloud,
                reason: "\(reason) Cleanup of the temporary probe also failed: \(error.localizedDescription)",
                underlyingError: underlyingError
            )
        }
    }

    private func failure(
        signedIntoICloud: Bool?,
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
        signedIntoICloud: Bool?,
        reason: String,
        underlyingError: Error?
    ) -> String {
        #if DEBUG
            let accountStatus: String
            if let signedIntoICloud {
                accountStatus = signedIntoICloud ? "Available" : "Not available"
            } else {
                accountStatus = "Unknown"
            }
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
            iCloud account status: \(accountStatus)

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
