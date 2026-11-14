import Foundation
import Observation

/// The languages the app is translated into. Each has a JSON file in `Localization/` (en.json, hr.json).
nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case en, hr

    var id: String { rawValue }

    /// The language's name in that language, as shown in the picker ("English", "Hrvatski").
    var nativeName: String {
        switch self {
        case .en: "English"
        case .hr: "Hrvatski"
        }
    }

    /// Used for dates, numbers and system controls, e.g. "pet, 13. stu" in Croatian.
    var locale: Locale {
        switch self {
        case .en: Locale(identifier: "en_GB")
        case .hr: Locale(identifier: "hr_HR")
        }
    }
}

/// Angular-style translations: one JSON file per language, looked up by key, e.g.
/// `t("auth.login.title")` or `t("rides.with_driver", ["name": driver])` for "Ride with {{name}}".
///
/// The JSON can be nested; `{"auth": {"login": {"title": "Log in"}}}` is the key `auth.login.title`.
/// A plural is an object with `one`, `few` and `other` (Croatian needs all three; English uses `one`
/// and `other`), looked up with `t("key", count: n)`, which also fills in `{{count}}`.
///
/// It's `@Observable`: a view that calls `t(...)` redraws by itself when the language changes, because
/// every lookup reads `language`. It's also usable off the main thread (models have display titles too),
/// so the loaded tables sit behind a lock; `language` itself is only changed from the main thread.
@Observable
nonisolated final class Localizer: @unchecked Sendable {
    static let shared = Localizer()

    /// Changing it switches the whole app at once and remembers the choice.
    var language: AppLanguage {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
            let table = language == .en ? english : Self.load(language)
            lock.withLock { _strings = table }
        }
    }

    var locale: Locale { language.locale }

    @ObservationIgnored private let lock = NSLock()
    @ObservationIgnored private var _strings: [String: Entry]
    /// English is the fallback for keys missing from another language.
    @ObservationIgnored private let english: [String: Entry]

    private static let storageKey = "appLanguage"

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey).flatMap(AppLanguage.init(rawValue:))
        // First launch: Croatian if the iPhone prefers it, otherwise English.
        let phone = Locale.preferredLanguages.first.map { $0.hasPrefix("hr") ? AppLanguage.hr : .en } ?? .en
        let language = saved ?? phone
        english = Self.load(.en)
        _strings = language == .en ? english : Self.load(language)
        self.language = language
    }

    /// The entry for a key in the current language, falling back to English.
    private func entry(_ key: String) -> Entry? {
        _ = language // registers the dependency, so views redraw when the language changes
        return lock.withLock { _strings[key] } ?? english[key]
    }

    /// The translation if this key exists, e.g. for optional keys like `errors.server.<code>`.
    func translation(_ key: String, _ args: [String: Any] = [:]) -> String? {
        entry(key) == nil ? nil : t(key, args)
    }

    func t(_ key: String, _ args: [String: Any] = [:]) -> String {
        guard let entry = entry(key) else { return missing(key) }
        switch entry {
        case let .text(text):
            return Self.fill(text, args)
        case let .plural(forms):
            // A plural key used without a count: take its "other" form.
            return Self.fill(forms["other"] ?? key, args)
        }
    }

    func t(_ key: String, count: Int, _ args: [String: Any] = [:]) -> String {
        guard let entry = entry(key) else { return missing(key) }
        var args = args
        args["count"] = count
        switch entry {
        case let .text(text):
            return Self.fill(text, args)
        case let .plural(forms):
            let form = forms[pluralCategory(count)] ?? forms["other"] ?? key
            return Self.fill(form, args)
        }
    }

    /// Croatian: 1, 21, 31… → one; 2–4, 22–24… → few; the rest (5–20, 11–14…) → other.
    private func pluralCategory(_ n: Int) -> String {
        let n = abs(n)
        switch language {
        case .en:
            return n == 1 ? "one" : "other"
        case .hr:
            if n % 10 == 1 && n % 100 != 11 { return "one" }
            if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return "few" }
            return "other"
        }
    }

    private func missing(_ key: String) -> String {
        #if DEBUG
        print("⚠️ Missing translation: \(key)")
        #endif
        return key
    }

    // MARK: - Loading

    enum Entry: Equatable {
        case text(String)
        case plural([String: String])
    }

    /// Replaces each `{{name}}` with its value.
    private static func fill(_ text: String, _ args: [String: Any]) -> String {
        guard !args.isEmpty, text.contains("{{") else { return text }
        var result = text
        for (name, value) in args {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: "\(value)")
        }
        return result
    }

    static func load(_ language: AppLanguage, bundle: Bundle = .main) -> [String: Entry] {
        guard let url = bundle.url(forResource: language.rawValue, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            assertionFailure("Couldn't read \(language.rawValue).json")
            return [:]
        }
        var table: [String: Entry] = [:]
        flatten(json, prefix: "", into: &table)
        return table
    }

    /// Turns nested objects into dotted keys. An object whose keys are all plural forms is one plural entry.
    private static func flatten(_ object: [String: Any], prefix: String, into table: inout [String: Entry]) {
        for (name, value) in object {
            let key = prefix.isEmpty ? name : "\(prefix).\(name)"
            if let text = value as? String {
                table[key] = .text(text)
            } else if let nested = value as? [String: Any] {
                if let forms = nested as? [String: String], !forms.isEmpty, Set(forms.keys).isSubset(of: pluralForms) {
                    table[key] = .plural(forms)
                } else {
                    flatten(nested, prefix: key, into: &table)
                }
            }
        }
    }

    private static let pluralForms: Set<String> = ["zero", "one", "two", "few", "many", "other"]
}

/// Shorthand used throughout the app: `Text(t("profile.title"))`.
nonisolated func t(_ key: String, _ args: [String: Any] = [:]) -> String {
    Localizer.shared.t(key, args)
}

/// Plural shorthand: `t("rides.count", count: 3)` → "3 rides" / "3 vožnje".
nonisolated func t(_ key: String, count: Int, _ args: [String: Any] = [:]) -> String {
    Localizer.shared.t(key, count: count, args)
}

nonisolated extension Date {
    /// Formats in the app's language rather than the iPhone's, e.g. `date.localized(.dateTime.weekday())`.
    func localized(_ style: Date.FormatStyle) -> String {
        formatted(style.locale(Localizer.shared.locale))
    }

    func localized(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(Localizer.shared.locale))
    }
}
