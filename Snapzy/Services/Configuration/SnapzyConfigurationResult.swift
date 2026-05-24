//
//  SnapzyConfigurationResult.swift
//  Snapzy
//
//  Import/export result models for TOML configuration.
//

import Foundation

enum SnapzyConfigurationIssueSeverity: Sendable {
  case warning
  case error
}

struct SnapzyConfigurationIssue: Identifiable, Sendable {
  let id = UUID()
  let severity: SnapzyConfigurationIssueSeverity
  let message: String
}

struct SnapzyConfigurationImportResult: Sendable {
  let appliedChangeCount: Int
  let issues: [SnapzyConfigurationIssue]

  var hasErrors: Bool {
    issues.contains { $0.severity == .error }
  }
}

enum SnapzyConfigurationSyncDecision: Equatable, Sendable {
  case alreadyCurrent
  case syncAutomatically
  case askBeforeReplacing
}

enum SnapzyConfigurationSyncStatus: Equatable, Sendable {
  case alreadyCurrent
  case synced
  case needsConfirmation
  case permissionRequired
}

struct SnapzyConfigurationSyncResult: Sendable {
  let status: SnapzyConfigurationSyncStatus
  let fileURL: URL
  let observedFileSignature: String?
  let exportedSettingsSignature: String?

  nonisolated init(
    status: SnapzyConfigurationSyncStatus,
    fileURL: URL,
    observedFileSignature: String? = nil,
    exportedSettingsSignature: String? = nil
  ) {
    self.status = status
    self.fileURL = fileURL
    self.observedFileSignature = observedFileSignature
    self.exportedSettingsSignature = exportedSettingsSignature
  }
}

enum SnapzyConfigurationSyncError: LocalizedError, Sendable {
  case fileChangedSinceConfirmation

  var errorDescription: String? {
    switch self {
    case .fileChangedSinceConfirmation:
      return "config.toml changed. Review it and try again."
    }
  }
}
