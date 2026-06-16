import SwiftUI

/// Review screen: shows the segmented garment and predicted tags, all editable before saving
/// (spec §5.1). When the on-device model is unsure, a banner nudges the user to confirm tags.
struct ItemReviewView: View {
    @ObservedObject var viewModel: AddItemViewModel
    let onSave: () async -> Void

    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                imagePreview
            }

            if viewModel.needsManualTags {
                Section {
                    Label("Please confirm the tags below — we couldn't detect them confidently.",
                          systemImage: "exclamationmark.triangle")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Details") {
                TextField("Name", text: $viewModel.draft.name)
                Picker("Category", selection: $viewModel.draft.category) {
                    ForEach(ClothingCategory.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Pattern", selection: $viewModel.draft.pattern) {
                    ForEach(ClothingPattern.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Formality", selection: $viewModel.draft.formality) {
                    ForEach(FormalityLevel.allCases) { Text($0.displayName).tag($0) }
                }
            }

            Section("Colors") {
                colorChips
            }

            Section("Seasons") {
                seasonToggles
            }

            Section("Optional") {
                TextField("Brand", text: Binding(
                    get: { viewModel.draft.brand ?? "" },
                    set: { viewModel.draft.brand = $0.isEmpty ? nil : $0 }
                ))
                TextField("Notes", text: Binding(
                    get: { viewModel.draft.notes ?? "" },
                    set: { viewModel.draft.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
            }

            Section {
                Button {
                    isSaving = true
                    Task { await onSave(); isSaving = false }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView() } else { Text("Save to Closet").bold() }
                        Spacer()
                    }
                }
                .disabled(isSaving || viewModel.draft.name.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image = viewModel.segmentedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .listRowBackground(DS.Colors.accent)
        }
    }

    private var colorChips: some View {
        HStack {
            ForEach(viewModel.draft.color, id: \.self) { hex in
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.secondary.opacity(0.3)))
                    Text(hex).font(DS.Typography.caption).monospaced()
                }
            }
            if viewModel.draft.color.isEmpty {
                Text("No colors detected").font(DS.Typography.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var seasonToggles: some View {
        ForEach(Season.allCases) { season in
            Toggle(season.displayName, isOn: Binding(
                get: { viewModel.draft.season.contains(season) },
                set: { isOn in
                    if isOn {
                        if !viewModel.draft.season.contains(season) { viewModel.draft.season.append(season) }
                    } else {
                        viewModel.draft.season.removeAll { $0 == season }
                    }
                }
            ))
        }
    }
}
