import SwiftUI

/// Detail screen for a wardrobe item: larger image, full tags, and wear actions (spec §7.1).
struct ItemDetailView: View {
    let item: ClothingItem
    let onMarkWorn: () async -> Void
    let onDelete: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                image
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.card))

                VStack(alignment: .leading, spacing: DS.Spacing.m) {
                    detailRow("Category", item.category.displayName)
                    detailRow("Pattern", item.pattern.displayName)
                    detailRow("Formality", item.formality.displayName)
                    detailRow("Seasons", item.season.map(\.displayName).joined(separator: ", "))
                    detailRow("Worn", "\(item.wearCount) times")
                    if let lastWorn = item.lastWorn {
                        detailRow("Last worn", lastWorn.shortLabel)
                    }
                    if let brand = item.brand { detailRow("Brand", brand) }
                    if let notes = item.notes { detailRow("Notes", notes) }
                }

                PrimaryButton(title: "Mark Worn Today") {
                    Task { await onMarkWorn(); dismiss() }
                }
            }
            .padding(DS.Spacing.m)
        }
        .navigationTitle(item.name.isEmpty ? item.category.displayName : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    Task { await onDelete(); dismiss() }
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var image: some View {
        if let data = item.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFit().padding(DS.Spacing.m)
        } else {
            Image(systemName: item.category.symbolName)
                .font(.system(size: 64)).foregroundStyle(DS.Colors.primary)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Text(value.isEmpty ? "—" : value).font(DS.Typography.body)
                .multilineTextAlignment(.trailing)
        }
    }
}
