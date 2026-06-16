import SwiftUI

/// Grid card for a single wardrobe item (spec §7.3). Renders the locally cached thumbnail
/// (background-removed) with a category badge and name.
struct ClothingCardView: View {
    let item: ClothingItem

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(DS.Colors.accent)
                thumbnail
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))

            Text(item.name.isEmpty ? item.category.displayName : item.name)
                .font(DS.Typography.caption.weight(.medium))
                .lineLimit(1)
            HStack(spacing: DS.Spacing.xs) {
                ForEach(item.color.prefix(3), id: \.self) { hex in
                    Circle().fill(Color(hex: hex)).frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.secondary.opacity(0.3)))
                }
                Spacer()
                Image(systemName: item.category.symbolName)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = item.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFit().padding(DS.Spacing.s)
        } else if let url = URL(string: item.imageURL), item.imageURL.hasPrefix("http") {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit().padding(DS.Spacing.s)
            } placeholder: {
                Image(systemName: item.category.symbolName)
                    .font(.system(size: 36)).foregroundStyle(DS.Colors.primary)
            }
        } else {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 36)).foregroundStyle(DS.Colors.primary)
        }
    }
}
