import PhotosUI
import SwiftUI

/// "NEW CAR" / "EDIT CAR": photos, details, performance, price and visibility.
/// Same look as the New ride sheet; opens from the tapped row or the Add car pill with a zoom transition.
struct CarEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: CarEditorModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var confirmDelete = false
    @State private var keyboardVisible = false

    init(car: CarDetail?) {
        _model = State(initialValue: CarEditorModel(car: car))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if let car = model.car {
                        CarStatusBanner(car: car)
                    }

                    BookingSection(t("cars.editor.photos")) { photoStrip }

                    BookingSection(t("booking.sent.car")) {
                        VStack(spacing: 0) {
                            EditorField(t("cars.editor.make"), text: $model.make, prompt: "Porsche")
                                .textInputAutocapitalization(.words)
                            EditorDivider()
                            EditorField(t("cars.editor.model"), text: $model.model, prompt: "911 GT3")
                                .textInputAutocapitalization(.words)
                            EditorDivider()
                            EditorField(t("cars.editor.year"), text: $model.year, prompt: "2023")
                                .keyboardType(.numberPad)
                            EditorDivider()
                            EditorField(t("cars.editor.colour"), text: $model.color, prompt: t("cars.editor.colour_prompt"))
                                .textInputAutocapitalization(.words)
                            EditorDivider()
                            VStack(alignment: .leading, spacing: 10) {
                                Text(t("cars.editor.category")).font(.subheadline).foregroundStyle(Theme.textSecondary)
                                Picker(t("cars.editor.category"), selection: $model.category) {
                                    ForEach(CarCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.vertical, 12)
                            EditorDivider()
                            VStack(alignment: .leading, spacing: 10) {
                                Text(t("cars.editor.gearbox")).font(.subheadline).foregroundStyle(Theme.textSecondary)
                                Picker(t("cars.editor.gearbox"), selection: $model.transmission) {
                                    ForEach(Transmission.allCases, id: \.self) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(.vertical, 12)
                        }
                    }

                    BookingSection(t("cars.editor.performance")) {
                        VStack(spacing: 0) {
                            EditorField(t("cars.editor.power"), text: $model.horsepower, prompt: "510", suffix: t("cars.spec.hp"))
                                .keyboardType(.numberPad)
                            EditorDivider()
                            EditorField("0–100 km/h", text: $model.zeroToHundred, prompt: "3.4", suffix: "s")
                                .keyboardType(.decimalPad)
                            EditorDivider()
                            EditorField(t("cars.editor.top_speed"), text: $model.topSpeed, prompt: "318", suffix: "km/h")
                                .keyboardType(.numberPad)
                        }
                    }

                    BookingSection(t("ride.driver.title")) {
                        VStack(spacing: 0) {
                            EditorField(t("ride.price"), text: $model.pricePerHour, prompt: "180", suffix: "€/h")
                                .keyboardType(.decimalPad)
                            EditorDivider()
                            Stepper(value: $model.seats, in: 1...8) {
                                HStack {
                                    Text(t("cars.editor.seats")).foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Text("\(model.seats)").monospacedDigit()
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }

                    BookingSection(t("cars.editor.about")) {
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("", text: $model.description,
                                      prompt: Text(t("cars.editor.about_prompt")).foregroundStyle(Theme.textSecondary),
                                      axis: .vertical)
                                .lineLimit(3...6)
                                .padding(.vertical, 10)
                            EditorDivider()
                            EditorField(t("cars.editor.plate"), text: $model.licensePlate, prompt: "ZG-1234-AB")
                                .textInputAutocapitalization(.characters)
                            Text(t("cars.editor.plate_note"))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.bottom, 4)
                        }
                    }

                    BookingSection(t("cars.editor.visibility")) {
                        Toggle(isOn: $model.isActive) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("cars.editor.show"))
                                Text(model.isActive ? t("cars.editor.show_on") : t("cars.editor.show_off"))
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .tint(Theme.accentRed)
                    }

                    if !model.isNew {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            if model.isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Text(t("cars.editor.delete")).foregroundStyle(Theme.accentRed)
                            }
                        }
                        .buttonStyle(.secondary)
                        .disabled(model.isDeleting)
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                if !keyboardVisible { bottomBar }
            }
            .trackKeyboard($keyboardVisible)
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(model.isNew ? t("cars.editor.new_title") : t("cars.editor.edit_title")).displayTitle(18)
                }
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(t("common.done")) { hideKeyboard() }
                }
            }
            .animation(.snappy, value: model.photoCount)
            .animation(.snappy, value: model.errorMessage)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await model.addPhotos(items)
                pickerItems = []
            }
        }
        .confirmationDialog(t("cars.editor.delete_title"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(t("cars.editor.delete"), role: .destructive) {
                Task { if await model.delete() { dismiss() } }
            }
        } message: {
            Text(t("cars.editor.delete_message"))
        }
    }

    // MARK: Photos

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Array(model.photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoTile(isCover: index == 0) {
                            RemoteImage(path: photo.url)
                        } onRemove: {
                            Task { await model.remove(photo) }
                        }
                    }
                    ForEach(Array(model.pendingPhotos.enumerated()), id: \.element.id) { index, photo in
                        PhotoTile(isCover: model.photos.isEmpty && index == 0) {
                            Image(uiImage: photo.preview).resizable().scaledToFill()
                        } onRemove: {
                            model.remove(photo)
                        }
                    }
                    ForEach(0..<model.uploadingCount, id: \.self) { _ in
                        ProgressView()
                            .frame(width: 96, height: 96)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    }
                    if model.canAddPhotos {
                        PhotosPicker(selection: $pickerItems,
                                     maxSelectionCount: CarEditorModel.maxPhotos - model.photoCount - model.uploadingCount,
                                     matching: .images) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.title2.weight(.semibold))
                                Text(t("cars.editor.add_photo"))
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5])))
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            Text(model.photoCount == 0
                 ? t("cars.editor.photos_hint_empty")
                 : t("cars.editor.photos_hint", ["count": model.photoCount, "max": CarEditorModel.maxPhotos]))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            FormError(message: model.errorMessage)
            Button(model.isNew ? t("cars.add") : t("cars.editor.save")) {
                Task { if await model.save() { dismiss() } }
            }
            .buttonStyle(.primary(isLoading: model.isSaving))
            // Greyed out until something is edited; undoing the edit greys it out again.
            .disabled(model.isSaving || !model.hasChanges)

            Text(model.isNew
                 ? t("cars.editor.review_note_new")
                 : t("cars.editor.review_note_edit"))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Label on the left, value on the right, optional unit after it. Used for every text row in the editor.
