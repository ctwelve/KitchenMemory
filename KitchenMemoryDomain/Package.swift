// swift-tools-version: 6.2

// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import PackageDescription

let package = Package(
    name: "KitchenMemoryDomain",
    products: [
        .library(name: "KitchenMemoryDomain", targets: ["KitchenMemoryDomain"]),
        .library(name: "KitchenMemorySampleData", targets: ["KitchenMemorySampleData"]),
    ],
    targets: [
        .target(name: "KitchenMemoryDomain"),
        .target(
            name: "KitchenMemorySampleData",
            dependencies: ["KitchenMemoryDomain"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KitchenMemoryDomainTests",
            dependencies: ["KitchenMemoryDomain"]
        ),
        .testTarget(
            name: "KitchenMemorySampleDataTests",
            dependencies: ["KitchenMemorySampleData"]
        ),
    ]
)
