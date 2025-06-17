import XCTest
import Dependencies
@testable import BotanyBattle

final class ScoringSystemTests: XCTestCase {
    
    var beatTheClockService: BeatTheClockService!
    var speedrunService: SpeedrunService!
    var trophyService: TrophyService!
    
    override func setUp() {
        super.setUp()
        beatTheClockService = BeatTheClockService()
        speedrunService = SpeedrunService()
        
        withDependencies {
            $0.userDefaults = MockUserDefaults()
        } operation: {
            trophyService = TrophyService()
        }
    }
    
    override func tearDown() {
        beatTheClockService = nil
        speedrunService = nil
        trophyService = nil
        super.tearDown()
    }
    
    // MARK: - Beat the Clock Scoring Tests
    
    func testBeatTheClockScoring_Perfect() {
        var session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        session.correctAnswers = 20
        session.questionsAnswered = 20
        session.totalGameTime = 60.0
        
        let score = beatTheClockService.calculateScore(session: session)
        
        XCTAssertEqual(score.correctAnswers, 20)
        XCTAssertEqual(score.totalAnswers, 20)
        XCTAssertEqual(score.accuracy, 1.0)
        XCTAssertEqual(score.timeUsed, 60.0)
        XCTAssertEqual(score.pointsPerSecond, 20.0 / 60.0)
        XCTAssertTrue(score.isNewRecord) // First time should be new record
    }
    
    func testBeatTheClockScoring_Partial() {
        var session = SingleUserGameSession(mode: .beatTheClock, difficulty: .easy)
        session.correctAnswers = 12
        session.questionsAnswered = 15
        session.totalGameTime = 60.0
        
        let score = beatTheClockService.calculateScore(session: session)
        
        XCTAssertEqual(score.correctAnswers, 12)
        XCTAssertEqual(score.totalAnswers, 15)
        XCTAssertEqual(score.accuracy, 0.8, accuracy: 0.01)
        XCTAssertEqual(score.timeUsed, 60.0)
        XCTAssertEqual(score.pointsPerSecond, 0.2, accuracy: 0.01)
    }
    
    func testBeatTheClockScoring_DifferentDifficulties() {
        var easySession = SingleUserGameSession(mode: .beatTheClock, difficulty: .easy)
        easySession.correctAnswers = 15
        easySession.questionsAnswered = 15
        easySession.totalGameTime = 60.0
        
        var hardSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .hard)
        hardSession.correctAnswers = 15
        hardSession.questionsAnswered = 15
        hardSession.totalGameTime = 60.0
        
        let easyScore = beatTheClockService.calculateScore(session: easySession)
        let hardScore = beatTheClockService.calculateScore(session: hardSession)
        
