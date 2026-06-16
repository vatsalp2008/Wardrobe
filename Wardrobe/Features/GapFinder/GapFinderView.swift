import SwiftUI

/// Gap Finder tab (spec §7.1): a hero card with the highest-impact missing item and a horizontal
/// scroll of live shopping results, plus runner-up suggestions.
struct GapFinderView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: GapFinderViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: GapFinderViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isAnalyzing {
                    ProgressView("Analyzing your wardrobe…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let top = viewModel.topSuggestion {
                    content(top: top)
                } else {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "Gap Finder",
                        message: viewModel.errorMessage
                            ?? "Find the single purchase that unlocks the most new outfits."
                    )
                }
            }
            .navigationTitle("Gap Finder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await viewModel.analyze() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Re-analyze wardrobe gaps")
                    .disabled(viewModel.isAnalyzing)
                }
            }
        }
        .task { await viewModel.load() }
    }

    private func content(top: GapSuggestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                heroCard(top)

                if !top.shoppingResults.isEmpty {
                    Text("Shop this gap")
                        .font(DS.Typography.headline)
                        .padding(.horizontal, DS.Spacing.m)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.m) {
                            ForEach(top.shoppingResults) { ShoppingResultCard(item: $0) }
                        }
                        .padding(.horizontal, DS.Spacing.m)
                    }
                }

                if viewModel.suggestions.count > 1 {
                    Text("Other gaps")
                        .font(DS.Typography.headline)
                        .padding(.horizontal, DS.Spacing.m)
                    VStack(spacing: DS.Spacing.s) {
                        ForEach(viewModel.suggestions.dropFirst()) { runnerUp($0) }
                    }
                    .padding(.horizontal, DS.Spacing.m)
                }
            }
            .padding(.vertical, DS.Spacing.m)
        }
    }

    private func heroCard(_ suggestion: GapSuggestion) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack {
                    Image(systemName: suggestion.missingCategory.symbolName)
                        .font(.system(size: 28)).foregroundStyle(DS.Colors.primary)
                    Spacer()
                    Label("\(Int(suggestion.trendAlignment * 100))% on-trend", systemImage: "flame")
                        .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
                Text("Adding \(suggestion.description.lowercased()) would unlock")
                    .font(DS.Typography.body)
                Text("\(suggestion.newOutfitsUnlocked) new outfit\(suggestion.newOutfitsUnlocked == 1 ? "" : "s")")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.primary)
                if let reasoning = suggestion.reasoning {
                    Text(reasoning)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.m)
    }

    private func runnerUp(_ suggestion: GapSuggestion) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: suggestion.missingCategory.symbolName)
                .foregroundStyle(DS.Colors.primary)
                .frame(width: 36)
            VStack(alignment: .leading) {
                Text(suggestion.description).font(DS.Typography.body)
                Text("+\(suggestion.newOutfitsUnlocked) outfits")
                    .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(DS.Spacing.m)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
    }
}
