import Foundation

enum AppFeatureFlags {
    private enum Flag: String, CaseIterable {
        case exploreTab = "explore_tab"
        case groupChallengesTab = "group_challenges_tab"

        var defaultValue: Bool { false }

        var appTab: AppTab {
            switch self {
            case .exploreTab:
                return .explore
            case .groupChallengesTab:
                return .groupChallenges
            }
        }

        var launchArgument: String {
            switch self {
            case .exploreTab:
                return "-enable-explore-tab"
            case .groupChallengesTab:
                return "-enable-group-challenges-tab"
            }
        }

        var disableLaunchArgument: String {
            switch self {
            case .exploreTab:
                return "-disable-explore-tab"
            case .groupChallengesTab:
                return "-disable-group-challenges-tab"
            }
        }

        var environmentKey: String {
            "BADVICE_FEATURE_\(rawValue.uppercased())"
        }
    }

    static var exploreTabEnabled: Bool {
        isEnabled(.explore)
    }

    static var groupChallengesTabEnabled: Bool {
        isEnabled(.groupChallenges)
    }

    static func isEnabled(_ tab: AppTab) -> Bool {
        guard let flag = Flag.allCases.first(where: { $0.appTab == tab }) else {
            return true
        }
        return resolvedValue(for: flag)
    }

    static func debugSummary() -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: Flag.allCases.map { flag in
                (
                    flag.appTab.rawValue,
                    resolvedValue(for: flag) ? "enabled" : "disabled"
                )
            }
        )
    }

    private static func resolvedValue(for flag: Flag) -> Bool {
        let processInfo = ProcessInfo.processInfo
        let arguments = Set(processInfo.arguments)

        if arguments.contains(flag.disableLaunchArgument) {
            return false
        }
        if arguments.contains(flag.launchArgument) {
            return true
        }
        if let environmentOverride = boolOverride(from: processInfo.environment[flag.environmentKey]) {
            return environmentOverride
        }
        return flag.defaultValue
    }

    private static func boolOverride(from rawValue: String?) -> Bool? {
        guard let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            !normalized.isEmpty
        else {
            return nil
        }

        switch normalized {
        case "1", "true", "yes", "on", "enabled":
            return true
        case "0", "false", "no", "off", "disabled":
            return false
        default:
            return nil
        }
    }
}

extension ProcessInfo {
    var isRunningUnderXCTest: Bool {
        environment.keys.contains("XCTestConfigurationFilePath")
            || environment["XCTestSessionIdentifier"] != nil
    }
}
