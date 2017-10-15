// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "SLang",
    dependencies: [
        .package(url: "https://github.com/vdka/OrderedDictionary.git", .branch("master")),
        .package(url: "https://github.com/vdka/LLVMSwift.git", .branch("master")),
        .package(url: "https://github.com/BrettRToomey/CLibGit2.git", .branch("master"))
    ],
    targets: [
        .target(name: "SLang", dependencies: ["LLVM"]),
    ],
    swiftLanguageVersions: [4]
)
