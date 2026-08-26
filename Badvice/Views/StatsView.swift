import Observation
import SwiftUI
import UIKit

// MARK: - New product shell

/// A compact editorial header shared by the redesigned tabs.
private struct BureauTabHeader: View {
    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    let theme: ThemeMode

    private var accent: Color { Theme.accent(for: theme) }
    private var primaryText: Color { Theme.primaryText(for: theme) }
    private var secondaryText: Color { Theme.secondaryText(for: theme) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(1.5)
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(primaryText)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Theme.espressoInk)
                .frame(width: 48, height: 48)
                .background(Theme.copperEmbossGradient, in: Circle())
                .shadow(color: Theme.copperFoilDeep.opacity(0.28), radius: 9, y: 4)
                .accessibilityHidden(true)
        }
    }
}

private struct BureauPanel<Content: View>: View {
    let theme: ThemeMode
    var emphasized = false
    @ViewBuilder let content: () -> Content

    private var accent: Color { Theme.accent(for: theme) }
    private var cardColor: Color { Theme.cardColor(for: theme) }

    var body: some View {
        content()
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(cardColor.opacity(0.9))
                    .overlay {
                        LinearGradient(
                            colors: [
                                accent.opacity(emphasized ? 0.15 : 0.07),
                                .clear,
                                Color.black.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accent.opacity(emphasized ? 0.34 : 0.14), lineWidth: 1)
            }
            .shadow(color: Theme.cardShadow(for: theme).color.opacity(0.16), radius: 12, y: 6)
    }
}

private struct BureauTag: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(accent.opacity(0.11), in: Capsule(style: .continuous))
    }
}

@MainActor
@Observable
private final class CasebookOrganizer {
    struct Metadata: Codable, Equatable {
        var folder: String?
        var tags: [String]

        static let empty = Metadata(folder: nil, tags: [])
    }

