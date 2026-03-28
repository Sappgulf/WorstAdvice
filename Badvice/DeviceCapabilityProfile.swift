import Foundation
import UIKit

enum DevicePerformanceTier {
    case low
    case medium
    case high
}

struct DeviceCapabilityProfile: Equatable {
    let tier: DevicePerformanceTier
    let thermalState: ProcessInfo.ThermalState
    let physicalMemoryBytes: UInt64
    let processorCount: Int
    let isPad: Bool

    var prefersReducedEffects: Bool {
        switch thermalState {
        case .serious, .critical:
            return true
        default:
            return tier == .low
        }
    }

    var forceLowPowerVisuals: Bool {
        switch thermalState {
        case .serious, .critical:
            return true
        default:
            return tier == .low
        }
    }

    var shouldAvoidOnDeviceLanguageGeneration: Bool {
        switch thermalState {
        case .serious, .critical:
            return true
        default:
            return tier == .low
        }
    }

    private static let lowTierMemoryThreshold: UInt64  = 3_000_000_000  // < 3 GB → low
    private static let midTierMemoryThreshold: UInt64  = 6_000_000_000  // < 6 GB → medium
    private static let lowTierCoreThreshold: Int        = 4              // ≤ 4 cores → low
    private static let midTierCoreThreshold: Int        = 6              // ≤ 6 cores → medium

    static func current(
        processInfo: ProcessInfo = .processInfo,
        device: UIDevice = .current
    ) -> DeviceCapabilityProfile {
        let memory = processInfo.physicalMemory
        let cores = processInfo.processorCount
        let isPad = device.userInterfaceIdiom == .pad

        let tier: DevicePerformanceTier
        if memory < lowTierMemoryThreshold || cores <= lowTierCoreThreshold {
            tier = .low
        } else if memory < midTierMemoryThreshold || cores <= midTierCoreThreshold {
            tier = .medium
        } else {
            tier = .high
        }

        return DeviceCapabilityProfile(
            tier: isPad && tier == .medium ? .high : tier,
            thermalState: processInfo.thermalState,
            physicalMemoryBytes: memory,
            processorCount: cores,
            isPad: isPad
        )
    }
}
