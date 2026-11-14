import XCTest
@testable import joyridr_ios

/// Keeps en.json and hr.json in step: every key in both files, with the same {{placeholders}}.
final class LocalizationTests: XCTestCase {
    private let english = Localizer.load(.en)
    private let croatian = Localizer.load(.hr)

    func testBothLanguagesHaveTheSameKeys() {
        XCTAssertFalse(english.isEmpty, "en.json didn't load")
        let missingInCroatian = Set(english.keys).subtracting(croatian.keys).sorted()
        let missingInEnglish = Set(croatian.keys).subtracting(english.keys).sorted()
        XCTAssertEqual(missingInCroatian, [], "Keys missing from hr.json")
        XCTAssertEqual(missingInEnglish, [], "Keys missing from en.json")
    }

    func testPlaceholdersMatch() {
        for (key, entry) in english {
            guard let other = croatian[key] else { continue }
            XCTAssertEqual(placeholders(entry), placeholders(other), "Different {{placeholders}} in \(key)")
        }
    }

    func testCroatianPluralsHaveAllThreeForms() {
        for (key, entry) in croatian {
            if case let .plural(forms) = entry {
                XCTAssertTrue(Set(["one", "few", "other"]).isSubset(of: forms.keys), "\(key) needs one, few and other")
            }
        }
    }

    private func placeholders(_ entry: Localizer.Entry) -> Set<String> {
        let texts: [String] = switch entry {
        case let .text(text): [text]
        case let .plural(forms): Array(forms.values)
        }
        var names = Set<String>()
        for text in texts {
            var rest = text[...]
            while let open = rest.range(of: "{{"), let close = rest[open.upperBound...].range(of: "}}") {
                names.insert(String(rest[open.upperBound..<close.lowerBound]))
                rest = rest[close.upperBound...]
            }
        }
        return names.subtracting(["count"])
    }
}
