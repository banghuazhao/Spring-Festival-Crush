import XCTest
@testable import SpringFestivalCrush

@MainActor
final class SpeechAccessibilityPreferenceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let saved = UserDefaults.standard.object(forKey: BoardSpeechDetail.preferenceKey)
        addTeardownBlock {
            if let saved {
                UserDefaults.standard.set(saved, forKey: BoardSpeechDetail.preferenceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: BoardSpeechDetail.preferenceKey)
            }
        }
        UserDefaults.standard.removeObject(forKey: BoardSpeechDetail.preferenceKey)
    }

    func testAbsentAndUnrecognizedPreferencesKeepDetailedAnnouncements() {
        XCTAssertEqual(BoardSpeechDetail.saved, .detailed)
        XCTAssertEqual(SettingModel().boardSpeechDetail, .detailed)

        UserDefaults.standard.set("unrecognized", forKey: BoardSpeechDetail.preferenceKey)
        XCTAssertEqual(BoardSpeechDetail.saved, .detailed)
        XCTAssertEqual(SettingModel().boardSpeechDetail, .detailed)
    }

    func testChangesPersistAndLoadInTheNextSettingsInstance() {
        let settings = SettingModel()
        settings.boardSpeechDetail = .brief
        XCTAssertEqual(BoardSpeechDetail.saved, .brief)
        XCTAssertEqual(SettingModel().boardSpeechDetail, .brief)

        settings.boardSpeechDetail = .detailed
        XCTAssertEqual(BoardSpeechDetail.saved, .detailed)
        XCTAssertEqual(SettingModel().boardSpeechDetail, .detailed)
    }

    func testSpeechAndKeyboardCopyExistsWithMatchingArgumentsInEveryLanguage() throws {
        let keys = ["Brief", "Detailed", "Board announcements", "Repeat last move result", "Row %lld",
                    "%lld moves left. %lld goal pieces remaining.", "Move to tile above", "Move to tile below",
                    "Move to tile on left", "Move to tile on right", "Select or swap tile",
                    "With a keyboard, use arrow keys to explore, Return or Space to select and swap, and Escape to cancel.",
                    "Brief announcements read essential move results. Detailed announcements also describe progress for each goal. You can always read board status or repeat the last move result."]
        for language in ["en", "zh-Hans", "zh-Hant"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                                                   subdirectory: nil, localization: language))
            let strings = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url),
                                                                               format: nil) as? [String: String])
            for key in keys {
                let translated = try XCTUnwrap(strings[key], "\(language): \(key)")
                XCTAssertFalse(translated.isEmpty)
                XCTAssertEqual(translated.components(separatedBy: "%lld").count,
                               key.components(separatedBy: "%lld").count)
                if language != "en" { XCTAssertNotEqual(translated, key) }
            }
        }
    }
}
