// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fyno",
    platforms: [
        .iOS(.v13)  // Specify your minimum target iOS version
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "fyno", type: .dynamic,        
            targets: ["fyno"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/ccgus/fmdb", from: "2.7.8"),
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "fyno",
            dependencies: [
                "SwiftyJSON",
                .product(name: "FMDB", package: "FMDB"),
            ]),
        .testTarget(
            name: "fynoTests",
            dependencies: ["fyno"]),
    ]
)
