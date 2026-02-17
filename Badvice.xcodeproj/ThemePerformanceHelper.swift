import SwiftUI

// MARK: - Theme Performance Utilities

/// Utility for profiling and optimizing theme rendering performance
enum ThemePerformanceHelper {
    
    /// Returns the render budget recommendation for a theme
    static func recommendedBudget(for theme: ThemeMode, deviceTier: DeviceTier = .current) -> RenderBudget {
        switch deviceTier {
        case .high:
            return .full // All effects enabled
            
        case .medium:
            // Reduce effects on complex themes
            switch theme {
            case .neon, .cosmic, .retro:
                return .balanced
            default:
                return .full
            }
            
        case .low:
            // Minimal effects on all themes
            switch theme {
            case .minimal:
                return .balanced // Minimal is already lightweight
            default:
                return .reduced
            }
        }
    }
    
    /// Returns the complexity score for a theme (0-10)
    static func complexityScore(for theme: ThemeMode) -> Int {
        var score = 0
        
        // Base complexity
        score += 2
        
        // Glassmorphism adds complexity
        if Theme.glassMorphismOpacity(for: theme) > 0 {
            score += 1
        }
        
        // Dual shadows add complexity
        if Theme.cardSecondaryShadow(for: theme) != nil {
            score += 2
        }
        
        // Glow effects add complexity
        if Theme.shouldUseGlow(for: theme) {
            score += 2
        }
        
        // Dual-color systems add complexity
        if Theme.secondaryAccent(for: theme) != nil {
            score += 1
        }
        
        // Special background effects
        switch theme {
        case .neon, .cosmic, .retro:
            score += 2 // Grid/starfield/scanline effects
        default:
            break
        }
        
        return min(score, 10)
    }
    
    /// Returns whether a theme should use reduced effects on low power mode
    static func shouldReduceInLowPowerMode(_ theme: ThemeMode) -> Bool {
        complexityScore(for: theme) >= 6
    }
    
    /// Returns the estimated memory footprint category
    static func memoryFootprint(for theme: ThemeMode) -> MemoryFootprint {
        let score = complexityScore(for: theme)
        
        if score <= 3 {
            return .light
        } else if score <= 6 {
            return .moderate
        } else {
            return .heavy
        }
    }
    
    /// Returns accessibility score (higher is better, 0-10)
    static func accessibilityScore(for theme: ThemeMode) -> Int {
        var score = 10
        
        // Deduct points for low contrast
        switch theme {
        case .minimal:
            score += 0 // Perfect contrast
        case .badvice, .evergreen:
            score -= 1 // Good contrast
        case .slate, .midnight:
            score -= 2 // Moderate contrast
        case .neon, .cosmic, .retro:
            score -= 3 // Lower contrast, vibrant colors
        default:
            score -= 1
        }
        
        // Deduct points for motion effects
        if Theme.shouldUseGlow(for: theme) {
            score -= 1 // Motion sensitivity consideration
        }
        
        return max(score, 0)
    }
}

// MARK: - Supporting Types

enum DeviceTier {
    case high   // iPhone 15 Pro, iPad Pro, etc.
    case medium // iPhone 12-14, iPad Air, etc.
    case low    // iPhone SE, older devices
    
    static var current: DeviceTier {
        #if targetEnvironment(simulator)
        return .high
        #else
        // In a real app, you'd detect device capabilities here
        // For now, default to medium
        return .medium
        #endif
    }
}

enum MemoryFootprint: String {
    case light = "Light"
    case moderate = "Moderate"
    case heavy = "Heavy"
    
    var icon: String {
        switch self {
        case .light: return "leaf.fill"
        case .moderate: return "circle.fill"
        case .heavy: return "cube.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .light: return .green
        case .moderate: return .orange
        case .heavy: return .red
        }
    }
}

// MARK: - Theme Performance Monitor View

