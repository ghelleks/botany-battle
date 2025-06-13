// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BotanyBattle",
    platforms: [
        .iOS(.v17),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "BotanyBattle",
            targets: ["BotanyBattle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        .package(url: "https://github.com/aws-amplify/amplify-swift", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "2.2.0")
    ],
    targets: [
        .target(
            name: "BotanyBattle",
            dependencies: [
                "Alamofire",
                "Starscream",
                .product(name: "Amplify", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI")
            ],
            path: "Sources"),
        .testTarget(
            name: "BotanyBattleTests",
            dependencies: ["BotanyBattle"],
            path: "Tests")
    ]
)