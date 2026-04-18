import SwiftUI

struct FriendsTabView: View {

    @Bindable var social: SocialViewModel
    @Bindable var settings: SettingsViewModel
    var onOpenTab: ((AppTab) -> Void)? = nil

    @State private var selectedSection: FriendsSection = .friends
    @State private var handleSearchText: String = ""
    @State private var activeToast: ToastMessage? = nil
    @State private var showingProfileSetup = false

    @State private var showCollabComposer = false
    @State private var collabComposerType: SocialPostType = .advice
    @State private var collabComposerText: String = ""
    @State private var selectedContributorIDs: Set<String> = []

    @State private var showCollabEditor = false
    @State private var collabEditorText: String = ""
    @State private var collabEditorVersion: Int64 = 0
    @State private var collabEditorType: SocialPostType = .advice
    @State private var collabEditorContributors: [SocialUser] = []

    @Environment(\.tabBarVisible) private var tabBarVisible

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var buttonText: Color { Theme.buttonText(for: settings.theme) }
    private var bg: LinearGradient { Theme.backgroundGradient(for: settings.theme) }
    private var friendsStatusMetricTitle: String {
        if !social.incomingRequests.isEmpty {
            return "Requests"
        }
        if !social.outgoingRequests.isEmpty {
            return "Pending"
        }
        return "Feed"
    }
    private var friendsStatusMetricValue: String {
        if !social.incomingRequests.isEmpty {
            return "\(social.incomingRequests.count)"
        }
        if !social.outgoingRequests.isEmpty {
            return "\(social.outgoingRequests.count)"
        }
        return social.feedPosts.isEmpty ? "Quiet" : "Live"
    }
    private var normalizedHandleSearchText: String {
        let trimmed = handleSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefixAt = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        return SocialViewModel.normalizedHandle(withoutPrefixAt)
    }
    private var canSearchForFriends: Bool {
        social.socialFeaturesEnabled && !normalizedHandleSearchText.isEmpty
    }
    private var friendsSetupTitle: String {
        switch social.friendsLoadState {
        case .idle, .checkingCloudKit, .bootstrappingProfile, .loadingFriends:
            return "Finishing Friends setup"
        case .failed:
            return "Repair Friends connection"
        case .needsProfileSetup:
            return "Create your Friends profile"
        case .empty:
            return "Add your first friend"
        case .ready:
            if social.currentUser == nil {
                return "Create your Friends profile"
            }
            if !social.incomingRequests.isEmpty {
                return "Review incoming requests"
            }
            if !social.outgoingRequests.isEmpty && social.friends.isEmpty {
                return "Track sent requests"
            }
            if social.friends.isEmpty {
                return "Add your first friend"
            }
            if social.feedPosts.isEmpty {
                return "Share your first post"
            }
            if social.collabDocs.isEmpty {
                return "Start your first collab"
            }
            return "Keep your social loop moving"
        }
    }
    private var friendsSetupDetail: String {
        switch social.friendsLoadState {
        case .idle:
            return "Connecting to iCloud so handles, requests, and drafts can load."
        case .checkingCloudKit:
            return "CloudKit is being verified before the social graph comes online."
        case .bootstrappingProfile:
            return "Your account is almost ready. Friends needs a profile before the rest can load."
        case .loadingFriends:
            return "Requests, friends, and collaboration data are being fetched now."
        case .failed(let message):
            return message
        case .needsProfileSetup:
            return "Set a public handle so people can find you, send requests, and start collabs."
        case .empty:
            return "Friends is online. Share your handle or search for someone to start the network."
        case .ready:
            if social.currentUser == nil {
                return "Create your profile first. That unlocks search, requests, feed posts, and collabs."
            }
            if !social.incomingRequests.isEmpty {
                return "People are waiting on you. Accept or decline requests so the network can actually start."
            }
            if !social.outgoingRequests.isEmpty && social.friends.isEmpty {
                return "Your first requests are out. Track them here or search for another friend so the tab does not stall."
            }
            if social.friends.isEmpty {
                return "You have a profile. Next step is sending or accepting a request so the social loop can start."
            }
            if social.feedPosts.isEmpty {
                return "Your network exists, but the feed is quiet. Share from Generate or Quotes to make Friends feel alive."
            }
            if social.collabDocs.isEmpty {
                return "Friends are connected. Start a shared draft to turn the tab into something collaborative."
            }
            return "Requests, posts, and collabs are all live. Keep the loop active from Generate, Quotes, and Friends."
        }
    }
    private var friendsPrimaryActionTitle: String {
        switch social.friendsLoadState {
        case .idle, .checkingCloudKit, .bootstrappingProfile, .loadingFriends:
            return "Refresh"
        case .failed:
            return "Retry"
        case .needsProfileSetup:
            return "Open Setup"
        case .empty:
            return "Find Friends"
        case .ready:
            if social.currentUser == nil {
                return "Open Setup"
            }
            if social.friends.isEmpty {
                return "Find Friends"
            }
            if social.feedPosts.isEmpty {
                return "Open Generate"
            }
            if social.collabDocs.isEmpty {
                return "Open Collab"
            }
            return "Refresh Social"
        }
    }
    private var friendsPrimaryActionIdentifier: String {
        friendsPrimaryActionTitle == "Open Setup" ? "friends.openSetup" : "friends.command.primary"
    }
    private var friendsPrimaryActionHint: String {
        switch social.friendsLoadState {
        case .idle, .checkingCloudKit, .bootstrappingProfile, .loadingFriends, .failed:
            return "Friend network is warming up. Retry once state stabilizes."
        case .needsProfileSetup:
            return "Create your Friends profile before requesting or sharing anything."
        case .empty:
            return "Search a handle or accept an incoming request to unlock the social loop."
        case .ready:
            if social.currentUser == nil {
                return "Finish profile setup first, then add your first friend."
            }
            if social.friends.isEmpty {
                return "Use the Friends section to find and add your first friend."
            }
            if social.feedPosts.isEmpty {
                return "Open Generate, create one post, and share it to wake feed activity."
            }
            if social.collabDocs.isEmpty {
                return "Open Collab and start a shared draft once sharing is active."
            }
            return "Refresh socials to fetch the newest request, feed, and collab updates."
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 12) {
                    friendsHeader
                    friendsCommandCard
                    friendsSetupFunnelCard
                    friendsStateBanner

                    sectionPicker
                    switch selectedSection {
                    case .friends:
                        friendsSection
                    case .feed:
                        feedSection
                    case .collab:
                        collabSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .trackScrollForTabBar()
        }
        .accessibilityIdentifier("friends.root")
        .accessibilityElement(children: .contain)
        .preferredColorScheme(Theme.colorScheme(for: settings.theme))
        .onAppear {
            tabBarVisible.wrappedValue = true
            #if DEBUG
                NSLog("FriendsTabView appeared")
            #endif
        }
        .onChange(of: social.statusMessage) { _, message in
            guard let message, !message.isEmpty else { return }
            activeToast = ToastMessage(
                message: message,
                style: message.lowercased().contains("error")
                    || message.lowercased().contains("failed")
                    || message.lowercased().contains("cannot")
                    ? .error : .success
            )
        }
        .onChange(of: social.pendingCollabDraft?.id) { _, newID in
            guard newID != nil, let draft = social.pendingCollabDraft else { return }
            collabComposerType = draft.type
            collabComposerText = draft.content
            selectedContributorIDs.removeAll()
            openFriendsSection(.collab, animated: false)
            showCollabComposer = true
        }
        .sheet(isPresented: $showCollabComposer, onDismiss: {
            selectedContributorIDs.removeAll()
        }) {
            collabComposerSheet
        }
        .sheet(isPresented: $showCollabEditor) {
            collabEditorSheet
        }
        .sheet(isPresented: $showingProfileSetup) {
            SocialProfileSetupView(social: social)
        }
        .toast(item: $activeToast, accentColor: accent)
    }

    private var friendsCommandCard: some View {
        TabCommandCard(
            eyebrow: "Friends Command",
            title: friendsSetupTitle,
            detail: friendsSetupDetail,
            systemImage: "person.2.fill",
            accent: accent,
            primaryText: primaryText,
            secondaryText: secondaryText,
            cardColor: cardColor
        ) {
            HStack(spacing: 8) {
                TabCommandMetric(title: "Profile", value: social.currentUser == nil ? "Missing" : "Ready", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
                TabCommandMetric(title: "Friends", value: "\(social.friends.count)", accent: accent, primaryText: primaryText, secondaryText: secondaryText)
                TabCommandMetric(title: friendsStatusMetricTitle, value: friendsStatusMetricValue, accent: accent, primaryText: primaryText, secondaryText: secondaryText)
            }
        } actions: {
            VStack(spacing: 10) {
                Button(friendsPrimaryActionTitle) {
                    performPrimaryFriendsAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .foregroundStyle(buttonText)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .accessibilityIdentifier(friendsPrimaryActionIdentifier)
                Text(friendsPrimaryActionHint)
                    .font(.caption2)
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button("Open Feed") {
                        openFriendsSection(.feed)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .accessibilityIdentifier("friends.command.feed")

                    Button("Open Collab") {
                        openFriendsSection(.collab)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .accessibilityIdentifier("friends.command.collab")
                }
            }
        }
    }

    @ViewBuilder
    private var friendsHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.9),
                                accent.opacity(0.5),
                                cardColor.opacity(0.95),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(buttonText)
            }
            .frame(width: 54, height: 54)
            .shadow(color: accent.opacity(0.22), radius: 10, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Friends")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(primaryText)
                        .accessibilityIdentifier("friends.title")

                    Text("Profile, first friend, first share, first collab. This tab now guides that loop.")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }

                HStack(spacing: 8) {
                    socialStatPill(title: "Live", value: social.socialFeaturesEnabled ? "On" : "Off", systemImage: "dot.radiowaves.left.and.right")
                    socialStatPill(title: "Requests", value: "\(social.incomingRequests.count)", systemImage: "tray.full.fill")
                    socialStatPill(title: "Drafts", value: "\(social.collabDocs.count)", systemImage: "doc.text.fill")
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 5)
    }

    private var friendsSetupFunnelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup Funnel")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text("Each step unlocks the next one so the tab feels guided instead of fully loaded on day one.")
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(friendsSetupStageBadge)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.opacity(0.12))
                    )
            }

            VStack(spacing: 9) {
                setupStepRow(
                    title: "Create profile",
                    detail: "Claim your handle and make yourself discoverable.",
                    state: social.currentUser != nil ? .done : .now
                )
                setupStepRow(
                    title: "Add first friend",
                    detail: "Search a handle or accept an incoming request.",
                    state: social.friends.isEmpty ? (social.currentUser != nil ? .now : .next) : .done
                )
                setupStepRow(
                    title: "Share first post",
                    detail: "Use Generate or Quotes to wake up the feed.",
                    state: social.feedPosts.isEmpty ? (!social.friends.isEmpty ? .now : .next) : .done
                )
                setupStepRow(
                    title: "Start first collab",
                    detail: "Turn the first connection into a shared draft.",
                    state: social.collabDocs.isEmpty ? (!social.feedPosts.isEmpty ? .now : .next) : .done
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(cardColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.1), lineWidth: 1)
                )
        )
        .accessibilityIdentifier("friends.setupFunnel")
    }

    @ViewBuilder
    private var friendsStateBanner: some View {
        switch social.friendsLoadState {
        case .idle:
            stateProgressCard(
                title: "Setting up Friends",
                message: "Connecting to iCloud…"
            )
        case .ready:
            EmptyView()
        case .checkingCloudKit:
            stateProgressCard(
                title: "Checking CloudKit",
                message: "Verifying your iCloud account and Friends profile."
            )
        case .bootstrappingProfile:
            stateProgressCard(
                title: "Creating profile",
                message: "Finishing Friends setup before loading requests and contacts."
            )
        case .loadingFriends:
            stateProgressCard(
                title: "Loading Friends",
                message: "Fetching your requests, contacts, and diagnostics."
            )
        case .needsProfileSetup:
            QuotesInlineBanner(
                text: "Finish your Friends profile to search handles, accept requests, and unlock the feed.",
                accent: accent,
                secondaryText: secondaryText,
                cardColor: cardColor
            )
        case .empty:
            QuotesInlineBanner(
                text: "Friends is ready. Share your handle or send a request to get started.",
                accent: accent,
                secondaryText: secondaryText,
                cardColor: cardColor
            )
        case .failed(let message):
            socialCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Friends Unavailable", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(primaryText)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                    VStack(spacing: 8) {
                        Button("Retry") {
                            Task { await social.retryFriendsLoad() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .foregroundStyle(buttonText)
                        .accessibilityIdentifier("friends.retryLoad")
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)

                            if social.needsProfileSetup {
                                Button("Open Setup") {
                                    openFriendsSetupFlow()
                                }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("friends.openSetup.banner")
                            .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                        }
                    }
                    #if DEBUG
                        SocialCloudKitDiagnosticsView(
                            social: social,
                            retryTitle: "Retry",
                            retryAction: {
                                Task { await social.retryFriendsLoad() }
                            }
                        )
                    #endif
                }
            }
        }
    }

    private var friendsSetupStageBadge: String {
        if social.currentUser == nil {
            return "Profile First"
        }
        if social.friends.isEmpty {
            return "Find Friend"
        }
        if social.feedPosts.isEmpty {
            return "First Share"
        }
        if social.collabDocs.isEmpty {
            return "First Collab"
        }
        return "Loop Active"
    }

    private func setupStepRow(title: String, detail: String, state: SetupStepState) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: state.iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(state.tint(accent: accent))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(primaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(state.label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(state.tint(accent: accent))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(state.tint(accent: accent).opacity(0.12))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.shellInnerCornerRadius, style: .continuous)
                .fill(secondaryText.opacity(0.08))
        )
    }

    private enum SetupStepState {
        case done
        case now
        case next

        var label: String {
            switch self {
            case .done: return "Done"
            case .now: return "Now"
            case .next: return "Next"
            }
        }

        var iconName: String {
            switch self {
            case .done: return "checkmark.circle.fill"
            case .now: return "arrow.right.circle.fill"
            case .next: return "circle"
            }
        }

        func tint(accent: Color) -> Color {
            switch self {
            case .done: return .green
            case .now: return accent
            case .next: return .secondary
            }
        }
    }

    private func stateProgressCard(title: String, message: String) -> some View {
        socialCard {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                }
                Spacer()
            }
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(FriendsSection.allCases) { section in
                Button {
                    openFriendsSection(section, animated: false)
                } label: {
                    VStack(spacing: 3) {
                        Text(section.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .foregroundStyle(selectedSection == section ? buttonText : secondaryText)
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectedSection == section ? accent : cardColor.opacity(0.55))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                selectedSection == section
                                    ? accent.opacity(0.55)
                                    : .white.opacity(0.08),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("friends.section.\(section.rawValue.lowercased())")
                .accessibilityLabel(section.rawValue)
                .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("friends.sectionPicker")
        .accessibilityLabel("Friends sections")
        .accessibilityValue(selectedSection.rawValue)
    }

    private var friendsSection: some View {
        VStack(spacing: 12) {
            if social.needsProfileSetup {
                socialCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Set up your Friends profile", systemImage: "person.crop.circle.badge.plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(primaryText)
                        Text("Handles are public and searchable. Create yours here without blocking the rest of Badvice.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                        VStack(spacing: 8) {
                            Button("Open Setup") {
                                openFriendsSetupFlow()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(buttonText)
                            .accessibilityIdentifier("friends.openSetup.section")
                            .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)

                            Button("Retry CloudKit") {
                                Task { await social.retryFriendsLoad() }
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("friends.retryCloudKit")
                            .frame(maxWidth: .infinity, minHeight: Theme.minimumTapTarget)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }

            if let currentUser = social.currentUser {
                socialCard {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentUser.displayName)
                                .font(.headline)
                                .foregroundStyle(primaryText)
                            Text("@\(currentUser.handle)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(accent)
                            Text("Joined \(memberSinceText(currentUser.createdAt)). Share your handle, add friends, then start posting from Generate or Quotes.")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                        }

                        HStack(spacing: 8) {
                            socialStatPill(
                                title: "Friends",
                                value: "\(social.friends.count)",
                                systemImage: "person.2.fill"
                            )
                            socialStatPill(
                                title: "Requests",
                                value: "\(social.incomingRequests.count + social.outgoingRequests.count)",
                                systemImage: "tray.full.fill"
                            )
                            socialStatPill(
                                title: "Collabs",
                                value: "\(social.collabDocs.count)",
                                systemImage: "doc.text.fill"
                            )
                        }

                        HStack(spacing: 8) {
                            Button("Open Generate") {
                                onOpenTab?(.generate)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(buttonText)

                            Button("Browse Quotes") {
                                onOpenTab?(.quotes)
                            }
                            .buttonStyle(.bordered)

                            Button("Copy My Handle") {
                                UIPasteboard.general.string = "@\(currentUser.handle)"
                                activeToast = ToastMessage(
                                    message: "Copied @\(currentUser.handle)",
                                    style: .success
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .accessibilityIdentifier("friends.overviewCard")
                }
            }

            socialCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Find friends by handle", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Text("Search with or without @. Once you connect, feed posts and shared drafts start showing up here.")
                        .font(.caption)
                        .foregroundStyle(secondaryText)

                    HStack(spacing: 8) {
                        TextField("@handle", text: $handleSearchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(cardColor)
                            )
                            .accessibilityIdentifier("friends.searchField")
                            .onSubmit {
                                guard canSearchForFriends else { return }
                                Task {
                                    await social.searchUserByHandle(normalizedHandleSearchText)
                                }
                            }

                        Button {
                            Task {
                                await social.searchUserByHandle(normalizedHandleSearchText)
                            }
                        } label: {
                            Text("Find")
                                .font(.caption.weight(.bold))
                                .frame(minWidth: 70, minHeight: 42)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .foregroundStyle(buttonText)
                        .disabled(!canSearchForFriends)
                        .accessibilityIdentifier("friends.searchButton")
                    }

                    if let result = social.latestSearchResult {
                        let relationshipState = relationshipState(for: result)
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(primaryText)
                                Text("@\(result.handle)")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                Text(relationshipState.detailText)
                                    .font(.caption2)
                                    .foregroundStyle(secondaryText)
                            }
                            Spacer(minLength: 8)
                            Button {
                                guard relationshipState.isActionEnabled else { return }
                                Task { await social.sendFriendRequest(to: result) }
                            } label: {
                                Text(relationshipState.buttonTitle)
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Capsule(style: .continuous).fill(accent))
                                    .foregroundStyle(buttonText)
                            }
                            .buttonStyle(.plain)
                            .disabled(!relationshipState.isActionEnabled || !social.socialFeaturesEnabled)
                            .accessibilityIdentifier("friends.addButton")
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(secondaryText.opacity(0.08))
                        )
                        .accessibilityIdentifier("friends.searchResult")
                    } else if social.statusMessage == "No user found for @\(social.latestSearchHandle)" {
                        Text("No match for @\(social.latestSearchHandle) yet. Check the spelling or ask them to finish Friends setup first.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                            .accessibilityIdentifier("friends.searchEmpty")
                    }
                }
            }

            socialCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Incoming Requests", systemImage: "tray.and.arrow.down.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)

                    if social.incomingRequests.isEmpty {
                        Text("No incoming requests.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    } else {
                        ForEach(social.incomingRequests) { request in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(request.fromUser?.displayName ?? "@unknown")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(primaryText)
                                    Text("@\(request.fromUser?.handle ?? "unknown")")
                                        .font(.caption2)
                                        .foregroundStyle(secondaryText)
                                }
                                Spacer(minLength: 8)
                                Button("Accept") {
                                    Task { await social.acceptRequest(request) }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(accent)
                                .font(.caption.weight(.semibold))
                                .disabled(!social.socialFeaturesEnabled)

                                Button("Decline") {
                                    Task { await social.declineRequest(request) }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption.weight(.semibold))
                                .disabled(!social.socialFeaturesEnabled)
                            }
                        }
                    }
                }
            }

            socialCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Sent Requests", systemImage: "paperplane.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)

                    if social.outgoingRequests.isEmpty {
                        Text("No pending invites. Send one above to get your network started.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    } else {
                        ForEach(social.outgoingRequests) { request in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.toUser?.displayName ?? "@unknown")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(primaryText)
                                Text("@\(request.toUser?.handle ?? "unknown")")
                                    .font(.caption2)
                                    .foregroundStyle(secondaryText)
                            }
                        }
                    }
                }
                .accessibilityIdentifier("friends.outgoingCard")
            }

            socialCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Friends", systemImage: "person.2.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)

                    if social.friends.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No friends yet. Invite a friend by sharing your handle, then search for theirs above.")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            if let currentUser = social.currentUser {
                                Button("Copy @\(currentUser.handle)") {
                                    UIPasteboard.general.string = "@\(currentUser.handle)"
                                    activeToast = ToastMessage(
                                        message: "Copied @\(currentUser.handle)",
                                        style: .success
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(accent)
                                .foregroundStyle(buttonText)
                                .font(.caption.weight(.semibold))
                            }
                        }
                    } else {
                        ForEach(social.friends, id: \.id) { friend in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(primaryText)
                                    Text("@\(friend.handle)")
                                        .font(.caption2)
                                        .foregroundStyle(secondaryText)
                                }
                                Spacer(minLength: 8)
                                Button("Block") {
                                    Task { await social.block(friend) }
                                }
                                .buttonStyle(.bordered)
                                .font(.caption.weight(.semibold))
                                .tint(.red)
                                .disabled(!social.socialFeaturesEnabled)

                                Button("Report") {
                                    social.report(user: friend)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }

            socialCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Blocked", systemImage: "hand.raised.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    if social.blockedUsers.isEmpty {
                        Text("No blocked users.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    } else {
                        ForEach(social.blockedUsers, id: \.id) { blocked in
                            Text("@\(blocked.handle)")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var feedSection: some View {
        VStack(spacing: 12) {
            socialCard {
                HStack {
                    Label("Friends Feed", systemImage: "person.3.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Spacer()
                    Button {
                        Task { await social.refreshSocialData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!social.socialFeaturesEnabled)
                    .accessibilityIdentifier("friends.feedRefresh")
                }
            }

            if social.feedPosts.isEmpty {
                socialCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(
                            social.friends.isEmpty
                                ? "Add friends first, then share from Generate or Quotes to wake up the feed."
                                : "Nobody has posted yet. Be first and break the silence."
                        )
                        .font(.caption)
                        .foregroundStyle(secondaryText)

                        VStack(spacing: 8) {
                            Button("Open Friends") {
                                onOpenTab?(.friends)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(buttonText)
                            .frame(maxWidth: .infinity, minHeight: 42)

                            HStack(spacing: 8) {
                                Button("Open Generate") {
                                    onOpenTab?(.generate)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .accessibilityIdentifier("friends.feed.openGenerate")

                                Button("Open Quotes") {
                                    onOpenTab?(.quotes)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .accessibilityIdentifier("friends.feed.openQuotes")
                            }

                            Button("Refresh Social") {
                                Task { await social.refreshSocialData() }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .disabled(!social.socialFeaturesEnabled)
                            .accessibilityIdentifier("friends.feed.refresh")
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .accessibilityIdentifier("friends.feed.empty")
                }
            } else {
                ForEach(social.feedPosts) { post in
                    socialCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(post.author?.displayName ?? "@unknown")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(primaryText)
                                Text("•")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(secondaryText)
                                Text(relativeTimestamp(post.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(secondaryText)
                                Spacer(minLength: 0)
                                Text(post.type.rawValue.capitalized)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule(style: .continuous).fill(accent.opacity(0.14)))
                            }
                            Text(post.text)
                                .font(.subheadline)
                                .foregroundStyle(primaryText)
                                .fixedSize(horizontal: false, vertical: true)

                            // #1 Feed Reactions
                            FeedReactionBar(postID: post.id, social: social)

                            HStack(spacing: 8) {
                                Button("Report") {
                                    social.report(post: post)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption.weight(.semibold))

                                if let author = post.author {
                                    Button("Block User") {
                                        Task { await social.block(author) }
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption.weight(.semibold))
                                    .tint(.red)
                                    .disabled(!social.socialFeaturesEnabled)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var collabSection: some View {
        VStack(spacing: 12) {
            socialCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Shared Drafts", systemImage: "doc.text.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(primaryText)

                    if let draft = social.pendingCollabDraft {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Draft ready from \(draft.type.rawValue).")
                                .font(.caption)
                                .foregroundStyle(secondaryText)
                            Text(draft.content)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(primaryText)
                            Button("Create Collaboration") {
                                collabComposerType = draft.type
                                collabComposerText = draft.content
                                showCollabComposer = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(buttonText)
                            .font(.caption.weight(.semibold))
                            .disabled(!social.socialFeaturesEnabled)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(secondaryText.opacity(0.08))
                        )
                    }

                    Button("New Blank Doc") {
                        collabComposerType = .advice
                        collabComposerText = ""
                        selectedContributorIDs.removeAll()
                        showCollabComposer = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.weight(.semibold))
                    .disabled(!social.socialFeaturesEnabled)
                    .accessibilityIdentifier("friends.newCollabDoc")
                }
            }

            if social.collabDocs.isEmpty {
                socialCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(
                            social.friends.isEmpty
                                ? "Add friends first, then invite them into a draft from Generate, Quotes, or a blank doc."
                                : "No collaboration docs yet. Start a blank draft here or send one over from Generate or Quotes."
                        )
                        .font(.caption)
                        .foregroundStyle(secondaryText)

                        VStack(spacing: 8) {
                            Button("Open Friends") {
                                onOpenTab?(.friends)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(accent)
                            .foregroundStyle(buttonText)
                            .frame(maxWidth: .infinity, minHeight: 42)

                            HStack(spacing: 8) {
                                Button("Open Generate") {
                                    onOpenTab?(.generate)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .accessibilityIdentifier("friends.collab.openGenerate")

                                Button("Open Quotes") {
                                    onOpenTab?(.quotes)
                                }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .accessibilityIdentifier("friends.collab.openQuotes")
                            }

                            Button("Refresh Social") {
                                Task { await social.refreshSocialData() }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .disabled(!social.socialFeaturesEnabled)
                            .accessibilityIdentifier("friends.collab.refresh")
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .accessibilityIdentifier("friends.collab.empty")
                }
            } else {
                ForEach(social.collabDocs) { doc in
                    Button {
                        Task {
                            await social.openCollabDoc(doc)
                            if let active = social.activeCollabDoc {
                                collabEditorText = active.content
                                collabEditorVersion = active.version
                                collabEditorType = active.type
                                collabEditorContributors = active.contributors
                                showCollabEditor = true
                            }
                        }
                    } label: {
                        socialCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(doc.type.rawValue.capitalized)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(accent)
                                    Text("v\(doc.version)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(secondaryText)
                                    Spacer()
                                    Text(relativeTimestamp(doc.updatedAt))
                                        .font(.caption2)
                                        .foregroundStyle(secondaryText)
                                }
                                Text(doc.content)
                                    .font(.subheadline)
                                    .foregroundStyle(primaryText)
                                    .lineLimit(3)
                                Text(
                                    "Owner: \(doc.owner?.displayName ?? "@unknown") • Contributors: \(doc.contributors.count)"
                                )
                                .font(.caption2)
                                .foregroundStyle(secondaryText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!social.socialFeaturesEnabled)
                }
            }
        }
    }

    private var collabComposerSheet: some View {
        NavigationStack {
            Form {
                Section("Draft") {
                    Picker("Type", selection: $collabComposerType) {
                        Text("Advice").tag(SocialPostType.advice)
                        Text("Quote").tag(SocialPostType.quote)
                    }
                    TextEditor(text: $collabComposerText)
                        .frame(minHeight: 140)
                }

                Section("Contributors") {
                    if social.friends.isEmpty {
                        Text("Add friends to invite contributors.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(social.friends, id: \.id) { friend in
                            Toggle(
                                friend.displayName,
                                isOn: Binding(
                                    get: { selectedContributorIDs.contains(friend.id) },
                                    set: { isOn in
                                        if isOn {
                                            selectedContributorIDs.insert(friend.id)
                                        } else {
                                            selectedContributorIDs.remove(friend.id)
                                        }
                                    }
                                )
                            )
                        }
                    }
                }
            }
            .navigationTitle("Collaborate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showCollabComposer = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let contributors = social.friends.filter {
                            selectedContributorIDs.contains($0.id)
                        }
                        Task {
                            if await social.createCollabDoc(
                                type: collabComposerType,
                                content: collabComposerText,
                                contributors: contributors
                            ) != nil {
                                showCollabComposer = false
                                selectedContributorIDs.removeAll()
                            }
                        }
                    }
                    .disabled(collabComposerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var collabEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    Text("Version \(collabEditorVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $collabEditorText)
                        .frame(minHeight: 180)
                }
                if let conflictMessage = social.collabConflictMessage {
                    Section {
                        Text(conflictMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Edit Collaboration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        showCollabEditor = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let active = social.activeCollabDoc else { return }
                        Task {
                            if let updated = await social.createCollabDoc(
                                docID: active.id,
                                type: collabEditorType,
                                content: collabEditorText,
                                contributors: collabEditorContributors,
                                expectedVersion: collabEditorVersion
                            ) {
                                collabEditorVersion = updated.version
                                collabEditorText = updated.content
                                showCollabEditor = false
                            } else if let latest = social.activeCollabDoc {
                                collabEditorVersion = latest.version
                                collabEditorText = latest.content
                            }
                        }
                    }
                }
            }
        }
    }

    private func socialCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.09),
                                        .clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 5)
    }

    private func performPrimaryFriendsAction() {
        switch social.friendsLoadState {
        case .idle, .checkingCloudKit, .bootstrappingProfile, .loadingFriends, .failed:
            Task { await social.retryFriendsLoad() }
        case .needsProfileSetup:
            openFriendsSetupFlow()
        case .empty:
            openFriendsSection(.friends, animated: false)
            activeToast = ToastMessage(
                message: "Open this section to search a handle, then send a request.",
                style: .info
            )
        case .ready:
            if social.currentUser == nil {
                openFriendsSetupFlow()
            } else if social.friends.isEmpty {
                openFriendsSection(.friends, animated: false)
                activeToast = ToastMessage(
                    message: "Add your first friend by searching a handle or accepting a request.",
                    style: .info
                )
            } else if social.feedPosts.isEmpty {
                onOpenTab?(.generate)
            } else if social.collabDocs.isEmpty {
                openFriendsSection(.collab)
            } else {
                Task { await social.refreshSocialData() }
            }
        }
    }

    private func openFriendsSetupFlow() {
        showingProfileSetup = true
    }

    private func openFriendsSection(_ section: FriendsSection, animated: Bool = true) {
        guard animated else {
            selectedSection = section
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            selectedSection = section
        }
    }

    private func relationshipState(for user: SocialUser) -> FriendSearchRelationshipState {
        if user.id == social.currentUser?.id {
            return .currentUser
        }
        if social.friends.contains(where: { $0.id == user.id }) {
            return .existingFriend
        }
        if social.incomingRequests.contains(where: { $0.fromUserID == user.recordID }) {
            return .incomingRequest
        }
        if social.outgoingRequests.contains(where: { $0.toUserID == user.recordID }) {
            return .outgoingRequest
        }
        if social.blockedUsers.contains(where: { $0.id == user.id }) {
            return .blocked
        }
        return .addable
    }

    private func socialStatPill(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(secondaryText.opacity(0.08))
        )
    }

    private func socialCommandMetric(title: String, value: String, accenting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(accenting ? accent : primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(accenting ? 0.14 : 0.08))
        )
    }

    private func memberSinceText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
