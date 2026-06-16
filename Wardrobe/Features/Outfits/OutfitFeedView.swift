import SwiftUI

/// Outfits tab (spec §7.1): a vertical feed of AI-generated outfits with occasion filter chips,
/// a weather header, pull-to-refresh, and favoriting.
struct OutfitFeedView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: OutfitViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: OutfitViewModel(container: container))
    }

    private let occasions: [Occasion?] = [nil, .casual, .work, .formal, .outdoor]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredOutfits.isEmpty {
                    emptyState
                } else {
                    feed
                }
            }
            .navigationTitle("Outfits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .safeAreaInset(edge: .top) { filterBar }
        }
        .task {
            await viewModel.loadCached()
            if viewModel.outfits.isEmpty { await viewModel.refresh() }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(occasions, id: \.self) { occasion in
                    FilterChip(
                        title: occasion?.displayName ?? "All",
                        isSelected: viewModel.selectedOccasion == occasion
                    ) {
                        viewModel.selectedOccasion = occasion
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s)
        }
        .background(.bar)
    }

    private var feed: some View {
        ScrollView {
            if let weather = viewModel.weather {
                weatherHeader(weather)
            }
            LazyVStack(spacing: DS.Spacing.m) {
                ForEach(viewModel.filteredOutfits) { outfit in
                    NavigationLink {
                        OutfitDetailView(
                            outfit: outfit,
                            onMarkWorn: { await viewModel.markWorn(outfit) },
                            onFavorite: { await viewModel.toggleFavorite(outfit) }
                        )
                    } label: {
                        OutfitCardView(outfit: outfit) {
                            Task { await viewModel.toggleFavorite(outfit) }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DS.Spacing.m)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func weatherHeader(_ weather: WeatherInfo) -> some View {
        HStack {
            Image(systemName: "thermometer.medium")
            Text("\(Int(weather.temperatureC))°C · \(weather.condition)")
            if weather.isFallback {
                Text("(estimated)").foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer()
        }
        .font(DS.Typography.caption)
        .padding(.horizontal, DS.Spacing.m)
        .padding(.top, DS.Spacing.s)
    }

    private var emptyState: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Generating outfits…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "Daily Outfits",
                    message: viewModel.errorMessage
                        ?? "Pull to refresh for AI-curated outfit suggestions from your wardrobe."
                )
            }
        }
    }
}
