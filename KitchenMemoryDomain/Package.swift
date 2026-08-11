// swift-tools-version: 6.2

// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import PackageDescription

let package = Package(
    name: "KitchenMemoryDomain",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "KitchenMemoryDomain", targets: ["KitchenMemoryDomain"]),
        .library(name: "KitchenMemorySampleData", targets: ["KitchenMemorySampleData"]),
        .library(name: "KitchenMemoryPersistence", targets: ["KitchenMemoryPersistence"]),
    ],
    targets: [
        .target(name: "KitchenMemoryDomain"),
        .target(
            name: "KitchenMemorySampleData",
            dependencies: ["KitchenMemoryDomain"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "KitchenMemoryPersistence",
            dependencies: ["KitchenMemoryDomain"]
        ),
        .testTarget(
            name: "KitchenMemoryDomainTests",
            dependencies: ["KitchenMemoryDomain"]
        ),
        .testTarget(
            name: "KitchenMemorySampleDataTests",
            dependencies: ["KitchenMemorySampleData"]
        ),
        .testTarget(
            name: "KitchenMemoryPersistenceTests",
            dependencies: [
                "KitchenMemoryPersistence",
                "KitchenMemorySampleData",
            ]
        ),
    ]
)