        XCTAssertEqual(easyScore.difficulty, .easy)
        XCTAssertEqual(hardScore.difficulty, .hard)
        XCTAssertEqual(easyScore.correctAnswers, hardScore.correctAnswers)
        // Same performance, different difficulty level
    }
    
    // MARK: - Speedrun Scoring Tests
    
    func testSpeedrunScoring_FastCompletion() {
        var session = SingleUserGameSession(mode: .speedrun, difficulty: .medium)
        session.correctAnswers = 25
        session.questionsAnswered = 25
        session.totalGameTime = 90.0 // Fast completion
        
        let score = speedrunService.calculateScore(session: session)
        
        XCTAssertEqual(score.correctAnswers, 25)
        XCTAssertEqual(score.totalQuestions, 25)
        XCTAssertEqual(score.completionTime, 90.0)
        XCTAssertEqual(score.accuracy, 1.0)
        XCTAssertGreaterThan(score.rating, 1000.0) // Should have good rating for fast completion
        XCTAssertTrue(score.isNewRecord) // First time should be new record
    }
    
    func testSpeedrunScoring_SlowCompletion() {
        var session = SingleUserGameSession(mode: .speedrun, difficulty: .medium)
        session.correctAnswers = 20
        session.questionsAnswered = 25
        session.totalGameTime = 300.0 // Slow completion
        
        let score = speedrunService.calculateScore(session: session)
        
        XCTAssertEqual(score.correctAnswers, 20)
        XCTAssertEqual(score.totalQuestions, 25)
        XCTAssertEqual(score.completionTime, 300.0)
        XCTAssertEqual(score.accuracy, 0.8)
        XCTAssertLessThan(score.rating, 1000.0) // Should have lower rating for slow completion
    }
    
    func testSpeedrunScoring_IncompleteGame() {
        var session = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        session.correctAnswers = 15
        session.questionsAnswered = 20 // Didn't finish all 25
        session.totalGameTime = 200.0
        
        let score = speedrunService.calculateScore(session: session)
        
        XCTAssertEqual(score.correctAnswers, 15)
        XCTAssertEqual(score.totalQuestions, 20) // Records actual questions attempted
        XCTAssertEqual(score.accuracy, 0.75)
        XCTAssertLessThan(score.rating, 800.0) // Penalty for incomplete game
    }
    
    // MARK: - Trophy Calculation Tests
    
    func testTrophyCalculation_BeatTheClock_Excellent() {
        var session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        session.correctAnswers = 18
        session.questionsAnswered = 20
        session.totalGameTime = 60.0
        
        // Add some correct answers to session for streak calculation
        for i in 0..<18 {
            session.answers.append(GameAnswer(
                plantId: "plant-\(i)",
                selectedAnswer: "correct",
                correctAnswer: "correct",
                isCorrect: i < 15, // 15 correct in a row, then 3 incorrect, then 3 more correct
                timestamp: Date(),
                timeToAnswer: 3.0
            ))
        }
        
        let reward = trophyService.calculateTrophiesEarned(session: session)
        
        XCTAssertGreaterThan(reward.totalTrophies, 0)
        XCTAssertGreaterThan(reward.breakdown.baseTrophies, 0)
        XCTAssertGreaterThan(reward.breakdown.accuracyBonus, 0) // Good accuracy should give bonus
        XCTAssertEqual(reward.breakdown.difficultyMultiplier, 1.0) // Medium difficulty
    }
    
    func testTrophyCalculation_Speedrun_Perfect() {
        var session = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        session.correctAnswers = 25
        session.questionsAnswered = 25
        session.totalGameTime = 85.0 // Fast time
        
        // Add perfect streak
        for i in 0..<25 {
            session.answers.append(GameAnswer(
                plantId: "plant-\(i)",
                selectedAnswer: "correct",
                correctAnswer: "correct",
                isCorrect: true,
                timestamp: Date(),
                timeToAnswer: 3.0
            ))
        }
        
        let reward = trophyService.calculateTrophiesEarned(session: session)
        
        XCTAssertGreaterThan(reward.totalTrophies, 200) // Should be high for perfect game
        XCTAssertEqual(reward.breakdown.baseTrophies, 200) // 25 * 8
        XCTAssertEqual(reward.breakdown.accuracyBonus, 100) // Perfect accuracy
        XCTAssertGreaterThan(reward.breakdown.streakBonus, 0) // Perfect streak
        XCTAssertGreaterThan(reward.breakdown.speedBonus, 0) // Fast completion
        XCTAssertEqual(reward.breakdown.completionBonus, 200) // Completed under 1.5 minutes
        XCTAssertEqual(reward.breakdown.difficultyMultiplier, 1.3) // Hard difficulty
    }
    
    func testTrophyCalculation_DifficultyMultipliers() {
        var baseSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        baseSession.correctAnswers = 10
        baseSession.questionsAnswered = 12
        baseSession.totalGameTime = 60.0
        
        // Test all difficulty levels
        let difficulties: [Game.Difficulty] = [.easy, .medium, .hard, .expert]
        let expectedMultipliers: [Double] = [0.8, 1.0, 1.3, 1.6]
        
        for (difficulty, expectedMultiplier) in zip(difficulties, expectedMultipliers) {
            var session = baseSession
            session.difficulty = difficulty
            
            let reward = trophyService.calculateTrophiesEarned(session: session)
            
            XCTAssertEqual(reward.breakdown.difficultyMultiplier, expectedMultiplier, accuracy: 0.01)
        }
    }
    
    func testTrophyCalculation_StreakBonus() {
        var session = SingleUserGameSession(mode: .speedrun, difficulty: .medium)
        session.correctAnswers = 20
        session.questionsAnswered = 25
        session.totalGameTime = 120.0
        
        // Test different streak lengths
        let streakLengths = [2, 5, 10, 15, 20]
        let expectedBonuses = [0, 25, 50, 80, 80] // Based on calculateStreakBonus logic
        
        for (streakLength, expectedBonus) in zip(streakLengths, expectedBonuses) {
            session.answers = []
            
            // Add streak of correct answers
            for i in 0..<streakLength {
                session.answers.append(GameAnswer(
                    plantId: "plant-\(i)",
                    selectedAnswer: "correct",
                    correctAnswer: "correct",
                    isCorrect: true,
                    timestamp: Date(),
                    timeToAnswer: 3.0
                ))
            }
            
            // Add some incorrect answers to break streak
            if streakLength < 25 {
                for i in streakLength..<25 {
                    session.answers.append(GameAnswer(
                        plantId: "plant-\(i)",
                        selectedAnswer: "wrong",
                        correctAnswer: "correct",
                        isCorrect: false,
                        timestamp: Date(),
                        timeToAnswer: 3.0
                    ))
                }
            }
            
            let reward = trophyService.calculateTrophiesEarned(session: session)
            XCTAssertEqual(reward.breakdown.streakBonus, expectedBonus)
        }
    }
    
    // MARK: - Personal Best Tracking Tests
    
    func testBeatTheClockPersonalBest() {
        // First game
        var session1 = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        session1.correctAnswers = 15
        session1.questionsAnswered = 18
        session1.totalGameTime = 60.0
        
        let score1 = beatTheClockService.calculateScore(session: session1)
        beatTheClockService.saveScore(score1)
        
        let best1 = beatTheClockService.getBestScore(for: .medium)
        XCTAssertNotNil(best1)
        XCTAssertEqual(best1?.correctAnswers, 15)
        
        // Better game
        var session2 = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        session2.correctAnswers = 20
        session2.questionsAnswered = 22
        session2.totalGameTime = 60.0
        
        let score2 = beatTheClockService.calculateScore(session: session2)
        beatTheClockService.saveScore(score2)
        
        let best2 = beatTheClockService.getBestScore(for: .medium)
        XCTAssertNotNil(best2)
        XCTAssertEqual(best2?.correctAnswers, 20) // Should be updated
        
        // Worse game
        var session3 = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        session3.correctAnswers = 10
        session3.questionsAnswered = 15
        session3.totalGameTime = 60.0
        
        let score3 = beatTheClockService.calculateScore(session: session3)
        beatTheClockService.saveScore(score3)
        
        let best3 = beatTheClockService.getBestScore(for: .medium)
        XCTAssertNotNil(best3)
        XCTAssertEqual(best3?.correctAnswers, 20) // Should remain unchanged
    }
    
    func testSpeedrunPersonalBest() {
        // First game
        var session1 = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        session1.correctAnswers = 25
        session1.questionsAnswered = 25
        session1.totalGameTime = 120.0
        
        let score1 = speedrunService.calculateScore(session: session1)
        speedrunService.saveScore(score1)
        
        let best1 = speedrunService.getBestScore(for: .hard)
        XCTAssertNotNil(best1)
        XCTAssertEqual(best1?.completionTime, 120.0)
        
        // Faster game
        var session2 = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        session2.correctAnswers = 24
        session2.questionsAnswered = 25
        session2.totalGameTime = 90.0
        
        let score2 = speedrunService.calculateScore(session: session2)
        speedrunService.saveScore(score2)
        
        let best2 = speedrunService.getBestScore(for: .hard)
        XCTAssertNotNil(best2)
        // Should update if rating is better, even with one wrong answer but much faster time
        XCTAssertGreaterThan(best2!.rating, best1!.rating)
    }
    
    // MARK: - Leaderboard Tests
    
    func testBeatTheClockLeaderboard() {
        // Add multiple scores
        let scores = [
            (15, 18, 60.0),
            (20, 22, 60.0),
            (12, 15, 60.0),
            (18, 20, 60.0),
            (25, 25, 60.0)
        ]
        
        for (correct, total, time) in scores {
            var session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
            session.correctAnswers = correct
            session.questionsAnswered = total
            session.totalGameTime = time
            
            let score = beatTheClockService.calculateScore(session: session)
            beatTheClockService.saveScore(score)
        }
        
        let leaderboard = beatTheClockService.getLeaderboard(for: .medium)
        XCTAssertFalse(leaderboard.isEmpty)
        
        // Should be sorted by correct answers descending
        if leaderboard.count > 1 {
            XCTAssertGreaterThanOrEqual(leaderboard[0].correctAnswers, leaderboard[1].correctAnswers)
        }
        
        // Best score should be 25 correct
        XCTAssertEqual(leaderboard.first?.correctAnswers, 25)
    }
    
    func testSpeedrunLeaderboard() {
        // Add multiple scores with different ratings
        let sessions = [
            (25, 25, 120.0), // Perfect, medium time
            (24, 25, 90.0),  // One wrong, fast time
            (25, 25, 85.0),  // Perfect, very fast time
            (20, 25, 150.0), // Some wrong, slow time
            (23, 25, 100.0)  // Few wrong, good time
        ]
        
        for (correct, total, time) in sessions {
            var session = SingleUserGameSession(mode: .speedrun, difficulty: .expert)
            session.correctAnswers = correct
            session.questionsAnswered = total
            session.totalGameTime = time
            
            let score = speedrunService.calculateScore(session: session)
            speedrunService.saveScore(score)
        }
        
        let leaderboard = speedrunService.getLeaderboard(for: .expert)
        XCTAssertFalse(leaderboard.isEmpty)
        
        // Should be sorted by rating descending
        if leaderboard.count > 1 {
            XCTAssertGreaterThanOrEqual(leaderboard[0].rating, leaderboard[1].rating)
        }
        
        // Best score should be perfect with very fast time
        let bestScore = leaderboard.first!
        XCTAssertEqual(bestScore.correctAnswers, 25)
        XCTAssertEqual(bestScore.completionTime, 85.0)
    }
}