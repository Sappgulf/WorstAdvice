import CloudKit
import Foundation

enum SocialPostType: String, CaseIterable, Codable, Sendable {
    case advice
    case quote
}

enum SocialPostVisibility: String, Codable, Sendable {
    case friends
}

enum SocialFriendRequestStatus: String, Codable, Sendable {
    case pending
    case accepted
    case rejected
    case canceled
    case blocked
}

enum SocialError: LocalizedError {
    case iCloudUnavailable(String)
    case missingProfile
    case invalidHandle
    case handleTaken
    case userNotFound
    case cannotFriendYourself
    case duplicateRequest
    case rateLimited(String)
    case permissionDenied
    case versionConflict(current: Int64)
    case invalidRecord

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable(let message):
            return message
        case .missingProfile:
            return "Create your profile first to unlock social features."
        case .invalidHandle:
            return "Handle must be 3–16 characters using lowercase letters, numbers, dots, or underscore."
        case .handleTaken:
            return "That handle is already taken."
        case .userNotFound:
            return "User not found."
        case .cannotFriendYourself:
            return "You cannot send a friend request to yourself."
        case .duplicateRequest:
            return "A request already exists for this user."
        case .rateLimited(let message):
            return message
        case .permissionDenied:
            return "You do not have permission for that action."
        case .versionConflict:
            return "This document was updated by someone else. Reloading latest version."
        case .invalidRecord:
            return "A CloudKit record was missing required fields."
        }
    }
}

struct SocialCloudKitErrorDiagnostic: Sendable {
    let operation: String
    let domain: String
    let code: String
    let localizedDescription: String
    let recordType: String?
    let recordNames: [String]
    let normalizedHandle: String?
    let predicateSummary: String?
    let fieldNames: [String]
    let sortKeys: [String]
    let containerIdentifier: String
    let databaseScope: String
    let environmentName: String
    let isRetryable: Bool
    let partialFailureDetails: [String]
    let debugUserInfo: String?

    var inlineSummary: String {
        "\(operation): \(code): \(localizedDescription)"
    }

    var debugSummary: String {
        var lines = [
            "Operation: \(operation)",
            "Domain: \(domain)",
            "Code: \(code)",
            "Description: \(localizedDescription)",
            "Container: \(containerIdentifier)",
            "Database Scope: \(databaseScope)",
            "Environment: \(environmentName)",
            "Retryable: \(isRetryable ? "yes" : "no")",
        ]
        if let recordType, !recordType.isEmpty {
            lines.append("Record Type: \(recordType)")
        }
        if !recordNames.isEmpty {
            lines.append("Record Names: \(recordNames.joined(separator: ", "))")
        }
        if let normalizedHandle, !normalizedHandle.isEmpty {
            lines.append("Normalized Handle: \(normalizedHandle)")
        }
        if let predicateSummary, !predicateSummary.isEmpty {
            lines.append("Predicate: \(predicateSummary)")
        }
        if !fieldNames.isEmpty {
            lines.append("Fields: \(fieldNames.joined(separator: ", "))")
        }
        if !sortKeys.isEmpty {
            lines.append("Sort Keys: \(sortKeys.joined(separator: ", "))")
        }
        if !partialFailureDetails.isEmpty {
            lines.append("Partial Failures:")
            lines.append(contentsOf: partialFailureDetails.map { "- \($0)" })
        }
        if let debugUserInfo, !debugUserInfo.isEmpty {
            lines.append("User Info: \(debugUserInfo)")
        }
        return lines.joined(separator: "\n")
    }

