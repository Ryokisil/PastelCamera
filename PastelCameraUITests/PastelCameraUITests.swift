//
//  PastelCameraUITests.swift
//  PastelCameraUITests
//
//  Created by silvia on 2024/11/05.
//

import XCTest

final class PastelCameraUITests: XCTestCase {
    func testCameraViewFilterButton() {
        let app = XCUIApplication()
        app.launch()

        // カメラ画面に遷移
        app.buttons["OpenCamera"].tap()

        // フィルターボタンをタップ
        let filterButton = app.buttons["FilterButton"]
        XCTAssertTrue(filterButton.exists, "Filter button should exist")
        filterButton.tap()

        // フィルターが適用されているか確認（ラベルなどで確認可能）
        let filterAppliedLabel = app.staticTexts["FilterApplied"]
        XCTAssertTrue(filterAppliedLabel.exists, "Filter applied label should appear after applying filter")
    }
}
