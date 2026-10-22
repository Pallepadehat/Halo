import XCTest

/// Drives edit mode the way a person does, on the demo layout. UI tests use XCTest: Swift Testing
/// doesn't drive XCUIApplication yet.
final class EditModeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(page: Int) {
        app.launchArguments = ["-HaloDemo", "\(page)", "-HaloDemoEditing"]
        app.launch()
    }

    /// Tap −, confirm, and the widget is gone.
    private func remove(_ title: String) {
        let removeButton = app.buttons["Remove \(title)"]
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5), "No remove button for \(title)")
        removeButton.tap()

        let confirm = app.buttons["Remove Widget"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "No confirmation for \(title)")
        confirm.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: removeButton)
        wait(for: [gone], timeout: 3)
    }

    func testRemovingAWidget() {
        launch(page: 0)
        remove("Clock")
    }

    /// The Deck has settings, whose tap target once sat above the remove button and swallowed it.
    func testRemovingAWidgetWithSettings() {
        launch(page: 3)
        remove("Deck")
        remove("Trackpad")
    }

    func testTappingAWidgetWithSettingsOpensThem() {
        launch(page: 3)
        let edit = app.buttons["Edit Deck"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.navigationBars["Deck"].waitForExistence(timeout: 3))
    }
}
