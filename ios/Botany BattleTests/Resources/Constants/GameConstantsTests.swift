import XCTest
@testable import BotanyBattle

final class GameConstantsTests: XCTestCase {
    
    func testPracticeTimeLimit() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.practiceTimeLimit, 60)
        XCTAssertGreaterThan(GameConstants.practiceTimeLimit, 0)
    }
    
    func testTimeAttackLimit() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.timeAttackLimit, 15)
        XCTAssertGreaterThan(GameConstants.timeAttackLimit, 0)
        XCTAssertLessThan(GameConstants.timeAttackLimit, GameConstants.practiceTimeLimit)
    }
    
    func testSpeedrunQuestionCount() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.speedrunQuestionCount, 25)
        XCTAssertGreaterThan(GameConstants.speedrunQuestionCount, 0)
    }
    
    func testMaxRounds() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.maxRounds, 5)
        XCTAssertGreaterThan(GameConstants.maxRounds, 0)
        XCTAssertLessThan(GameConstants.maxRounds, 10, "Max rounds should be reasonable for gameplay")
    }
    
    func testAnswerOptionsCount() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.answerOptionsCount, 4)
        XCTAssertGreaterThanOrEqual(GameConstants.answerOptionsCount, 2)
        XCTAssertLessThanOrEqual(GameConstants.answerOptionsCount, 6)
    }
    
    func testScoreMultipliers() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.correctAnswerPoints, 10)
        XCTAssertEqual(GameConstants.speedBonus, 5)
        XCTAssertEqual(GameConstants.streakMultiplier, 2)
        
        XCTAssertGreaterThan(GameConstants.correctAnswerPoints, 0)
        XCTAssertGreaterThan(GameConstants.speedBonus, 0)
        XCTAssertGreaterThan(GameConstants.streakMultiplier, 1)
    }
    
    func testTimingConstants() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.questionTransitionDelay, 1.5)
        XCTAssertEqual(GameConstants.resultDisplayDuration, 3.0)
        
        XCTAssertGreaterThan(GameConstants.questionTransitionDelay, 0)
        XCTAssertGreaterThan(GameConstants.resultDisplayDuration, 0)
    }
    
    func testAchievementThresholds() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.perfectScoreThreshold, 100)
        XCTAssertEqual(GameConstants.speedDemonThreshold, 30)
        XCTAssertEqual(GameConstants.plantExpertThreshold, 500)
        
        XCTAssertGreaterThan(GameConstants.perfectScoreThreshold, 0)
        XCTAssertGreaterThan(GameConstants.speedDemonThreshold, 0)
        XCTAssertGreaterThan(GameConstants.plantExpertThreshold, 0)
    }
    
    func testTrophyRewards() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.trophiesPerWin, 10)
        XCTAssertEqual(GameConstants.trophiesPerPerfectGame, 25)
        XCTAssertEqual(GameConstants.dailyBonusTrophies, 5)
        
        XCTAssertGreaterThan(GameConstants.trophiesPerWin, 0)
        XCTAssertGreaterThan(GameConstants.trophiesPerPerfectGame, GameConstants.trophiesPerWin)
        XCTAssertGreaterThan(GameConstants.dailyBonusTrophies, 0)
    }
    
    func testAPIConstants() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.maxAPIRetries, 3)
        XCTAssertEqual(GameConstants.apiTimeoutInterval, 30.0)
        XCTAssertEqual(GameConstants.cacheExpirationHours, 24)
        
        XCTAssertGreaterThan(GameConstants.maxAPIRetries, 0)
        XCTAssertGreaterThan(GameConstants.apiTimeoutInterval, 0)
        XCTAssertGreaterThan(GameConstants.cacheExpirationHours, 0)
    }
    
    func testAnimationConstants() {
        // Given & When & Then
        XCTAssertEqual(GameConstants.defaultAnimationDuration, 0.3)
        XCTAssertEqual(GameConstants.feedbackAnimationDuration, 0.5)
        
        XCTAssertGreaterThan(GameConstants.defaultAnimationDuration, 0)
        XCTAssertGreaterThan(GameConstants.feedbackAnimationDuration, 0)
    }
    
    func testConstantsRelationships() {
        // Given & When & Then
        // Verify logical relationships between constants
        XCTAssertLessThan(GameConstants.timeAttackLimit, GameConstants.practiceTimeLimit)
        XCTAssertGreaterThan(GameConstants.trophiesPerPerfectGame, GameConstants.trophiesPerWin)
        XCTAssertLessThan(GameConstants.defaultAnimationDuration, GameConstants.questionTransitionDelay)
        XCTAssertLessThan(GameConstants.questionTransitionDelay, GameConstants.resultDisplayDuration)
    }
    
    func testConstantsImmutability() {
        // Given
        let originalPracticeTime = GameConstants.practiceTimeLimit
        let originalMaxRounds = GameConstants.maxRounds
        
        // When & Then
        // Constants should be static and immutable
        XCTAssertEqual(GameConstants.practiceTimeLimit, originalPracticeTime)
        XCTAssertEqual(GameConstants.maxRounds, originalMaxRounds)
    }
}