    static func make(
        from error: Error,
        context: SocialCloudKitOperationContext,
        isRetryable: Bool
    ) -> SocialCloudKitErrorDiagnostic? {
        guard let ckError = error as? CKError else { return nil }
        #if DEBUG
            let localizedDescription = ckError.localizedDescription
            var debugLines: [String] = []
            var partialFailureDetails: [String] = []
            if !ckError.userInfo.isEmpty {
                debugLines.append("UserInfo: \(String(describing: ckError.userInfo))")
            }
            if ckError.code == .partialFailure,
                let partialErrors = ckError.partialErrorsByItemID,
                !partialErrors.isEmpty
            {
                for (itemID, partialError) in partialErrors {
                    partialFailureDetails.append("\(itemID): \(partialError.localizedDescription)")
                }
            }
            if ckError.code == .serverRecordChanged {
                if let serverRecord = ckError.serverRecord {
                    debugLines.append("Server Record: \(serverRecord.recordID.recordName)")
                }
                if let ancestorRecord = ckError.ancestorRecord {
                    debugLines.append("Ancestor Record: \(ancestorRecord.recordID.recordName)")
                }
                if let clientRecord = ckError.clientRecord {
                    debugLines.append("Client Record: \(clientRecord.recordID.recordName)")
                }
            }
            let debugUserInfo = debugLines.isEmpty ? nil : debugLines.joined(separator: "\n")
        #else
            let localizedDescription = sanitizedDescription(for: ckError)
            let debugUserInfo: String? = nil
            let partialFailureDetails: [String] = []
        #endif
        return SocialCloudKitErrorDiagnostic(
            operation: context.operation,
            domain: CKError.errorDomain,
            code: "\(ckError.code) (\(ckError.code.rawValue))",
            localizedDescription: localizedDescription,
            recordType: context.recordType,
            recordNames: context.recordNames,
            normalizedHandle: context.normalizedHandle,
            predicateSummary: context.predicateSummary,
            fieldNames: context.fieldNames,
            sortKeys: context.sortKeys,
            containerIdentifier: context.containerIdentifier,
            databaseScope: context.databaseScope,
            environmentName: context.environmentName,
            isRetryable: isRetryable,
            partialFailureDetails: partialFailureDetails,
            debugUserInfo: debugUserInfo
        )
    }

    private static func sanitizedDescription(for error: CKError) -> String {
        switch error.code {
        case .notAuthenticated:
            return "You are not signed in to iCloud."
        case .permissionFailure:
            return "This build does not have CloudKit permission to complete the request."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
            return "CloudKit is temporarily unavailable."
        case .accountTemporarilyUnavailable:
            return "Your iCloud account is temporarily unavailable."
        case .quotaExceeded, .limitExceeded:
            return "CloudKit storage limits were reached."
        default:
            return "CloudKit request failed."
        }
    }
}

struct SocialCloudKitOperationContext: Sendable {
    let operation: String
    let recordType: String?
    let recordNames: [String]
    let normalizedHandle: String?
    let predicateSummary: String?
    let fieldNames: [String]
    let sortKeys: [String]
    let containerIdentifier: String
    let databaseScope: String
    let environmentName: String

    static func generic(operation: String) -> SocialCloudKitOperationContext {
        SocialCloudKitOperationContext(
            operation: operation,
            recordType: nil,
            recordNames: [],
            normalizedHandle: nil,
            predicateSummary: nil,
            fieldNames: [],
            sortKeys: [],
            containerIdentifier: CloudKitSocialConfig.containerIdentifier,
            databaseScope: CloudKitManager.socialDatabaseScope,
            environmentName: CloudKitSocialConfig.environmentName
        )
    }
}

struct SocialCloudOperationError: Error {
    let underlyingError: Error
    let diagnostic: SocialCloudKitErrorDiagnostic?
}

extension SocialCloudOperationError: LocalizedError {
    var errorDescription: String? {
        underlyingError.localizedDescription
    }
}

struct SocialCloudKitDiagnostics: Sendable {
    let accountStatus: CKAccountStatus?
    let containerIdentifier: String
    let databaseScope: String
    let environmentName: String
    let lastError: SocialCloudKitErrorDiagnostic?

    var isAccountAvailable: Bool {
        accountStatus == .available
    }

    var accountStatusLabel: String {
        guard let accountStatus else { return "Checking" }
        switch accountStatus {
        case .available:
            return "available"
        case .noAccount:
            return "noAccount"
        case .restricted:
            return "restricted"
        case .couldNotDetermine:
            return "couldNotDetermine"
        case .temporarilyUnavailable:
            return "temporarilyUnavailable"
        @unknown default:
            return "unknown(\(accountStatus.rawValue))"
        }
    }

    var userVisibleMessage: String {
        guard let accountStatus else {
            return "Checking CloudKit account status..."
        }
        switch accountStatus {
        case .available:
            if lastError != nil {
                return "CloudKit account is available, but the last Friends request failed."
            }
            return "CloudKit account is available."
        case .noAccount:
            return "Sign in to iCloud in Settings to use Friends."
        case .restricted:
            return "iCloud access is restricted on this device."
        case .couldNotDetermine:
            return "CloudKit account status could not be determined."
        case .temporarilyUnavailable:
            return "CloudKit is temporarily unavailable."
        @unknown default:
            return "CloudKit account status is unknown."
        }
    }