    private static let storageKey = "com.worstadvice.casebook.metadata.v1"
    private let defaults: UserDefaults
    private(set) var metadataByRecordID: [String: Metadata]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: Metadata].self, from: data) {
            metadataByRecordID = decoded
        } else {
            metadataByRecordID = [:]
        }
    }

    func metadata(for recordID: UUID) -> Metadata {
        metadataByRecordID[recordID.uuidString] ?? .empty
    }

    func save(recordID: UUID, folder: String?, tags: [String]) {
        let normalizedFolder = folder?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(32)
        let normalizedTags = Array(
            Set(
                tags
                    .map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            .lowercased()
                    }
                    .filter { !$0.isEmpty }
                    .map { String($0.prefix(18)) }
            )
        )
        .sorted()
        let folderValue = normalizedFolder.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
        if folderValue == nil, normalizedTags.isEmpty {
            metadataByRecordID.removeValue(forKey: recordID.uuidString)
        } else {
            metadataByRecordID[recordID.uuidString] = Metadata(
                folder: folderValue,
                tags: Array(normalizedTags.prefix(6))
            )
        }
        persist()
    }

    func remove(recordID: UUID) {
        metadataByRecordID.removeValue(forKey: recordID.uuidString)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(metadataByRecordID) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

// MARK: - Casebook

struct CasebookTabView: View {
    enum Shelf: String, CaseIterable, Identifiable {
        case saved
        case recent

        var id: String { rawValue }
        var title: String { self == .saved ? "Saved" : "Recent" }
    }

    @Bindable var favorites: FavoritesViewModel
    @Bindable var history: HistoryViewModel
    @Bindable var settings: SettingsViewModel

    let initialShelf: Shelf
    var onUseRecord: (AdviceRecord) -> Void
    var onDataChanged: () -> Void
    var onJumpToGenerate: () -> Void

    @Environment(\.tabBarVisible) private var tabBarVisible
    @State private var shelf: Shelf
    @State private var activeToast: ToastMessage?
    @State private var organizer = CasebookOrganizer()
    @State private var organizingRecord: AdviceRecord?
    @State private var selectedFolder: String?

    init(
        favorites: FavoritesViewModel,
        history: HistoryViewModel,
        settings: SettingsViewModel,
        initialShelf: Shelf,
        onUseRecord: @escaping (AdviceRecord) -> Void,
        onDataChanged: @escaping () -> Void,
        onJumpToGenerate: @escaping () -> Void
    ) {
        self.favorites = favorites
        self.history = history
        self.settings = settings
        self.initialShelf = initialShelf
        self.onUseRecord = onUseRecord
        self.onDataChanged = onDataChanged
        self.onJumpToGenerate = onJumpToGenerate
        _shelf = State(initialValue: initialShelf)
    }

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var canvas: Color { Theme.canvasColor(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var records: [AdviceRecord] {
        let base = shelf == .saved ? favorites.filteredFavorites : history.filteredHistory
        guard shelf == .saved, let selectedFolder else { return base }
        return base.filter { organizer.metadata(for: $0.id).folder == selectedFolder }
    }
    private var searchText: Binding<String> {
        Binding(
            get: { shelf == .saved ? favorites.searchText : history.searchText },
            set: {
                if shelf == .saved {
                    favorites.searchText = $0
                } else {
                    history.searchText = $0
                }
            }
        )
    }
    private var selectedCategory: AdviceCategory? {
        shelf == .saved ? favorites.selectedCategory : history.selectedCategory
    }
    private var availableFolders: [String] {
        Array(
            Set(
                favorites.favorites.compactMap {
                    organizer.metadata(for: $0.id).folder
                }
            )
        )
        .sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                canvas.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        BureauTabHeader(
                            eyebrow: "Favorites & history",
                            title: "Casebook",
                            detail: "The takes worth keeping—and the ones best used as evidence.",
                            systemImage: "books.vertical.fill",
                            theme: settings.theme
                        )

                        BureauPanel(theme: settings.theme, emphasized: true) {
                            VStack(spacing: 12) {
                                Picker("Casebook shelf", selection: $shelf) {
                                    ForEach(Shelf.allCases) { item in
                                        Text(item.title).tag(item)
                                    }
                                }
                                .pickerStyle(.segmented)

                                HStack(spacing: 10) {
                                    InlineSearchField(
                                        text: searchText,
                                        prompt: shelf == .saved ? "Search saved takes" : "Search recent takes",
                                        accent: accent,
                                        secondaryText: secondaryText,
                                        surfaceColor: cardColor
                                    )

                                    Menu {
                                        Button("All lanes") {
                                            setCategory(nil)
                                        }
                                        ForEach(AdviceCategory.concrete) { category in
                                            Button(category.title) {
                                                setCategory(category)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: selectedCategory == nil
                                              ? "line.3.horizontal.decrease.circle"
                                              : "line.3.horizontal.decrease.circle.fill")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundStyle(selectedCategory == nil ? secondaryText : accent)
                                            .frame(width: 48, height: 48)
                                            .background(canvas.opacity(0.72), in: RoundedRectangle(cornerRadius: 15))
                                    }
                                    .accessibilityLabel("Filter casebook by lane")
                                }
                            }
                        }
                        .accessibilityIdentifier(
                            shelf == .saved ? "favorites.command.card" : "history.command.card"
                        )

                        if shelf == .saved, !favorites.favorites.isEmpty {
                            monthlyRecap
                            folderFilters
                        }

                        if records.isEmpty {
                            emptyState
                        } else {
                            ForEach(records) { record in
                                recordRow(record)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 26)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .onAppear {
                shelf = initialShelf
                favorites.loadIfNeeded()
                history.loadIfNeeded()
                tabBarVisible.wrappedValue = true
            }
            .onChange(of: shelf) { _, newShelf in
                if newShelf != .saved {
                    selectedFolder = nil
                }
            }
        }
        .toast(item: $activeToast, accentColor: accent)
        .sheet(item: $organizingRecord) { record in
            CasebookOrganizationSheet(
                record: record,
                organizer: organizer,
                theme: settings.theme
            )
        }
    }

    private var monthlyRecap: some View {
        let calendar = Calendar.current
        let monthRecords = favorites.favorites.filter {
            calendar.isDate($0.createdAt, equalTo: Date(), toGranularity: .month)
        }
        let legendaryCount = favorites.favorites.filter { $0.caseRarity == .legendary }.count
        let leadingCategory = Dictionary(grouping: monthRecords, by: \.category)
            .max { $0.value.count < $1.value.count }?.key
        let monthTitle = Date().formatted(.dateTime.month(.wide))

        return BureauPanel(theme: settings.theme) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MONTHLY DOSSIER")
                            .font(.caption2.weight(.black))
                            .tracking(1.3)
                            .foregroundStyle(accent)
                        Text(monthTitle)
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .foregroundStyle(primaryText)
                    }
                    Spacer()
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                }

                HStack(spacing: 8) {
                    casebookMetric("\(monthRecords.count)", label: "Filed")
                    casebookMetric("\(legendaryCount)", label: "Legendary")
                    casebookMetric(leadingCategory?.title ?? "Open", label: "Top lane")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Monthly dossier for \(monthTitle)")
        .accessibilityValue(
            "\(monthRecords.count) filed, \(legendaryCount) legendary, top lane \(leadingCategory?.title ?? "open")"
        )
        .accessibilityIdentifier("casebook.monthlyDossier")
    }

    private var folderFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                folderFilterButton("All files", folder: nil)
                ForEach(availableFolders, id: \.self) { folder in
                    folderFilterButton(folder, folder: folder)
                }
            }
            .padding(.vertical, 1)
            .padding(.trailing, 4)
        }
        .accessibilityIdentifier("casebook.folderFilters")
    }

    private var emptyState: some View {
        BureauPanel(theme: settings.theme) {
            VStack(spacing: 14) {
                Image("BureauCasebook")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)

                Text(shelf == .saved ? "No filed takes yet" : "The recent file is clean")
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(primaryText)

                Text(shelf == .saved
                     ? "Save a result from Desk and it will land here."
                     : "Commission a take and its paper trail will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)

                Button(action: onJumpToGenerate) {
                    Label("Open Desk", systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .accessibilityIdentifier("favorites.generate")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func recordRow(_ record: AdviceRecord) -> some View {
        BureauPanel(theme: settings.theme) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    Text("CASE \(record.caseNumber)")
                        .font(.caption2.weight(.black).monospaced())
                        .tracking(0.8)
                        .foregroundStyle(secondaryText)
                    Spacer(minLength: 0)
                    BureauTag(
                        title: record.caseRarity.title,
                        systemImage: record.caseRarity.systemImage,
                        accent: record.caseRarity == .legendary ? accent : secondaryText
                    )
                }

                Text(record.adviceLine)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(4)
                    .lineSpacing(2)

                HStack(spacing: 7) {
                    BureauTag(title: record.category.title, systemImage: record.category.icon, accent: accent)
                    BureauTag(title: record.tone.voice.name, systemImage: record.tone.voice.systemImage, accent: secondaryText)
                    Spacer(minLength: 0)
                }

                let metadata = organizer.metadata(for: record.id)
                if metadata.folder != nil || !metadata.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if let folder = metadata.folder {
                                BureauTag(title: folder, systemImage: "folder.fill", accent: accent)
                            }
                            ForEach(metadata.tags, id: \.self) { tag in
                                BureauTag(title: "#\(tag)", systemImage: "tag.fill", accent: secondaryText)
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(secondaryText)

                    Spacer()

                    if shelf == .saved {
                        rowAction("Organize", systemImage: "folder.badge.plus") {
                            organizingRecord = record
                        }
                    }

                    rowAction("Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = record.adviceLine
                        activeToast = ToastMessage(message: "Copied to clipboard", style: .success)
                    }

                    rowAction("Use", systemImage: "arrow.up.right") {
                        onUseRecord(record)
                    }

                    rowAction(
                        shelf == .saved ? "Remove" : "Save",
                        systemImage: shelf == .saved ? "bookmark.slash" : "bookmark"
                    ) {
                        if shelf == .saved {
                            favorites.remove(record)
                            organizer.remove(recordID: record.id)
                        } else {
                            history.saveFromHistory(record)
                        }
                        onDataChanged()
                    }
                }
            }
        }
        .contextMenu {
            Button("Use on Desk", systemImage: "sparkles") {
                onUseRecord(record)
            }
            Button("Copy", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = record.adviceLine
            }
            if shelf == .saved {
                Button("Organize case", systemImage: "folder.badge.plus") {
                    organizingRecord = record
                }
                Button("Remove from saved", systemImage: "bookmark.slash", role: .destructive) {
                    favorites.remove(record)
                    organizer.remove(recordID: record.id)
                    onDataChanged()
                }
            }
        }
    }

    private func rowAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.caption.weight(.bold))
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(accent)
        .accessibilityLabel(title)
    }

    private func setCategory(_ category: AdviceCategory?) {
        if shelf == .saved {
            favorites.selectedCategory = category
        } else {
            history.selectedCategory = category
        }
    }

    private func folderFilterButton(_ title: String, folder: String?) -> some View {
        let isSelected = selectedFolder == folder
        return Button {
            selectedFolder = folder
        } label: {
            Label(title, systemImage: folder == nil ? "books.vertical" : "folder.fill")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .frame(minHeight: 40)
                .foregroundStyle(isSelected ? Theme.buttonText(for: settings.theme) : primaryText)
                .background(
                    isSelected ? accent : secondaryText.opacity(0.08),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func casebookMetric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label.uppercased())
                .font(.caption2.weight(.black))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CasebookOrganizationSheet: View {
    let record: AdviceRecord
    let organizer: CasebookOrganizer
    let theme: ThemeMode

    @Environment(\.dismiss) private var dismiss
    @State private var folder: String
    @State private var tags: String

    init(record: AdviceRecord, organizer: CasebookOrganizer, theme: ThemeMode) {
        self.record = record
        self.organizer = organizer
        self.theme = theme
        let metadata = organizer.metadata(for: record.id)
        _folder = State(initialValue: metadata.folder ?? "")
        _tags = State(initialValue: metadata.tags.joined(separator: ", "))
    }

    private var accent: Color { Theme.accent(for: theme) }
    private var canvas: Color { Theme.canvasColor(for: theme) }
    private var cardColor: Color { Theme.cardColor(for: theme) }
    private var primaryText: Color { Theme.primaryText(for: theme) }
    private var secondaryText: Color { Theme.secondaryText(for: theme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("CASE \(record.caseNumber)")
                            .font(.caption2.weight(.black).monospaced())
                            .foregroundStyle(accent)
                        Text(record.adviceLine)
                            .font(.system(.headline, design: .serif, weight: .semibold))
                            .foregroundStyle(primaryText)
                            .lineLimit(4)
                    }
                    .padding(16)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dossier")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(primaryText)
                        TextField("e.g. Best Of, Office, Shareable", text: $folder)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("casebook.organize.folder")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["Best Of", "Office", "Shareable", "Evidence"], id: \.self) {
                                    suggestion in
                                    Button(suggestion) {
                                        folder = suggestion
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(accent)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(primaryText)
                        TextField("deadpan, meeting, bestie", text: $tags)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("casebook.organize.tags")
                        Text("Separate up to six tags with commas.")
                            .font(.caption)
                            .foregroundStyle(secondaryText)
                    }
                }
                .padding(18)
            }
            .background(canvas.ignoresSafeArea())
            .navigationTitle("Organize Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        organizer.save(
                            recordID: record.id,
                            folder: folder,
                            tags: tags.split(separator: ",").map(String.init)
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .accessibilityIdentifier("casebook.organize.save")
                }
            }
        }
        .preferredColorScheme(Theme.colorScheme(for: theme))
    }
}

