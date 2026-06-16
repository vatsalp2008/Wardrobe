import PhotosUI
import SwiftUI

/// Sheet that walks the user through adding a clothing item: choose a source (camera or photo
/// library), then segment / classify / review / save. Presented from `ClosetView`.
struct AddItemFlowView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: AddItemViewModel
    @State private var photoItem: PhotosPickerItem?

    /// Called after a successful save so the closet can refresh.
    let onSaved: () -> Void

    init(container: AppContainer, onSaved: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AddItemViewModel(container: container))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add Item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .chooseSource:
            sourceChooser
        case .camera:
            CameraCaptureView(
                onCapture: { image in Task { await viewModel.process(image) } },
                onCancel: { viewModel.step = .chooseSource }
            )
            .ignoresSafeArea()
        case .processing:
            ProgressView("Removing background…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .review:
            ItemReviewView(
                viewModel: viewModel,
                onSave: {
                    do {
                        try await viewModel.save()
                        onSaved()
                        dismiss()
                    } catch {
                        viewModel.errorMessage = "Couldn't save the item."
                    }
                }
            )
        }
    }

    private var sourceChooser: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()
            Image(systemName: "tshirt")
                .font(.system(size: 56))
                .foregroundStyle(DS.Colors.primary)
            Text("Add a clothing item")
                .font(DS.Typography.headline)
            Text("Take a photo or pick one from your library. We'll remove the background and tag it.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.l)

            VStack(spacing: DS.Spacing.m) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    PrimaryButton(title: "Take Photo") { viewModel.step = .camera }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Choose from Library")
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(DS.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
        .alert("Something went wrong",
               isPresented: .constant(viewModel.errorMessage != nil),
               actions: { Button("OK") { viewModel.errorMessage = nil } },
               message: { Text(viewModel.errorMessage ?? "") })
        .onChange(of: photoItem) { newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.process(image)
                }
            }
        }
    }
}
