import XCTest
@testable import Focusward

final class QuitPolicyTests: XCTestCase {
    private let systemQuitReasons = [
        kAELogOut,
        kAEReallyLogOut,
        kAEShowRestartDialog,
        kAERestart,
        kAEShowShutdownDialog,
        kAEShutDown,
    ].map { OSType($0) }

    func testAllowsAQuitWhenNothingIsActive() {
        XCTAssertEqual(
            QuitPolicy.decision(quitReason: nil, isSessionActive: false, isDailyLimitsActive: false),
            .allow
        )
    }

    func testRefusesAnOrdinaryQuitDuringASession() {
        XCTAssertEqual(
            QuitPolicy.decision(quitReason: nil, isSessionActive: true, isDailyLimitsActive: true),
            .refuse(
                title: "A focus session is active",
                message: "To quit Focusward, end the session early in the Focus Session section first."
            )
        )
    }

    func testRefusesAnOrdinaryQuitWhileDailyLimitsAreActive() {
        XCTAssertEqual(
            QuitPolicy.decision(quitReason: nil, isSessionActive: false, isDailyLimitsActive: true),
            .refuse(
                title: "Daily Limits are active",
                message: "To quit Focusward, turn off Daily Limits in the Daily Limits section first."
            )
        )
    }

    func testAllowsALogoutRestartOrShutdownDuringProtection() {
        for reason in systemQuitReasons {
            XCTAssertEqual(
                QuitPolicy.decision(quitReason: reason, isSessionActive: true, isDailyLimitsActive: true),
                .allow
            )
        }
    }

    func testRefusesAQuitWithAnotherReasonDuringProtection() {
        XCTAssertNotEqual(
            QuitPolicy.decision(
                quitReason: OSType(kAEQuitApplication),
                isSessionActive: true,
                isDailyLimitsActive: false
            ),
            .allow
        )
    }
}
