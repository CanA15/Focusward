import XCTest

final class BundleResourcesTests: XCTestCase {
    func testApplicationIconIsBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "AppIcon", withExtension: "icns"))
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String, "AppIcon")
    }

    func testShieldPageUsesBundledFocuswardLogo() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blocked", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)

        XCTAssertNotNil(Bundle.main.url(forResource: "FocuswardLogo", withExtension: "png"))
        XCTAssertTrue(html.contains("<img src=\"FocuswardLogo.png\""))
        XCTAssertTrue(html.contains("img-src 'self'"))
        XCTAssertFalse(html.contains(">F</div>"))
        XCTAssertFalse(html.contains("<svg"))
    }

    func testShieldPageExplainsDailyLimitBreaks() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blocked", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(html.contains("params.get(\"mode\")"))
        XCTAssertTrue(html.contains("params.get(\"left\")"))
        XCTAssertTrue(html.contains("Open Focusward to take a break"))
        XCTAssertTrue(html.contains("No break time left today"))
        XCTAssertTrue(html.contains("params.get(\"session\")"))
        XCTAssertTrue(html.contains("You can take a break after the focus session ends."))
        XCTAssertFalse(html.contains("You can open the website"))
    }
}
