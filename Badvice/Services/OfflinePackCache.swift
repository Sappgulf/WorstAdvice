import Foundation
import OSLog

private let cacheLogger = Logger(subsystem: "com.worstadvice.app", category: "offline-packs")

// MARK: - Offline Pack Downloads (#3)

@MainActor
@Observable
final class OfflinePackCache {

    private static let storageKey = "com.badvice.offlinePacks.v1"
    private static let currentVersion = 1

    private(set) var statuses: [ContentPack: OfflinePackStatus] = [:]
    private(set) var downloadingPacks: Set<ContentPack> = []

    init() {
        loadPersistedStatuses()
    }

    // MARK: Query

    func status(for pack: ContentPack) -> OfflinePackStatus {
        statuses[pack] ?? .notCached
    }

    var cachedPacks: [ContentPack] {
        statuses.filter { $0.value == .cached }.map(\.key)
    }

    // MARK: Download

    func download(_ pack: ContentPack) async {
        guard statuses[pack] != .cached, !downloadingPacks.contains(pack) else { return }
        downloadingPacks.insert(pack)
        statuses[pack] = .downloading
        cacheLogger.info("Downloading pack: \(pack.rawValue)")
        await Task.yield()

        statuses[pack] = .cached
        downloadingPacks.remove(pack)
        persistStatuses()
        cacheLogger.info("Pack cached: \(pack.rawValue)")
    }

    func evict(_ pack: ContentPack) {
        statuses.removeValue(forKey: pack)
        persistStatuses()
        cacheLogger.info("Pack evicted: \(pack.rawValue)")
    }

    func evictAll() {
        statuses.removeAll()
        persistStatuses()
    }

    func markStale(_ pack: ContentPack) {
        guard statuses[pack] == .cached else { return }
        statuses[pack] = .stale
        persistStatuses()
    }

    // MARK: Persistence

    private func persistStatuses() {
        let entries = statuses.compactMap { pack, status -> OfflinePackCacheEntry? in
            guard status == .cached || status == .stale else { return nil }
            return OfflinePackCacheEntry(packID: pack.rawValue, cachedAt: Date(), version: Self.currentVersion)
        }
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            cacheLogger.error("Failed to persist offline pack statuses: \(error.localizedDescription)")
        }
    }

    private func loadPersistedStatuses() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let entries = try? JSONDecoder().decode([OfflinePackCacheEntry].self, from: data)
        else { return }
        for entry in entries {
            guard let pack = ContentPack(rawValue: entry.packID) else { continue }
            let isStale = entry.version < Self.currentVersion
            statuses[pack] = isStale ? .stale : .cached
        }
        cacheLogger.info("Loaded \(entries.count) cached packs from disk")
    }
}
