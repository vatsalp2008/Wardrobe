import SwiftUI

/// Detail for a generated outfit: full item list, weather range, reasoning, and actions.
struct OutfitDetailView: View {
    let outfit: Outfit
    let onMarkWorn: () async -> Void
    let onFavorite: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                ForEach(outfit.items) { item in
                    HStack(spacing: DS.Spacing.m) {
                        thumbnail(for: item)
                            .frame(width: 64, height: 64)
                            .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(item.name.isEmpty ? item.category.displayName : item.name)
                                .font(DS.Typography.body.weight(.medium))
                            Text("\(item.category.displayName) · \(item.formality.displayName)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        Spacer()
                    }
                }

                Divider()

                infoRow("Occasion", outfit.occasion.displayName)
                infoRow("Trend score", "\(Int(outfit.trendScore * 100))%")
                infoRow("Suitable", "\(Int(outfit.weatherSuitability.minC))–\(Int(outfit.weatherSuitability.maxC))°C")
                if let reasoning = outfit.reasoning {
                    Text(reasoning).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                }

                PrimaryButton(title: "Mark Worn Today") {
                    Task { await onMarkWorn(); dismiss() }
                }

                // Phase 3: a "Try On" button here will composite this outfit onto the user's photo.
            }
            .padding(DS.Spacing.m)
        }
        .navigationTitle("Outfit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await onFavorite() }
                } label: {
                    Image(systemName: outfit.isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(outfit.isFavorited ? .red : DS.Colors.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for item: ClothingItem) -> some View {
        if let data = item.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit().padding(6)
        } else {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 26)).foregroundStyle(DS.Colors.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Text(value)
        }
        .font(DS.Typography.body)
    }
}
