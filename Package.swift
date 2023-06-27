// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "fyno",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "fyno",
            targets: ["fyno"]),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.0.0")
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "fyno",
            dependencies: [.product(name: "SocketIO", package: "socket.io-client-swift")]),
        .testTarget(
            name: "fynoTests",
            dependencies: ["fyno"]),
    ]
)
