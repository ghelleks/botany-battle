import Foundation

struct Game: Codable, Equatable, Identifiable {
    let id: String
    let players: [Player]
    let state: GameState
    let currentRound: Int
    let totalRounds: Int
    let timePerRound: TimeInterval
    let difficulty: Difficulty
    let createdAt: Date
    let updatedAt: Date
    
    enum GameState: String, Codable, CaseIterable {
        case waiting = "waiting"
        case inProgress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"
    }
    
    enum Difficulty: String, Codable, CaseIterable {
        case easy = "easy"
        case medium = "medium"
        case hard = "hard"
        case expert = "expert"
        
        var displayName: String {
            switch self {
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            case .expert: return "Expert"
            }
        }
        
        var timePerRound: TimeInterval {
            switch self {
            case .easy: return 30
            case .medium: return 20
            case .hard: return 15
            case .expert: return 10
            }
        }
    }
    
    struct Player: Codable, Equatable, Identifiable {
        let id: String
        let userId: String
        let username: String
        let score: Int
        let answers: [Answer]
        let isReady: Bool
        let joinedAt: Date
        
        struct Answer: Codable, Equatable, Identifiable {
            let id: String
            let roundNumber: Int
            let plantId: String
            let selectedAnswer: String
            let correctAnswer: String
            let isCorrect: Bool
            let timeToAnswer: TimeInterval
            let pointsEarned: Int
            let submittedAt: Date
        }
    }
}

struct Round: Codable, Equatable, Identifiable {
    let id: String
    let gameId: String
    let roundNumber: Int
    let plant: Plant
    let options: [String]
    let correctAnswer: String
    let timeLimit: TimeInterval
    let startedAt: Date
    let endsAt: Date
    
    var isActive: Bool {
        let now = Date()
        return now >= startedAt && now <= endsAt
    }
    
    var timeRemaining: TimeInterval {
        max(0, endsAt.timeIntervalSinceNow)
    }
}