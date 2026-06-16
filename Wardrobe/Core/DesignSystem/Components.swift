import SwiftUI

// MARK: - Primary button

/// Filled brand-blue button (spec §7.2). Used for key actions.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
                .background(DS.Colors.primary, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter chip

/// Selectable pill used in filter bars (occasion / category).
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.caption.weight(.medium))
                .padding(.horizontal, DS.Spacing.m)
                .padding(.vertical, DS.Spacing.s)
                .background(
                    isSelected ? DS.Colors.primary : DS.Colors.accent,
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : DS.Colors.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card container

/// Rounded surface card with consistent padding and corner radius.
struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(DS.Spacing.m)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
    }
}

// MARK: - Empty state

/// Shared placeholder shown by feature tabs until their content is implemented.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(DS.Colors.primary)
            Text(title)
                .font(DS.Typography.headline)
            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
    }
}
