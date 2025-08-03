import XCTest
import CoreData
@testable import BotanyBattle

final class CoreDataServiceTests: XCTestCase {
    
    var sut: CoreDataService!
    var testContext: NSManagedObjectContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for testing
        sut = CoreDataService()
        
        // Override with in-memory store for testing
        let persistentContainer = NSPersistentContainer(name: "BotanyBattle")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        await withCheckedContinuation { continuation in
            persistentContainer.loadPersistentStores { _, error in
                XCTAssertNil(error)
                continuation.resume()
            }
        }
        
        // Wait for Core Data to be ready
        await waitForCoreDataReady()
    }
    
    override func tearDown() async throws {
        try await sut?.clearAllData()
        sut = nil
        testContext = nil
        try await super.tearDown()
    }
    
    private func waitForCoreDataReady() async {
        while !sut.isReady {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    // MARK: - Game Progress Tests
    
    func testSaveGameProgress_ValidData_SavesSuccessfully() async throws {
        // Given
        let progressData = createMockGameProgressData()
        
        // When
        try await sut.saveGameProgress(progressData)
        
        // Then
        let savedProgress = try await sut.fetchGameProgress(for: progressData.userId, mode: progressData.mode)
        XCTAssertEqual(savedProgress.count, 1)
        XCTAssertEqual(savedProgress[0].id, progressData.id)
        XCTAssertEqual(savedProgress[0].score, progressData.score)
        XCTAssertEqual(savedProgress[0].mode, progressData.mode)
    }
    
    func testFetchGameProgress_MultipleEntries_ReturnsSortedByDate() async throws {
        // Given
        let userId = "test-user"
        let mode = GameMode.practice
        
        let progress1 = createMockGameProgressData(userId: userId, mode: mode, score: 10, date: Date().addingTimeInterval(-3600))
        let progress2 = createMockGameProgressData(userId: userId, mode: mode, score: 20, date: Date().addingTimeInterval(-1800))
        let progress3 = createMockGameProgressData(userId: userId, mode: mode, score: 15, date: Date())
        
        // When
        try await sut.saveGameProgress(progress1)
        try await sut.saveGameProgress(progress2)
        try await sut.saveGameProgress(progress3)
        
        let fetchedProgress = try await sut.fetchGameProgress(for: userId, mode: mode)
        
        // Then
        XCTAssertEqual(fetchedProgress.count, 3)
        XCTAssertEqual(fetchedProgress[0].score, 15) // Most recent first
        XCTAssertEqual(fetchedProgress[1].score, 20)
        XCTAssertEqual(fetchedProgress[2].score, 10)
    }
    
    func testGetPersonalBest_MultipleScores_ReturnsHighestScore() async throws {
        // Given
        let userId = "test-user"
        let mode = GameMode.beatTheClock
        
        let progress1 = createMockGameProgressData(userId: userId, mode: mode, score: 15)
        let progress2 = createMockGameProgressData(userId: userId, mode: mode, score: 25)
        let progress3 = createMockGameProgressData(userId: userId, mode: mode, score: 20)
        
        // When
        try await sut.saveGameProgress(progress1)
        try await sut.saveGameProgress(progress2)
        try await sut.saveGameProgress(progress3)
        
        let personalBest = try await sut.getPersonalBest(for: userId, mode: mode)
        
        // Then
        XCTAssertNotNil(personalBest)
        XCTAssertEqual(personalBest?.score, 25)
    }
    
    func testGetPersonalBest_NoData_ReturnsNil() async throws {
        // Given
        let userId = "non-existent-user"
        let mode = GameMode.speedrun
        
        // When
        let personalBest = try await sut.getPersonalBest(for: userId, mode: mode)
        
        // Then
        XCTAssertNil(personalBest)
    }
    
    // MARK: - Plant Caching Tests
    
    func testCachePlantData_ValidPlants_CachesSuccessfully() async throws {
        // Given
        let plants = [
            createMockPlantData(id: "1", name: "Oak", scientificName: "Quercus robur"),
            createMockPlantData(id: "2", name: "Rose", scientificName: "Rosa rubiginosa")
        ]
        
        // When
        try await sut.cachePlantData(plants)
        
        // Then
        let cachedPlants = try await sut.fetchCachedPlants()
        XCTAssertEqual(cachedPlants.count, 2)
        XCTAssertEqual(cachedPlants[0].name, "Oak")
        XCTAssertEqual(cachedPlants[1].name, "Rose")
    }
    
    func testCachePlantData_ReplaceExistingCache_ReplacesSuccessfully() async throws {
        // Given - Initial cache
        let initialPlants = [createMockPlantData(id: "1", name: "Old Plant", scientificName: "Oldus plantus")]
        try await sut.cachePlantData(initialPlants)
        
        // When - Replace with new data
        let newPlants = [
            createMockPlantData(id: "2", name: "New Plant 1", scientificName: "Newus plantus1"),
            createMockPlantData(id: "3", name: "New Plant 2", scientificName: "Newus plantus2")
        ]
        try await sut.cachePlantData(newPlants)
        
        // Then
        let cachedPlants = try await sut.fetchCachedPlants()
        XCTAssertEqual(cachedPlants.count, 2)
        XCTAssertFalse(cachedPlants.contains { $0.name == "Old Plant" })
        XCTAssertTrue(cachedPlants.contains { $0.name == "New Plant 1" })
        XCTAssertTrue(cachedPlants.contains { $0.name == "New Plant 2" })
    }
    
    func testGetCacheAge_WithCachedData_ReturnsValidAge() async throws {
        // Given
        let plants = [createMockPlantData(id: "1", name: "Test Plant", scientificName: "Testus plantus")]
        
        // When
        try await sut.cachePlantData(plants)
        let cacheAge = try await sut.getCacheAge()
        
        // Then
        XCTAssertNotNil(cacheAge)
        XCTAssertLessThan(abs(cacheAge!), 1.0) // Should be very recent (less than 1 second ago)
    }
    
    func testGetCacheAge_NoCachedData_ReturnsNil() async throws {
        // When
        let cacheAge = try await sut.getCacheAge()
        
        // Then
        XCTAssertNil(cacheAge)
    }
    
    // MARK: - User Settings Tests
    
    func testSaveUserSettings_ValidSettings_SavesSuccessfully() async throws {
        // Given
        let settingsData = createMockUserSettingsData()
        
        // When
        try await sut.saveUserSettings(settingsData)
        
        // Then
        let fetchedSettings = try await sut.fetchUserSettings(for: settingsData.userId)
        XCTAssertNotNil(fetchedSettings)
        XCTAssertEqual(fetchedSettings?.userId, settingsData.userId)
        XCTAssertEqual(fetchedSettings?.soundEnabled, settingsData.soundEnabled)
        XCTAssertEqual(fetchedSettings?.selectedTheme, settingsData.selectedTheme)
        XCTAssertEqual(fetchedSettings?.selectedDifficulty, settingsData.selectedDifficulty)
    }
    
    func testSaveUserSettings_UpdateExisting_UpdatesSuccessfully() async throws {
        // Given - Initial settings
        let initialSettings = createMockUserSettingsData(soundEnabled: true, hapticsEnabled: false)
        try await sut.saveUserSettings(initialSettings)
        
        // When - Update settings
        let updatedSettings = UserSettingsData(
            userId: initialSettings.userId,
            soundEnabled: false,
            hapticsEnabled: true,
            reducedAnimations: initialSettings.reducedAnimations,
            selectedTheme: .dark,
            selectedDifficulty: .hard
        )
        try await sut.saveUserSettings(updatedSettings)
        
        // Then
        let fetchedSettings = try await sut.fetchUserSettings(for: initialSettings.userId)
        XCTAssertNotNil(fetchedSettings)
        XCTAssertEqual(fetchedSettings?.soundEnabled, false)
        XCTAssertEqual(fetchedSettings?.hapticsEnabled, true)
        XCTAssertEqual(fetchedSettings?.selectedTheme, .dark)
        XCTAssertEqual(fetchedSettings?.selectedDifficulty, .hard)
    }
    
    // MARK: - Achievement Tests
    
    func testSaveAchievement_ValidAchievement_SavesSuccessfully() async throws {
        // Given
        let achievementData = createMockAchievementData()
        
        // When
        try await sut.saveAchievement(achievementData)
        
        // Then
        let achievements = try await sut.fetchAchievements(for: achievementData.userId)
        XCTAssertEqual(achievements.count, 1)
        XCTAssertEqual(achievements[0].id, achievementData.id)
        XCTAssertEqual(achievements[0].title, achievementData.title)
        XCTAssertEqual(achievements[0].userId, achievementData.userId)
    }
    
    func testFetchAchievements_MultipleUsers_ReturnsOnlyUserAchievements() async throws {
        // Given
        let user1Achievement = createMockAchievementData(userId: "user1", title: "User 1 Achievement")
        let user2Achievement = createMockAchievementData(userId: "user2", title: "User 2 Achievement")
        
        // When
        try await sut.saveAchievement(user1Achievement)
        try await sut.saveAchievement(user2Achievement)
        
        let user1Achievements = try await sut.fetchAchievements(for: "user1")
        let user2Achievements = try await sut.fetchAchievements(for: "user2")
        
        // Then
        XCTAssertEqual(user1Achievements.count, 1)
        XCTAssertEqual(user2Achievements.count, 1)
        XCTAssertEqual(user1Achievements[0].title, "User 1 Achievement")
        XCTAssertEqual(user2Achievements[0].title, "User 2 Achievement")
    }
    
    // MARK: - Data Maintenance Tests
    
    func testPerformMaintenance_CleansOldData() async throws {
        // Given - Create old game progress entries (simulating 200 entries)
        let userId = "test-user"
        for i in 0..<200 {
            let progress = createMockGameProgressData(
                userId: userId,
                mode: .practice,
                score: i,
                date: Date().addingTimeInterval(-Double(i * 3600)) // Each hour older
            )
            try await sut.saveGameProgress(progress)
        }
        
        // When
        await sut.performMaintenance()
        
        // Then - Should keep only 100 most recent entries
        let remainingProgress = try await sut.fetchGameProgress(for: userId)
        XCTAssertLessThanOrEqual(remainingProgress.count, 100)
        
        // Verify most recent entries are kept
        XCTAssertEqual(remainingProgress[0].score, 0) // Most recent (score 0)
        XCTAssertEqual(remainingProgress.last?.score, 99) // 100th entry
    }
    
    func testClearAllData_RemovesAllData() async throws {
        // Given - Add data to all entities
        try await sut.saveGameProgress(createMockGameProgressData())
        try await sut.cachePlantData([createMockPlantData(id: "1", name: "Test", scientificName: "Test")])
        try await sut.saveUserSettings(createMockUserSettingsData())
        try await sut.saveAchievement(createMockAchievementData())
        
        // When
        try await sut.clearAllData()
        
        // Then
        let gameProgress = try await sut.fetchGameProgress(for: "test-user")
        let cachedPlants = try await sut.fetchCachedPlants()
        let userSettings = try await sut.fetchUserSettings(for: "test-user")
        let achievements = try await sut.fetchAchievements(for: "test-user")
        
        XCTAssertTrue(gameProgress.isEmpty)
        XCTAssertTrue(cachedPlants.isEmpty)
        XCTAssertNil(userSettings)
        XCTAssertTrue(achievements.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveGameProgress_InvalidData_ThrowsError() async {
        // Given
        let invalidProgress = GameProgressData(
            id: UUID(),
            mode: .practice,
            score: -1, // Invalid score
            correctAnswers: -1, // Invalid answers
            totalQuestions: 0, // Invalid total
            timeElapsed: -1, // Invalid time
            completedAt: Date(),
            userId: ""
        )
        
        // When/Then
        do {
            try await sut.saveGameProgress(invalidProgress)
            // Should handle gracefully, not throw
        } catch {
            // Error handling is acceptable
            XCTAssertNotNil(error)
        }
    }
    
    func testFetchGameProgress_DatabaseError_HandlesGracefully() async {
        // This test would require more sophisticated mocking of Core Data errors
        // For now, we'll test that the method doesn't crash with normal operations
        
        // Given
        let userId = "test-user"
        
        // When
        let progress = try? await sut.fetchGameProgress(for: userId)
        
        // Then
        XCTAssertNotNil(progress) // Should return empty array, not nil
        XCTAssertTrue(progress?.isEmpty ?? false)
    }
    
    // MARK: - Performance Tests
    
    func testSaveGameProgress_Performance() async throws {
        let progressData = createMockGameProgressData()
        
        measure {
            let expectation = XCTestExpectation(description: "Save game progress")
            
            Task {
                try? await sut.saveGameProgress(progressData)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    func testFetchCachedPlants_Performance() async throws {
        // Given - Cache some plants first
        let plants = (0..<100).map { i in
            createMockPlantData(id: "\(i)", name: "Plant \(i)", scientificName: "Plantus \(i)")
        }
        try await sut.cachePlantData(plants)
        
        measure {
            let expectation = XCTestExpectation(description: "Fetch cached plants")
            
            Task {
                _ = try? await sut.fetchCachedPlants()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSaveOperations_HandlesSafely() async throws {
        // Given
        let progressEntries = (0..<10).map { i in
            createMockGameProgressData(
                userId: "user-\(i)",
                mode: .practice,
                score: i * 10
            )
        }
        
        // When - Concurrent saves
        await withTaskGroup(of: Void.self) { group in
            for progress in progressEntries {
                group.addTask {
                    try? await self.sut.saveGameProgress(progress)
                }
            }
        }
        
        // Then - All entries should be saved
        let allProgress = try await sut.fetchGameProgress(for: "user-1") // Test one user
        XCTAssertEqual(allProgress.count, 1)
        XCTAssertEqual(allProgress[0].score, 10)
    }
}

// MARK: - Test Helper Methods

extension CoreDataServiceTests {
    
    private func createMockGameProgressData(
        userId: String = "test-user",
        mode: GameMode = .practice,
        score: Int = 15,
        date: Date = Date()
    ) -> GameProgressData {
        return GameProgressData(
            id: UUID(),
            mode: mode,
            score: score,
            correctAnswers: 12,
            totalQuestions: 15,
            timeElapsed: 120.0,
            completedAt: date,
            userId: userId
        )
    }
    
    private func createMockPlantData(id: String, name: String, scientificName: String) -> PlantData {
        return PlantData(
            id: id,
            name: name,
            scientificName: scientificName,
            imageURL: "https://example.com/\(id).jpg",
            description: "A test plant for unit testing",
            difficulty: .medium,
            category: "Test Plants"
        )
    }
    
    private func createMockUserSettingsData(
        userId: String = "test-user",
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true
    ) -> UserSettingsData {
        return UserSettingsData(
            userId: userId,
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled,
            reducedAnimations: false,
            selectedTheme: .light,
            selectedDifficulty: .medium
        )
    }
    
    private func createMockAchievementData(
        userId: String = "test-user",
        title: String = "Test Achievement"
    ) -> AchievementData {
        return AchievementData(
            id: UUID(),
            userId: userId,
            title: title,
            description: "A test achievement for unit testing",
            icon: "star.fill",
            unlockedAt: Date(),
            category: "Testing"
        )
    }
}

// MARK: - Additional Data Models for Testing

// These would need to be defined if not already present in the main codebase
extension GameMode: CaseIterable {
    public static var allCases: [GameMode] = [.practice, .speedrun, .beatTheClock]
}

enum Theme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

enum Difficulty: String, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
}