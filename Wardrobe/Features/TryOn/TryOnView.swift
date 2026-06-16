import PhotosUI
import SwiftUI

/// Try-On tab (spec §7.1): one-time photo setup, then pick an outfit to composite onto the photo.
struct TryOnView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: TryOnViewModel
    @State private var photoItem: PhotosPickerItem?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: TryOnViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.hasUserPhoto {
                    setup
                } else {
                    hub
                }
            }
            .navigationTitle("Try On")
            .toolbar {
                if viewModel.hasUserPhoto {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Replace Photo") { photoItem = nil; viewModel.removePhoto() }
                        } label: { Image(systemName: "person.crop.circle") }
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .onChange(of: photoItem) { newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.savePhoto(image)
                }
            }
        }
        .sheet(item: $viewModel.result) { result in
            NavigationStack {
                TryOnResultView(original: result.original, rendered: result.rendered)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { viewModel.result = nil }
                        }
                    }
            }
        }
        .alert("Try-On",
               isPresented: .constant(viewModel.errorMessage != nil),
               actions: { Button("OK") { viewModel.errorMessage = nil } },
               message: { Text(viewModel.errorMessage ?? "") })
    }

    // MARK: - One-time setup

    private var setup: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()
            Image(systemName: "person.crop.rectangle")
                .font(.system(size: 56)).foregroundStyle(DS.Colors.primary)
            Text("Add a full-body photo")
                .font(DS.Typography.headline)
            Text(viewModel.setupGuidance
                 ?? "Use one clear, full-body photo — standing, facing the camera, good lighting. It's stored encrypted on your device.")
                .font(DS.Typography.body)
                .foregroundStyle(viewModel.setupGuidance == nil ? DS.Colors.textSecondary : .orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.l)
            PhotosPicker(selection: $photoItem, matching: .images) {
                Text("Choose Photo")
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.m)
                    .background(DS.Colors.primary, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
            }
            .padding(.horizontal, DS.Spacing.l)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
    }

    // MARK: - Hub

    private var hub: some View {
        ScrollView {
            if let photo = viewModel.userPhoto {
                Image(uiImage: photo)
                    .resizable().scaledToFit().frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                    .padding(.horizontal, DS.Spacing.m)
            }
            Text("\(viewModel.remainingToday) try-ons left today")
                .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                .padding(.top, DS.Spacing.xs)

            if viewModel.outfits.isEmpty {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "No outfits yet",
                    message: "Generate outfits on the Outfits tab, then try them on here."
                )
                .frame(height: 320)
            } else {
                LazyVStack(spacing: DS.Spacing.m) {
                    ForEach(viewModel.outfits) { outfit in
                        Button {
                            Task { await viewModel.generate(for: outfit) }
                        } label: {
                            OutfitCardView(outfit: outfit) {}
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isGenerating)
                    }
                }
                .padding(DS.Spacing.m)
            }
        }
        .overlay {
            if viewModel.isGenerating {
                ProgressView("Compositing… (10–20s)")
                    .padding(DS.Spacing.l)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            }
        }
    }
}
