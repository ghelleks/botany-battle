import Foundation

struct User: Codable, Equatable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let displayName: String?
    let avatarURL: URL?
    let createdAt: Date
    let stats: UserStats
    let currency: Currency
    
    struct UserStats: Codable, Equatable {
        let totalGamesPlayed: Int
        let totalWins: Int
        let currentStreak: Int
        let longestStreak: Int
        let eloRating: Int
        let rank: String
        let plantsIdentified: Int
        let accuracyRate: Double
        
        var winRate: Double {
            guard totalGamesPlayed > 0 else { return 0.0 }
            return Double(totalWins) / Double(totalGamesPlayed)
        }
    }
    
    struct Currency: Codable, Equatable {
        let coins: Int
        let gems: Int
        let tokens: Int
    }
}