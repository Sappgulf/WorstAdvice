import Foundation
import UIKit
import OSLog

private let referralLogger = Logger(subsystem: "com.worstadvice.app", category: "referral")

// MARK: - Referral Manager (#15)

@MainActor
@Observable
final class ReferralManager {

    private static let storedLinksKey = "com.badvice.referral.links.v1"

    private(set) var activeLink: ReferralLink?
    private(set) var pendingInviteID: UUID?

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
        guard url.scheme == "badvice", url.host == "invite",
              let uuidString = url.pathComponents.dropFirst().first,
              let id = UUID(uuidString: uuidString)
        else { return }
        pendingInviteID = id
        referralLogger.info("Received invite from link id=\(id)")
    }

    func clearPendingInvite() {
        pendingInviteID = nil
    }

    // MARK: Persistence

    private func persist(_ link: ReferralLink) {
        guard let data = try? JSONEncoder().encode(link) else { return }
        UserDefaults.standard.set(data, forKey: Self.storedLinksKey)
    }

    func loadStoredLink() {
        guard let data = UserDefaults.standard.data(forKey: Self.storedLinksKey),
              let link = try? JSONDecoder().decode(ReferralLink.self, from: data)
        else { return }
        activeLink = link
    }
}
