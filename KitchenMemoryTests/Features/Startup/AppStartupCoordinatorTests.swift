// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import XCTest

@MainActor
final class AppStartupCoordinatorTests: XCTestCase {
  private final class DescriptionRecorder: @unchecked Sendable {
    var wasRead = false
  }

  private struct PrivateStartupFailure: Error, CustomStringConvertible {
    let recorder: DescriptionRecorder

    var description: String {
      recorder.wasRead = true
      return "private startup details"
    }
  }

  func testFailureIsRetryableWithoutReadingPrivateDetails() async throws {
    let recorder = DescriptionRecorder()
    var shouldFail = true
    let prepare: () async -> AppStartupState = {
      let makePreparedApp: () async throws -> PreparedApp = {
        if shouldFail { throw PrivateStartupFailure(recorder: recorder) }
        return try AppRuntime.testing()
      }
      return await AppStartupState.prepare(using: makePreparedApp)
    }

    let failedState = await prepare()
    XCTAssertNil(failedState.preparedApp)
    XCTAssertFalse(recorder.wasRead)

    shouldFail = false
    let recoveredState = await prepare()
    let recovered = try XCTUnwrap(recoveredState.preparedApp)
    recovered.libraryModel.loadIfNeeded()
    XCTAssertEqual(recovered.libraryModel.recipes.count, 3)
  }

  func testCoordinatorRetainsPreparationAcrossViewLifecycle() async {
    var continuations: [CheckedContinuation<AppStartupState, Never>] = []
    let attemptStarted = expectation(description: "startup attempt started")
    let attemptFinished = expectation(description: "startup attempt finished")
    let coordinator = AppStartupCoordinator(
      prepareApplication: {
        await withCheckedContinuation {
          continuations.append($0)
          attemptStarted.fulfill()
        }
      },
      recordMilestone: {
        if $0 == .preparationUnavailable {
          attemptFinished.fulfill()
        }
      }
    )

    coordinator.startupSurfacePresented()
    coordinator.startupSurfacePresented()
    await fulfillment(of: [attemptStarted])

    XCTAssertEqual(continuations.count, 1)
    continuations[0].resume(returning: .unavailable)
    await fulfillment(of: [attemptFinished])

    if case .unavailable = coordinator.state {
      // Expected: the coordinator, rather than a transient window task, owns
      // and publishes the completed startup attempt.
    } else {
      XCTFail("Expected the completed startup state.")
    }
  }

  func testWaitsForPresentedSurfaceBeforePreparing() async {
    var preparationStarted = false
    let attemptStarted = expectation(description: "startup attempt started")
    let coordinator = AppStartupCoordinator {
      preparationStarted = true
      attemptStarted.fulfill()
      return .unavailable
    }

    await Task.yield()
    XCTAssertFalse(preparationStarted)

    coordinator.startupSurfacePresented()
    await fulfillment(of: [attemptStarted])

    XCTAssertTrue(preparationStarted)
  }

  func testSuccessfulPreparationPublishesReadyState() async throws {
    let preparedApp = try AppRuntime.testing()
    let readyReported = expectation(description: "ready milestone reported")
    let coordinator = AppStartupCoordinator(
      prepareApplication: { .ready(preparedApp) },
      recordMilestone: {
        if $0 == .preparationReady {
          readyReported.fulfill()
        }
      }
    )

    coordinator.startupSurfacePresented()
    await fulfillment(of: [readyReported])

    XCTAssertNotNil(coordinator.state.preparedApp)
  }

  func testRetryRetiresActivePreparationBeforeStartingReplacement() async {
    var continuations: [CheckedContinuation<AppStartupState, Never>] = []
    let firstAttemptStarted = expectation(description: "first startup attempt started")
    let replacementStarted = expectation(description: "replacement startup attempt started")
    let coordinator = AppStartupCoordinator {
      await withCheckedContinuation {
        continuations.append($0)
        if continuations.count == 1 {
          firstAttemptStarted.fulfill()
        } else {
          replacementStarted.fulfill()
        }
      }
    }

    coordinator.startupSurfacePresented()
    await fulfillment(of: [firstAttemptStarted])
    coordinator.retry()
    await Task.yield()

    let attemptsStartedBeforeRetirement = continuations.count
    continuations[0].resume(returning: .unavailable)
    await fulfillment(of: [replacementStarted])

    continuations[1].resume(returning: .unavailable)
    await Task.yield()

    XCTAssertEqual(attemptsStartedBeforeRetirement, 1)
    XCTAssertEqual(continuations.count, 2)
  }

  func testReportsTypedStartupMilestones() async {
    var milestones: [AppStartupMilestone] = []
    let unavailableReported = expectation(description: "unavailable milestone reported")
    let coordinator = AppStartupCoordinator(
      prepareApplication: { .unavailable },
      recordMilestone: {
        milestones.append($0)
        if $0 == .preparationUnavailable {
          unavailableReported.fulfill()
        }
      }
    )

    coordinator.startupSurfacePresented()
    await fulfillment(of: [unavailableReported])

    XCTAssertEqual(
      milestones,
      [.startupSurfacePresented, .preparationStarted, .preparationUnavailable]
    )
  }

  func testDevelopmentDiagnosticsRetainOnlyBoundedInMemoryMilestones() {
    let diagnostics = AppStartupDiagnostics(
      maximumMilestones: 2,
      uptime: { 42 }
    )

    diagnostics.record(.startupSurfacePresented)
    diagnostics.record(.preparationStarted)
    diagnostics.record(.preparationReady)

    XCTAssertEqual(
      diagnostics.markers.map(\.milestone),
      [.startupSurfacePresented, .preparationStarted]
    )
  }

  func testShellPresentationDescribesEveryStartupStateWithoutPrivateFailureDetails() throws {
    let preparedApp = try AppRuntime.testing()

    XCTAssertEqual(AppShellPresentation(state: .preparing), .loading)
    XCTAssertEqual(AppShellPresentation(state: .unavailable), .recovery)
    XCTAssertEqual(AppShellPresentation(state: .ready(preparedApp)), .ready)
    XCTAssertFalse(AppShellPresentation.loading.permitsKitchenActions)
    XCTAssertFalse(AppShellPresentation.recovery.permitsKitchenActions)
    XCTAssertTrue(AppShellPresentation.ready.permitsKitchenActions)
  }
}
