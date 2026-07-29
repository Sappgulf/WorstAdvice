import SwiftUI

struct FloatingTabBarView: View {
    @Binding var selectedTab: AppTab
    @Binding var showingSettingsRoot: Bool
    @Binding var showingShellMenu: Bool
    @Binding var tabBarVisible: Bool

    let tabs: [AppTab]
    let overflowTabs: [AppTab]
    let theme: ThemeMode
    let hapticsEnabled: Bool
    let reduceMotion: Bool
    let lowPowerModeEnabled: Bool
    let onPrimaryTabSelected: (AppTab) -> Void
    let onSettingsSelected: () -> Void

    @State private var tabBarWidth: CGFloat = 0
    @State private var tabDragHighlight: AppTab? = nil
    @State private var tabSlideModeActive = false
    @State private var tabSlideLastIndex: Int?
    @State private var tabSlideLastHapticTab: AppTab?
    @State private var tabSlideLastSwitchAt: Date = .distantPast

    private var tabBarStyle: ThemeTabBarStyle { Theme.tabBarStyle(for: theme) }
    private var accent: Color { Theme.accent(for: theme) }
    private var secondaryText: Color { Theme.secondaryText(for: theme) }

    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer()

                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        tabButton(tab)
                    }

                    moreButton
                }
                .contentShape(Rectangle())
                .background(widthReader)
                .simultaneousGesture(slideGesture)
                .padding(.horizontal, Theme.floatingTabBarInnerPadding)
                .padding(.vertical, Theme.floatingTabBarInnerPadding)
                .frame(minHeight: Theme.floatingTabBarReservedHeight - 10)
                .background { tabBarBackground }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: Theme.floatingTabBarCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: Theme.floatingTabBarCornerRadius,
                        style: .continuous
                    )
                    .stroke(tabBarStyle.borderTop.opacity(0.7), lineWidth: 0.8)
                }
                .shadow(
                    color: tabBarStyle.shadow,
                    radius: tabBarStyle.shadowRadius,
                    x: 0,
                    y: 5
                )
                .padding(.horizontal, Theme.floatingTabBarHorizontalPadding)
                .padding(.bottom, max(8, proxy.safeAreaInsets.bottom * 0.24))
                .background(alignment: .bottom) {
                    if reduceMotion {
                        LinearGradient(
                            colors: [
                                Theme.canvasColor(for: theme).opacity(0),
                                Theme.canvasColor(for: theme).opacity(0.72),
                                Theme.canvasColor(for: theme),
                                Theme.canvasColor(for: theme),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                            .frame(
                                height: Theme.floatingTabBarReservedHeight
                                    + max(26, proxy.safeAreaInsets.bottom + 16)
                                    + 18
                            )
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
                .offset(y: tabBarVisible ? 0 : 120)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8),
                    value: tabBarVisible
                )
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .ignoresSafeArea(.container, edges: .bottom)
        .ignoresSafeArea(.keyboard)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab || (tab == .settings && showingSettingsRoot)
        let isHighlighted = tabDragHighlight == tab
        let titleText = isSelected ? tab.title : tab.compactTitle

        return Button {
            handleTap(on: tab)
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected, let glow = tabBarStyle.glow {
                        Circle()
                            .fill(glow)
                            .frame(width: 28, height: 16)
                            .blur(radius: 8)
                            .offset(y: 2)
                    }
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                        .symbolVariant(isSelected ? .fill : .none)
                        .foregroundStyle(
                            isSelected
                                ? accent
                                : (isHighlighted ? accent.opacity(0.78) : secondaryText.opacity(0.62))
                        )
                        .scaleEffect(isSelected ? 1.04 : (isHighlighted ? 1.02 : 0.96))
                }

                Text(titleText)
                    .font(.system(size: isSelected ? 10 : 9, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(height: 12)
            }
            .foregroundStyle(
                isSelected
                    ? accent
                    : (isHighlighted ? accent.opacity(0.58) : secondaryText.opacity(0.62))
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.floatingTabItemMinHeight)
            .padding(.top, 5)
            .padding(.bottom, 5)
            .scaleEffect(isSelected ? tabBarStyle.selectedScale : 1)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.09))
                        .padding(.horizontal, 3)
                }
            }
            .overlay(alignment: .top) {
                if isSelected || isHighlighted {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(isSelected ? 1 : 0.5),
                                    (Theme.secondaryAccent(for: theme) ?? accent).opacity(isSelected ? 0.85 : 0.35),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: isSelected ? 3 : 2)
                        .shadow(color: accent.opacity(isSelected ? 0.45 : 0), radius: 4, y: 0)
                        .padding(.horizontal, max(12, tabBarStyle.indicatorInset + 10))
                        .padding(.top, 1)
                        .animation(
                            reduceMotion ? nil : Theme.badBounce,
                            value: isSelected
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(tab.title)
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var moreButton: some View {
        let selectedTabIsOverflow = overflowTabs.contains(selectedTab) && !tabs.contains(selectedTab)
        let isSelected = showingShellMenu || showingSettingsRoot || selectedTabIsOverflow

        return Button {
            HapticsManager.playSelection(isEnabled: hapticsEnabled)
            showingShellMenu = true
        } label: {
            VStack(spacing: 2) {
                Group {
                    if reduceMotion {
                        Image(systemName: "ellipsis.circle")
                    } else {
                        Image(systemName: "ellipsis.circle")
                            .symbolEffect(.bounce.up.byLayer, value: isSelected)
                    }
                }
                .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? accent : secondaryText.opacity(0.74))

                Text(selectedTabIsOverflow ? selectedTab.compactTitle : "More")
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(height: 12)
            }
            .foregroundStyle(isSelected ? accent : secondaryText.opacity(0.74))
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.floatingTabItemMinHeight)
            .padding(.top, 5)
            .padding(.bottom, 5)
            .scaleEffect(isSelected ? tabBarStyle.selectedScale : 1)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.09))
                        .padding(.horizontal, 3)
                }
            }
            .overlay(alignment: .top) {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.9))
                        .frame(height: 3)
                        .padding(.horizontal, max(12, tabBarStyle.indicatorInset + 10))
                        .padding(.top, 1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
        .accessibilityHint("Opens saved work, history, discovery, challenges, settings, and other quick access destinations")
        .accessibilityIdentifier("tab.more")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var widthReader: some View {
        GeometryReader { barGeo in
            Color.clear
                .onAppear {
                    tabBarWidth = barGeo.size.width
                }
                .onChange(of: barGeo.size.width) { _, width in
                    tabBarWidth = width
                }
        }
    }

    private var slideGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { drag in
                let horizontalMovement = abs(drag.translation.width)
                let verticalMovement = abs(drag.translation.height)
                let shouldActivateSlide =
                    horizontalMovement >= 6
                    || (horizontalMovement > verticalMovement && horizontalMovement >= 2)
                guard shouldActivateSlide else { return }
                if !tabSlideModeActive {
                    beginTabSlide()
                }
                updateTabSlide(locationX: drag.location.x)
            }
            .onEnded { _ in
                endTabSlide()
            }
    }

    private var tabBarBackground: some View {
        RoundedRectangle(
            cornerRadius: Theme.floatingTabBarCornerRadius,
            style: .continuous
        )
            .fill(tabBarStyle.backgroundTint)
            .overlay {
                RoundedRectangle(
                    cornerRadius: Theme.floatingTabBarCornerRadius,
                    style: .continuous
                )
                    .fill(.ultraThinMaterial)
                    .opacity(tabBarStyle.materialOverlayOpacity)
            }
    }

    private func handleTap(on tab: AppTab) {
        if tab == .settings {
            HapticsManager.playSelection(isEnabled: hapticsEnabled)
            onSettingsSelected()
            return
        }
        if selectedTab == tab {
            showingSettingsRoot = false
            return
        }
        showingSettingsRoot = false
        HapticsManager.playSelection(isEnabled: hapticsEnabled)
        onPrimaryTabSelected(tab)
    }

    private func beginTabSlide() {
        guard !tabs.isEmpty else { return }
        guard !tabSlideModeActive else { return }
        tabSlideModeActive = true
        if !tabs.contains(selectedTab), let fallback = tabs.first {
            selectedTab = fallback
        }
        tabDragHighlight = selectedTab
        tabSlideLastIndex = tabs.firstIndex(of: selectedTab) ?? 0
        tabSlideLastSwitchAt = Date()
        tabSlideLastHapticTab = selectedTab
        HapticsManager.playSelection(isEnabled: hapticsEnabled)
    }

    private func updateTabSlide(locationX: CGFloat) {
        guard tabSlideModeActive, !tabs.isEmpty else { return }
        guard locationX.isFinite, tabBarWidth.isFinite, tabBarWidth > 0 else { return }

        let tabWidth = tabBarWidth / CGFloat(tabs.count + 1)
        guard tabWidth.isFinite, tabWidth > .ulpOfOne else { return }

        let primaryTabsWidth = tabWidth * CGFloat(tabs.count)
        guard locationX < primaryTabsWidth else {
            tabDragHighlight = nil
            return
        }

        let clampedX = min(max(locationX, 0), max(primaryTabsWidth - 0.001, 0))
        guard clampedX.isFinite else { return }
        let indexValue = clampedX / tabWidth
        guard indexValue.isFinite else { return }

        let rawIndex = Int(indexValue.rounded(.down))
        let hoveredIndex = max(0, min(rawIndex, tabs.count - 1))
        guard tabs.indices.contains(hoveredIndex) else { return }
        let hoveredTab = tabs[hoveredIndex]

        if tabDragHighlight != hoveredTab {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                tabDragHighlight = hoveredTab
            }
        }

        guard let lastIndex = tabSlideLastIndex else {
            tabSlideLastIndex = hoveredIndex
            return
        }

        guard hoveredIndex != lastIndex else { return }

        let now = Date()
        guard now.timeIntervalSince(tabSlideLastSwitchAt) >= 0.03 else { return }

        if selectedTab != hoveredTab {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showingSettingsRoot = false
                selectedTab = hoveredTab
            }
        }

        tabSlideLastIndex = hoveredIndex
        tabSlideLastSwitchAt = now
        if tabSlideLastHapticTab != hoveredTab {
            HapticsManager.playSelection(isEnabled: hapticsEnabled)
            tabSlideLastHapticTab = hoveredTab
        }
    }

    private func endTabSlide() {
        if reduceMotion {
            tabDragHighlight = nil
        } else {
            withAnimation(.easeOut(duration: 0.16)) {
                tabDragHighlight = nil
            }
        }
        tabSlideModeActive = false
        tabSlideLastIndex = nil
        tabSlideLastHapticTab = nil
        tabSlideLastSwitchAt = .distantPast
    }
}
