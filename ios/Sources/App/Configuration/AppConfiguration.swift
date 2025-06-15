import Foundation

final class AppConfiguration {
    static func configure() {
        configureApp()
    }
    
    private static func configureApp() {
        print("App configured successfully")
    }
}

struct DevelopmentConfiguration {
    static let apiBaseURL = "https://fsmiubpnza.execute-api.us-west-2.amazonaws.com/dev"
    static let websocketURL = "wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/dev"
    static let enableDebugLogging = true
    static let mockServices = false
}

struct ProductionConfiguration {
    static let apiBaseURL = "https://fsmiubpnza.execute-api.us-west-2.amazonaws.com/prod"
    static let websocketURL = "wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/prod"
    static let enableDebugLogging = false
    static let mockServices = false
}