private struct EditorField: View {
    let label: String
    @Binding var text: String
    let prompt: String
    var suffix: String?

    init(_ label: String, text: Binding<String>, prompt: String, suffix: String? = nil) {
        self.label = label
        _text = text
        self.prompt = prompt
        self.suffix = suffix
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 12)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Theme.textSecondary.opacity(0.6)))
                .multilineTextAlignment(.trailing)
                .autocorrectionDisabled()
            if let suffix {
                Text(suffix)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct EditorDivider: View {
    var body: some View {
        Divider().overlay(.white.opacity(0.1))
    }
}

/// A square photo with a remove button and an optional "Cover" label.
private struct PhotoTile<Content: View>: View {
    let isCover: Bool
    @ViewBuilder var content: Content
    let onRemove: () -> Void

    var body: some View {
        content
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .bottomLeading) {
                if isCover {
                    Text(t("cars.editor.cover"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.brandRed, in: Capsule())
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .padding(4)
                .accessibilityLabel(t("cars.editor.remove_photo"))
            }
    }
}

/// What the review status means and what the driver can do about it.
private struct CarStatusBanner: View {
    let car: CarDetail

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch car.status {
        case .pendingReview: "hourglass"
        case .rejected: "xmark.seal.fill"
        case .approved: car.isActive ? "checkmark.seal.fill" : "eye.slash.fill"
        }
    }

    private var color: Color {
        switch car.status {
        case .pendingReview: .orange
        case .rejected: Theme.accentRed
        case .approved: car.isActive ? Theme.available : Theme.textSecondary
        }
    }

    private var title: String {
        switch car.status {
        case .pendingReview: t("cars.status.waiting")
        case .rejected: t("cars.status.not_approved")
        case .approved: car.isActive ? t("cars.status.live") : t("cars.status.hidden")
        }
    }

    private var message: String {
        switch car.status {
        case .pendingReview:
            return t("cars.status.waiting_message")
        case .rejected:
            let reason = car.rejectionReason.flatMap { $0.isEmpty ? nil : "“\($0)” " } ?? ""
            return reason + t("cars.status.rejected_message")
        case .approved:
            return car.isActive ? t("cars.status.live_message") : t("cars.status.hidden_message")
        }
    }
}
