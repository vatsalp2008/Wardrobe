import SwiftUI

/// Closet tab (spec §7.1): a grid of wardrobe items with a category filter bar and an add button.
struct ClosetView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ClosetViewModel
    @State private var showingAddFlow = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: DS.Spacing.m)]

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ClosetViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.items.isEmpty {
                    EmptyStateView(
                        systemImage: "square.grid.2x2",
                        title: "Your Closet",
                        message: "Tap + to add a clothing item. We'll remove the background and tag it for you."
                    )
                } else {
                    grid
                }
            }
            .navigationTitle("Closet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddFlow = true } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showingAddFlow) {
            AddItemFlowView(container: container) {
                Task { await viewModel.load() }
            }
            .environmentObject(container)
        }
    }

    private var grid: some View {
        ScrollView {
            if !viewModel.availableCategories.isEmpty {
                filterBar
            }
            LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
                ForEach(viewModel.filteredItems) { item in
                    NavigationLink {
                        ItemDetailView(
                            item: item,
                            onMarkWorn: { await viewModel.markWorn(item) },
                            onDelete: { await viewModel.delete(item) }
                        )
                    } label: {
                        ClothingCardView(item: item)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { Task { await viewModel.markWorn(item) } } label: {
                            Label("Mark Worn", systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) { Task { await viewModel.delete(item) } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(DS.Spacing.m)
        }
        .refreshable { await viewModel.load() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                FilterChip(title: "All", isSelected: viewModel.categoryFilter == nil) {
                    viewModel.categoryFilter = nil
                }
                ForEach(viewModel.availableCategories) { category in
                    FilterChip(title: category.displayName,
                               isSelected: viewModel.categoryFilter == category) {
                        viewModel.categoryFilter = category
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.top, DS.Spacing.s)
        }
    }
}
