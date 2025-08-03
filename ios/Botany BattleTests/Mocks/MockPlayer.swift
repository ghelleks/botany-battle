import Foundation
import GameKit
@testable import BotanyBattle

class MockPlayer {
    let id: String
    let username: String
    var rating: Int
    var currentMatch: MatchFoundData?
    
    // Callback handlers for testing
    var onMatchFound: ((MatchFoundData) -> Void)?
    var onMatchmakingTimeout: (() -> Void)?
    var onChallengeReceived: ((Challenge) -> Void)?
    var onRoundResult: ((RoundResult) -> Void)?
    var onGameCompleted: ((GameResult) -> Void)?
    var onReconnected: (() -> Void)?
    var onConnectivityIssue: ((ConnectivityIssue) -> Void)?
    var onError: ((Error) -> Void)?
    var onLeaderboardUpdated: ((Leaderboard) -> Void)?
    var onAchievementUnlocked: ((Achievement) -> Void)?
    
    // Test state
    private var submittedAnswers: [Int: String] = [:]
    private var answerTimestamps: [Int: Date] = [:]
    
    init(id: String, username: String, rating: Int) {
        self.id = id
        self.username = username
        self.rating = rating
    }
    
    func submitAnswer(_ answer: String, for gameId: String, round: Int, at timestamp: Date = Date()) {
        submittedAnswers[round] = answer
        answerTimestamps[round] = timestamp
        
        // Simulate answer submission to backend
        NotificationCenter.default.post(
            name: .playerAnswerSubmitted,
            object: nil,
            userInfo: [
                "playerId": id,
                "gameId": gameId,
                "round": round,
                "answer": answer,
                "timestamp": timestamp
            ]
        )
    }
    
    func getSubmittedAnswer(for round: Int) -> String? {
        return submittedAnswers[round]
    }
    
    func getAnswerTimestamp(for round: Int) -> Date? {
        return answerTimestamps[round]
    }
    
    // Mock methods for handling game events
    func handleMatchFound(_ match: MatchFoundData) {
        currentMatch = match
        onMatchFound?(match)
    }
    
    func handleMatchmakingTimeout() {
        onMatchmakingTimeout?()
    }
    
    func handleChallengeReceived(_ challenge: Challenge) {
        onChallengeReceived?(challenge)
    }
    
    func handleRoundResult(_ result: RoundResult) {
        onRoundResult?(result)
    }
    
    func handleGameCompleted(_ result: GameResult) {
        onGameCompleted?(result)
    }
    
    func handleReconnection() {
        onReconnected?()
    }
    
    func handleConnectivityIssue(_ issue: ConnectivityIssue) {
        onConnectivityIssue?(issue)
    }
    
    func handleError(_ error: Error) {
        onError?(error)
    }
    
    func handleLeaderboardUpdate(_ leaderboard: Leaderboard) {
        onLeaderboardUpdated?(leaderboard)
    }
    
    func handleAchievementUnlocked(_ achievement: Achievement) {
        onAchievementUnlocked?(achievement)
    }
}

// MARK: - Supporting Types

struct Challenge {
    let id: String
    let from: String
    let to: String
    let timestamp: Date
}

enum ConnectivityIssue {
    case slowConnection
    case intermittentConnection
    case highLatency
}

struct Leaderboard {
    let id: String
    let score: Int
    let rank: Int
}

struct Achievement {
    let id: String
    let name: String
    let description: String
    let unlockedAt: Date
}

// MARK: - Notification Names

extension Notification.Name {
    static let playerAnswerSubmitted = Notification.Name("playerAnswerSubmitted")
    static let matchFound = Notification.Name("matchFound")
    static let gameCompleted = Notification.Name("gameCompleted")
}