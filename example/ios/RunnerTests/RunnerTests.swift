import Flutter
import UIKit
import XCTest

@testable import itchi_flutter_duo_layout

class RunnerTests: XCTestCase {
  func testSetItemsRequiresItems() {
    let channel = FlutterMethodChannel(
      name: "itchi_flutter_duo_layout/side_back",
      binaryMessenger: FlutterEngine(name: "test").binaryMessenger
    )
    let plugin = ItchiFlutterDuoLayoutPlugin(channel: channel)

    let call = FlutterMethodCall(methodName: "setItems", arguments: [:])
    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue(result is FlutterError)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