    func withLastError(_ lastError: SocialCloudKitErrorDiagnostic?) -> SocialCloudKitDiagnostics {
        SocialCloudKitDiagnostics(
            accountStatus: accountStatus,
            containerIdentifier: containerIdentifier,
            databaseScope: databaseScope,
            environmentName: environmentName,
            lastError: lastError
        )
    }

    func text(includeDebugDetails: Bool) -> String {
        var lines = [
            "Account Status: \(accountStatusLabel)",
            "Container: \(containerIdentifier)",
            "Database Scope: \(databaseScope)",
            "Environment: \(environmentName)",
        ]
        if let lastError {
            lines.append("Last CKError: \(lastError.code)")
            lines.append("Operation: \(lastError.operation)")
            if let recordType = lastError.recordType {
                lines.append("Record Type: \(recordType)")
            }
            if !lastError.recordNames.isEmpty {
                lines.append("Record Names: \(lastError.recordNames.joined(separator: ", "))")
            }
            if let normalizedHandle = lastError.normalizedHandle {
                lines.append("Normalized Handle: \(normalizedHandle)")
            }
            if let predicateSummary = lastError.predicateSummary {
                lines.append("Predicate: \(predicateSummary)")
            }
            if !lastError.fieldNames.isEmpty {
                lines.append("Fields: \(lastError.fieldNames.joined(separator: ", "))")
            }
            if !lastError.sortKeys.isEmpty {
                lines.append("Sort Keys: \(lastError.sortKeys.joined(separator: ", "))")
            }
            lines.append("Retryable: \(lastError.isRetryable ? "yes" : "no")")
            lines.append("Last Description: \(lastError.localizedDescription)")
            if includeDebugDetails {
                lines.append(lastError.debugSummary)
            }
        } else {
            lines.append("Last CKError: none")
        }
        return lines.joined(separator: "\n")
    }

    static let pending = SocialCloudKitDiagnostics(
        accountStatus: nil,
        containerIdentifier: CloudKitSocialConfig.containerIdentifier,
        databaseScope: CloudKitManager.socialDatabaseScope,
        environmentName: CloudKitSocialConfig.environmentName,
        lastError: nil
    )
}

struct SocialAvailabilityState: Sendable {
    let isAvailable: Bool
    let diagnostics: SocialCloudKitDiagnostics

    var message: String {
        diagnostics.userVisibleMessage
    }

    var isAccountAvailable: Bool {
        diagnostics.isAccountAvailable
    }

    func withLastError(_ lastError: SocialCloudKitErrorDiagnostic?) -> SocialAvailabilityState {
        SocialAvailabilityState(
            isAvailable: isAvailable,
            diagnostics: diagnostics.withLastError(lastError)
        )
    }

    static let available = SocialAvailabilityState(
        isAvailable: true,
        diagnostics: SocialCloudKitDiagnostics(
            accountStatus: .available,
            containerIdentifier: CloudKitSocialConfig.containerIdentifier,
            databaseScope: CloudKitManager.socialDatabaseScope,
            environmentName: CloudKitSocialConfig.environmentName,
            lastError: nil
        )
    )
}

enum SocialLoadState: Equatable {
    case idle
    case checkingCloudKit
    case needsProfileSetup
    case bootstrappingProfile
    case loadingFriends
    case empty
    case failed(message: String)
    case ready

    var allowsSocialActions: Bool {
        switch self {
        case .empty, .ready:
            return true
        default:
            return false
        }
    }
}

struct SocialUser: Identifiable, Hashable, Sendable {
    let recordID: CKRecord.ID
    let handle: String
    let displayName: String
    let createdAt: Date

    var id: String { recordID.recordName }
}

struct SocialFriendRequest: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let fromUserID: CKRecord.ID
    let toUserID: CKRecord.ID
    let status: SocialFriendRequestStatus
    let createdAt: Date
    let fromUser: SocialUser?
    let toUser: SocialUser?

    var id: String { recordID.recordName }
}

struct SocialPost: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let authorUserID: CKRecord.ID
    let author: SocialUser?
    let type: SocialPostType
    let text: String
    let visibility: SocialPostVisibility
    let createdAt: Date

    var id: String { recordID.recordName }
}