// MARK: - Dares

struct DaresTabView: View {
    @Bindable var generate: GenerateViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    var onOpenTab: (AppTab) -> Void
    var onDataChanged: () -> Void

    @Environment(\.tabBarVisible) private var tabBarVisible
    @State private var showingBracket = false

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var canvas: Color { Theme.canvasColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var daily: GenerateViewModel.ChaosMissionState { generate.dailyMissionState }
    private var weekly: GenerateViewModel.WeeklyMissionState { generate.weeklyMissionState }

    var body: some View {
        NavigationStack {
            ZStack {
                canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        BureauTabHeader(
                            eyebrow: "Missions",
                            title: "Dares",
                            detail: "Tiny assignments for keeping your worst instincts in fighting shape.",
                            systemImage: "flag.checkered.2.crossed",
                            theme: settings.theme
                        )
                        .accessibilityIdentifier("chaos.command.card")

                        BureauPanel(theme: settings.theme, emphasized: true) {
                            missionCard(
                                eyebrow: "TODAY",
                                title: daily.title.replacingOccurrences(of: "Daily Mission: ", with: ""),
                                detail: daily.subtitle,
                                progress: daily.progressFraction,
                                count: "\(daily.currentCount)/\(daily.targetCount)",
                                completed: daily.isComplete
                            ) {
                                generate.runDailyMissionGeneration()
                                onDataChanged()
                                onOpenTab(.generate)
                            }
                        }

                        BureauPanel(theme: settings.theme) {
                            missionCard(
                                eyebrow: "THIS WEEK",
                                title: weekly.title.replacingOccurrences(of: "Weekly Mission: ", with: ""),
                                detail: weekly.subtitle,
                                progress: weekly.progressFraction,
                                count: "\(weekly.currentCount)/\(weekly.targetCount)",
                                completed: weekly.isComplete,
                                prominent: false
                            ) {
                                generate.updateSelections(
                                    category: weekly.category,
                                    tone: weekly.tone,
                                    autoGenerate: false
                                )
                                onOpenTab(.generate)
                            }
                        }
                        .accessibilityIdentifier("chaos.progressionPath")

                        BureauPanel(theme: settings.theme) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("YOUR FIELD NOTES")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.3)
                                    .foregroundStyle(accent)

                                HStack(spacing: 0) {
                                    metric("\(generate.todayGeneratedCount)", label: "Today")
                                    Divider().frame(height: 40)
                                    metric("\(generate.favoriteCount)", label: "Filed")
                                    Divider().frame(height: 40)
                                    metric("\(generate.challengeStreakDays)", label: "Streak")
                                }
                            }
                        }

                        BureauPanel(theme: settings.theme) {
                            VStack(alignment: .leading, spacing: 13) {
                                Text("AFTER HOURS")
                                    .font(.caption2.weight(.black))
                                    .tracking(1.3)
                                    .foregroundStyle(accent)
                                Text("Play a bracket or bring in accomplices.")
                                    .font(.system(.title3, design: .serif, weight: .bold))
                                    .foregroundStyle(primaryText)
                                Text("Solo works everywhere. Group challenges appear when social services are available.")
                                    .font(.subheadline)
                                    .foregroundStyle(secondaryText)

                                HStack(spacing: 10) {
                                    Button {
                                        showingBracket = true
                                    } label: {
                                        Label("Advice bracket", systemImage: "trophy.fill")
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(accent)

                                    Button {
                                        onOpenTab(.groupChallenges)
                                    } label: {
                                        Label("Groups", systemImage: "person.3.fill")
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(accent)
                                }

                                Label(
                                    social.socialFeaturesEnabled ? "Friends connected" : "Solo mode ready",
                                    systemImage: social.socialFeaturesEnabled ? "person.2.badge.gearshape.fill" : "person.fill"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(secondaryText)
                            }
                        }
                        .accessibilityIdentifier("chaos.social.leaderboardCard")
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 26)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .onAppear {
                tabBarVisible.wrappedValue = true
                generate.trackChaosHubOpened()
                generate.refreshRetentionStateOnAppear()
            }
        }
        .sheet(isPresented: $showingBracket) {
            AdviceBracketView(settings: settings, generateViewModel: generate)
        }
    }

    private func missionCard(
        eyebrow: String,
        title: String,
        detail: String,
        progress: Double,
        count: String,
        completed: Bool,
        prominent: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(eyebrow)
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(accent)
                Spacer()
                Text(completed ? "COMPLETE" : count)
                    .font(.caption.weight(.black).monospacedDigit())
                    .foregroundStyle(completed ? .green : secondaryText)
            }

            Text(title)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(primaryText)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(secondaryText)

            ProgressView(value: progress)
                .tint(accent)

            // Only the daily dare carries the filled CTA; the weekly card steps
            // down to bordered so the two cards do not compete for the tap.
            let label = Label(
                completed ? "Commission another" : "Accept the dare",
                systemImage: completed ? "arrow.clockwise" : "arrow.up.right"
            )
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 46)