/// A diagnostic overlay for theme performance monitoring (debug builds only)
struct ThemePerformanceMonitor: View {
    let theme: ThemeMode
    @State private var fps: Int = 60
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("Performance")
                        .font(.caption.weight(.semibold))
                    
                    Spacer()
                    
                    Circle()
                        .fill(fpsColor)
                        .frame(width: 8, height: 8)
                    
                    Text("\(fps) FPS")
                        .font(.caption.monospacedDigit())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
            }
            
            // Expanded details
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 8) {
                    detailRow("Theme", theme.title)
                    detailRow("Complexity", "\(ThemePerformanceHelper.complexityScore(for: theme))/10")
                    detailRow("Memory", ThemePerformanceHelper.memoryFootprint(for: theme).rawValue)
                    detailRow("A11y Score", "\(ThemePerformanceHelper.accessibilityScore(for: theme))/10")
                    
                    if ThemePerformanceHelper.shouldReduceInLowPowerMode(theme) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Reduce in Low Power Mode")
                                .font(.caption2)
                        }
                        .foregroundStyle(.yellow)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
        .onAppear {
            startFPSMonitoring()
        }
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
        }
    }
    
    private var fpsColor: Color {
        if fps >= 55 {
            return .green
        } else if fps >= 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func startFPSMonitoring() {
        // In a real implementation, you'd use CADisplayLink or similar
        // For demo purposes, we'll simulate varying FPS
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let complexity = ThemePerformanceHelper.complexityScore(for: theme)
            // Simulate FPS based on complexity
            fps = max(30, 60 - (complexity * 2) + Int.random(in: -3...3))
        }
    }
}

// MARK: - View Extension for Performance Monitoring

extension View {
    /// Adds a performance monitor overlay (debug builds only)
    @ViewBuilder
    func performanceMonitor(theme: ThemeMode, enabled: Bool = true) -> some View {
        #if DEBUG
        if enabled {
            self.overlay(alignment: .topTrailing) {
                ThemePerformanceMonitor(theme: theme)
                    .padding(16)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

// MARK: - Theme Optimization Recommendations

struct ThemeOptimizationRecommendations {
    let theme: ThemeMode
    
    var recommendations: [String] {
        var items: [String] = []
        
        let complexity = ThemePerformanceHelper.complexityScore(for: theme)
        let a11yScore = ThemePerformanceHelper.accessibilityScore(for: theme)
        
        // Performance recommendations
        if complexity >= 8 {
            items.append("Consider using .balanced render budget on older devices")
            items.append("Implement low power mode detection for this theme")
        }
        
        if Theme.shouldUseGlow(for: theme) {
            items.append("Respect reduce motion accessibility setting for glow animations")
        }
        
        // Accessibility recommendations
        if a11yScore < 7 {
            items.append("Review text contrast ratios for WCAG AA compliance")
            items.append("Consider increasing secondary text opacity")
        }
        
        // Memory recommendations
        switch ThemePerformanceHelper.memoryFootprint(for: theme) {
        case .heavy:
            items.append("Monitor memory usage on devices with < 4GB RAM")
        default:
            break
        }
        
        // Theme-specific recommendations
        switch theme {
        case .neon, .cosmic, .retro:
            items.append("Use drawingGroup() on complex canvas animations")
        case .minimal:
            items.append("Perfect for accessibility mode or focus sessions")
        default:
            break
        }
        
        return items
    }
}

// MARK: - Preview

#Preview("Performance Monitor") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
        }
        .performanceMonitor(theme: .cosmic)
    }
}

#Preview("Optimization Recommendations") {
    NavigationStack {
        List {
            Section("Cosmic Theme") {
                ForEach(ThemeOptimizationRecommendations(theme: .cosmic).recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(recommendation)
                            .font(.subheadline)
                    }
                }
            }
            
            Section("Minimal Theme") {
                ForEach(ThemeOptimizationRecommendations(theme: .minimal).recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text(recommendation)
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Recommendations")
    }
}