struct SocialChaosScore: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let seasonId: String
    let userID: CKRecord.ID
    let user: SocialUser?
    let score: Int64
    let updatedAt: Date

    var id: String { recordID.recordName }
}

struct SocialCollabDoc: Identifiable, Sendable {
    let recordID: CKRecord.ID
    let ownerID: CKRecord.ID
    let owner: SocialUser?
    let contributorIDs: [CKRecord.ID]
    let contributors: [SocialUser]
    let type: SocialPostType
    let content: String
    let version: Int64
    let updatedAt: Date

    var id: String { recordID.recordName }
}

struct SocialCollabDraft: Identifiable, Sendable {
    let id = UUID()
    let type: SocialPostType
    let content: String
}

enum SocialModerationTargetType: String, Codable, Sendable {
    case post
    case user
}

struct SocialModerationReport: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let targetType: SocialModerationTargetType
    let targetRecordName: String
    let reporterHandle: String
    let reason: String?
    let createdAt: Date
}

enum SocialQueuedActionPayload: Codable, Sendable {
    case friendRequest(handle: String)
    case sharePost(type: SocialPostType, text: String)
    case chaosScore(seasonId: String, score: Int64)
    case moderationReport(SocialModerationReport)
}

extension SocialQueuedActionPayload {
    var stableDedupeKey: String {
        switch self {
        case .friendRequest(let handle):
            "friend:\(handle)"
        case .sharePost(let type, let text):
            let normalizedText = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return "share:\(type.rawValue):\(normalizedText)"
        case .chaosScore(let seasonId, let score):
            "chaos:\(seasonId):\(score)"
        case .moderationReport(let report):
            "report:\(report.id)"
        }
    }
}

struct SocialQueuedAction: Identifiable, Codable, Sendable {
    let id: UUID
    let dedupeKey: String?
    let createdAt: Date
    var nextRetryAt: Date
    var attemptCount: Int
    let payload: SocialQueuedActionPayload
}

enum SocialReportLogger {
    private static let userDefaultsKey = "social.reportLog.v1"
    private static let maxEntries = 80

    static func log(_ entry: String, userDefaults: UserDefaults = .standard) {
        let now = ISO8601DateFormatter().string(from: Date())
        var logs = userDefaults.stringArray(forKey: userDefaultsKey) ?? []
        logs.insert("[\(now)] \(entry)", at: 0)
        if logs.count > maxEntries {
            logs = Array(logs.prefix(maxEntries))
        }
        userDefaults.set(logs, forKey: userDefaultsKey)
    }
}

protocol SocialBackend: Sendable {
    func backendDisplayName() async -> String
    func availabilityState() async -> SocialAvailabilityState
    func setStoredCurrentUserRecordName(_ recordName: String?) async
    func fetchCurrentUserIfStored() async throws -> SocialUser?
    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser
    func findUserByHandle(_ handle: String) async throws -> SocialUser?
    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest
    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest]
    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest]
    func acceptFriendRequest(_ request: SocialFriendRequest) async throws
    func declineFriendRequest(_ request: SocialFriendRequest) async throws
    func blockUser(_ user: SocialUser) async throws
    func fetchBlockedUsers() async throws -> [SocialUser]
    func fetchFriends() async throws -> [SocialUser]
    func createPost(type: SocialPostType, text: String) async throws -> SocialPost
    func fetchFriendsFeed() async throws -> [SocialPost]
    func submitChaosScore(seasonId: String, score: Int64) async throws
    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore]
    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc
    func fetchMyCollabDocs() async throws -> [SocialCollabDoc]
    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc?
    func submitModerationReport(_ report: SocialModerationReport) async throws
}

