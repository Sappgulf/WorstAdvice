import Combine
import Foundation
import OSLog

#if canImport(CoreML)
    import CoreML
#endif

#if canImport(FoundationModels)
    import FoundationModels
#endif

enum LocalModelSource: String, Codable, Sendable {
    case system
    case bundled
    case downloaded

    var badgeLabel: String {
        switch self {
        case .system: return "System"
        case .bundled: return "Bundled"
        case .downloaded: return "Downloaded"
        }
    }
}

struct LocalModelDescriptor: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let displayName: String
    let sizeBytes: Int64?
    let version: String?
    let source: LocalModelSource
    let fileURL: URL
    let isInstalled: Bool

    var isSystemModel: Bool { source == .system }
}

enum LocalModelInstallState: Equatable, Sendable {
    case idle
    case installing(progress: Double?)
    case installed
    case ready
    case error(String)
}

@MainActor
final class LocalModelStore: ObservableObject {
    struct PersistedIndex: Codable {
        var version: Int = 1
        var entries: [PersistedIndexEntry]
    }

    struct PersistedIndexEntry: Codable {
        var id: String
        var displayName: String
        var sizeBytes: Int64?
        var version: String?
        var source: LocalModelSource
        var relativePath: String
    }

    enum GenerationGate: Equatable, Sendable {
        case ready(modelID: String)
        case unavailable(
            reasonKey: String,
            message: String,
            settingsWarning: String?,
            shouldOpenAppSettings: Bool
        )

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    @Published private(set) var availableModels: [LocalModelDescriptor] = []
    @Published private(set) var installedModelIDs: Set<String> = []
    @Published var selectedModelID: String? {
        didSet {
            persistSelectedModelID()
            if oldValue != selectedModelID {
                resetWarmUpStateIfNeeded(forDeselectedID: oldValue)
            }
        }
    }
    @Published private(set) var installStateByID: [String: LocalModelInstallState] = [:]

    nonisolated static let selectedModelDefaultsKey = "appleLocalModel.selectedModelID"
    nonisolated private static let warmedModelIDsDefaultsKey = "appleLocalModel.warmedModelIDs"
    nonisolated private static let modelRootFolderName = "Models"
    nonisolated private static let indexFileName = "models_index.json"
    nonisolated private static let systemModelID = "apple.foundation.system"
    nonisolated private static let systemModelPlaceholderName = "system-model"

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let bundle: Bundle
    private let appSupportBaseURLOverride: URL?
    private let includeSystemModelWhenFrameworkMissing: Bool
    private let logger = Logger(subsystem: "com.worstadvice.app", category: "localModelStore")
    private var warmedModelIDs: Set<String>
    private var reloadTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        appSupportBaseURLOverride: URL? = nil,
        includeSystemModelWhenFrameworkMissing: Bool = false
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.bundle = bundle
        self.appSupportBaseURLOverride = appSupportBaseURLOverride
        self.includeSystemModelWhenFrameworkMissing = includeSystemModelWhenFrameworkMissing
        self.selectedModelID = userDefaults.string(forKey: Self.selectedModelDefaultsKey)
        self.warmedModelIDs = Set(
            userDefaults.stringArray(forKey: Self.warmedModelIDsDefaultsKey) ?? [])
    }

    deinit {
        reloadTask?.cancel()
    }

    func reloadAvailableModels() {
        reloadTask?.cancel()
        let fileManager = self.fileManager
        let userDefaults = self.userDefaults
        let bundle = self.bundle
        let appSupportBaseURLOverride = self.appSupportBaseURLOverride
        let includeSystemModelWhenFrameworkMissing = self.includeSystemModelWhenFrameworkMissing
        let warmedModelIDs = self.warmedModelIDs

        reloadTask = Task(priority: .utility) { [weak self] in
            let snapshot = await Self.discoverSnapshot(
                fileManager: fileManager,
                bundle: bundle,
                appSupportBaseURLOverride: appSupportBaseURLOverride,
                includeSystemModelWhenFrameworkMissing: includeSystemModelWhenFrameworkMissing,
                warmedModelIDs: warmedModelIDs,
                existingSelectedModelID: userDefaults.string(forKey: Self.selectedModelDefaultsKey)
            )
            guard !Task.isCancelled else { return }
            self?.applyDiscoverySnapshot(snapshot)
        }
    }

