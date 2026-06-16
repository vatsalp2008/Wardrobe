import SwiftUI

/// Split-screen compare (spec §5.3 / §7.3): drag the divider to reveal the try-on over the
/// original. Save-to-Photos and share-sheet actions.
struct TryOnResultView: View {
    let original: UIImage
    let rendered: UIImage

    @State private var reveal: CGFloat = 0.5
    @State private var savedConfirmation = false

    var body: some View {
        VStack(spacing: DS.Spacing.m) {
            comparison
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                .padding(DS.Spacing.m)

            HStack(spacing: DS.Spacing.m) {
                Button {
                    UIImageWriteToSavedPhotosAlbum(rendered, nil, nil, nil)
                    savedConfirmation = true
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.s)
                }
                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
                .foregroundStyle(DS.Colors.primary)

                ShareLink(item: Image(uiImage: rendered),
                          preview: SharePreview("Wardrobe Try-On", image: Image(uiImage: rendered))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.s)
                }
                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.chip))
                .foregroundStyle(DS.Colors.primary)
            }
            .padding(.horizontal, DS.Spacing.m)
        }
        .navigationTitle("Try-On")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Saved to Photos", isPresented: $savedConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private var comparison: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image(uiImage: original)
                    .resizable().scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                Image(uiImage: rendered)
                    .resizable().scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: geo.size.width * reveal)
                    }

                // Divider handle.
                Rectangle()
                    .fill(.white)
                    .frame(width: 3)
                    .offset(x: geo.size.width * reveal - 1.5)
                    .overlay(
                        Image(systemName: "arrow.left.and.right.circle.fill")
                            .foregroundStyle(.white)
                            .background(Circle().fill(DS.Colors.primary))
                            .offset(x: geo.size.width * reveal - 12, y: geo.size.height / 2 - 12)
                    )

                labels(width: geo.size.width)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        reveal = min(1, max(0, value.location.x / geo.size.width))
                    }
            )
        }
        .aspectRatio(original.size.width / original.size.height, contentMode: .fit)
    }

    private func labels(width: CGFloat) -> some View {
        HStack {
            Text("Original").font(DS.Typography.caption.weight(.semibold))
                .padding(6).background(.black.opacity(0.4), in: Capsule()).foregroundStyle(.white)
            Spacer()
            Text("Try-On").font(DS.Typography.caption.weight(.semibold))
                .padding(6).background(DS.Colors.primary.opacity(0.8), in: Capsule()).foregroundStyle(.white)
        }
        .padding(DS.Spacing.s)
    }
}
