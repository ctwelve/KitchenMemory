// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeURLRedirectDelegateTests: XCTestCase {
  func testSessionAuthenticationDelegateUsesTheCentralDispositionPolicy() throws {
    let controller = RedirectController(maximumRedirects: 2, timeout: 5)
    let challenge = challenge(authenticationMethod: NSURLAuthenticationMethodServerTrust)
    var receivedDisposition: URLSession.AuthChallengeDisposition?
    var receivedCredential: URLCredential?

    controller.urlSession(URLSession.shared, didReceive: challenge) { disposition, credential in
      receivedDisposition = disposition
      receivedCredential = credential
    }

    XCTAssertEqual(receivedDisposition, .performDefaultHandling)
    XCTAssertNil(receivedCredential)
  }

  func testTaskAuthenticationDelegateRejectsAmbientCredentials() throws {
    let controller = RedirectController(maximumRedirects: 2, timeout: 5)
    let challenge = challenge(authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
    let task = URLSession.shared.dataTask(with: URL(string: "https://first.example")!)
    var receivedDisposition: URLSession.AuthChallengeDisposition?
    var receivedCredential: URLCredential?

    controller.urlSession(
      URLSession.shared,
      task: task,
      didReceive: challenge
    ) { disposition, credential in
      receivedDisposition = disposition
      receivedCredential = credential
    }

    XCTAssertEqual(receivedDisposition, .cancelAuthenticationChallenge)
    XCTAssertNil(receivedCredential)
  }

  func testRedirectionDelegateReturnsTheRebuiltRequest() throws {
    let sourceURL = try XCTUnwrap(URL(string: "https://first.example/recipe"))
    let destinationURL = try XCTUnwrap(URL(string: "https://second.example/recipe"))
    let response = try XCTUnwrap(HTTPURLResponse(
      url: sourceURL,
      statusCode: 302,
      httpVersion: nil,
      headerFields: nil
    ))
    var proposed = URLRequest(url: destinationURL)
    proposed.httpMethod = "POST"
    proposed.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
    let task = URLSession.shared.dataTask(with: sourceURL)
    let controller = RedirectController(maximumRedirects: 2, timeout: 5)
    var receivedRequest: URLRequest?

    controller.urlSession(
      URLSession.shared,
      task: task,
      willPerformHTTPRedirection: response,
      newRequest: proposed
    ) { request in
      receivedRequest = request
    }

    XCTAssertEqual(receivedRequest?.url, destinationURL)
    XCTAssertEqual(receivedRequest?.httpMethod, "GET")
    XCTAssertNil(receivedRequest?.value(forHTTPHeaderField: "Authorization"))
  }

  private func challenge(authenticationMethod: String) -> URLAuthenticationChallenge {
    URLAuthenticationChallenge(
      protectionSpace: URLProtectionSpace(
        host: "publisher.example",
        port: 443,
        protocol: "https",
        realm: nil,
        authenticationMethod: authenticationMethod
      ),
      proposedCredential: nil,
      previousFailureCount: 0,
      failureResponse: nil,
      error: nil,
      sender: ChallengeSender()
    )
  }
}

private final class ChallengeSender: NSObject, URLAuthenticationChallengeSender {
  func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}

  func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}

  func cancel(_ challenge: URLAuthenticationChallenge) {}

  func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}

  func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}