            if prominent {
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.bordered)
                    .tint(accent)
            }
        }
    }

    private func metric(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.black).monospacedDigit())
                .foregroundStyle(primaryText)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Dispatches

struct DispatchesTabView: View {
    enum Desk: String, CaseIterable, Identifiable {
        case daily
        case ideas
        case archive

        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: "Daily"
            case .ideas: "Starters"
            case .archive: "Archive"
            }
        }
    }

    private struct Starter: Identifiable {
        let id: String
        let title: String
        let prompt: String
        let category: AdviceCategory
        let tone: ToneMode
    }

    @Bindable var quotes: QuotesViewModel
    @Bindable var settings: SettingsViewModel
    @Bindable var social: SocialViewModel
    let initialDesk: Desk
    var onUseStarter: (AdviceCategory, ToneMode, String) -> Void
    var onOpenTab: (AppTab) -> Void

    @Environment(\.tabBarVisible) private var tabBarVisible
    @State private var desk: Desk
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var activeToast: ToastMessage?

    init(
        quotes: QuotesViewModel,
        settings: SettingsViewModel,
        social: SocialViewModel,
        initialDesk: Desk,
        onUseStarter: @escaping (AdviceCategory, ToneMode, String) -> Void,
        onOpenTab: @escaping (AppTab) -> Void
    ) {
        self.quotes = quotes
        self.settings = settings
        self.social = social
        self.initialDesk = initialDesk
        self.onUseStarter = onUseStarter
        self.onOpenTab = onOpenTab
        _desk = State(initialValue: initialDesk)
    }

    private var accent: Color { Theme.accent(for: settings.theme) }
    private var canvas: Color { Theme.canvasColor(for: settings.theme) }
    private var cardColor: Color { Theme.cardColor(for: settings.theme) }
    private var primaryText: Color { Theme.primaryText(for: settings.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: settings.theme) }
    private var starters: [Starter] {
        [
            .init(id: "meeting", title: "The status meeting", prompt: "I need to explain a project delay without sounding worried.", category: .career, tone: .corporateConsultant),
            .init(id: "reply", title: "The slow reply", prompt: "They keep taking hours to text me back.", category: .dating, tone: .toxicBestFriend),
            .init(id: "splurge", title: "The little splurge", prompt: "I want to buy something unnecessary and call it self-care.", category: .money, tone: .influencer),
            .init(id: "groupchat", title: "The group chat", prompt: "The group chat went quiet after I made it awkward.", category: .social, tone: .friendRoast),
            .init(id: "sideproject", title: "The side project", prompt: "I have a new app idea and no time to build it.", category: .tech, tone: .alphaPodcast),
            .init(id: "trip", title: "The packed itinerary", prompt: "I am planning every minute of a vacation.", category: .travel, tone: .lifeCoach),
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                canvas.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        BureauTabHeader(
                            eyebrow: "Quotes & prompts",
                            title: "Dispatches",
                            detail: "A daily bad idea, plus useful ways to start your own.",
                            systemImage: "envelope.open.fill",
                            theme: settings.theme
                        )

                        Picker("Dispatch desk", selection: $desk) {
                            ForEach(Desk.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch desk {
                        case .daily:
                            dailyDispatch
                        case .ideas:
                            starterDispatches
                        case .archive:
                            archiveDispatches
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 26)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(Theme.colorScheme(for: settings.theme))
            .onAppear {
                desk = initialDesk
                quotes.loadIfNeeded()
                tabBarVisible.wrappedValue = true
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ActivityShareSheet(items: shareItems)
        }
        .toast(item: $activeToast, accentColor: accent)
    }

    private var dailyDispatch: some View {
        let quote = quotes.dailyQuote
        return BureauPanel(theme: settings.theme, emphasized: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("TODAY'S DISPATCH")
                        .font(.caption2.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                    Spacer()
                    BureauTag(title: quote.category.title, systemImage: quote.category.icon, accent: accent)
                }

                Text("“\(quote.text)”")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .foregroundStyle(primaryText)
                    .lineSpacing(4)

                Text("— \(quote.source)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(secondaryText)

                HStack(spacing: 8) {
                    quoteAction(
                        "Like",
                        systemImage: quotes.vote(for: quote) == .like ? "hand.thumbsup.fill" : "hand.thumbsup"
                    ) {
                        quotes.toggleVote(.like, for: quote)
                    }
                    quoteAction("Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = quote.text
                        quotes.trackCopy(quote, isDaily: true)
                        activeToast = ToastMessage(message: "Dispatch copied", style: .success)
                    }
                    quoteAction("Share", systemImage: "square.and.arrow.up") {
                        shareItems = ["“\(quote.text)” — \(quote.source)\n\nBadvice"]
                        quotes.trackShare(quote, isDaily: true)
                        showingShareSheet = true
                    }
                }
            }
        }
        .accessibilityIdentifier("quotes.dailyHero")
    }

    private var starterDispatches: some View {
        ForEach(starters) { starter in
            Button {
                onUseStarter(starter.category, starter.tone, starter.prompt)
            } label: {
                BureauPanel(theme: settings.theme) {
                    HStack(alignment: .top, spacing: 13) {
                        Image(systemName: starter.category.icon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.espressoInk)
                            .frame(width: 42, height: 42)
                            .background(Theme.copperEmbossGradient, in: Circle())

                        VStack(alignment: .leading, spacing: 5) {
                            Text(starter.title)
                                .font(.system(.headline, design: .serif, weight: .bold))
                                .foregroundStyle(primaryText)
                            Text(starter.prompt)
                                .font(.subheadline)
                                .foregroundStyle(secondaryText)
                                .lineLimit(3)
                            Text("\(starter.category.title) · \(starter.tone.voice.name)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(accent)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.black))
                            .foregroundStyle(accent)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var archiveDispatches: some View {
        Group {
            BureauPanel(theme: settings.theme) {
                VStack(spacing: 10) {
                    InlineSearchField(
                        text: $quotes.searchText,
                        prompt: "Search dispatches",
                        accent: accent,
                        secondaryText: secondaryText,
                        surfaceColor: cardColor
                    )

                    HStack {
                        Picker("Sort dispatches", selection: $quotes.rankingMode) {
                            ForEach(QuoteRankingMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(accent)

                        Spacer()

                        Menu {
                            Button("All lanes") {
                                quotes.selectedCategory = nil
                            }
                            ForEach(AdviceCategory.concrete) { category in
                                Button(category.title) {
                                    quotes.selectedCategory = category
                                }
                            }
                        } label: {
                            Label(
                                quotes.selectedCategory?.title ?? "All lanes",
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                            .font(.caption.weight(.bold))
                        }
                        .tint(accent)
                    }
                }
            }

            if quotes.filteredQuotes.isEmpty {
                BureauPanel(theme: settings.theme) {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(accent)
                        Text("No dispatches match that file.")
                            .font(.headline)
                            .foregroundStyle(primaryText)
                        Button("Clear filters") {
                            quotes.searchText = ""
                            quotes.selectedCategory = nil
                        }
                        .buttonStyle(.bordered)
                        .tint(accent)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(quotes.filteredQuotes.prefix(20), id: \.id) { quote in
                    BureauPanel(theme: settings.theme) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("“\(quote.text)”")
                                .font(.system(.body, design: .serif, weight: .semibold))
                                .foregroundStyle(primaryText)
                                .lineLimit(4)
                            HStack {
                                BureauTag(title: quote.category.title, systemImage: quote.category.icon, accent: accent)
                                Text(quote.source)
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                    .lineLimit(1)
                                Spacer()
                                quoteAction("Copy", systemImage: "doc.on.doc") {
                                    UIPasteboard.general.string = quote.text
                                    quotes.trackCopy(quote, isDaily: false)
                                    activeToast = ToastMessage(message: "Dispatch copied", style: .success)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func quoteAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .foregroundStyle(accent)
        .accessibilityLabel(title)
    }
}

// MARK: - Settings front door

struct BureauSettingsTabView: View {
    @Bindable var viewModel: SettingsViewModel
    @Bindable var generateViewModel: GenerateViewModel
    @Bindable var quotesViewModel: QuotesViewModel
    @Bindable var social: SocialViewModel
    @Bindable var auth: AuthViewModel
    var achievementsManager: AchievementsManager
    var onSignOut: () -> Void
    var onDeleteAccount: (_ password: String) async -> Void

    @Environment(\.tabBarVisible) private var tabBarVisible

    private var accent: Color { Theme.accent(for: viewModel.theme) }
    private var canvas: Color { Theme.canvasColor(for: viewModel.theme) }
    private var cardColor: Color { Theme.cardColor(for: viewModel.theme) }
    private var primaryText: Color { Theme.primaryText(for: viewModel.theme) }
    private var secondaryText: Color { Theme.secondaryText(for: viewModel.theme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BureauTabHeader(
                    eyebrow: "Preferences",
                    title: "Settings",
                    detail: "The essentials up front. The machinery stays one level deeper.",
                    systemImage: "slider.horizontal.3",
                    theme: viewModel.theme
                )

                BureauPanel(theme: viewModel.theme, emphasized: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        settingsLabel("ADVICE ENGINE", detail: "Local by default. Apple Intelligence is optional.")

                        Picker("Advice engine", selection: $viewModel.preferredGenerationProvider) {
                            ForEach(AdviceGenerationProvider.userSelectable) { provider in
                                Text(provider.title).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.generation.provider")

                        Label(
                            viewModel.preferredGenerationProvider == .classic
                                ? "Bureau Engine works offline with no model setup."
                                : viewModel.appleOnDeviceModelStatusText,
                            systemImage: viewModel.preferredGenerationProvider == .classic
                                ? "bolt.shield.fill"
                                : "apple.intelligence"
                        )
                        .font(.caption)
                        .foregroundStyle(secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                        Picker("Content pack", selection: $viewModel.preferredContentPack) {
                            ForEach(ContentPack.allCases) { pack in
                                Text(pack.title).tag(pack)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(accent)
                    }
                }

                BureauPanel(theme: viewModel.theme) {
                    VStack(alignment: .leading, spacing: 12) {
                        settingsLabel("EXPERIENCE", detail: "A few controls with visible consequences.")
                        settingsToggle("Explain why it is terrible", systemImage: "text.bubble", isOn: $viewModel.includeRationale)
                        Divider()
                        settingsToggle("Avoid repeats", systemImage: "arrow.trianglehead.2.clockwise.rotate.90", isOn: $viewModel.strictNoRepeats)
                        Divider()
                        settingsToggle("Haptics", systemImage: "waveform", isOn: $viewModel.hapticsEnabled)
                        Divider()
                        settingsToggle(
                            "Daily dispatch",
                            systemImage: "bell.badge.fill",
                            isOn: $viewModel.dailyNotificationsEnabled
                        )
                        Divider()
                        settingsToggle("Reduce motion", systemImage: "figure.walk.motion", isOn: $viewModel.reduceMotion)
                    }
                }

                BureauPanel(theme: viewModel.theme) {
                    VStack(alignment: .leading, spacing: 13) {
                        settingsLabel(
                            "PRIVATE TASTE",
                            detail: "Ranking adapts from device-side actions, never an uploaded profile."
                        )
                        Label(
                            generateViewModel.localTasteSummary.detail,
                            systemImage: "brain.head.profile"
                        )
                        .font(.subheadline)
                        .foregroundStyle(primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                        Picker("Share card", selection: $viewModel.preferredTemplate) {
                            ForEach(ShareCardTemplate.allCases) { template in
                                Text(template.title).tag(template)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(accent)
                        .accessibilityIdentifier("settings.share.template")
                    }
                }

                BureauPanel(theme: viewModel.theme) {
                    VStack(alignment: .leading, spacing: 13) {
                        settingsLabel("LOOK", detail: "Choose the bureau's lighting.")

                        Picker("Theme", selection: $viewModel.theme) {
                            ForEach(ThemeMode.allCases) { theme in
                                Text(theme.title).tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(accent)

                        HStack(spacing: 8) {
                            ForEach(ThemeMode.allCases.prefix(6)) { theme in
                                Button {
                                    viewModel.theme = theme
                                } label: {
                                    Circle()
                                        .fill(Theme.accent(for: theme))
                                        .frame(
                                            width: viewModel.theme == theme ? 28 : 22,
                                            height: viewModel.theme == theme ? 28 : 22
                                        )
                                        .overlay {
                                            if viewModel.theme == theme {
                                                Circle().stroke(primaryText.opacity(0.7), lineWidth: 2)
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(theme.title)
                                .accessibilityAddTraits(
                                    viewModel.theme == theme ? .isSelected : []
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                BureauPanel(theme: viewModel.theme) {
                    VStack(alignment: .leading, spacing: 13) {
                        settingsLabel("ACCOUNT", detail: "Stored locally on this device.")

                        HStack(spacing: 12) {
                            Text(String(auth.displayName.prefix(1)).uppercased())
                                .font(.headline.weight(.black))
                                .foregroundStyle(Theme.espressoInk)
                                .frame(width: 44, height: 44)
                                .background(Theme.copperEmbossGradient, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(auth.displayName)
                                    .font(.headline)
                                    .foregroundStyle(primaryText)
                                    .accessibilityIdentifier("settings.auth.displayName")
                                Text(auth.signedInEmail ?? "Signed in")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                                    .accessibilityIdentifier("settings.auth.email")
                            }
                            Spacer()
                        }

                        HStack(spacing: 10) {
                            advancedAccountLink(
                                title: "Security",
                                systemImage: "key.fill",
                                identifier: "settings.auth.changePassword"
                            )
                            advancedAccountLink(
                                title: "Delete",
                                systemImage: "trash",
                                identifier: "settings.auth.deleteAccount"
                            )
                        }

                        Button(role: .destructive, action: onSignOut) {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("settings.auth.signOut")
                    }
                }

                NavigationLink {
                    advancedSettings
                } label: {
                    BureauPanel(theme: viewModel.theme) {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(accent)
                                .frame(width: 42, height: 42)
                                .background(accent.opacity(0.1), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("All settings & diagnostics")
                                    .font(.headline)
                                    .foregroundStyle(primaryText)
                                Text("Notifications, sharing, account tools, labs, and model setup.")
                                    .font(.caption)
                                    .foregroundStyle(secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(secondaryText)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.advanced")
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, tabBarVisible.wrappedValue ? Theme.tabContentBottomInset : 26)
        }
        .scrollIndicators(.hidden)
        .background(canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(Theme.colorScheme(for: viewModel.theme))
        .onAppear {
            tabBarVisible.wrappedValue = true
            viewModel.refreshAppleOnDeviceModelAvailability()
        }
    }

    private var advancedSettings: some View {
        SettingsTabView(
            viewModel: viewModel,
            generateViewModel: generateViewModel,
            quotesViewModel: quotesViewModel,
            social: social,
            auth: auth,
            achievementsManager: achievementsManager,
            onSignOut: onSignOut,
            onDeleteAccount: onDeleteAccount
        )
        .navigationTitle("Advanced")
    }

    private func settingsLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.black))
                .tracking(1.3)
                .foregroundStyle(accent)
            Text(detail)
                .font(.caption)
                .foregroundStyle(secondaryText)
        }
    }

    private func settingsToggle(
        _ title: String,
        systemImage: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(primaryText)
        }
        .tint(accent)
    }

    private func advancedAccountLink(
        title: String,
        systemImage: String,
        identifier: String
    ) -> some View {
        NavigationLink {
            advancedSettings
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(accent)
        .accessibilityIdentifier(identifier)
    }
}
