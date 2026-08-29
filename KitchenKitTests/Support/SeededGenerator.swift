// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// SplitMix64 gives property tests a small, stable corpus generator.
///
/// This is deliberately not a security primitive. Its contract is repeatable
/// test data: the same seed and call sequence must keep producing the same bits.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func bool() -> Bool {
        next() & 1 == 0
    }

    mutating func uuid() -> UUID {
        let high = next()
        let low = next()
        return UUID(uuid: (
            byte(high, 56), byte(high, 48), byte(high, 40), byte(high, 32),
            byte(high, 24), byte(high, 16), byte(high, 8), byte(high, 0),
            byte(low, 56), byte(low, 48), byte(low, 40), byte(low, 32),
            byte(low, 24), byte(low, 16), byte(low, 8), byte(low, 0)
        ))
    }

    private func byte(_ value: UInt64, _ shift: UInt64) -> UInt8 {
        UInt8(truncatingIfNeeded: value >> shift)
    }
}
