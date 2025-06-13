import Foundation
import Amplify
import AWSCognitoAuthPlugin

final class AppConfiguration {
    static func configure() {
        configureAmplify()
    }
    
    private static func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
            print("Amplify configured successfully")
        } catch {
            print("Failed to initialize Amplify: \(error)")
        }
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