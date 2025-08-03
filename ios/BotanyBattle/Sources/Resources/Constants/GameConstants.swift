import Foundation

enum GameConstants {
    // MARK: - Game Mode Timing
    static let practiceTimeLimit: Int = 60
    static let timeAttackLimit: Int = 15
    static let speedrunQuestionCount: Int = 25
    static let maxRounds: Int = 5
    
    // MARK: - Game Mechanics
    static let answerOptionsCount: Int = 4
    static let correctAnswerPoints: Int = 10
    static let speedBonus: Int = 5
    static let streakMultiplier: Int = 2
    
    // MARK: - UI Timing
    static let questionTransitionDelay: Double = 1.5
    static let resultDisplayDuration: Double = 3.0
    static let defaultAnimationDuration: Double = 0.3
    static let feedbackAnimationDuration: Double = 0.5
    
    // MARK: - Achievement Thresholds
    static let perfectScoreThreshold: Int = 100
    static let speedDemonThreshold: Int = 30
    static let plantExpertThreshold: Int = 500
    
    // MARK: - Trophy Economy
    static let trophiesPerWin: Int = 10
    static let trophiesPerPerfectGame: Int = 25
    static let dailyBonusTrophies: Int = 5
    
    // MARK: - API Configuration
    static let maxAPIRetries: Int = 3
    static let apiTimeoutInterval: TimeInterval = 30.0
    static let cacheExpirationHours: Int = 24
    
    // MARK: - iNaturalist API
    static let iNaturalistBaseURL: String = "https://api.inaturalist.org/v1"
    static let plantsPerPage: Int = 20
    static let minimumObservations: Int = 1000
    static let taxonID: Int = 47126 // Plants kingdom
    
    // MARK: - Image Loading
    static let maxImageCacheSize: Int = 100 * 1024 * 1024 // 100MB
    static let imageCompressionQuality: Double = 0.8
    static let thumbnailSize: CGSize = CGSize(width: 200, height: 200)
    
    // MARK: - Performance
    static let maxConcurrentDownloads: Int = 3
    static let backgroundQueueQoS: DispatchQoS.QoSClass = .background
    
    // MARK: - User Defaults Keys
    enum UserDefaultsKeys {
        static let isFirstLaunch = "isFirstLaunch"
        static let tutorialCompleted = "tutorialCompleted"
        static let practiceHighScore = "practiceHighScore"
        static let speedrunBestTime = "speedrunBestTime"
        static let timeAttackHighScore = "timeAttackHighScore"
        static let totalTrophies = "totalTrophies"
        static let gamesPlayed = "gamesPlayed"
        static let perfectGames = "perfectGames"
        static let totalCorrectAnswers = "totalCorrectAnswers"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let lastPlayDate = "lastPlayDate"
        static let ownedShopItems = "ownedShopItems"
        static let equippedItems = "equippedItems"
        static let soundEnabled = "soundEnabled"
        static let hapticsEnabled = "hapticsEnabled"
        static let reducedAnimations = "reducedAnimations"
    }
    
    // MARK: - Game Center
    enum GameCenter {
        static let leaderboardID = "com.botanybattle.highscores"
        static let achievementPrefix = "com.botanybattle.achievement."
        
        enum Achievements {
            static let firstWin = GameCenter.achievementPrefix + "first_win"
            static let perfectGame = GameCenter.achievementPrefix + "perfect_game"
            static let speedDemon = GameCenter.achievementPrefix + "speed_demon"
            static let plantExpert = GameCenter.achievementPrefix + "plant_expert"
            static let streakMaster = GameCenter.achievementPrefix + "streak_master"
            static let marathonRunner = GameCenter.achievementPrefix + "marathon_runner"
        }
    }
    
    // MARK: - Error Messages
    enum ErrorMessages {
        static let networkError = "Unable to connect to the internet. Please check your connection and try again."
        static let apiError = "Unable to load plant data. Please try again later."
        static let cacheError = "Unable to load cached data."
        static let gameError = "An error occurred during the game. Please restart."
        static let purchaseError = "Unable to complete purchase. Please try again."
        static let gameCenterError = "Unable to connect to Game Center."
    }
    
    // MARK: - Validation
    static var isValid: Bool {
        return practiceTimeLimit > 0 &&
               timeAttackLimit > 0 &&
               speedrunQuestionCount > 0 &&
               maxRounds > 0 &&
               answerOptionsCount >= 2 &&
               trophiesPerPerfectGame > trophiesPerWin &&
               questionTransitionDelay > 0 &&
               resultDisplayDuration > 0
    }
}

// MARK: - CGSize Extension for Constants
import CoreGraphics

extension GameConstants {
    static let defaultImageSize = CGSize(width: 300, height: 300)
    static let cardImageSize = CGSize(width: 150, height: 150)
}