import Foundation
import UIKit
import OSLog

private let referralLogger = Logger(subsystem: "com.worstadvice.app", category: "referral")

// MARK: - Referral Manager (#15)

@MainActor
@Observable
final class ReferralManager {

    private static let storedLinksKey = "com.badvice.referral.links.v1"
    private static let pendingInviteIDsKey = "com.badvice.referral.pendingInviteIDs.v1"
    private static let handledInviteIDsKey = "com.badvice.referral.handledInviteIDs.v1"
    private static let maxPendingInviteIDs = 25
    private static let maxHandledInviteIDs = 24

    private(set) var activeLink: ReferralLink?
    private(set) var pendingInviteID: UUID?
    private(set) var handledInviteIDs: [UUID] = []

    init() {
        loadStoredLink()
        handledInviteIDs = persistedHandledInviteIDs()
        pendingInviteID = persistedPendingInviteIDs().last
    }

    // MARK: Generate

    func generateLink(for handle: String) -> ReferralLink {
        if let existing = activeLink, existing.inviterHandle == handle {
            return existing
        }
        let link = ReferralLink(id: UUID(), inviterHandle: handle, createdAt: Date())
        activeLink = link
        persist(link)
        referralLogger.info("Generated referral link for \(handle)")
        return link
    }

    // MARK: Share

    func share(link: ReferralLink, from viewController: UIViewController? = nil) {
        let items: [Any] = [link.shareText]
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        let presenter = viewController
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        presenter?.present(vc, animated: true)
    }

    // MARK: Handle incoming deep link

    func handleIncomingURL(_ url: URL) {
        guard let deepLink = DeepLink(url: url), deepLink.type == .invite, let id = deepLink.inviteID else {
            return
        }
        if handledInviteIDs.contains(id) {
            referralLogger.info("Ignoring already handled invite id=\(id)")
            return
        }
        enqueuePendingInvite(id)
        referralLogger.info("Received invite from link id=\(id)")
    }

    func inviteID(from url: URL) -> UUID? {
        guard let deepLink = DeepLink(url: url), deepLink.type == .invite else { return nil }
        return deepLink.inviteID
    }

    func consumePendingInviteID() -> UUID? {
        var ids = persistedPendingInviteIDs()
        if ids.isEmpty { return nil }
        let nextID = ids.removeFirst()
        persistPendingInviteIDs(ids)
        pendingInviteID = ids.first
        markInviteHandled(nextID)
        return nextID
    }

    private func persistHandledInviteIDs() {
        do {
            let data = try JSONEncoder().encode(handledInviteIDs)
            UserDefaults.standard.set(data, forKey: Self.handledInviteIDsKey)
        } catch {
            referralLogger.error("Failed to persist handled invite IDs: \(error.localizedDescription)")
        }
    }

    private func persistedHandledInviteIDs() -> [UUID] {
        guard let data = UserDefaults.standard.data(forKey: Self.handledInviteIDsKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data)
        else { return [] }
        return ids
    }

    private func markInviteHandled(_ id: UUID) {
        handledInviteIDs.removeAll { $0 == id }
        handledInviteIDs.append(id)
        if handledInviteIDs.count > Self.maxHandledInviteIDs {
            handledInviteIDs.removeFirst(handledInviteIDs.count - Self.maxHandledInviteIDs)
        }
        persistHandledInviteIDs()
    }

    private func enqueuePendingInvite(_ id: UUID) {
        var ids = persistedPendingInviteIDs()
        ids.removeAll { $0 == id }
        ids.append(id)
        if ids.count > Self.maxPendingInviteIDs {
            ids.removeFirst(ids.count - Self.maxPendingInviteIDs)
        }
        persistPendingInviteIDs(ids)
        pendingInviteID = ids.last
        referralLogger.info("Stored invite queue size=\(ids.count)")
    }

    private func persistedPendingInviteIDs() -> [UUID] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingInviteIDsKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data)
        else { return [] }
        return ids
    }

    private func persistPendingInviteIDs(_ ids: [UUID]) {
        if ids.isEmpty {
            UserDefaults.standard.removeObject(forKey: Self.pendingInviteIDsKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(ids)
            UserDefaults.standard.set(data, forKey: Self.pendingInviteIDsKey)
        } catch {
            referralLogger.error("Failed to persist pending invite IDs: \(error.localizedDescription)")
        }
    }

    func clearPendingInvites() {
        pendingInviteID = nil
        persistPendingInviteIDs([])
    }

    func clearPendingInvite(id: UUID) {
        var ids = persistedPendingInviteIDs()
        ids.removeAll { $0 == id }
        persistPendingInviteIDs(ids)
        pendingInviteID = ids.first
    }

    // MARK: Persistence

    @discardableResult
    func consumePendingInvite() -> UUID? {
        consumePendingInviteID()
    }

    private func persist(_ link: ReferralLink) {
        do {
            let data = try JSONEncoder().encode(link)
            UserDefaults.standard.set(data, forKey: Self.storedLinksKey)
        } catch {
            referralLogger.error("Failed to encode ReferralLink for persistence: \(error.localizedDescription)")
        }
    }

    func loadStoredLink() {
        guard let data = UserDefaults.standard.data(forKey: Self.storedLinksKey),
              let link = try? JSONDecoder().decode(ReferralLink.self, from: data)
        else { return }
        activeLink = link
    }
}
