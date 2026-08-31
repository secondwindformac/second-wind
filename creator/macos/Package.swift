// swift-tools-version:5.9
// Second Wind Creator — the "new Mac on a USB stick" builder, for macOS.
// Plain SwiftUI + SPM (no Xcode project needed): `swift build` on a Mac,
// or let the creator-macos GitHub workflow build the .app.
//
// Deployment floor is macOS 11 Big Sur ON PURPOSE: the newest macOS that a
// 2013–2014 Mac (our audience) can run. Do not use SwiftUI APIs newer than 11.
import PackageDescription

let package = Package(
    name: "SecondWindCreator",
    platforms: [.macOS(.v11)],
    dependencies: [
        // CryptoKit API that also works on Linux (CI validates the disk
        // engine there with real fsck/sgdisk/mtools).
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
    ],
    targets: [
        .systemLibrary(name: "CZLib", path: "Sources/CZLib"),
        // Platform-agnostic engine: GPT patching, FAT32 volume builder,
        // tar.gz reading, download+verify. Compiles on macOS AND Linux.
        .target(
            name: "CreatorCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                "CZLib",
            ]
        ),
        // The SwiftUI app (macOS only).
        .executableTarget(
            name: "SecondWindCreator",
            dependencies: ["CreatorCore"]
        ),
        // Headless CLI over the same engine: lets CI (and developers on
        // Linux) build seed images against a file and validate them with
        // sgdisk / fsck.vfat / mtools — the exact tools the Linux USB
        // creator trusts.
        .executableTarget(
            name: "seedtool",
            dependencies: ["CreatorCore"]
        ),
        .testTarget(
            name: "CreatorCoreTests",
            dependencies: ["CreatorCore"]
        ),
    ]
)
