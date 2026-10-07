// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RedirectController: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let maximumRedirects: Int
  private let timeout: TimeInterval
  private let lock = NSLock()
  private var redirectCount = 0
  private var storedError: RecipeURLImportError?

  init(maximumRedirects: Int, timeout: TimeInterval) {
    self.maximumRedirects = maximumRedirects
    self.timeout = timeout
  }

  var error: RecipeURLImportError? {
    lock.withLock { storedError }
  }

  /// Chooses the only two authentication outcomes recipe import permits.
  ///
  /// Server trust is not an application credential: default handling asks the
  /// operating system to perform its normal certificate and hostname checks.
  /// Every other challenge requests a password, client identity, proxy secret,
  /// or mechanism-specific credential that a public recipe import neither owns
  /// nor needs. Cancelling those challenges also prevents Foundation from
  /// consulting ambient credentials on the app's behalf.
  static func authenticationDisposition(
    for authenticationMethod: String
  ) -> URLSession.AuthChallengeDisposition {
    authenticationMethod == NSURLAuthenticationMethodServerTrust
      ? .performDefaultHandling
      : .cancelAuthenticationChallenge
  }

  func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (
      URLSession.AuthChallengeDisposition,
      URLCredential?
    ) -> Void
  ) {
    completionHandler(
      Self.authenticationDisposition(
        for: challenge.protectionSpace.authenticationMethod
      ),
      nil
    )
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (
      URLSession.AuthChallengeDisposition,
      URLCredential?
    ) -> Void
  ) {
    completionHandler(
      Self.authenticationDisposition(
        for: challenge.protectionSpace.authenticationMethod
      ),
      nil
    )
  }

  func urlSession(
    _ session: URLSession,
    task _: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(redirectRequest(response: response, proposedRequest: request))
  }

  /// Validates one redirect and returns a new minimal request when it is safe.
  ///
  /// This method is separate from the delegate callback so the trust boundary
  /// can be exercised without starting a real network request. Both the source
  /// response and proposed destination must remain within fetch policy; only
  /// the destination URL survives into the returned request.
  func redirectRequest(
    response: HTTPURLResponse,
    proposedRequest: URLRequest
  ) -> URLRequest? {
    lock.withLock {
      guard storedError == nil else { return nil }
      redirectCount += 1
      guard redirectCount <= maximumRedirects else {
        storedError = .tooManyRedirects
        return nil
      }
      // A redirect is a new network destination, not merely part of the first
      // URL. Validate it before handing it back to URLSession; approving first
      // and inspecting only the final response would allow an intermediate GET
      // to reach a private service. This delegate runs on URLSession's operation
      // queue, but the validation itself is deliberately pure string/URL work;
      // URLSession retains ownership of cancellable system DNS.
      guard let sourceURL = response.url,
            URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(sourceURL),
            let url = proposedRequest.url,
            URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(url)
      else {
        storedError = .disallowedURL
        return nil
      }
      return URLSessionRecipeDocumentLoader.recipeRequest(for: url, timeout: timeout)
    }
  }
}
