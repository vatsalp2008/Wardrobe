import PhotosUI
import SwiftUI

/// Profile tab (spec §7.1): photo management, wear stats, notification + budget settings, privacy.
struct ProfileView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ProfileViewModel
    @State private var photoItem: PhotosPickerItem?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                statsSection
                settingsSection
                aboutSection
            }
            .navigationTitle("Profile")
        }
        .task { await viewModel.load() }
        .onChange(of: photoItem) { newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    UserPhotoStore.shared.delete()
                    try? UserPhotoStore.shared.save(image)
                    await viewModel.load()
                }
            }
        }
    }

    private var photoSection: some View {
        Section("Try-On Photo") {
            if let photo = viewModel.userPhoto {
                HStack {
                    Image(uiImage: photo).resizable().scaledToFill()
                        .frame(width: 56, height: 56).clipShape(Circle())
                        .accessibilityLabel("Your try-on photo")
                    Spacer()
                    Button("Remove", role: .destructive) { viewModel.removePhoto() }
                }
                PhotosPicker(selection: $photoItem, matching: .images) { Text("Replace Photo") }
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) { Text("Add a full-body photo") }
                Text("Stored encrypted on your device. Only sent to the try-on service when you tap Try On.")
                    .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
        }
    }

    private var statsSection: some View {
        Section("Wear Stats") {
            statRow("Items", "\(viewModel.stats.itemCount)")
            statRow("Total wears", "\(viewModel.stats.totalWears)")
            statRow("Never worn", "\(viewModel.stats.neverWornCount)")
            if let mostWorn = viewModel.stats.mostWornName {
                statRow("Most worn", mostWorn)
            }
        }
    }

    private var settingsSection: some View {
        Section("Settings") {
            Toggle("Daily outfit reminder", isOn: $viewModel.dailyRemindersEnabled)
            Stepper("Shopping budget: $\(viewModel.budgetUSD)",
                    value: $viewModel.budgetUSD, in: 25...1000, step: 25)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Cloud sync")
                Spacer()
                Text(viewModel.cloudSyncEnabled ? "On" : "Local only")
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            NavigationLink("Privacy") { PrivacyPolicyView() }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(DS.Colors.textSecondary)
        }
    }
}
