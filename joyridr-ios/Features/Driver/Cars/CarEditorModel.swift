import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Add or edit one car. Number fields are kept as text while typing and checked on save.
@Observable
final class CarEditorModel {
    /// A photo picked for a car that doesn't exist yet; uploaded right after the car is created.
    struct PendingPhoto: Identifiable {
        let id = UUID()
        let jpeg: Data
        let preview: UIImage
    }

    static let maxPhotos = 12

    private(set) var car: CarDetail?

    var make = ""
    var model = ""
    var year = ""
    var color = ""
    var category: CarCategory = .sportsCar
    var transmission: Transmission = .automatic
    var horsepower = ""
    var zeroToHundred = ""
    var topSpeed = ""
    var seats = 1
    var pricePerHour = ""
    var description = ""
    var licensePlate = ""
    var isActive = true

    private(set) var photos: [CarPhoto] = []
    private(set) var pendingPhotos: [PendingPhoto] = []
    private(set) var uploadingCount = 0
    private(set) var isSaving = false
    private(set) var isDeleting = false
    var errorMessage: String?

    /// The car's details as they were loaded (or last saved), to tell whether the driver changed anything.
    private var savedValues: EditableValues?

    private let cars: CarsService

    init(car: CarDetail?, cars: CarsService = CarsService()) {
        self.cars = cars
        guard let car else { return }
        self.car = car
        make = car.make
        model = car.model
        year = String(car.year)
        color = car.color
        category = car.category
        transmission = car.transmission
        horsepower = String(car.horsepower)
        zeroToHundred = car.zeroToHundredSeconds.map { "\($0)" } ?? ""
        topSpeed = car.topSpeedKmh.map(String.init) ?? ""
        seats = car.passengerSeats
        pricePerHour = "\(car.pricePerHour)"
        description = car.description ?? ""
        licensePlate = car.licensePlate ?? ""
        isActive = car.isActive
        photos = car.photos.sorted { $0.sortOrder < $1.sortOrder }
        savedValues = currentValues
    }

    var isNew: Bool { car == nil }
    var photoCount: Int { photos.count + pendingPhotos.count }
    var canAddPhotos: Bool { photoCount + uploadingCount < Self.maxPhotos }

    /// False while an existing car's details match what's saved, so "Save changes" has nothing to save.
    /// Photos don't count: they're uploaded the moment they're picked. A new car can always be saved.
    var hasChanges: Bool {
        guard let savedValues else { return true }
        return currentValues != savedValues
    }

    // MARK: Photos

    /// Existing cars upload straight away; new cars keep the photos until the car is saved.
    func addPhotos(_ items: [PhotosPickerItem]) async {
        for item in items.prefix(Self.maxPhotos - photoCount - uploadingCount) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  // At most 2000 px; the backend allows 10 MB per photo.
                  let (jpeg, preview) = JPEGImage.prepare(data, maxSide: 2000) else {
                errorMessage = t("cars.editor.error_photo_read")
                continue
            }
            if let car {
                uploadingCount += 1
                do {
                    photos.append(try await cars.uploadPhoto(car.id, jpeg: jpeg))
                } catch {
                    errorMessage = error.localizedDescription
                }
                uploadingCount -= 1
            } else {
                pendingPhotos.append(PendingPhoto(jpeg: jpeg, preview: preview))
            }
        }
    }

    func remove(_ photo: CarPhoto) async {
        guard let car else { return }
        do {
            try await cars.deletePhoto(car.id, photoID: photo.id)
            photos.removeAll { $0.id == photo.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ photo: PendingPhoto) {
        pendingPhotos.removeAll { $0.id == photo.id }
    }

    // MARK: Save / delete

    /// Returns true when the sheet can close.
    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        guard let request = validatedRequest() else { return false }

        isSaving = true
        defer { isSaving = false }
        do {
            if let car {
                self.car = try await cars.update(car.id, request)
                savedValues = currentValues
                return true
            }
            let created = try await cars.create(request)
            car = created
            var failed = 0
            for photo in pendingPhotos {
                do {
                    photos.append(try await cars.uploadPhoto(created.id, jpeg: photo.jpeg))
                } catch {
                    failed += 1
                }
            }
            pendingPhotos = []
            if failed > 0 {
                // The car exists now, so the sheet switches to editing it and the driver can retry.
                errorMessage = t("cars.editor.error_photo_upload", count: failed)
                return false
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete() async -> Bool {
        guard let car, !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await cars.delete(car.id)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: Helpers

    /// Every field the editor can change, side by side, so two sets can be compared with `!=`.
    private struct EditableValues: Equatable {
        let make, model, year, color: String
        let category: CarCategory
        let transmission: Transmission
        let horsepower, zeroToHundred, topSpeed: String
        let seats: Int
        let pricePerHour, description, licensePlate: String
        let isActive: Bool
    }

    private var currentValues: EditableValues {
        EditableValues(
            make: make, model: model, year: year, color: color, category: category, transmission: transmission,
            horsepower: horsepower, zeroToHundred: zeroToHundred, topSpeed: topSpeed, seats: seats,
            pricePerHour: pricePerHour, description: description, licensePlate: licensePlate, isActive: isActive)
    }

    /// Checks the fields with the same limits as the backend, so mistakes show up right away.
    private func validatedRequest() -> UpsertCarRequest? {
        let trimmedMake = make.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        let trimmedColor = color.trimmingCharacters(in: .whitespaces)
        let maxYear = Calendar.current.component(.year, from: .now) + 1

        guard !trimmedMake.isEmpty, !trimmedModel.isEmpty else { return fail(t("cars.editor.error_make")) }
        guard let yearValue = Int(year), (1950...maxYear).contains(yearValue) else { return fail(t("cars.editor.error_year", ["max": maxYear])) }
        guard !trimmedColor.isEmpty else { return fail(t("cars.editor.error_colour")) }
        guard let hp = Int(horsepower), (1...3000).contains(hp) else { return fail(t("cars.editor.error_power")) }

        let acceleration = Self.decimal(zeroToHundred)
        if !zeroToHundred.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let acceleration, acceleration >= 1, acceleration <= 30 else { return fail(t("cars.editor.error_acceleration")) }
        }
        let speed = Int(topSpeed)
        if !topSpeed.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let speed, (50...600).contains(speed) else { return fail(t("cars.editor.error_top_speed")) }
        }
        guard let price = Self.decimal(pricePerHour), price >= 1, price <= 100_000 else { return fail(t("cars.editor.error_price")) }

        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlate = licensePlate.trimmingCharacters(in: .whitespaces)
        return UpsertCarRequest(
            make: trimmedMake, model: trimmedModel, year: yearValue, color: trimmedColor,
            category: category, transmission: transmission, horsepower: hp,
            zeroToHundredSeconds: acceleration, topSpeedKmh: speed, passengerSeats: seats,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            licensePlate: trimmedPlate.isEmpty ? nil : trimmedPlate,
            pricePerHour: price, currency: car?.currency ?? "EUR", isActive: isActive)
    }

    private func fail(_ message: String) -> UpsertCarRequest? {
        errorMessage = message
        return nil
    }

    /// Accepts "3.4" and "3,4" (Croatian keyboards type a comma).
    private static func decimal(_ text: String) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return cleaned.isEmpty ? nil : Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }
}
