//
//  SnapzyConfigurationServiceTests.swift
//  SnapzyTests
//
//  Tests for configuration file materialization.
//

import XCTest
@testable import Snapzy

@MainActor
final class SnapzyConfigurationServiceTests: XCTestCase {
  func testConfigFileURLAppendsConfigTomlToSelectedDirectory() {
    let directory = URL(fileURLWithPath: "/Users/example/.config/snapzy", isDirectory: true)

    let url = SnapzyConfigurationService.shared.configFileURL(inDirectory: directory)

    XCTAssertEqual(url.path, "/Users/example/.config/snapzy/config.toml")
  }

  func testSuggestedConfigDirectoryMatchingUsesCanonicalPath() {
    let expectedDirectory = SnapzyConfigurationPaths.suggestedConfigDirectoryURL

    XCTAssertTrue(SnapzyConfigurationService.shared.isSuggestedConfigDirectory(expectedDirectory))
    XCTAssertFalse(
      SnapzyConfigurationService.shared.isSuggestedConfigDirectory(
        expectedDirectory.deletingLastPathComponent()
      )
    )
  }

  func testSuggestedConfigParentDirectoryMatchingUsesCanonicalPath() {
    let expectedParentDirectory = SnapzyConfigurationPaths.suggestedConfigDirectoryURL
      .deletingLastPathComponent()

    XCTAssertTrue(SnapzyConfigurationService.shared.isSuggestedConfigParentDirectory(expectedParentDirectory))
    XCTAssertFalse(
      SnapzyConfigurationService.shared.isSuggestedConfigParentDirectory(
        expectedParentDirectory.appendingPathComponent("snapzy")
      )
    )
  }

  func testSuggestedConfigRootDirectoryMatchingUsesCanonicalPath() {
    let expectedRootDirectory = SnapzyConfigurationPaths.userHomeDirectory

    XCTAssertTrue(SnapzyConfigurationService.shared.isSuggestedConfigRootDirectory(expectedRootDirectory))
    XCTAssertFalse(
      SnapzyConfigurationService.shared.isSuggestedConfigRootDirectory(
        expectedRootDirectory.appendingPathComponent(".config", isDirectory: true)
      )
    )
  }

