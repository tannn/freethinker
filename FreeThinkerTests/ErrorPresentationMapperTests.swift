import XCTest
@testable import FreeThinker

final class ErrorPresentationMapperTests: XCTestCase {
    func testAccessibilityErrorIncludesTranslocationGuidanceWhenDetected() {
        let mapper = ErrorPresentationMapper(isTranslocatedProvider: { true })

        let presentation = mapper.map(
            error: .accessibilityPermissionDenied,
            source: .hotkey
        )

        XCTAssertTrue(presentation.message.contains("Move it to /Applications"))
        XCTAssertEqual(presentation.action, .openAccessibilitySettings)
    }

    func testAccessibilityErrorKeepsBaselineMessageWhenNotTranslocated() {
        let mapper = ErrorPresentationMapper(isTranslocatedProvider: { false })

        let presentation = mapper.map(
            error: .accessibilityPermissionDenied,
            source: .hotkey
        )

        XCTAssertEqual(
            presentation.message,
            "FreeThinker needs Accessibility access. Open Settings -> Privacy & Security -> Accessibility, then enable FreeThinker."
        )
    }
}
