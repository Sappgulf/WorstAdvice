import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color Extensions

extension Color {
    static let badviceAccent = Color.accentColor
    static let badviceCard = Color(.secondarySystemBackground)
    static let badvicePrimary = Color.primary
    static let badviceSecondary = Color.secondary
}

// MARK: - Reusable Card Components

struct BCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct BCardSection<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content
    
    init(_ title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let icon = icon {
                Label(title, systemImage: icon)
                    .font(.headline)
            } else {
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Reusable Button Components

struct BButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return .badviceAccent
        case .secondary: return .gray
        case .destructive: return .red
        }
    }
}

struct BIconButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    init(_ icon: String, size: CGFloat = 44, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: size, height: size)
                .background(Color.badviceAccent.opacity(0.2))
                .clipShape(Circle())
        }
    }
}

// MARK: - Loading States

struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.badviceSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FullScreenLoading: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Empty States

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.badviceSecondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.badviceSecondary)
                .multilineTextAlignment(.center)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.badviceAccent)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

// MARK: - Stat Components

struct StatBox: View {
    let value: String
    let label: String
    let icon: String?
    let color: Color
    
    init(
        _ value: String,
        label: String,
        icon: String? = nil,
        color: Color = .badviceAccent
    ) {
        self.value = value
        self.label = label
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.badviceSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    init(_ icon: String, label: String, value: String, color: Color = .badviceAccent) {
        self.icon = icon
        self.label = label
        self.value = value
        self.color = color
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.badviceSecondary)
        }
    }
}

// MARK: - Progress Components

struct BProgressBar: View {
    let value: Double
    let total: Double
    let color: Color
    let showLabel: Bool
    
    init(
        value: Double,
        total: Double,
        color: Color = .badviceAccent,
        showLabel: Bool = true
    ) {
        self.value = value
        self.total = total
        self.color = color
        self.showLabel = showLabel
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.badviceSecondary.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
            
            if showLabel {
                Text("\(Int(value))/\(Int(total))")
                    .font(.caption)
                    .foregroundColor(.badviceSecondary)
            }
        }
    }
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(value / total, 1.0)
    }
}

// MARK: - Badge Components

struct BBadge: View {
    let text: String
    let color: Color
    
    init(_ text: String, color: Color = .badviceAccent) {
        self.text = text
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Toggle Components

struct BToggle: View {
    let title: String
    let icon: String?
    @Binding var isOn: Bool
    
    init(_ title: String, icon: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.icon = icon
        self._isOn = isOn
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.badviceAccent)
                }
                Text(title)
            }
        }
        .tint(.badviceAccent)
    }
}

// MARK: - Section Header

struct BSectionHeader: View {
    let title: String
    let icon: String?
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        _ title: String,
        icon: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Label(title, systemImage: icon)
                    .font(.headline)
            } else {
                Text(title)
                    .font(.headline)
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.caption)
                        .foregroundColor(.badviceAccent)
                }
            }
        }
    }
}

// MARK: - Animation Extensions

extension Animation {
    static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smooth = Animation.easeInOut(duration: 0.3)
    static let quick = Animation.easeInOut(duration: 0.15)
}

// MARK: - Grid Helpers

struct BGrid {
    static func adaptiveColumns(minimum: CGFloat = 150) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum))]
    }
    
    static func fixedColumns(count: Int, spacing: CGFloat = 12) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }
}
