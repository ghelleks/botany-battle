import Foundation

enum GameMode: String, Codable, CaseIterable {
    case multiplayer = "multiplayer"
    case beatTheClock = "beat_the_clock"
    case speedrun = "speedrun"
    
    var displayName: String {
        switch self {
        case .multiplayer: return "Multiplayer"
        case .beatTheClock: return "Beat the Clock"
        case .speedrun: return "Speedrun"
        }
    }
    
    var description: String {
        switch self {
        case .multiplayer: return "Challenge other players"
        case .beatTheClock: return "Answer as many as possible in 60 seconds"
        case .speedrun: return "Answer 25 questions as quickly as possible"
        }
    }
    
    var totalQuestions: Int {
        switch self {
        case .multiplayer: return 5
        case .beatTheClock: return Int.max // No limit
        case .speedrun: return 25
        }
    }
    
    var timeLimit: TimeInterval? {
        switch self {
        case .multiplayer: return nil // Per-round timing
        case .beatTheClock: return 60 // 60 seconds total
        case .speedrun: return nil // No time limit
        }
    }
}

struct Game: Codable, Equatable, Identifiable {
    let id: String
    let mode: GameMode
    let players: [Player]
    let state: GameState
    let currentRound: Int
    let totalRounds: Int
    let timePerRound: TimeInterval
    let difficulty: Difficulty
    let createdAt: Date
    let updatedAt: Date
    
    // Single-user specific properties
    let totalGameTime: TimeInterval?
    let questionsAnswered: Int
    let correctAnswers: Int
    
    var isMultiplayer: Bool {
        mode == .multiplayer
    }
    
    var isSingleUser: Bool {
        !isMultiplayer
    }
    
    var accuracy: Double {
        guard questionsAnswered > 0 else { return 0.0 }
        return Double(correctAnswers) / Double(questionsAnswered)
    }
    
    var score: Int {
        switch mode {
        case .multiplayer:
            return players.first?.score ?? 0
        case .beatTheClock:
            return correctAnswers
        case .speedrun:
            return questionsAnswered == totalRounds ? Int(1000.0 / (totalGameTime ?? 1.0)) : 0
        }
    }
    
    // Backward compatibility initializer for existing multiplayer games
    init(
        id: String,
        players: [Player],
        state: GameState,
        currentRound: Int,
        totalRounds: Int,
        timePerRound: TimeInterval,
        difficulty: Difficulty,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.mode = .multiplayer
        self.players = players
        self.state = state
        self.currentRound = currentRound
        self.totalRounds = totalRounds
        self.timePerRound = timePerRound
        self.difficulty = difficulty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalGameTime = nil
        self.questionsAnswered = currentRound
        self.correctAnswers = players.first?.score ?? 0
    }
    
    // Single-user game initializer
    init(
        id: String,
        mode: GameMode,
        difficulty: Difficulty,
        createdAt: Date = Date(),
        totalGameTime: TimeInterval? = nil,
        questionsAnswered: Int = 0,
        correctAnswers: Int = 0
    ) {
        self.id = id
        self.mode = mode
        self.players = []
        self.state = .inProgress
        self.currentRound = 1
        self.totalRounds = mode.totalQuestions == Int.max ? 100 : mode.totalQuestions
        self.timePerRound = difficulty.timePerRound
        self.difficulty = difficulty
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.totalGameTime = totalGameTime
        self.questionsAnswered = questionsAnswered
        self.correctAnswers = correctAnswers
    }
    
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

// MARK: - Single User Game Models

struct PersonalBest: Codable, Equatable, Identifiable {
    let id: String
    let gameMode: GameMode
    let difficulty: Game.Difficulty
    let score: Int
    let correctAnswers: Int
    let questionsAnswered: Int
    let totalGameTime: TimeInterval
    let achievedAt: Date
    
