import XCTest
@testable import BotanyBattle

final class UserDefaultsServiceTests: XCTestCase {
    
    var sut: UserDefaultsService!
    var mockUserDefaults: MockUserDefaults!
    
    override func setUp() {
        super.setUp()
        mockUserDefaults = MockUserDefaults()
        sut = UserDefaultsService(userDefaults: mockUserDefaults)
    }
    
    override func tearDown() {
        sut = nil
        mockUserDefaults = nil
        super.tearDown()
    }
    
    // MARK: - First Launch Tests
    
    func testIsFirstLaunch_InitiallyTrue() {
        // Given & When
        let isFirstLaunch = sut.isFirstLaunch
        
        // Then
        XCTAssertTrue(isFirstLaunch)
    }
    
    func testMarkFirstLaunchComplete_SetsToFalse() {
        // Given
        XCTAssertTrue(sut.isFirstLaunch)
        
        // When
        sut.markFirstLaunchComplete()
        
        // Then
        XCTAssertFalse(sut.isFirstLaunch)
        XCTAssertTrue(mockUserDefaults.setValue_called)
    }
    
    // MARK: - Tutorial Tests
    
    func testTutorialCompleted_InitiallyFalse() {
        // Given & When
        let isCompleted = sut.tutorialCompleted
        
        // Then
        XCTAssertFalse(isCompleted)
    }
    
    func testSetTutorialCompleted_UpdatesValue() {
        // Given
        XCTAssertFalse(sut.tutorialCompleted)
        
        // When
        sut.tutorialCompleted = true
        
        // Then
        XCTAssertTrue(sut.tutorialCompleted)
        XCTAssertTrue(mockUserDefaults.setValue_called)
    }
    
    // MARK: - High Score Tests
    
    func testPracticeHighScore_InitiallyZero() {
        // Given & When
        let highScore = sut.practiceHighScore
        
        // Then
        XCTAssertEqual(highScore, 0)
    }
    
    func testUpdatePracticeHighScore_OnlyUpdatesIfHigher() {
        // Given
        sut.practiceHighScore = 100
        
        // When - Try to set lower score
        sut.updatePracticeHighScore(50)
        
        // Then
        XCTAssertEqual(sut.practiceHighScore, 100)
        
        // When - Set higher score
        sut.updatePracticeHighScore(150)
        
        // Then
        XCTAssertEqual(sut.practiceHighScore, 150)
    }
    
    func testSpeedrunBestTime_InitiallyMaxValue() {
        // Given & When
        let bestTime = sut.speedrunBestTime
        
        // Then
        XCTAssertEqual(bestTime, Double.greatestFiniteMagnitude)
    }
    
    func testUpdateSpeedrunBestTime_OnlyUpdatesIfFaster() {
        // Given
        sut.speedrunBestTime = 60.0
        
        // When - Try to set slower time
        sut.updateSpeedrunBestTime(90.0)
        
        // Then
        XCTAssertEqual(sut.speedrunBestTime, 60.0)
        
        // When - Set faster time
        sut.updateSpeedrunBestTime(45.0)
        
        // Then
        XCTAssertEqual(sut.speedrunBestTime, 45.0)
    }
    
    // MARK: - Trophy Tests
    
    func testTotalTrophies_InitiallyZero() {
        // Given & When
        let trophies = sut.totalTrophies
        
        // Then
        XCTAssertEqual(trophies, 0)
    }
    
    func testAddTrophies_IncreasesTotal() {
        // Given
        sut.totalTrophies = 50
        
        // When
        sut.addTrophies(25)
        
        // Then
        XCTAssertEqual(sut.totalTrophies, 75)
    }
    
    func testSpendTrophies_DecreasesTotal() {
        // Given
        sut.totalTrophies = 100
        
        // When
        let success = sut.spendTrophies(30)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertEqual(sut.totalTrophies, 70)
    }
    
    func testSpendTrophies_InsufficientFunds_ReturnsFalse() {
        // Given
        sut.totalTrophies = 20
        
        // When
        let success = sut.spendTrophies(50)
        
        // Then
        XCTAssertFalse(success)
        XCTAssertEqual(sut.totalTrophies, 20) // Unchanged
    }
    
    func testCanAfford_ReturnsCorrectValue() {
        // Given
        sut.totalTrophies = 100
        
        // When & Then
        XCTAssertTrue(sut.canAfford(50))
        XCTAssertTrue(sut.canAfford(100))
        XCTAssertFalse(sut.canAfford(101))
    }
    
    // MARK: - Statistics Tests
    
    func testGamesPlayed_InitiallyZero() {
        // Given & When
        let gamesPlayed = sut.gamesPlayed
        
        // Then
        XCTAssertEqual(gamesPlayed, 0)
    }
    
    func testIncrementGamesPlayed_IncreasesCount() {
        // Given
        sut.gamesPlayed = 5
        
        // When
        sut.incrementGamesPlayed()
        
        // Then
        XCTAssertEqual(sut.gamesPlayed, 6)
    }
    
    func testRecordGameCompletion_UpdatesStatistics() {
        // Given
        let initialGames = sut.gamesPlayed
        let initialCorrect = sut.totalCorrectAnswers
        
        // When
        sut.recordGameCompletion(correctAnswers: 8, wasPerfect: true)
        
        // Then
        XCTAssertEqual(sut.gamesPlayed, initialGames + 1)
        XCTAssertEqual(sut.totalCorrectAnswers, initialCorrect + 8)
        XCTAssertEqual(sut.perfectGames, 1)
    }
    
    // MARK: - Streak Tests
    
