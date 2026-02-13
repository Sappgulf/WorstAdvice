import SwiftUI

struct HistoryTabView: View {
    @Bindable var viewModel: HistoryViewModel
    @Bindable var settings: SettingsViewModel
    let onUseRecord: (AdviceRecord) -> Void
    let onDataChanged: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.history.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(viewModel.history, id: \.id) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(record.adviceLine)
                                    .font(.body)
                                    .foregroundStyle(Theme.primaryText(for: settings.theme))

                                Text("\(record.category.title) • \(record.tone.title)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText(for: settings.theme))

                                HStack(spacing: 10) {
                                    Button("Use") {
                                        onUseRecord(record)
                                    }
                                    .buttonStyle(.bordered)

                                    Button(record.isFavorite ? "Saved" : "Save") {
                                        viewModel.saveFromHistory(record)
                                        onDataChanged()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Theme.accent(for: settings.theme))
                                }
                                .padding(.top, 2)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.backgroundGradient(for: settings.theme).ignoresSafeArea())
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        viewModel.clearHistory()
                        onDataChanged()
                    }
                    .disabled(viewModel.history.isEmpty)
                }
            }
            .onAppear { viewModel.reload() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
            Text("History is empty")
                .font(.headline)
                .foregroundStyle(Theme.primaryText(for: settings.theme))
            Text("Generated advice appears here (last 50 items).")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryText(for: settings.theme))
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