    // Computed properties for backwards compatibility
    var mode: GameMode { gameMode }
    var accuracy: Double {
        guard questionsAnswered > 0 else { return 0.0 }
        return Double(correctAnswers) / Double(questionsAnswered)
    }
    var totalTime: TimeInterval? { totalGameTime }
    
    var displayScore: String {
        switch gameMode {
        case .multiplayer:
            return "\(score) points"
        case .beatTheClock:
            return "\(correctAnswers) correct answers"
        case .speedrun:
            return String(format: "%.1fs", totalGameTime)
        }
    }
    
    var isNewRecord: Bool {
        achievedAt.timeIntervalSinceNow > -300 // Within last 5 minutes
    }
}

struct SingleUserGameSession: Codable, Equatable, Identifiable {
    let id: String
    let mode: GameMode
    let difficulty: Game.Difficulty
    let startedAt: Date
    var currentQuestionIndex: Int
    var correctAnswers: Int
    var answers: [SingleUserAnswer]
    var state: SessionState
    var pausedAt: Date?
    var totalPausedTime: TimeInterval
    
    enum SessionState: String, Codable {
        case active = "active"
        case paused = "paused"
        case completed = "completed"
        case expired = "expired"
    }
    
    struct SingleUserAnswer: Codable, Equatable, Identifiable {
        let id: String
        let questionIndex: Int
        let plantId: String
        let selectedAnswer: String
        let correctAnswer: String
        let isCorrect: Bool
        let timeToAnswer: TimeInterval
        let answeredAt: Date
    }
    
    var questionsAnswered: Int {
        answers.count
    }
    
    var accuracy: Double {
        guard questionsAnswered > 0 else { return 0.0 }
        return Double(correctAnswers) / Double(questionsAnswered)
    }
    
    var totalGameTime: TimeInterval {
        let endTime = state == .completed ? (answers.last?.answeredAt ?? startedAt) : Date()
        return endTime.timeIntervalSince(startedAt) - totalPausedTime
    }
    
    var isTimeExpired: Bool {
        guard mode == .beatTheClock else { return false }
        return totalGameTime >= 60.0
    }
    
    var isComplete: Bool {
        switch mode {
        case .multiplayer:
            return false // Not applicable
        case .beatTheClock:
            return isTimeExpired || state == .completed
        case .speedrun:
            return questionsAnswered >= 25 || state == .completed
        }
    }
    
    var score: Int {
        switch mode {
        case .multiplayer:
            return 0
        case .beatTheClock:
            return correctAnswers
        case .speedrun:
            guard questionsAnswered >= 25 else { return 0 }
            return Int(1000.0 / max(totalGameTime, 1.0))
        }
    }
    
    mutating func pause() {
        guard state == .active else { return }
        state = .paused
        pausedAt = Date()
    }
    
    mutating func resume() {
        guard state == .paused, let pausedTime = pausedAt else { return }
        totalPausedTime += Date().timeIntervalSince(pausedTime)
        pausedAt = nil
        state = .active
    }
    
    mutating func addAnswer(_ answer: SingleUserAnswer) {
        answers.append(answer)
        if answer.isCorrect {
            correctAnswers += 1
        }
        currentQuestionIndex += 1
        
        if isComplete {
            state = .completed
        }
    }
    
    init(
        id: String = UUID().uuidString,
        mode: GameMode,
        difficulty: Game.Difficulty,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.mode = mode
        self.difficulty = difficulty
        self.startedAt = startedAt
        self.currentQuestionIndex = 0
        self.correctAnswers = 0
        self.answers = []
        self.state = .active
        self.pausedAt = nil
        self.totalPausedTime = 0
    }
    
    func toPersonalBest() -> PersonalBest {
        PersonalBest(
            id: UUID().uuidString,
            gameMode: mode,
            difficulty: difficulty,
            score: score,
            correctAnswers: correctAnswers,
            questionsAnswered: questionsAnswered,
            totalGameTime: totalGameTime,
            achievedAt: Date()
        )
    }
}