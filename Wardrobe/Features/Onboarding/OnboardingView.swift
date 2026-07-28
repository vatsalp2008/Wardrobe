import SwiftUI

/// First-run intro (spec §7.3): three slides introducing the app, then a page that primes the
/// camera and notification permissions before the user hits them mid-flow.
struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    private static let slides: [OnboardingSlide] = [
        OnboardingSlide(
            systemImage: "square.grid.2x2",
            title: "Your closet, digitized",
            message: "Photograph each item once. Wardrobe removes the background and tags the "
                + "colour, pattern, and formality for you."
        ),
        OnboardingSlide(
            systemImage: "sparkles",
            title: "Outfits picked for you",
            message: "Fresh combinations every day, matched to the weather and the occasion — "
                + "and never the same thing you wore yesterday."
        ),
        OnboardingSlide(
            systemImage: "person.crop.rectangle",
            title: "See it on you first",
            message: "Preview an outfit on your own photo before you get dressed. Your photo is "
                + "encrypted and stays on your device."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.page) {
                ForEach(Array(Self.slides.enumerated()), id: \.offset) { index, slide in
                    slideView(slide).tag(index)
                }
                permissionsPage.tag(OnboardingViewModel.slideCount)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            footer
        }
        .background(DS.Colors.background)
    }

    // MARK: - Pages

    private func slideView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: DS.Spacing.m) {
            Spacer()
            Image(systemName: slide.systemImage)
                .font(.system(size: 72))
                .foregroundStyle(DS.Colors.primary)
                .padding(.bottom, DS.Spacing.s)
            Text(slide.title)
                .font(DS.Typography.title)
                .multilineTextAlignment(.center)
            Text(slide.message)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    private var permissionsPage: some View {
        VStack(spacing: DS.Spacing.m) {
            Spacer()
            Text("Two quick permissions")
                .font(DS.Typography.title)
                .multilineTextAlignment(.center)
            Text("You can change these any time in Settings.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, DS.Spacing.s)

            permissionRow(
                systemImage: "camera",
                title: "Camera",
                message: "So you can photograph your clothes.",
                isPrimed: viewModel.cameraPrimed,
                action: { await viewModel.primeCamera() }
            )
            permissionRow(
                systemImage: "bell",
                title: "Notifications",
                message: "For your morning outfit picks.",
                isPrimed: viewModel.notificationsPrimed,
                action: { await viewModel.primeNotifications() }
            )
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.l)
    }

    private func permissionRow(
        systemImage: String,
        title: String,
        message: String,
        isPrimed: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        CardContainer {
            HStack(spacing: DS.Spacing.m) {
                Image(systemName: systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(DS.Colors.primary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(title).font(DS.Typography.body.weight(.semibold))
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                if isPrimed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.Colors.primary)
                        .transition(.scale)
                } else {
                    Button("Allow") { Task { await action() } }
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(DS.Colors.primary)
                }
            }
        }
        .animation(DS.Motion.spring, value: isPrimed)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: DS.Spacing.s) {
            if viewModel.isOnPermissionsPage {
                PrimaryButton(title: "Get started") { viewModel.finish() }
            } else {
                PrimaryButton(title: "Continue") {
                    withAnimation(DS.Motion.spring) { viewModel.advance() }
                }
                Button("Skip") { viewModel.finish() }
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.l)
    }
}

/// One intro slide's content.
private struct OnboardingSlide {
    let systemImage: String
    let title: String
    let message: String
}

#Preview {
    OnboardingView()
}