    func reloadAvailableModelsNowForTesting() async {
        let snapshot = await Self.discoverSnapshot(
            fileManager: fileManager,
            bundle: bundle,
            appSupportBaseURLOverride: appSupportBaseURLOverride,
            includeSystemModelWhenFrameworkMissing: includeSystemModelWhenFrameworkMissing,
            warmedModelIDs: warmedModelIDs,
            existingSelectedModelID: selectedModelID
        )
        applyDiscoverySnapshot(snapshot)
    }

    func installModel(id: String) async throws {
        guard let descriptor = availableModels.first(where: { $0.id == id }) else {
            throw NSError(
                domain: "LocalModelStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Model not found."]
            )
        }

        if descriptor.isSystemModel {
            installStateByID[id] = .installing(progress: nil)
            debugLog("install begin id=\(id) source=system")
            let availability = await AppleOnDeviceAdviceBridge.prewarmSystemModelAndPoll()
            switch availability {
            case .ready:
                installStateByID[id] = warmedModelIDs.contains(id) ? .ready : .installed
            case .unavailable(let reason):
                if availability.analyticsKey == "model_not_ready" {
                    installStateByID[id] = .installing(progress: nil)
                } else {
                    installStateByID[id] = .error(reason)
                    throw NSError(
                        domain: "LocalModelStore",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: reason]
                    )
                }
            }
            reloadAvailableModels()
            return
        }

        if descriptor.isInstalled {
            installStateByID[id] = warmedModelIDs.contains(id) ? .ready : .installed
            return
        }

        installStateByID[id] = .error(
            "No downloadable source is configured for this model in the current build.")
        throw NSError(
            domain: "LocalModelStore",
            code: 501,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "No downloadable source is configured for this model in the current build."
            ]
        )
    }

    func removeModel(id: String) async {
        guard let descriptor = availableModels.first(where: { $0.id == id }) else { return }
        guard descriptor.source == .downloaded, !descriptor.isSystemModel else { return }

        do {
            let modelFolder = descriptor.fileURL.deletingLastPathComponent()
            if fileManager.fileExists(atPath: modelFolder.path) {
                try fileManager.removeItem(at: modelFolder)
            } else if fileManager.fileExists(atPath: descriptor.fileURL.path) {
                try fileManager.removeItem(at: descriptor.fileURL)
            }
            installStateByID[id] = .idle
            warmedModelIDs.remove(id)
            persistWarmedModelIDs()
            if selectedModelID == id {
                selectedModelID = nil
            }
            debugLog("remove success id=\(id) path=\(descriptor.fileURL.path)")
            reloadAvailableModels()
        } catch {
            installStateByID[id] = .error(error.localizedDescription)
            debugLog("remove failed id=\(id) error=\(error.localizedDescription)")
        }
    }

    func warmUp(id: String) async {
        guard let descriptor = availableModels.first(where: { $0.id == id }) else { return }
        let perfToken = AppPerformanceInstrumentation.beginLocalModelWarmUpInterval(modelID: id)
        defer { AppPerformanceInstrumentation.endLocalModelWarmUpInterval(perfToken, modelID: id) }

        installStateByID[id] = .installing(progress: nil)
        debugLog("warmup begin id=\(id) path=\(descriptor.fileURL.path)")

        if descriptor.isSystemModel {
            let availability = await AppleOnDeviceAdviceBridge.prewarmSystemModelAndPoll()
            switch availability {
            case .ready:
                warmedModelIDs.insert(id)
                persistWarmedModelIDs()
                installStateByID[id] = .ready
            case .unavailable(let reason):
                if availability.analyticsKey == "model_not_ready" {
                    installStateByID[id] = .installing(progress: nil)
                } else {
                    installStateByID[id] = .error(reason)
                }
            }
            reloadAvailableModels()
            return
        }

        do {
            try await Self.loadModelForWarmUp(url: descriptor.fileURL)
            warmedModelIDs.insert(id)
            persistWarmedModelIDs()
            installStateByID[id] = .ready
            debugLog("warmup success id=\(id)")
        } catch {
            installStateByID[id] = .error(error.localizedDescription)
            debugLog("warmup failed id=\(id) error=\(error.localizedDescription)")
        }
    }

    func generationGate(
        appleAvailability: AppleOnDeviceModelAvailability = AppleOnDeviceAdviceBridge.currentAvailability()
    ) -> GenerationGate {
        guard let selectedModelID else {
            return .unavailable(
                reasonKey: "no_selection",
                message: "No on-device model selected. Select and warm a model in Settings.",
                settingsWarning: "Auto will use the Classic generator until a local model is selected.",
                shouldOpenAppSettings: false
            )
        }

        guard let selected = availableModels.first(where: { $0.id == selectedModelID }) else {
            return .unavailable(
                reasonKey: "selected_missing",
                message: "The selected on-device model is missing. Tap Recheck in Settings.",
                settingsWarning: "Selected local model is missing. Recheck the model list.",
                shouldOpenAppSettings: false
            )
        }

        guard selected.isInstalled else {
            if selected.isSystemModel, appleAvailability.analyticsKey == "model_not_ready" {
                return .unavailable(
                    reasonKey: "system_downloading",
                    message: appleAvailability.statusText,
                    settingsWarning:
                        "Apple is still preparing the system model. Keep the device on Wi-Fi and power, then Recheck.",
                    shouldOpenAppSettings: false
                )
            }
            return .unavailable(
                reasonKey: "not_installed",
                message: "The selected local model is not installed yet.",
                settingsWarning: "Install the selected model before using Apple On-Device generation.",
                shouldOpenAppSettings: false
            )
        }

        let state = installStateByID[selectedModelID] ?? .idle
        guard state == .ready else {
            if case .error(let message) = state {
                return .unavailable(
                    reasonKey: "warmup_error",
                    message: "Local model warm-up failed: \(message)",
                    settingsWarning: "Warm-up failed for the selected model. Try Warm Up again.",
                    shouldOpenAppSettings: false
                )
            }
            return .unavailable(
                reasonKey: "not_warmed",
                message: "Local model is installed but not warmed up. Warm it up in Settings first.",
                settingsWarning: "Selected local model is installed but not warmed yet.",
                shouldOpenAppSettings: false
            )
        }

        if selected.isSystemModel {
            guard appleAvailability.isReady else {
                let shouldOpenAppSettings = appleAvailability.analyticsKey == "disabled"
                return .unavailable(
                    reasonKey: "system_unavailable_\(appleAvailability.analyticsKey)",
                    message: appleAvailability.statusText,
                    settingsWarning: appleAvailability.statusText,
                    shouldOpenAppSettings: shouldOpenAppSettings
                )
            }
            return .ready(modelID: selectedModelID)
        }

        return .unavailable(
            reasonKey: "unsupported_selected_model",
            message:
                "The selected model was validated locally, but this build uses Apple Intelligence system generation. Select the Apple system model to generate on-device.",
            settingsWarning:
                "Selected model can be warmed and inspected, but generation currently requires the Apple system model.",
            shouldOpenAppSettings: false
        )
    }

    func effectiveStatus(for provider: AdviceGenerationProvider) -> (
        key: String,
        message: String,
        hint: String,
        pill: String,
        warning: String?,
        shouldShowSettingsShortcut: Bool
    ) {
        let availability = AppleOnDeviceAdviceBridge.currentAvailability()
        let gate = generationGate(appleAvailability: availability)
        let selected = selectedModelID.flatMap { id in availableModels.first(where: { $0.id == id }) }
        let selectedState = selected.flatMap { installStateByID[$0.id] }

        switch gate {
        case .ready:
            return (
                "ready",
                "Apple on-device model is ready.",
                "Selected model is installed and warmed. Apple On-Device and Auto will use it.",
                "Ready",
                nil,
                false
            )
        case .unavailable(let reasonKey, let message, let settingsWarning, let shouldOpenAppSettings):
            if availableModels.isEmpty {
                return (
                    "no_models",
                    "No on-device models available yet.",
                    "Install or bundle a local model, then tap Recheck. Simulator builds may not expose Apple’s system model.",
                    "Empty",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if let selected, selected.isInstalled, selectedState != .ready, reasonKey == "not_warmed" {
                return (
                    "installed_not_warmed",
                    "Selected local model is installed but not warmed up.",
                    "Tap Warm Up to confirm the model can load before using Apple On-Device generation.",
                    "Installed",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if let selectedState, case .installing = selectedState {
                return (
                    "installing",
                    message,
                    "Recheck refreshes Apple model availability and local files after installation progress changes.",
                    "Installing",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if let selectedState, case .error(let errorMessage) = selectedState {
                return (
                    "error",
                    "Local model error: \(errorMessage)",
                    "Fix the model file, reinstall, or choose another model, then Recheck.",
                    "Error",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            if selected == nil {
                return (
                    "not_installed",
                    "Select an on-device model to enable Apple On-Device generation.",
                    "Choose a model below, then install and warm it up.",
                    "Select",
                    provider == .classic ? nil : settingsWarning,
                    shouldOpenAppSettings
                )
            }

            return (
                "unavailable",
                message,
                "Tap Recheck after changing Apple Intelligence or device power settings.",
                "Status",
                provider == .classic ? nil : settingsWarning,
                shouldOpenAppSettings
            )
        }
    }

    func state(for modelID: String) -> LocalModelInstallState {
        installStateByID[modelID] ?? .idle
    }

    func selectModel(_ id: String?) {
        guard selectedModelID != id else { return }
        selectedModelID = id
    }

    var modelsRootDirectoryURLForTesting: URL? { try? modelsRootDirectory() }
    var modelsIndexFileURLForTesting: URL? {
        guard let root = try? modelsRootDirectory() else { return nil }
        return root.appendingPathComponent(Self.indexFileName, isDirectory: false)
    }

    private func persistSelectedModelID() {
        if let selectedModelID, !selectedModelID.isEmpty {
            userDefaults.set(selectedModelID, forKey: Self.selectedModelDefaultsKey)
        } else {
            userDefaults.removeObject(forKey: Self.selectedModelDefaultsKey)
        }
    }

    private func persistWarmedModelIDs() {
        userDefaults.set(Array(warmedModelIDs).sorted(), forKey: Self.warmedModelIDsDefaultsKey)
    }

    private func resetWarmUpStateIfNeeded(forDeselectedID oldValue: String?) {
        guard let oldValue else { return }
        if case .ready = installStateByID[oldValue] {
            installStateByID[oldValue] = .installed
        }
    }

    private func applyDiscoverySnapshot(_ snapshot: DiscoverySnapshot) {
        availableModels = snapshot.availableModels
        installedModelIDs = snapshot.installedModelIDs

        var nextInstallStates = installStateByID
        let currentInstalling = installStateByID.filter {
            if case .installing = $0.value { return true }
            return false
        }
        for model in snapshot.availableModels {
            if let inFlight = currentInstalling[model.id] {
                nextInstallStates[model.id] = inFlight
                continue
            }
            nextInstallStates[model.id] = snapshot.installStateByID[model.id] ?? .idle
        }
        nextInstallStates.keys
            .filter { id in !snapshot.availableModels.contains(where: { $0.id == id }) }
            .forEach { nextInstallStates.removeValue(forKey: $0) }
        installStateByID = nextInstallStates

        let validIDs = Set(snapshot.availableModels.map(\.id))
        let healedWarmed = Set(warmedModelIDs.filter(validIDs.contains))
        if healedWarmed != warmedModelIDs {
            warmedModelIDs = healedWarmed
            persistWarmedModelIDs()
        }

        if let selectedModelID, !validIDs.contains(selectedModelID) {
            self.selectedModelID = snapshot.defaultSelectedModelID
        } else if self.selectedModelID == nil {
            self.selectedModelID = snapshot.defaultSelectedModelID
        }

        if snapshot.availableModels.isEmpty {
            debugLog(
                "recheck empty bundled=\(snapshot.debugCounts.bundled) downloaded=\(snapshot.debugCounts.downloaded) systemIncluded=\(snapshot.debugCounts.systemIncluded) reason=\(snapshot.debugEmptyReason)"
            )
        } else {
            debugLog(
                "recheck models=\(snapshot.availableModels.count) installed=\(snapshot.installedModelIDs.count) selected=\(self.selectedModelID ?? "nil") bundled=\(snapshot.debugCounts.bundled) downloaded=\(snapshot.debugCounts.downloaded) systemIncluded=\(snapshot.debugCounts.systemIncluded)"
            )
        }
    }

    private func modelsRootDirectory() throws -> URL {
        let baseURL: URL
        if let appSupportBaseURLOverride {
            baseURL = appSupportBaseURLOverride
        } else {
            baseURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }

        let modelsRoot = baseURL
            .appendingPathComponent(Self.modelRootFolderName, isDirectory: true)
        if !fileManager.fileExists(atPath: modelsRoot.path) {
            try fileManager.createDirectory(at: modelsRoot, withIntermediateDirectories: true)
        }
        return modelsRoot
    }

    private static func discoverSnapshot(
        fileManager: FileManager,
        bundle: Bundle,
        appSupportBaseURLOverride: URL?,
        includeSystemModelWhenFrameworkMissing: Bool,
        warmedModelIDs: Set<String>,
        existingSelectedModelID: String?
    ) async -> DiscoverySnapshot {
        let helper = DiscoveryHelper(
            fileManager: fileManager,
            bundle: bundle,
            appSupportBaseURLOverride: appSupportBaseURLOverride,
            includeSystemModelWhenFrameworkMissing: includeSystemModelWhenFrameworkMissing,
            warmedModelIDs: warmedModelIDs,
            existingSelectedModelID: existingSelectedModelID
        )
        return await Task.detached(priority: .utility) {
            do {
                return try helper.run()
            } catch {
                return DiscoverySnapshot(
                    availableModels: [],
                    installedModelIDs: [],
                    installStateByID: [:],
                    defaultSelectedModelID: nil,
                    debugCounts: .init(systemIncluded: 0, bundled: 0, downloaded: 0),
                    debugEmptyReason: "discovery_failed_\(error.localizedDescription)"
                )
            }
        }.value
    }

    private static func loadModelForWarmUp(url: URL) async throws {
        #if canImport(CoreML)
            try await Task.detached(priority: .utility) {
                _ = try MLModel(contentsOf: url)
            }.value
        #else
            throw NSError(
                domain: "LocalModelStore",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "CoreML is unavailable in this build."]
            )
        #endif
    }

    private func debugLog(_ message: String) {
        #if DEBUG
            logger.debug("\(message, privacy: .public)")
        #endif
    }

    private struct DiscoveryCounts: Sendable {
        var systemIncluded: Int
        var bundled: Int
        var downloaded: Int
    }

    private struct DiscoverySnapshot: Sendable {
        var availableModels: [LocalModelDescriptor]
        var installedModelIDs: Set<String>
        var installStateByID: [String: LocalModelInstallState]
        var defaultSelectedModelID: String?
        var debugCounts: DiscoveryCounts
        var debugEmptyReason: String
    }

    private struct DiscoveryHelper: @unchecked Sendable {
        let fileManager: FileManager
        let bundle: Bundle
        let appSupportBaseURLOverride: URL?
        let includeSystemModelWhenFrameworkMissing: Bool
        let warmedModelIDs: Set<String>
        let existingSelectedModelID: String?

        func run() throws -> DiscoverySnapshot {
            let modelsRoot = try modelsRootDirectory()
            let indexFileURL = modelsRoot.appendingPathComponent(
                LocalModelStore.indexFileName,
                isDirectory: false
            )

            var bundled: [LocalModelDescriptor] = []
            var downloaded: [LocalModelDescriptor] = []
            var installStates: [String: LocalModelInstallState] = [:]
            var installedIDs = Set<String>()
            var emptyReasons: [String] = []

            if let systemModel = buildSystemDescriptor() {
                bundled.append(systemModel)
                if systemModel.isInstalled {
                    installedIDs.insert(systemModel.id)
                    installStates[systemModel.id] =
                        warmedModelIDs.contains(systemModel.id) ? .ready : .installed
                } else {
                    let availability = AppleOnDeviceAdviceBridge.currentAvailability()
                    switch availability.analyticsKey {
                    case "model_not_ready":
                        installStates[systemModel.id] = .installing(progress: nil)
                    case "ready":
                        installStates[systemModel.id] =
                            warmedModelIDs.contains(systemModel.id) ? .ready : .installed
                    case "disabled", "device_policy_blocked", "device_not_eligible", "os_too_old":
                        installStates[systemModel.id] = .error(availability.statusText)
                    case "framework_missing":
                        if includeSystemModelWhenFrameworkMissing {
                            installStates[systemModel.id] = .error(availability.statusText)
                        } else {
                            bundled.removeAll { $0.id == systemModel.id }
                            emptyReasons.append("system_framework_missing")
                        }
                    default:
                        installStates[systemModel.id] = .idle
                        emptyReasons.append("system_\(availability.analyticsKey)")
                    }
                }
            } else {
                emptyReasons.append("system_model_not_exposed")
            }

            let bundledFiles = discoverBundledCoreMLModels()
            for descriptor in bundledFiles {
                bundled.append(descriptor)
                installedIDs.insert(descriptor.id)
                installStates[descriptor.id] = warmedModelIDs.contains(descriptor.id) ? .ready : .installed
            }
            if bundledFiles.isEmpty {
                emptyReasons.append("no_bundled_mlmodelc")
            }

            var indexedEntries = loadIndex(from: indexFileURL)?.entries ?? []
            let downloadedFromIndex = indexedEntries.compactMap { entry -> LocalModelDescriptor? in
                let fileURL = modelsRoot.appendingPathComponent(entry.relativePath, isDirectory: true)
                guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
                return LocalModelDescriptor(
                    id: entry.id,
                    displayName: entry.displayName,
                    sizeBytes: entry.sizeBytes,
                    version: entry.version,
                    source: .downloaded,
                    fileURL: fileURL,
                    isInstalled: true
                )
            }
            if downloadedFromIndex.count != indexedEntries.count {
                indexedEntries = downloadedFromIndex.map { descriptor in
                    PersistedIndexEntry(
                        id: descriptor.id,
                        displayName: descriptor.displayName,
                        sizeBytes: descriptor.sizeBytes,
                        version: descriptor.version,
                        source: .downloaded,
                        relativePath: relativePath(
                            for: descriptor.fileURL,
                            root: modelsRoot
                        )
                    )
                }
            }

            var downloadedByID = Dictionary(uniqueKeysWithValues: downloadedFromIndex.map { ($0.id, $0) })

            let discoveredDownloaded = discoverDownloadedCoreMLModels(in: modelsRoot)
            for descriptor in discoveredDownloaded where downloadedByID[descriptor.id] == nil {
                downloadedByID[descriptor.id] = descriptor
                indexedEntries.append(
                    PersistedIndexEntry(
                        id: descriptor.id,
                        displayName: descriptor.displayName,
                        sizeBytes: descriptor.sizeBytes,
                        version: descriptor.version,
                        source: .downloaded,
                        relativePath: relativePath(for: descriptor.fileURL, root: modelsRoot)
                    )
                )
            }

            downloaded = downloadedByID.values.sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            for descriptor in downloaded {
                installedIDs.insert(descriptor.id)
                installStates[descriptor.id] = warmedModelIDs.contains(descriptor.id) ? .ready : .installed
            }
            if downloaded.isEmpty {
                emptyReasons.append("no_downloaded_models")
            }

            persistIndexIfNeeded(entries: indexedEntries, to: indexFileURL)

            let allModels = (bundled + downloaded)
                .sorted(by: modelSort(lhs:rhs:))
            let validIDs = Set(allModels.map(\.id))
            let defaultSelected = validSelection(
                existingSelectedModelID,
                validIDs: validIDs,
                allModels: allModels
            )

            return DiscoverySnapshot(
                availableModels: allModels,
                installedModelIDs: installedIDs,
                installStateByID: installStates,
                defaultSelectedModelID: defaultSelected,
                debugCounts: .init(
                    systemIncluded: allModels.contains(where: { $0.source == .system }) ? 1 : 0,
                    bundled: allModels.filter { $0.source == .bundled }.count,
                    downloaded: downloaded.count
                ),
                debugEmptyReason: emptyReasons.joined(separator: "|")
            )
        }

        private func modelsRootDirectory() throws -> URL {
            let baseURL: URL
            if let appSupportBaseURLOverride {
                baseURL = appSupportBaseURLOverride
            } else {
                baseURL = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            }
            let modelsRoot = baseURL.appendingPathComponent(LocalModelStore.modelRootFolderName, isDirectory: true)
            if !fileManager.fileExists(atPath: modelsRoot.path) {
                try fileManager.createDirectory(at: modelsRoot, withIntermediateDirectories: true)
            }
            return modelsRoot
        }

        private func buildSystemDescriptor() -> LocalModelDescriptor? {
            let availability = AppleOnDeviceAdviceBridge.currentAvailability()
            if availability.analyticsKey == "framework_missing", !includeSystemModelWhenFrameworkMissing {
                return nil
            }

            let baseURL = appSupportBaseURLOverride ?? (try? fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ))
            let placeholderRoot = (baseURL ?? bundle.bundleURL)
                .appendingPathComponent(LocalModelStore.modelRootFolderName, isDirectory: true)
                .appendingPathComponent(LocalModelStore.systemModelPlaceholderName, isDirectory: true)

            return LocalModelDescriptor(
                id: LocalModelStore.systemModelID,
                displayName: "Apple Intelligence System Model",
                sizeBytes: nil,
                version: nil,
                source: .system,
                fileURL: placeholderRoot,
                isInstalled: availability.isReady
            )
        }

        private func discoverBundledCoreMLModels() -> [LocalModelDescriptor] {
            guard let resourceURL = bundle.resourceURL else { return [] }
            return discoverCoreMLModels(
                in: resourceURL,
                source: .bundled,
                idPrefix: "bundled."
            )
        }

        private func discoverDownloadedCoreMLModels(in modelsRoot: URL) -> [LocalModelDescriptor] {
            var results: [LocalModelDescriptor] = []
            guard let directories = try? fileManager.contentsOfDirectory(
                at: modelsRoot,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return results
            }
            for directory in directories {
                if directory.lastPathComponent == LocalModelStore.indexFileName { continue }
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                results.append(
                    contentsOf: discoverCoreMLModels(
                        in: directory,
                        source: .downloaded,
                        idPrefix: "downloaded."
                    )
                )
            }
            return results
        }

        private func discoverCoreMLModels(in root: URL, source: LocalModelSource, idPrefix: String)
            -> [LocalModelDescriptor]
        {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            var results: [LocalModelDescriptor] = []
            for case let candidate as URL in enumerator {
                guard candidate.pathExtension == "mlmodelc" else { continue }
                let relative = relativePath(for: candidate, root: root)
                let idBase = relative
                    .replacingOccurrences(of: "/", with: ".")
                    .replacingOccurrences(of: " ", with: "_")
                    .lowercased()
                let displayName = candidate.deletingPathExtension().lastPathComponent
                let size = directoryByteSize(at: candidate)
                results.append(
                    LocalModelDescriptor(
                        id: "\(idPrefix)\(idBase)",
                        displayName: displayName,
                        sizeBytes: size,
                        version: nil,
                        source: source,
                        fileURL: candidate,
                        isInstalled: true
                    )
                )
                enumerator.skipDescendants()
            }
            return results
        }

        private func loadIndex(from url: URL) -> PersistedIndex? {
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(PersistedIndex.self, from: data)
        }

        private func persistIndexIfNeeded(entries: [PersistedIndexEntry], to url: URL) {
            let normalized = entries
                .filter { !$0.relativePath.isEmpty }
                .sorted { lhs, rhs in lhs.id.localizedCaseInsensitiveCompare(rhs.id) == .orderedAscending }
            let payload = PersistedIndex(entries: normalized)
            guard let data = try? JSONEncoder().encode(payload) else { return }
            try? data.write(to: url, options: [.atomic])
        }

        private func directoryByteSize(at root: URL) -> Int64? {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return nil
            }
            var total: Int64 = 0
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                guard values?.isRegularFile == true else { continue }
                let fileSize = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0
                total += Int64(fileSize)
            }
            return total == 0 ? nil : total
        }

        private func validSelection(
            _ existingSelectedModelID: String?,
            validIDs: Set<String>,
            allModels: [LocalModelDescriptor]
        ) -> String? {
            if let existingSelectedModelID, validIDs.contains(existingSelectedModelID) {
                return existingSelectedModelID
            }
            if let preferred = allModels.first(where: { $0.source == .system }) {
                return preferred.id
            }
            return allModels.first?.id
        }

        private func relativePath(for url: URL, root: URL) -> String {
            let rootPath = root.standardizedFileURL.path
            let fullPath = url.standardizedFileURL.path
            guard fullPath.hasPrefix(rootPath) else {
                return url.lastPathComponent
            }
            return String(fullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        private func modelSort(lhs: LocalModelDescriptor, rhs: LocalModelDescriptor) -> Bool {
            let sourceRank: (LocalModelSource) -> Int = {
                switch $0 {
                case .system: return 0
                case .bundled: return 1
                case .downloaded: return 2
                }
            }
            if sourceRank(lhs.source) != sourceRank(rhs.source) {
                return sourceRank(lhs.source) < sourceRank(rhs.source)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

