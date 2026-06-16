import SwiftUI

/// Feed card for one generated outfit (spec §7.3): item thumbnails, trend score, occasion,
/// reasoning, and a favorite toggle.
struct OutfitCardView: View {
    let outfit: Outfit
    let onFavorite: () -> Void

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                header
                itemThumbnails
                itemChips
                if let reasoning = outfit.reasoning {
                    Text(reasoning)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(outfit.occasion.displayName)
                .font(DS.Typography.caption.weight(.semibold))
                .padding(.horizontal, DS.Spacing.s)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.accent, in: Capsule())
                .foregroundStyle(DS.Colors.primary)
            Spacer()
            Label("\(Int(outfit.trendScore * 100))%", systemImage: "chart.line.uptrend.xyaxis")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            Button(action: onFavorite) {
                Image(systemName: outfit.isFavorited ? "heart.fill" : "heart")
                    .foregroundStyle(outfit.isFavorited ? .red : DS.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(outfit.isFavorited ? "Remove favorite" : "Add favorite")
        }
    }

    private var itemThumbnails: some View {
        HStack(spacing: DS.Spacing.s) {
            ForEach(outfit.items) { item in
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.chip).fill(DS.Colors.accent)
                    if let data = item.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit().padding(6)
                    } else {
                        Image(systemName: item.category.symbolName)
                            .font(.system(size: 22)).foregroundStyle(DS.Colors.primary)
                    }
                }
                .frame(width: 72, height: 72)
            }
        }
    }

    private var itemChips: some View {
        Text(outfit.items.map { $0.name.isEmpty ? $0.category.displayName : $0.name }
            .joined(separator: " · "))
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Colors.textPrimary)
            .lineLimit(2)
    }
}