    func testCurrentStreak_InitiallyZero() {
        // Given & When
        let streak = sut.currentStreak
        
        // Then
        XCTAssertEqual(streak, 0)
    }
    
    func testIncrementStreak_IncreasesStreakAndUpdatesLongest() {
        // Given
        sut.currentStreak = 5
        sut.longestStreak = 5
        
        // When
        sut.incrementStreak()
        
        // Then
        XCTAssertEqual(sut.currentStreak, 6)
        XCTAssertEqual(sut.longestStreak, 6)
    }
    
    func testResetStreak_SetsToZero() {
        // Given
        sut.currentStreak = 10
        
        // When
        sut.resetStreak()
        
        // Then
        XCTAssertEqual(sut.currentStreak, 0)
    }
    
    // MARK: - Shop Items Tests
    
    func testOwnedShopItems_InitiallyEmpty() {
        // Given & When
        let ownedItems = sut.ownedShopItems
        
        // Then
        XCTAssertTrue(ownedItems.isEmpty)
    }
    
    func testPurchaseItem_AddsToOwnedItems() {
        // Given
        let itemID = 1
        XCTAssertFalse(sut.ownsItem(itemID))
        
        // When
        sut.purchaseItem(itemID)
        
        // Then
        XCTAssertTrue(sut.ownsItem(itemID))
        XCTAssertTrue(sut.ownedShopItems.contains(itemID))
    }
    
    func testEquippedItems_InitiallyEmpty() {
        // Given & When
        let equippedItems = sut.equippedItems
        
        // Then
        XCTAssertTrue(equippedItems.isEmpty)
    }
    
    func testEquipItem_AddsToEquippedItems() {
        // Given
        let itemID = 2
        sut.purchaseItem(itemID) // Must own item first
        
        // When
        sut.equipItem(itemID)
        
        // Then
        XCTAssertTrue(sut.isItemEquipped(itemID))
        XCTAssertTrue(sut.equippedItems.contains(itemID))
    }
    
    func testUnequipItem_RemovesFromEquippedItems() {
        // Given
        let itemID = 3
        sut.purchaseItem(itemID)
        sut.equipItem(itemID)
        XCTAssertTrue(sut.isItemEquipped(itemID))
        
        // When
        sut.unequipItem(itemID)
        
        // Then
        XCTAssertFalse(sut.isItemEquipped(itemID))
        XCTAssertFalse(sut.equippedItems.contains(itemID))
    }
    
    // MARK: - Settings Tests
    
    func testSoundEnabled_InitiallyTrue() {
        // Given & When
        let soundEnabled = sut.soundEnabled
        
        // Then
        XCTAssertTrue(soundEnabled)
    }
    
    func testHapticsEnabled_InitiallyTrue() {
        // Given & When
        let hapticsEnabled = sut.hapticsEnabled
        
        // Then
        XCTAssertTrue(hapticsEnabled)
    }
    
    func testReducedAnimations_InitiallyFalse() {
        // Given & When
        let reducedAnimations = sut.reducedAnimations
        
        // Then
        XCTAssertFalse(reducedAnimations)
    }
    
    func testUpdateSettings_PersistsChanges() {
        // Given
        XCTAssertTrue(sut.soundEnabled)
        XCTAssertTrue(sut.hapticsEnabled)
        XCTAssertFalse(sut.reducedAnimations)
        
        // When
        sut.soundEnabled = false
        sut.hapticsEnabled = false
        sut.reducedAnimations = true
        
        // Then
        XCTAssertFalse(sut.soundEnabled)
        XCTAssertFalse(sut.hapticsEnabled)
        XCTAssertTrue(sut.reducedAnimations)
        XCTAssertEqual(mockUserDefaults.setValueCallCount, 3)
    }
    
    // MARK: - Last Play Date Tests
    
    func testLastPlayDate_InitiallyNil() {
        // Given & When
        let lastPlayDate = sut.lastPlayDate
        
        // Then
        XCTAssertNil(lastPlayDate)
    }
    
    func testUpdateLastPlayDate_SetsCurrentDate() {
        // Given
        XCTAssertNil(sut.lastPlayDate)
        
        // When
        sut.updateLastPlayDate()
        
        // Then
        XCTAssertNotNil(sut.lastPlayDate)
        XCTAssertTrue(mockUserDefaults.setValue_called)
    }
    
    // MARK: - Data Validation Tests
    
    func testNegativeValues_NotAllowed() {
        // Given & When & Then
        sut.addTrophies(-10)
        XCTAssertEqual(sut.totalTrophies, 0) // Should not go negative
        
        sut.updatePracticeHighScore(-5)
        XCTAssertEqual(sut.practiceHighScore, 0) // Should not accept negative
    }
    
    // MARK: - Performance Tests
    
    func testUserDefaultsAccess_Performance() {
        measure {
            for _ in 0..<1000 {
                _ = sut.totalTrophies
                sut.totalTrophies = Int.random(in: 0...1000)
            }
        }
    }
}

// MARK: - Mock UserDefaults

class MockUserDefaults: UserDefaultsProtocol {
    private var storage: [String: Any] = [:]
    
    var setValue_called = false
    var setValueCallCount = 0
    
    func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }
    
    func set(_ value: Any?, forKey defaultName: String) {
        setValue_called = true
        setValueCallCount += 1
        storage[defaultName] = value
    }
    
    func bool(forKey defaultName: String) -> Bool {
        return storage[defaultName] as? Bool ?? false
    }
    
    func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }
    
    func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }
    
    func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }
    
    func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }
    
    func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }
    
    func synchronize() -> Bool {
        return true
    }
}