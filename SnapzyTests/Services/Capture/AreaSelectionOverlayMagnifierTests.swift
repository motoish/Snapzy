//
//  AreaSelectionOverlayMagnifierTests.swift
//  SnapzyTests
//
//  Unit tests for magnifier zoom-state mechanics: scroll-wheel input, min/max
//  clamping, and reverse-direction setting.
//

import XCTest
import AppKit
@testable import Snapzy

final class AreaSelectionOverlayMagnifierTests: AreaSelectionOverlayTestCase {

  func testMagnifierZoom_scrollWheelAndLimits() {
    // GIVEN: A valid backdrop
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // WHEN: Scrolling with Command modifier
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)

    // THEN: Zoom should increase beyond 1.0 and magnifier layers should be created
    XCTAssertGreaterThan(overlayView.testMagnifierZoom, 1.0)

    guard let containerLayer = overlayView.testMagnifierContainerLayer else {
      XCTFail("magnifierContainerLayer not found")
      return
    }
    XCTAssertFalse(containerLayer.isHidden)

    // WHEN: Scrolling back down below 1.0
    overlayView.testScrollWheel(deltaY: -5.0, modifierFlags: .command)

    // THEN: Zoom clamps to 1.0 and magnifier layers are removed
    XCTAssertEqual(overlayView.testMagnifierZoom, 1.0)
    XCTAssertNil(overlayView.testMagnifierContainerLayer)
  }

  func testMagnifierZoom_reverseDirection() {
    let image = createSolidColorImage(color: .white, size: CGSize(width: 800, height: 600))
    let backdrop = AreaSelectionBackdrop(displayID: 0, image: image, scaleFactor: 1.0)
    overlayView.applyBackdrop(backdrop)

    // 1. GIVEN: Reverse zoom direction is OFF (false)
    overlayView.testReverseMagnifierZoomDirection = false
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)
    // Zoom should increase (1.0 + 1.0 = 2.0)
    XCTAssertEqual(overlayView.testMagnifierZoom, 2.0)

    // Reset zoom
    overlayView.clearBackdrop()
    overlayView.applyBackdrop(backdrop)

    // 2. GIVEN: Reverse zoom direction is ON (true)
    overlayView.testReverseMagnifierZoomDirection = true
    overlayView.testScrollWheel(deltaY: 1.0, modifierFlags: .command)
    // Zoom should decrease (but clamps at min zoom 1.0)
    XCTAssertEqual(overlayView.testMagnifierZoom, 1.0)

    // Scroll with negative delta (meaning zoom out under normal, so zoom in under reversed)
    overlayView.testScrollWheel(deltaY: -1.0, modifierFlags: .command)
    // Zoom should increase (1.0 + 1.0 = 2.0)
    XCTAssertEqual(overlayView.testMagnifierZoom, 2.0)
  }
}
