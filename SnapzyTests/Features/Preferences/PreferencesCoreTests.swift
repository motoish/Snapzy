//
//  PreferencesCoreTests.swift
//  SnapzyTests
//
//  Unit tests for persisted preferences value models.
//

import XCTest
@testable import Snapzy

final class PreferencesCoreTests: XCTestCase {

  func testCloudUploadFloatingPositionStored_readsValidValueAndFallsBackToDefault() throws {
    let defaults = try makeDefaults()
    XCTAssertEqual(CloudUploadFloatingPosition.stored(userDefaults: defaults), .center)

    defaults.set(CloudUploadFloatingPosition.top.rawValue, forKey: PreferencesKeys.cloudUploadsFloatingPosition)
    XCTAssertEqual(CloudUploadFloatingPosition.stored(userDefaults: defaults), .top)

    defaults.set("invalid", forKey: PreferencesKeys.cloudUploadsFloatingPosition)
    XCTAssertEqual(CloudUploadFloatingPosition.stored(userDefaults: defaults), .center)
  }

  func testHistoryBackgroundStyleStored_readsValidValueAndFallsBackToDefault() throws {
    let defaults = try makeDefaults()
    XCTAssertEqual(HistoryBackgroundStyle.currentStoredStyle(userDefaults: defaults), .hud)

    defaults.set(HistoryBackgroundStyle.solid.rawValue, forKey: PreferencesKeys.historyBackgroundStyle)
    XCTAssertEqual(HistoryBackgroundStyle.currentStoredStyle(userDefaults: defaults), .solid)

    defaults.set("invalid", forKey: PreferencesKeys.historyBackgroundStyle)
    XCTAssertEqual(HistoryBackgroundStyle.currentStoredStyle(userDefaults: defaults), .hud)
  }

  func testAnnotateClipboardImageBehaviorStored_readsValidValueAndFallsBackToAsk() throws {
    let defaults = try makeDefaults()
    XCTAssertEqual(AnnotateClipboardImageBehavior.stored(userDefaults: defaults), .ask)

    defaults.set(
      AnnotateClipboardImageBehavior.loadAutomatically.rawValue,
      forKey: PreferencesKeys.annotateClipboardImageOpenBehavior
    )
    XCTAssertEqual(AnnotateClipboardImageBehavior.stored(userDefaults: defaults), .loadAutomatically)

    defaults.set("invalid", forKey: PreferencesKeys.annotateClipboardImageOpenBehavior)
    XCTAssertEqual(AnnotateClipboardImageBehavior.stored(userDefaults: defaults), .ask)
  }

  func testAnnotateQuickPropertiesSyncPreference_defaultsToEnabled() throws {
    let defaults = try makeDefaults()
    XCTAssertTrue(AnnotateQuickPropertiesSyncPreference.isEnabled(userDefaults: defaults))

    defaults.set(false, forKey: PreferencesKeys.annotateQuickPropertiesSyncEnabled)
    XCTAssertFalse(AnnotateQuickPropertiesSyncPreference.isEnabled(userDefaults: defaults))

    defaults.set(true, forKey: PreferencesKeys.annotateQuickPropertiesSyncEnabled)
    XCTAssertTrue(AnnotateQuickPropertiesSyncPreference.isEnabled(userDefaults: defaults))
  }

  func testPreferencesTabsRemainUniqueAndHashable() {
    let tabs: Set<PreferencesTab> = [
      .general,
      .capture,
      .annotate,
      .quickAccess,
      .history,
      .shortcuts,
      .permissions,
      .cloud,
      .about,
    ]

    XCTAssertEqual(tabs.count, 9)
  }

  private func makeDefaults(
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> UserDefaults {
    let suiteName = "SnapzyTests.PreferencesCoreTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName), file: file, line: line)
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}
