// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import XCTest

final class PropertyTestHarnessTests: XCTestCase {
    func testBundledCatalogContainsExactlyTheNamedSeeds() throws {
        let catalog = try PropertyTestSeeds.bundled()

        XCTAssertEqual(
            catalog.names,
            Set(PropertyTestSeedName.allCases.map(\.rawValue))
        )
    }

    func testSameSeedReproducesRawAndDerivedCorpora() throws {
        let seed = try PropertyTestSeeds.bundled().seed(named: .domainCodableIngredients)

        XCTAssertEqual(rawCorpus(seed: seed.value), rawCorpus(seed: seed.value))
        XCTAssertEqual(derivedCorpus(seed: seed.value), derivedCorpus(seed: seed.value))
    }

    func testKnownAnswerPinsReplayContractAcrossGeneratorEdits() throws {
        let seed = try PropertyTestSeeds.bundled().seed(named: .domainCodableIngredients)
        var rawGenerator = SeededGenerator(seed: seed.value)

        // Saved seed/case diagnostics remain replayable only while both the
        // bitstream and the derived-value consumption order stay stable.
        XCTAssertEqual(
            (0..<4).map { _ in rawGenerator.next() },
            [
                0xDBBA_A852_1EFF_A441,
                0x7ADF_638A_B8B8_3F42,
                0xB89C_C244_78CA_B476,
                0x01A8_86C8_6840_0B6F,
            ]
        )

        var derivedGenerator = SeededGenerator(seed: seed.value)
        let expectedIdentifier = try XCTUnwrap(
            UUID(uuidString: "B89CC244-78CA-B476-01A8-86C868400B6F")
        )
        XCTAssertEqual(
            DerivedSample(
                count: derivedGenerator.int(in: 0...10_000),
                flag: derivedGenerator.bool(),
                identifier: derivedGenerator.uuid()
            ),
            DerivedSample(count: 4_861, flag: true, identifier: expectedIdentifier)
        )
    }

    func testChangingNamedSeedChangesRawAndDerivedCorpora() throws {
        let catalog = try PropertyTestSeeds.bundled()
        let first = try catalog.seed(named: .domainRationalNormalization)
        let second = try catalog.seed(named: .domainRationalMultiplication)

        XCTAssertNotEqual(first.value, second.value)
        XCTAssertNotEqual(rawCorpus(seed: first.value), rawCorpus(seed: second.value))
        XCTAssertNotEqual(derivedCorpus(seed: first.value), derivedCorpus(seed: second.value))
    }

    func testMissingResourceAndNamedSeedThrowSpecificErrors() throws {
        XCTAssertThrowsError(
            try PropertyTestSeeds.load(
                resourceName: "AbsentPropertyTestSeeds",
                bundle: Bundle(for: PropertyTestHarnessTests.self)
            )
        ) { error in
            XCTAssertEqual(
                error as? PropertyTestSeeds.LoadError,
                .missingResource("AbsentPropertyTestSeeds")
            )
        }

        let catalog = try PropertyTestSeeds(data: data(#"""
        {
          "formatVersion": 1,
          "seeds": []
        }
        """#))
        XCTAssertThrowsError(try catalog.seed(named: .importNormalizerMarkup)) { error in
            XCTAssertEqual(
                error as? PropertyTestSeeds.LoadError,
                .missingSeed(PropertyTestSeedName.importNormalizerMarkup.rawValue)
            )
        }
    }

    func testMalformedJSONThrowsADiagnosticError() {
        XCTAssertThrowsError(try PropertyTestSeeds(data: data(#"{"formatVersion":1,"seeds":["#))) {
            guard case let PropertyTestSeeds.LoadError.malformedResource(details) = $0 else {
                return XCTFail("Unexpected error: \($0)")
            }
            XCTAssertFalse(details.isEmpty)
        }
    }

    func testDuplicateNamesAndValuesAreRejected() {
        assertLoadError(
            #"""
            {
              "formatVersion": 1,
              "seeds": [
                {"name":"duplicate", "hexadecimal":"0x1"},
                {"name":"duplicate", "hexadecimal":"0x2"}
              ]
            }
            """#,
            equals: .duplicateName("duplicate")
        )
        assertLoadError(
            #"""
            {
              "formatVersion": 1,
              "seeds": [
                {"name":"first", "hexadecimal":"0x01"},
                {"name":"second", "hexadecimal":"0x1"}
              ]
            }
            """#,
            equals: .duplicateValue("first", "second")
        )
    }

    func testInvalidNamesHexadecimalAndVersionsAreRejected() {
        assertLoadError(
            #"{"formatVersion":2,"seeds":[]}"#,
            equals: .unsupportedFormatVersion(2)
        )
        assertLoadError(
            #"""
            {
              "formatVersion": 1,
              "seeds": [{"name":" ", "hexadecimal":"0x1"}]
            }
            """#,
            equals: .emptyName
        )
        for invalidHexadecimal in ["not-hex", "0x+1", "0xG1"] {
            assertLoadError(
                """
                {
                  "formatVersion": 1,
                  "seeds": [{"name":"bad", "hexadecimal":"\(invalidHexadecimal)"}]
                }
                """,
                equals: .invalidHexadecimal(name: "bad", value: invalidHexadecimal)
            )
        }
    }

    private func rawCorpus(seed: UInt64) -> [UInt64] {
        var generator = SeededGenerator(seed: seed)
        return (0..<32).map { _ in generator.next() }
    }

    private func derivedCorpus(seed: UInt64) -> [DerivedSample] {
        var generator = SeededGenerator(seed: seed)
        return (0..<16).map { _ in
            DerivedSample(
                count: generator.int(in: 0...10_000),
                flag: generator.bool(),
                identifier: generator.uuid()
            )
        }
    }

    private func assertLoadError(
        _ json: String,
        equals expected: PropertyTestSeeds.LoadError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try PropertyTestSeeds(data: data(json)), file: file, line: line) {
            XCTAssertEqual($0 as? PropertyTestSeeds.LoadError, expected, file: file, line: line)
        }
    }

    private func data(_ json: String) -> Data {
        Data(json.utf8)
    }
}

private struct DerivedSample: Equatable {
    let count: Int
    let flag: Bool
    let identifier: UUID
}
