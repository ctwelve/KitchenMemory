// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeDocumentLoaderPolicyTests: XCTestCase {
  func testPublicInitializerBuildsFreshHardenedConfigurations() {
    let loader = URLSessionRecipeDocumentLoader(timeout: 7)

    let first = loader.makeSessionConfiguration()
    let second = loader.makeSessionConfiguration()

    // Fresh identity matters: an import must not inherit cookies or cache state
    // mutated by an earlier import, even within the same loader value.
    XCTAssertNotIdentical(first, second)
    XCTAssertEqual(first.timeoutIntervalForRequest, 7)
    XCTAssertEqual(first.timeoutIntervalForResource, 7)
    XCTAssertNil(first.urlCache)
    XCTAssertNil(first.httpCookieStorage)
    XCTAssertNil(first.urlCredentialStorage)
    XCTAssertFalse(first.httpShouldSetCookies)
  }

  func testResponseBodyCancellationInvokesTransportCleanup() async {
    let recorder = CancellationRecorder()
    let (stream, continuation) = AsyncStream<UInt8>.makeStream()
    continuation.yield(42)
    defer { continuation.finish() }

    let task = Task {
      try await URLSessionRecipeDocumentLoader.consumeResponseBody(
        stream,
        expectedContentLength: -1,
        maximumBytes: 16,
        onCancel: { recorder.record() }
      )
    }
    // Cancellation handlers also run when cancellation wins the race to task
    // startup, which makes this assertion deterministic rather than sleep-based.
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
    XCTAssertTrue(recorder.wasRecorded)
  }
}

private final class CancellationRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var recorded = false

  var wasRecorded: Bool {
    lock.lock()
    defer { lock.unlock() }
    return recorded
  }

  func record() {
    lock.lock()
    recorded = true
    lock.unlock()
  }
}
