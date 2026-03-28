import SwiftUI

struct ErrorBoundaryView<Content: View, Recovery: View>: View {
    let error: Error
    let recovery: () -> Recovery
    let content: () -> Content
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            
            Text("Something went wrong")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange, in: Capsule())
            }
            
            recovery()
        }
        .padding()
    }
}

struct SwiftDataErrorView: View {
    let error: Error
    let onDismiss: () -> Void
    
    var body: some View {
        ErrorBoundaryView(error: error, recovery: {
            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.bordered)
        }) {
            EmptyView()
        }
    }
}

@MainActor
func withErrorBoundary<T: Sendable>(
    operation: () async throws -> T,
    onError: (Error) -> Void
) async -> T? {
    do {
        return try await operation()
    } catch {
        onError(error)
        return nil
    }
}
