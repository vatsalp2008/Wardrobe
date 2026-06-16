import SwiftUI

/// A single live shopping result (spec §5.4 / §7.3). Tapping opens the retailer link.
struct ShoppingResultCard: View {
    let item: ShoppingItem

    var body: some View {
        Link(destination: URL(string: item.buyLink) ?? URL(string: "https://www.google.com/search?tbm=shop")!) {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.chip).fill(DS.Colors.accent)
                    if let url = URL(string: item.imageURL), !item.imageURL.isEmpty {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit().padding(DS.Spacing.s)
                        } placeholder: {
                            Image(systemName: "bag").font(.system(size: 28)).foregroundStyle(DS.Colors.primary)
                        }
                    } else {
                        Image(systemName: "bag").font(.system(size: 28)).foregroundStyle(DS.Colors.primary)
                    }
                }
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip))

                Text(item.title)
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)
                HStack {
                    Text(item.price).font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(DS.Colors.primary)
                    Spacer()
                    Text(item.retailer).font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary).lineLimit(1)
                }
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
    }
}