actor SocialActionQueueStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let maxRetryAttempts: Int = 8
    private let staleActionWindow: TimeInterval = 14 * 24 * 60 * 60

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "social.actionQueue.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func enqueue(_ action: SocialQueuedAction) {
        var actions = load()
        let normalizedDedupeKey = action.dedupeKey ?? action.payload.stableDedupeKey
        if let normalizedDedupeKey,
            actions.contains(where: { $0.dedupeKey == normalizedDedupeKey })
        {
            return
        }
        let normalizedAction = SocialQueuedAction(
            id: action.id,
            dedupeKey: normalizedDedupeKey,
            createdAt: action.createdAt,
            nextRetryAt: action.nextRetryAt,
            attemptCount: action.attemptCount,
            payload: action.payload
        )
        actions.append(normalizedAction)
        save(actions)
    }

    func readyActions(now: Date = Date(), limit: Int = 10) -> [SocialQueuedAction] {
        let sorted = load().sorted { lhs, rhs in
            if lhs.nextRetryAt != rhs.nextRetryAt {
                return lhs.nextRetryAt < rhs.nextRetryAt
            }
            return lhs.createdAt < rhs.createdAt
        }
        return Array(sorted.filter { $0.nextRetryAt <= now }.prefix(max(1, limit)))
    }

    func markSucceeded(id: UUID) {
        var actions = load()
        actions.removeAll { $0.id == id }
        save(actions)
    }

    func reschedule(id: UUID, retryAt: Date) {
        var actions = load()
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index].attemptCount += 1
        if shouldDrop(actions[index], now: Date()) {
            actions.remove(at: index)
            save(actions)
            return
        }
        actions[index].nextRetryAt = retryAt
        save(actions)
    }

    private func shouldDrop(_ action: SocialQueuedAction, now: Date) -> Bool {
        action.attemptCount >= maxRetryAttempts
            || now.timeIntervalSince(action.createdAt) > staleActionWindow
    }

    func totalCount() -> Int {
        load().count
    }

    func pendingModerationReportCount() -> Int {
        load().reduce(into: 0) { count, action in
            if case .moderationReport = action.payload {
                count += 1
            }
        }
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    private func load() -> [SocialQueuedAction] {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SocialQueuedAction].self, from: data)
        else {
            return []
        }
        let now = Date()
        let fresh = decoded.filter { !shouldDrop($0, now: now) }
        if fresh.count != decoded.count {
            save(fresh)
        }
        return fresh
    }

    private func save(_ actions: [SocialQueuedAction]) {
        if actions.isEmpty {
            userDefaults.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(actions) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

enum SocialBackendFactory {
    static func make() -> any SocialBackend {
        let arguments = ProcessInfo.processInfo.arguments
        let isRunningUnderXCTest =
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isUITestingLaunch = arguments.contains("-ui-testing")
        let allowLiveCloudKit = arguments.contains("-ui-testing-cloudkit-live")
            || arguments.contains("-social-live")
        let isRunningOnSimulator: Bool = {
            #if targetEnvironment(simulator)
                return true
            #else
                return false
            #endif
        }()
        let shouldUseMockBackend =
            arguments.contains("-ui-testing-social-mock")
            || (!allowLiveCloudKit && (isUITestingLaunch || isRunningUnderXCTest || isRunningOnSimulator))
        if shouldUseMockBackend {
            return UITestSocialBackend(
                forceUnavailable: arguments.contains("-ui-testing-force-social-unavailable"),
                seededIncomingRequests: intArgument(after: "-ui-testing-social-seed-incoming") ?? 0
            )
        }
        return CloudKitStore()
    }

    private static func intArgument(after flag: String) -> Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard valueIndex < arguments.endIndex else { return nil }
        return Int(arguments[valueIndex])
    }
}

actor UITestSocialBackend: SocialBackend {
    private var currentUser: SocialUser?
    private var usersByHandle: [String: SocialUser] = [:]
    private var usersByRecordName: [String: SocialUser] = [:]
    private var friendRequests: [SocialFriendRequest] = []
    private var friendshipsByUser: [String: Set<String>] = [:]
    private var blockedByUser: [String: Set<String>] = [:]
    private var posts: [SocialPost] = []
    private var scoresBySeason: [String: [String: Int64]] = [:]
    private var collabDocsByID: [String: SocialCollabDoc] = [:]
    private var moderationReports: [SocialModerationReport] = []

    private let forceUnavailable: Bool
    private let seededIncomingRequests: Int
    private var seededIncomingApplied = false

    init(forceUnavailable: Bool, seededIncomingRequests: Int) {
        self.forceUnavailable = forceUnavailable
        self.seededIncomingRequests = max(0, seededIncomingRequests)
    }

    func backendDisplayName() async -> String {
        "UI Test Mock"
    }

    func setStoredCurrentUserRecordName(_ recordName: String?) async {
        guard let recordName, !recordName.isEmpty else {
            currentUser = nil
            return
        }
        currentUser = usersByRecordName[recordName]
    }

    func availabilityState() async -> SocialAvailabilityState {
        if forceUnavailable {
            return SocialAvailabilityState(
                isAvailable: false,
                diagnostics: SocialCloudKitDiagnostics(
                    accountStatus: .couldNotDetermine,
                    containerIdentifier: CloudKitSocialConfig.containerIdentifier,
                    databaseScope: CloudKitManager.socialDatabaseScope,
                    environmentName: CloudKitSocialConfig.environmentName,
                    lastError: SocialCloudKitErrorDiagnostic(
                        operation: "ui-test",
                        domain: CKError.errorDomain,
                        code: "unavailable",
                        localizedDescription: "Social features are unavailable in this test run.",
                        recordType: nil,
                        recordNames: [],
                        normalizedHandle: nil,
                        predicateSummary: nil,
                        fieldNames: [],
                        sortKeys: [],
                        containerIdentifier: CloudKitSocialConfig.containerIdentifier,
                        databaseScope: CloudKitManager.socialDatabaseScope,
                        environmentName: CloudKitSocialConfig.environmentName,
                        isRetryable: false,
                        partialFailureDetails: [],
                        debugUserInfo: nil
                    )
                )
            )
        }
        return .available
    }

    func fetchCurrentUserIfStored() async throws -> SocialUser? {
        currentUser
    }

    func getOrCreateCurrentUser(handle: String, displayName: String?) async throws -> SocialUser {
        if let currentUser {
            return currentUser
        }
        let normalized = SocialHandleNormalizer.normalize(handle)
        guard CloudKitStore.isValidHandle(normalized) else {
            throw SocialError.invalidHandle
        }
        if usersByHandle[normalized] != nil {
            throw SocialError.handleTaken
        }
        let user = SocialUser(
            recordID: CKRecord.ID(recordName: "mock_user_\(normalized)"),
            handle: normalized,
            displayName: normalizedDisplayName(displayName, fallbackHandle: normalized),
            createdAt: Date()
        )
        usersByHandle[normalized] = user
        usersByRecordName[user.recordID.recordName] = user
        currentUser = user
        applySeededIncomingRequestsIfNeeded()
        return user
    }

    func findUserByHandle(_ handle: String) async throws -> SocialUser? {
        let normalized = SocialHandleNormalizer.normalize(handle)
        guard let user = usersByHandle[normalized] else { return nil }
        if user.recordID == currentUser?.recordID {
            return nil
        }
        return user
    }

    func sendFriendRequest(toUser target: SocialUser) async throws -> SocialFriendRequest {
        let current = try requireCurrentUser()
        guard current.recordID != target.recordID else {
            throw SocialError.cannotFriendYourself
        }
        guard usersByRecordName[target.recordID.recordName] != nil else {
            throw SocialError.userNotFound
        }
        if friendshipsByUser[current.recordID.recordName]?.contains(target.recordID.recordName) == true {
            throw SocialError.duplicateRequest
        }
        if friendRequests.contains(where: {
            $0.fromUserID == current.recordID
                && $0.toUserID == target.recordID
                && ($0.status == .pending || $0.status == .accepted || $0.status == .blocked)
        }) {
            throw SocialError.duplicateRequest
        }
        if friendRequests.contains(where: {
            $0.fromUserID == target.recordID
                && $0.toUserID == current.recordID
                && ($0.status == .pending || $0.status == .accepted || $0.status == .blocked)
        }) {
            throw SocialError.duplicateRequest
        }

        let request = SocialFriendRequest(
            recordID: CKRecord.ID(recordName: "mock_friendrequest_\(UUID().uuidString)"),
            fromUserID: current.recordID,
            toUserID: target.recordID,
            status: .pending,
            createdAt: Date(),
            fromUser: current,
            toUser: target
        )
        friendRequests.append(request)
        return request
    }

    func fetchIncomingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try requireCurrentUser()
        return friendRequests
            .filter { $0.toUserID == current.recordID && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchOutgoingFriendRequests() async throws -> [SocialFriendRequest] {
        let current = try requireCurrentUser()
        return friendRequests
            .filter { $0.fromUserID == current.recordID && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func acceptFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try requireCurrentUser()
        guard request.toUserID == current.recordID else { throw SocialError.permissionDenied }
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else {
            throw SocialError.invalidRecord
        }
        friendRequests[index] = SocialFriendRequest(
            recordID: request.recordID,
            fromUserID: request.fromUserID,
            toUserID: request.toUserID,
            status: .accepted,
            createdAt: request.createdAt,
            fromUser: request.fromUser,
            toUser: request.toUser
        )
        addFriendship(a: request.fromUserID.recordName, b: request.toUserID.recordName)
    }

    func declineFriendRequest(_ request: SocialFriendRequest) async throws {
        let current = try requireCurrentUser()
        guard request.toUserID == current.recordID else { throw SocialError.permissionDenied }
        guard let index = friendRequests.firstIndex(where: { $0.id == request.id }) else {
            throw SocialError.invalidRecord
        }
        friendRequests[index] = SocialFriendRequest(
            recordID: request.recordID,
            fromUserID: request.fromUserID,
            toUserID: request.toUserID,
            status: .rejected,
            createdAt: request.createdAt,
            fromUser: request.fromUser,
            toUser: request.toUser
        )
    }

    func blockUser(_ user: SocialUser) async throws {
        let current = try requireCurrentUser()
        let currentRecordName = current.recordID.recordName
        let targetRecordName = user.recordID.recordName

        var blocked = blockedByUser[currentRecordName] ?? []
        blocked.insert(targetRecordName)
        blockedByUser[currentRecordName] = blocked

        friendshipsByUser[currentRecordName]?.remove(targetRecordName)
        friendshipsByUser[targetRecordName]?.remove(currentRecordName)

        if let index = friendRequests.firstIndex(where: {
            $0.fromUserID.recordName == currentRecordName && $0.toUserID.recordName == targetRecordName
        }) {
            let existing = friendRequests[index]
            friendRequests[index] = SocialFriendRequest(
                recordID: existing.recordID,
                fromUserID: existing.fromUserID,
                toUserID: existing.toUserID,
                status: .blocked,
                createdAt: existing.createdAt,
                fromUser: existing.fromUser,
                toUser: existing.toUser
            )
        } else {
            friendRequests.append(
                SocialFriendRequest(
                    recordID: CKRecord.ID(recordName: "mock_friendrequest_\(UUID().uuidString)"),
                    fromUserID: current.recordID,
                    toUserID: user.recordID,
                    status: .blocked,
                    createdAt: Date(),
                    fromUser: current,
                    toUser: user
                )
            )
        }
    }

    func fetchBlockedUsers() async throws -> [SocialUser] {
        let current = try requireCurrentUser()
        let blocked = blockedByUser[current.recordID.recordName] ?? []
        return blocked.compactMap { usersByRecordName[$0] }
            .sorted { $0.handle < $1.handle }
    }

    func fetchFriends() async throws -> [SocialUser] {
        let current = try requireCurrentUser()
        let friendIDs = friendshipsByUser[current.recordID.recordName] ?? []
        return friendIDs.compactMap { usersByRecordName[$0] }
            .sorted { $0.handle < $1.handle }
    }

    func createPost(type: SocialPostType, text: String) async throws -> SocialPost {
        let current = try requireCurrentUser()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }
        let post = SocialPost(
            recordID: CKRecord.ID(recordName: "mock_post_\(UUID().uuidString)"),
            authorUserID: current.recordID,
            author: current,
            type: type,
            text: String(trimmed.prefix(480)),
            visibility: .friends,
            createdAt: Date()
        )
        posts.append(post)
        return post
    }

    func fetchFriendsFeed() async throws -> [SocialPost] {
        let current = try requireCurrentUser()
        let friendIDs = friendshipsByUser[current.recordID.recordName] ?? []
        return posts.filter { friendIDs.contains($0.authorUserID.recordName) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func submitChaosScore(seasonId: String, score: Int64) async throws {
        let current = try requireCurrentUser()
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        var seasonScores = scoresBySeason[normalizedSeason] ?? [:]
        seasonScores[current.recordID.recordName] = max(seasonScores[current.recordID.recordName] ?? 0, score)
        scoresBySeason[normalizedSeason] = seasonScores
    }

    func fetchLeaderboard(seasonId: String, limit: Int) async throws -> [SocialChaosScore] {
        let normalizedSeason = seasonId.trimmingCharacters(in: .whitespacesAndNewlines)
        let seasonScores = scoresBySeason[normalizedSeason] ?? [:]
        return seasonScores
            .compactMap { key, value -> SocialChaosScore? in
                guard let user = usersByRecordName[key] else { return nil }
                return SocialChaosScore(
                    recordID: CKRecord.ID(recordName: "mock_chaos_\(normalizedSeason)_\(key)"),
                    seasonId: normalizedSeason,
                    userID: user.recordID,
                    user: user,
                    score: value,
                    updatedAt: Date()
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.user?.handle ?? "" < rhs.user?.handle ?? ""
                }
                return lhs.score > rhs.score
            }
            .prefix(max(1, min(limit, 100)))
            .map { $0 }
    }

    func createOrUpdateCollabDoc(
        docID: String?,
        type: SocialPostType,
        content: String,
        contributorIDs: [CKRecord.ID],
        expectedVersion: Int64?
    ) async throws -> SocialCollabDoc {
        let current = try requireCurrentUser()
        let trimmed = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(4_000))
        guard !trimmed.isEmpty else { throw SocialError.invalidRecord }

        if let docID, let existing = collabDocsByID[docID] {
            let isContributor = existing.contributorIDs.contains(current.recordID)
            guard existing.ownerID == current.recordID || isContributor else {
                throw SocialError.permissionDenied
            }
            if let expectedVersion, existing.version > expectedVersion {
                throw SocialError.versionConflict(current: existing.version)
            }
            let contributors = contributorIDs.compactMap { usersByRecordName[$0.recordName] }
            let contributorRecordIDs = contributors.map(\.recordID)
            let updated = SocialCollabDoc(
                recordID: existing.recordID,
                ownerID: existing.ownerID,
                owner: existing.owner,
                contributorIDs: contributorRecordIDs,
                contributors: contributors,
                type: type,
                content: trimmed,
                version: existing.version + 1,
                updatedAt: Date()
            )
            collabDocsByID[docID] = updated
            return updated
        }

        let recordName = docID ?? "mock_collab_\(UUID().uuidString)"
        let contributors = contributorIDs.compactMap { usersByRecordName[$0.recordName] }
        let contributorRecordIDs = contributors.map(\.recordID)
        let doc = SocialCollabDoc(
            recordID: CKRecord.ID(recordName: recordName),
            ownerID: current.recordID,
            owner: current,
            contributorIDs: contributorRecordIDs,
            contributors: contributors,
            type: type,
            content: trimmed,
            version: 1,
            updatedAt: Date()
        )
        collabDocsByID[doc.id] = doc
        return doc
    }

    func fetchMyCollabDocs() async throws -> [SocialCollabDoc] {
        let current = try requireCurrentUser()
        return collabDocsByID.values
            .filter { $0.ownerID == current.recordID || $0.contributorIDs.contains(current.recordID) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchCollabDoc(id: String) async throws -> SocialCollabDoc? {
        collabDocsByID[id]
    }

    func submitModerationReport(_ report: SocialModerationReport) async throws {
        moderationReports.append(report)
    }

    private func requireCurrentUser() throws -> SocialUser {
        guard let currentUser else {
            throw SocialError.missingProfile
        }
        return currentUser
    }

    private func addFriendship(a: String, b: String) {
        var aFriends = friendshipsByUser[a] ?? []
        aFriends.insert(b)
        friendshipsByUser[a] = aFriends
        var bFriends = friendshipsByUser[b] ?? []
        bFriends.insert(a)
        friendshipsByUser[b] = bFriends
    }

    private func normalizedDisplayName(_ displayName: String?, fallbackHandle: String) -> String {
        SocialHandleNormalizer.displayName(displayName, fallbackHandle: fallbackHandle)
    }

    private func applySeededIncomingRequestsIfNeeded() {
        guard !seededIncomingApplied, seededIncomingRequests > 0, let currentUser else { return }
        seededIncomingApplied = true
        for index in 0..<seededIncomingRequests {
            let handle = "seed_friend_\(index + 1)"
            let seedUser = SocialUser(
                recordID: CKRecord.ID(recordName: "mock_seed_user_\(index + 1)"),
                handle: handle,
                displayName: "Seed Friend \(index + 1)",
                createdAt: Date().addingTimeInterval(TimeInterval(-(index + 1) * 60))
            )
            usersByHandle[handle] = seedUser
            usersByRecordName[seedUser.recordID.recordName] = seedUser
            friendRequests.append(
                SocialFriendRequest(
                    recordID: CKRecord.ID(recordName: "mock_seed_request_\(index + 1)"),
                    fromUserID: seedUser.recordID,
                    toUserID: currentUser.recordID,
                    status: .pending,
                    createdAt: Date().addingTimeInterval(TimeInterval(-(index + 1) * 30)),
                    fromUser: seedUser,
                    toUser: currentUser
                )
            )
        }
    }
}
