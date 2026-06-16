import SwiftUI

/// In-app privacy summary (spec §10). Mirrors the App Store Privacy Nutrition Label intent:
/// on-device first, no data sold, photo never used for training.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                section("Your photo", """
                Your full-body try-on photo is encrypted on your device (AES-GCM) and is only \
                sent to the virtual try-on service (Replicate) when you tap Try On. It is never \
                used for training and is removed from that service shortly after rendering.
                """)
                section("Your wardrobe", """
                Clothing photos and tags are stored locally. If cloud sync is enabled, images are \
                stored in your private storage bucket protected by row-level security so only you \
                can access them.
                """)
                section("AI features", """
                Outfit and gap suggestions send your wardrobe tags (not raw photos) to the AI \
                service to generate recommendations.
                """)
                section("No selling, no third-party analytics", """
                We do not sell your data and use no third-party analytics SDKs.
                """)
            }
            .padding(DS.Spacing.l)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text(title).font(DS.Typography.headline)
            Text(body).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
        }
    }
}