  func testEnsureConfigExistsCreatesParentDirectoryAndFile() throws {
    let homeDirectory = temporaryHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectory) }
    let url = SnapzyConfigurationPaths.suggestedConfigURL(homeDirectory: homeDirectory)

    let returnedURL = try SnapzyConfigurationService.shared.ensureConfigExists(at: url)

    XCTAssertEqual(returnedURL.path, url.path)
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

    let source = try String(contentsOf: url, encoding: .utf8)
    let document = try SimpleTOMLParser.parse(source)
    XCTAssertEqual(document.value(at: "schema_version")?.intValue, 1)
  }

  func testEnsureConfigExistsDoesNotOverwriteExistingFile() throws {
    let homeDirectory = temporaryHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectory) }
    let url = SnapzyConfigurationPaths.suggestedConfigURL(homeDirectory: homeDirectory)
    let existingSource = """
    schema_version = 1

    [general]
    language = "system"
    """

    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try existingSource.write(to: url, atomically: true, encoding: .utf8)

    try SnapzyConfigurationService.shared.ensureConfigExists(at: url)

    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), existingSource)
  }

  func testImportBackupReplacingManagedConfigWritesSelectedTomlToManagedFile() throws {
    let directory = temporaryHomeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let backupURL = directory.appendingPathComponent("backup.toml")
    let managedURL = directory
      .appendingPathComponent(".config", isDirectory: true)
      .appendingPathComponent("snapzy", isDirectory: true)
      .appendingPathComponent("config.toml")
    let source = "schema_version = 1\n"

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try source.write(to: backupURL, atomically: true, encoding: .utf8)

    let result = try SnapzyConfigurationService.shared.importBackupReplacingManagedConfig(
      from: backupURL,
      managedConfigURL: managedURL
    )

    XCTAssertFalse(result.hasErrors)
    XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), source)
  }

  func testImportBackupReplacingManagedConfigDoesNotOverwriteWhenInvalid() throws {
    let directory = temporaryHomeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let backupURL = directory.appendingPathComponent("invalid.toml")
    let managedURL = directory
      .appendingPathComponent(".config", isDirectory: true)
      .appendingPathComponent("snapzy", isDirectory: true)
      .appendingPathComponent("config.toml")
    let existingSource = "schema_version = 1\n"
    let invalidSource = """
    schema_version = 99

    [capture.screenshot]
    format = "webp"
    """

    try FileManager.default.createDirectory(at: managedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try existingSource.write(to: managedURL, atomically: true, encoding: .utf8)
    try invalidSource.write(to: backupURL, atomically: true, encoding: .utf8)

    let result = try SnapzyConfigurationService.shared.importBackupReplacingManagedConfig(
      from: backupURL,
      managedConfigURL: managedURL
    )

    XCTAssertTrue(result.hasErrors)
    XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), existingSource)
  }

  func testSyncDecisionAlreadyCurrentWhenSourcesMatch() {
    let defaults = UserDefaultsFactory.make()
    let source = "schema_version = 1\n"

    let decision = SnapzyConfigurationService.syncDecision(
      fileSource: source,
      currentSource: source,
      defaults: defaults
    )

    XCTAssertEqual(decision, .alreadyCurrent)
  }

  func testSyncDecisionAutoSyncsWhenFileMatchesLastAppliedSignature() {
    let defaults = UserDefaultsFactory.make()
    let fileSource = "schema_version = 1\n"
    let currentSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"
    SnapzyConfigurationAutoImporter.markCurrentFileApplied(fileSource, defaults: defaults)

    let decision = SnapzyConfigurationService.syncDecision(
      fileSource: fileSource,
      currentSource: currentSource,
      defaults: defaults
    )

    XCTAssertEqual(decision, .syncAutomatically)
  }

  func testSyncDecisionAsksBeforeReplacingExternallyChangedFile() {
    let defaults = UserDefaultsFactory.make()
    let fileSource = "schema_version = 1\n\n[general]\nplay_sounds = true\n"
    let currentSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

    let decision = SnapzyConfigurationService.syncDecision(
      fileSource: fileSource,
      currentSource: currentSource,
      defaults: defaults
    )

    XCTAssertEqual(decision, .askBeforeReplacing)
  }

  func testPrepareManagedConfigForOpeningCreatesMissingFileFromCurrentSettings() throws {
    try withRestoredLastAppliedSignature {
      let directory = temporaryHomeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let managedURL = directory.appendingPathComponent("config.toml")

      let result = try SnapzyConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)

      XCTAssertEqual(result.status, .synced)
      XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
      let source = try String(contentsOf: managedURL, encoding: .utf8)
      XCTAssertTrue(SnapzyConfigurationAutoImporter.isCurrentFileApplied(source))
    }
  }

  func testPrepareManagedConfigForOpeningAutoSyncsStaleAppOwnedFile() throws {
    try withRestoredLastAppliedSignature {
      let directory = temporaryHomeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let managedURL = directory.appendingPathComponent("config.toml")
      let staleSource = "schema_version = 1\n"

      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try staleSource.write(to: managedURL, atomically: true, encoding: .utf8)
      SnapzyConfigurationAutoImporter.markCurrentFileApplied(staleSource)

      let result = try SnapzyConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)
      let syncedSource = try String(contentsOf: managedURL, encoding: .utf8)

      XCTAssertEqual(result.status, .synced)
      XCTAssertNotEqual(syncedSource, staleSource)
      XCTAssertTrue(SnapzyConfigurationAutoImporter.isCurrentFileApplied(syncedSource))
    }
  }

  func testPrepareManagedConfigForOpeningDoesNotOverwriteExternalChangesWithoutConfirmation() throws {
    try withRestoredLastAppliedSignature {
      let directory = temporaryHomeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let managedURL = directory.appendingPathComponent("config.toml")
      let externalSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try externalSource.write(to: managedURL, atomically: true, encoding: .utf8)

      let result = try SnapzyConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)

      XCTAssertEqual(result.status, .needsConfirmation)
      XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), externalSource)
    }
  }

  func testSyncManagedConfigToCurrentSettingsOverwritesAfterConfirmation() throws {
    try withRestoredLastAppliedSignature {
      let directory = temporaryHomeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let managedURL = directory.appendingPathComponent("config.toml")
      let externalSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try externalSource.write(to: managedURL, atomically: true, encoding: .utf8)

      try SnapzyConfigurationService.shared.syncManagedConfigToCurrentSettings(at: managedURL)
      let syncedSource = try String(contentsOf: managedURL, encoding: .utf8)

      XCTAssertNotEqual(syncedSource, externalSource)
      XCTAssertTrue(SnapzyConfigurationAutoImporter.isCurrentFileApplied(syncedSource))
    }
  }

  func testSyncManagedConfigToCurrentSettingsIfUnchangedOverwritesApprovedFile() throws {
    try withRestoredLastAppliedSignature {
      let directory = temporaryHomeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let managedURL = directory.appendingPathComponent("config.toml")
      let externalSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"

      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try externalSource.write(to: managedURL, atomically: true, encoding: .utf8)

      let result = try SnapzyConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)
      try SnapzyConfigurationService.shared.syncManagedConfigToCurrentSettingsIfUnchanged(
        at: managedURL,
        expectedFileSignature: result.observedFileSignature
      )

      let syncedSource = try String(contentsOf: managedURL, encoding: .utf8)
      XCTAssertNotEqual(syncedSource, externalSource)
      XCTAssertTrue(SnapzyConfigurationAutoImporter.isCurrentFileApplied(syncedSource))
    }
  }

  func testSyncManagedConfigToCurrentSettingsIfUnchangedDoesNotOverwriteChangedFile() throws {
    try withRestoredLastAppliedSignature {
      let directory = temporaryHomeDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let managedURL = directory.appendingPathComponent("config.toml")
      let approvedSource = "schema_version = 1\n\n[general]\nplay_sounds = false\n"
      let changedSource = "schema_version = 1\n\n[general]\nplay_sounds = true\n"

      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try approvedSource.write(to: managedURL, atomically: true, encoding: .utf8)

      let result = try SnapzyConfigurationService.shared.prepareManagedConfigForOpening(at: managedURL)
      try changedSource.write(to: managedURL, atomically: true, encoding: .utf8)

      XCTAssertThrowsError(
        try SnapzyConfigurationService.shared.syncManagedConfigToCurrentSettingsIfUnchanged(
          at: managedURL,
          expectedFileSignature: result.observedFileSignature
        )
      ) { error in
        XCTAssertTrue(error is SnapzyConfigurationSyncError)
      }
      XCTAssertEqual(try String(contentsOf: managedURL, encoding: .utf8), changedSource)
    }
  }

  private func temporaryHomeDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("snapzy-config-service-\(UUID().uuidString)", isDirectory: true)
  }

  private func withRestoredLastAppliedSignature(_ body: () throws -> Void) rethrows {
    let defaults = UserDefaults.standard
    let key = PreferencesKeys.configurationLastAppliedSignature
    let previousValue = defaults.object(forKey: key)
    defer {
      if let previousValue {
        defaults.set(previousValue, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
    try body()
  }
}
