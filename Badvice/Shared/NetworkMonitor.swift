import Foundation
import Network
import OSLog
import SwiftUI

private let networkLogger = Logger(subsystem: "com.worstadvice.app", category: "network")

// MARK: - Network Monitor

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isOnline: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.worstadvice.network", qos: .utility)

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isOnline != online {
                    networkLogger.info("Network status changed: \(online ? "online" : "offline")")
                    self.isOnline = online
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Offline Banner View

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.weight(.semibold))
            Text("Showing cached results — you're offline")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.2, green: 0.2, blue: 0.22).opacity(0.92))
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityLabel("You are offline. Showing cached results.")
    }
}
