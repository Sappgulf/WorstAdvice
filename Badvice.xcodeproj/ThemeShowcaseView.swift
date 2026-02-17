import SwiftUI

/// A comprehensive showcase of all theme features for testing and demonstration
struct ThemeShowcaseView: View {
    @State private var selectedTheme: ThemeMode = .badvice
    @State private var showingDetails = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Theme Selector
                    themeSelectorSection
                    
                    // Color Palette
                    colorPaletteSection
                    
                    // Typography Showcase
                    typographySection
                    
                    // Card Showcase
                    cardShowcaseSection
                    
                    // Shadow Comparison
                    shadowShowcaseSection
                    
                    // Glow & Effects
                    effectsShowcaseSection
                    
                    // Theme Stats
                    themeStatsSection
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.vertical, 20)
            }
            .background(ThemeBackgroundView(mode: selectedTheme).ignoresSafeArea())
            .navigationTitle("Theme Showcase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Details") {
                    showingDetails.toggle()
                }
            }
            .sheet(isPresented: $showingDetails) {
                ThemeDetailsSheet(theme: selectedTheme)
            }
            .themeTransition(selectedTheme)
        }
    }
    
    // MARK: - Sections
    
    private var themeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Theme")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: selectedTheme))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemeMode.allCases) { theme in
                        ThemeOptionButton(
                            theme: theme,
                            isSelected: selectedTheme == theme
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                selectedTheme = theme
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Color Palette")
            
            VStack(spacing: 12) {
                colorSwatch("Primary Accent", Theme.accent(for: selectedTheme))
                
                if let secondary = Theme.secondaryAccent(for: selectedTheme) {
                    colorSwatch("Secondary Accent", secondary)
                }
                
                colorSwatch("Primary Text", Theme.primaryText(for: selectedTheme))
                colorSwatch("Secondary Text", Theme.secondaryText(for: selectedTheme))
                colorSwatch("Card Background", Theme.cardColor(for: selectedTheme))
                colorSwatch("Particle Color", Theme.particleColor(for: selectedTheme))
                
                if let glow = Theme.glowColor(for: selectedTheme) {
                    colorSwatch("Glow Color", glow)
                }
            }
        }
    }
    
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Typography")
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Headline Font")
                    .font(Theme.headlineFont)
                    .foregroundStyle(Theme.headerColor(for: selectedTheme))
                    .shadow(color: Theme.headerShadowColor(for: selectedTheme), radius: 6)
                
                Text("Card Font")
                    .font(Theme.cardFont)
                    .foregroundStyle(Theme.primaryText(for: selectedTheme))
                
                Text("Body Font")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.secondaryText(for: selectedTheme))
                
                Text("Chip Font")
                    .font(Theme.chipFont)
                    .foregroundStyle(Theme.accent(for: selectedTheme))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.cardColor(for: selectedTheme))
            )
        }
    }
    
    private var cardShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Card Examples")
            
            // Standard Card
            standardCardExample
            
            // Card with Border
            borderedCardExample
        }
    }
    
    private var standardCardExample: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Example Category", systemImage: "star.fill")
                    .font(Theme.chipFont)
                    .foregroundStyle(Theme.accent(for: selectedTheme))
                Spacer()
                Text("Intensity")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: selectedTheme))
            }
            
            Text("This is an example advice card demonstrating the theme's styling.")
                .font(Theme.cardFont)
                .foregroundStyle(Theme.primaryText(for: selectedTheme))
                .lineSpacing(4)
            
            Divider()
                .background(Theme.secondaryText(for: selectedTheme).opacity(0.2))
            
            Text("Additional details would appear here, styled with secondary text.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.secondaryText(for: selectedTheme))
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(Theme.cardColor(for: selectedTheme))
                
                if selectedTheme != .minimal {
                    RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(Theme.glassMorphismOpacity(for: selectedTheme))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .shadow(
            color: Theme.cardShadow(for: selectedTheme).color,
            radius: Theme.cardShadow(for: selectedTheme).radius,
            y: Theme.cardShadow(for: selectedTheme).y
        )
    }
    
    private var borderedCardExample: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Card with Enhanced Border")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText(for: selectedTheme))
            
            Text("This card showcases the gradient border effect.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText(for: selectedTheme))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardColor(for: selectedTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.accent(for: selectedTheme).opacity(0.5),
                            Theme.accent(for: selectedTheme).opacity(0.15),
                            Theme.secondaryAccent(for: selectedTheme)?.opacity(0.4) ?? Theme.accent(for: selectedTheme).opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
    
    private var shadowShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Shadow System")
            
            let primaryShadow = Theme.cardShadow(for: selectedTheme)
            let secondaryShadow = Theme.cardSecondaryShadow(for: selectedTheme)
            
            VStack(spacing: 10) {
                infoRow("Primary Shadow Radius", "\(Int(primaryShadow.radius))pt")
                infoRow("Primary Shadow Y-Offset", "\(Int(primaryShadow.y))pt")
                
                if let secondary = secondaryShadow {
                    infoRow("Secondary Shadow", "✓ Available")
                    infoRow("Secondary Radius", "\(Int(secondary.radius))pt")
                } else {
                    infoRow("Secondary Shadow", "Not used")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardColor(for: selectedTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private var effectsShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Special Effects")
            
            VStack(spacing: 10) {
                infoRow("Glassmorphism", "\(Int(Theme.glassMorphismOpacity(for: selectedTheme) * 100))%")
                infoRow("Glow Effects", Theme.shouldUseGlow(for: selectedTheme) ? "Enabled" : "Disabled")
                infoRow("Header Glow", Theme.headerShouldGlow(for: selectedTheme) ? "Enabled" : "Disabled")
                
                if Theme.secondaryAccent(for: selectedTheme) != nil {
                    infoRow("Dual-Color System", "✓ Active")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardColor(for: selectedTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Live Glow Demo
            if Theme.shouldUseGlow(for: selectedTheme) {
                glowDemoView
            }
        }
    }
    
    private var glowDemoView: some View {
        VStack(spacing: 12) {
            Text("Glow Effect Preview")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText(for: selectedTheme))
            
            Circle()
                .fill(Theme.glowColor(for: selectedTheme) ?? .clear)
                .frame(width: 60, height: 60)
                .blur(radius: 20)
                .overlay {
                    Circle()
                        .fill(Theme.accent(for: selectedTheme))
                        .frame(width: 40, height: 40)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Theme.cardColor(for: selectedTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private var themeStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Theme Information")
            
            VStack(spacing: 10) {
                infoRow("Theme Name", selectedTheme.title)
                infoRow("Raw Value", selectedTheme.rawValue)
                infoRow("Category", themeCategory(selectedTheme))
                infoRow("Recommended For", themeRecommendation(selectedTheme))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardColor(for: selectedTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.primaryText(for: selectedTheme))
    }
    
    private func colorSwatch(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText(for: selectedTheme))
                
                Text(colorHex(color))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText(for: selectedTheme))
            }
            
            Spacer()
        }
        .padding(12)
        .background(Theme.cardColor(for: selectedTheme).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText(for: selectedTheme))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.primaryText(for: selectedTheme))
        }
    }
    
    // MARK: - Helper Functions
    
    private func colorHex(_ color: Color) -> String {
        // This is a simplified version - in production you'd extract actual RGB values
        return "Theme Color"
    }
    
    private func themeCategory(_ theme: ThemeMode) -> String {
        switch theme {
        case .badvice, .minimal:
            return "Core"
        case .ember, .slate, .evergreen:
            return "Nature"
        case .neon, .cosmic, .retro:
            return "Vibrant"
        case .midnight, .sunset:
            return "Atmospheric"
        }
    }
    
    private func themeRecommendation(_ theme: ThemeMode) -> String {
        switch theme {
        case .badvice:
            return "Default experience"
        case .minimal:
            return "Clean, focused reading"
        case .ember:
            return "Warm, energetic vibe"
        case .slate:
            return "Professional, calm"
        case .evergreen:
            return "Natural, organic feel"
        case .neon:
            return "High energy, cyberpunk"
        case .midnight:
            return "Late-night sessions"
        case .sunset:
            return "Warm, inspirational"
        case .cosmic:
            return "Creative, spacey"
        case .retro:
            return "80s nostalgia"
        }
    }
}

// MARK: - Theme Option Button

private struct ThemeOptionButton: View {
    let theme: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Theme preview circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.accent(for: theme),
                                Theme.secondaryAccent(for: theme) ?? Theme.accent(for: theme).opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay {
                        if isSelected {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                            Circle()
                                .stroke(Theme.accent(for: theme), lineWidth: 6)
                                .scaleEffect(1.1)
                        }
                    }
                    .shadow(
                        color: Theme.accent(for: theme).opacity(0.5),
                        radius: isSelected ? 8 : 4,
                        y: isSelected ? 4 : 2
                    )
                
                Text(theme.title)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.accent(for: theme) : Theme.secondaryText(for: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 80)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Details Sheet

private struct ThemeDetailsSheet: View {
    let theme: ThemeMode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Theme Name & Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(theme.title)
                            .font(.title.bold())
                            .foregroundStyle(Theme.accent(for: theme))
                        
                        Text(themeDescription)
                            .font(.body)
                            .foregroundStyle(Theme.secondaryText(for: theme))
                    }
                    
                    // Features List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText(for: theme))
                        
                        ForEach(themeFeatures, id: \.self) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.accent(for: theme))
                                Text(feature)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText(for: theme))
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardColor(for: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(20)
            }
            .background(ThemeBackgroundView(mode: theme).ignoresSafeArea())
            .navigationTitle("Theme Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private var themeDescription: String {
        switch theme {
        case .badvice:
            return "The signature Badvice theme with warm coral accents and deep shadows."
        case .minimal:
            return "Clean and distraction-free with minimal effects for focused reading."
        case .ember:
            return "Warm and energetic with vibrant orange tones reminiscent of glowing embers."
        case .slate:
            return "Professional and calm with cool blue accents on a slate backdrop."
        case .evergreen:
            return "Natural and organic with sage green tones that feel fresh and alive."
        case .neon:
            return "High-energy cyberpunk aesthetic with magenta and cyan dual colors."
        case .midnight:
            return "Serene and focused with frost blue accents perfect for late-night sessions."
        case .sunset:
            return "Warm and inspirational with golden tones and coral complements."
        case .cosmic:
            return "Creative and spacey with purple gradients and starfield effects."
        case .retro:
            return "80s vaporwave nostalgia with matrix green and hot pink dual colors."
        }
    }
    
    private var themeFeatures: [String] {
        var features: [String] = []
        
        if Theme.secondaryAccent(for: theme) != nil {
            features.append("Dual-color accent system")
        }
        
        if Theme.shouldUseGlow(for: theme) {
            features.append("Animated glow effects")
        }
        
        if Theme.cardSecondaryShadow(for: theme) != nil {
            features.append("Enhanced depth with dual shadows")
        }
        
        if Theme.glassMorphismOpacity(for: theme) > 0.55 {
            features.append("Premium glassmorphism")
        }
        
        if Theme.headerShouldGlow(for: theme) {
            features.append("Glowing header text")
        }
        
        features.append("Optimized for \(theme == .minimal ? "readability" : "visual impact")")
        
        return features
    }
}

#Preview("Theme Showcase") {
    ThemeShowcaseView()
}

#Preview("Theme Details") {
    ThemeDetailsSheet(theme: .cosmic)
}
