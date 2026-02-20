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

    static func current(
        processInfo: ProcessInfo = .processInfo,
        device: UIDevice = .current
    ) -> DeviceCapabilityProfile {
        let memory = processInfo.physicalMemory
        let cores = processInfo.processorCount
        let isPad = device.userInterfaceIdiom == .pad

        let tier: DevicePerformanceTier
        if memory < 3_000_000_000 || cores <= 4 {
            tier = .low
        } else if memory < 6_000_000_000 || cores <= 6 {
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

