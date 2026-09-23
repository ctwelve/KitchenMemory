// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Defaults
import Foundation
import KitchenKit
import Observation

/// Observable local organization preferences, bound to one owner/store and Kitchen.
///
/// Feature visibility belongs to the device; expansion belongs to the bound scope.
/// Pending commands and synchronized organization policy are not preferences.
@MainActor
protocol OrganizationPreferencesStoring: AnyObject {
  var foldersEnabled: Bool { get set }
  var tagsEnabled: Bool { get set }
  var tagsExpanded: Bool { get set }
  var expanded: Set<Folder.ID> { get set }
  func resetExpansion()
}

extension OrganizationPreferencesStoring {
  /// Reset disclosure state while retaining the person's device-local feature choices.
  func resetExpansion() {
    expanded = []
    tagsExpanded = true
  }
}

/// Typed local storage with one-time adoption of legacy dotted keys.
/// Folder identities retain their sorted string-array encoding; no domain schema changes.
@MainActor
@Observable
final class DefaultsOrganizationPreferences: OrganizationPreferencesStoring {
  private let foldersKey: Defaults.Key<Bool>
  private let tagsKey: Defaults.Key<Bool>
  private let tagsExpandedKey: Defaults.Key<Bool>
  private let expandedKey: Defaults.Key<[String]>
  @ObservationIgnored private var observations: [any Defaults.Observation] = []

  init(defaults: UserDefaults, scope: String, kitchenID: Kitchen.ID) {
    let legacyPrefix = "organization." + scope + "." + kitchenID.rawValue.uuidString
    // Defaults uses KVO key paths, so dots and arbitrary owner characters are
    // unsupported. Hex encoding is injective and keeps the bound scope ASCII.
    let encodedScope = scope.utf8.map { String(format: "%02x", $0) }.joined()
    let prefix = "organization_" + encodedScope + "_" + kitchenID.rawValue.uuidString
    func key<Value: Defaults.Serializable>(
      _ name: String, legacy: String, default value: Value
    ) -> Defaults.Key<Value> {
      if defaults.object(forKey: name) == nil, let previous = defaults.object(forKey: legacy) {
        defaults.set(previous, forKey: name)
      }
      // Do not populate UserDefaults' shared registration domain: another
      // isolated suite's fallback must not mask this suite's legacy value.
      return Defaults.Key(name, suite: defaults, iCloud: false, default: { value })
    }
    foldersKey = key("organizationFoldersEnabled", legacy: "organization.folders.enabled", default: true)
    tagsKey = key("organizationTagsEnabled", legacy: "organization.tags.enabled", default: true)
    tagsExpandedKey = key(prefix + "_tagsExpanded", legacy: legacyPrefix + ".tags-expanded", default: true)
    expandedKey = key(prefix + "_expanded", legacy: legacyPrefix + ".expanded", default: [])
    observe(foldersKey) { [weak self] in self?.withMutation(keyPath: \.foldersEnabled) {} }
    observe(tagsKey) { [weak self] in self?.withMutation(keyPath: \.tagsEnabled) {} }
    observe(tagsExpandedKey) { [weak self] in self?.withMutation(keyPath: \.tagsExpanded) {} }
    observe(expandedKey) { [weak self] in self?.withMutation(keyPath: \.expanded) {} }
  }

  /// Invalidate other bound consumers after in-process Defaults writes. Getters
  /// always read storage, so delayed notification cannot restore an older value.
  private func observe<Value: Defaults.Serializable>(
    _ key: Defaults.Key<Value>, onChange: @escaping @MainActor @Sendable () -> Void
  ) {
    observations.append(Defaults.observe(key, options: []) { _ in
      Task { @MainActor in onChange() }
    })
  }

  var foldersEnabled: Bool {
    get { access(keyPath: \.foldersEnabled); return Defaults[foldersKey] }
    set { withMutation(keyPath: \.foldersEnabled) { Defaults[foldersKey] = newValue } }
  }

  var tagsEnabled: Bool {
    get { access(keyPath: \.tagsEnabled); return Defaults[tagsKey] }
    set { withMutation(keyPath: \.tagsEnabled) { Defaults[tagsKey] = newValue } }
  }

  var tagsExpanded: Bool {
    get { access(keyPath: \.tagsExpanded); return Defaults[tagsExpandedKey] }
    set { withMutation(keyPath: \.tagsExpanded) { Defaults[tagsExpandedKey] = newValue } }
  }

  var expanded: Set<Folder.ID> {
    get {
      access(keyPath: \.expanded)
      return Set(Defaults[expandedKey].compactMap(UUID.init(uuidString:)).map(Folder.ID.init(rawValue:)))
    }
    set {
      withMutation(keyPath: \.expanded) {
        Defaults[expandedKey] = newValue.map { $0.rawValue.uuidString }.sorted()
      }
    }
  }
}

/// One disposable device's feature choices, shared across its bound scopes.
@MainActor
@Observable
final class VolatileOrganizationVisibility {
  var foldersEnabled = true
  var tagsEnabled = true
}

/// In-memory preferences for disposable application graphs, with no defaults writes.
@MainActor
@Observable
final class VolatileOrganizationPreferences: OrganizationPreferencesStoring {
  private let visibility: VolatileOrganizationVisibility
  var tagsExpanded = true
  var expanded: Set<Folder.ID> = []

  init(visibility: VolatileOrganizationVisibility) {
    self.visibility = visibility
  }

  var foldersEnabled: Bool {
    get { visibility.foldersEnabled }
    set { visibility.foldersEnabled = newValue }
  }

  var tagsEnabled: Bool {
    get { visibility.tagsEnabled }
    set { visibility.tagsEnabled = newValue }
  }
}
