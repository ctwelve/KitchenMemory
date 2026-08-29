// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

private final class KitchenMemoryLocalizationBundleToken: NSObject {}

extension Bundle {
  /// The application resource bundle even when code runs under a hosted unit test.
  nonisolated static var kitchenMemory: Bundle {
    let definingBundle = Bundle(for: KitchenMemoryLocalizationBundleToken.self)
    let candidates = [Bundle.main, definingBundle] + Bundle.allBundles + Bundle.allFrameworks
    return candidates.first(where: { candidate in
      candidate.url(
        forResource: "Localizable",
        withExtension: "strings",
        subdirectory: nil,
        localization: "fr-CA"
      ) != nil
    }) ?? definingBundle
  }

  /// Resolves a locale-specific `.lproj` bundle for deterministic previews and tests.
  nonisolated static func kitchenMemory(for locale: Locale) -> Bundle {
    let bundle = kitchenMemory
    let requested = locale.identifier(.bcp47)
    let requestedLanguage = requested.split(separator: "-").first.map(String.init)
    let localization = bundle.localizations.first(where: {
      $0.caseInsensitiveCompare(requested) == .orderedSame
    }) ?? bundle.localizations.first(where: {
      $0.split(separator: "-").first.map(String.init) == requestedLanguage
    })
    guard let localization,
          let path = bundle.path(forResource: localization, ofType: "lproj"),
          let localizedBundle = Bundle(path: path) else {
      return bundle
    }
    return localizedBundle
  }
}

extension LocalizedStringResource {
  /// Resolves a generated catalog symbol using an explicit presentation locale.
  ///
  /// SwiftUI applies its environment locale automatically. Presentation code
  /// that must return `String` instead carries the same locale through the
  /// resource before resolving it.
  nonisolated func localized(for locale: Locale) -> String {
    var resource = self
    resource.locale = locale
    return String(localized: resource)
  }
}
