import SwiftUI

// MARK: - Toast

enum ToastStyle {
    case success   // green check — "Copied!", "Saved!"
    case deleted   // orange — "Removed"
    case error     // red — "Failed"
    case info      // accent-tinted — generic

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .deleted: return "bookmark.slash.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    func tintColor(accent: Color) -> Color {
        switch self {
        case .success: return Color(hex: "34C759")
        case .deleted: return Color.orange
        case .error:   return Color(hex: "FF3B30")
        case .info:    return accent
        }
    }
}

struct ToastMessage: Equatable {
    let id: UUID
    let message: String
    let style: ToastStyle

    init(message: String, style: ToastStyle = .success) {
        self.id = UUID()
        self.message = message
        self.style = style
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastView: View {
    let toast: ToastMessage
    let accentColor: Color

    @ViewBuilder
    private var toastSurface: some View {
        let tint = toast.style.tintColor(accent: accentColor)

        if #available(iOS 26.0, *) {
            toastContent
                .glassEffect(.regular.tint(tint.opacity(0.18)), in: .capsule)
        } else {
            toastContent
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        }
    }

    private var toastContent: some View {
        HStack(spacing: 9) {
            Image(systemName: toast.style.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(toast.style.tintColor(accent: accentColor))

            Text(toast.message)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    var body: some View {
        let tint = toast.style.tintColor(accent: accentColor)

        toastSurface
            .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
    }
}

extension View {
    /// Attach a floating toast banner. Pass a `Binding<ToastMessage?>` — set it to trigger a toast.
    func toast(item: Binding<ToastMessage?>, accentColor: Color) -> some View {
        modifier(ToastModifier(item: item, accentColor: accentColor))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var item: ToastMessage?
    let accentColor: Color
    @State private var task: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = item {
                ToastView(toast: toast, accentColor: accentColor)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
                    .padding(.bottom, 28)
                    .id(toast.id)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.12) : .spring(response: Theme.animMedium, dampingFraction: 0.78), value: item)
        .onChange(of: item) { _, newVal in
            guard newVal != nil else { return }
            task?.cancel()
            task = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.22)) {
                    item = nil
                }
            }
        }
    }
}
