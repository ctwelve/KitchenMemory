// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Validates source metadata before it becomes an editable or active web link.
///
/// This policy is intentionally smaller than recipe-fetch policy. Opening a
/// person-selected link in the system browser is not the same operation as the
/// app fetching an untrusted page in the background. At this final activation
/// boundary Kitchen Memory only needs to prevent relative paths, custom schemes,
/// embedded credentials, and implausibly large pasted values from becoming
/// actions. DNS, TLS, and browser navigation remain system responsibilities.
public enum RecipeSourceURLPolicy {
  /// Maximum UTF-8 byte length admitted for an actionable source link.
  public static let maximumUTF8Bytes = 4_096

  /// Trims and validates an absolute HTTP or HTTPS link without credentials.
  /// Returns nil for blank, oversized, relative, or unsupported input; performs no network request.
  public static func validatedURL(from enteredValue: String) -> URL? {
    let value = enteredValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty,
          value.utf8.count <= maximumUTF8Bytes,
          let url = URL(string: value),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          url.user == nil,
          url.password == nil,
          let host = url.host,
          !host.isEmpty
    else { return nil }
    return url
  }

  /// Revalidates a URL through the same actionable source-link policy; nil remains nil.
  public static func validatedURL(_ url: URL?) -> URL? {
    guard let url else { return nil }
    return validatedURL(from: url.absoluteString)
  }

  /// Returns a validated host and optional port, bracketing IPv6 for unambiguous display.
  public static func displayHost(for url: URL) -> String? {
    guard let url = validatedURL(url), let host = url.host else { return nil }
    let hostWithUnambiguousIPv6Brackets = host.contains(":") ? "[\(host)]" : host
    return url.port.map { "\(hostWithUnambiguousIPv6Brackets):\($0)" }
      ?? hostWithUnambiguousIPv6Brackets
  }
}
