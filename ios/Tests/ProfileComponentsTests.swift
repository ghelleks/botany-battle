import XCTest
import SwiftUI
@testable import BotanyBattle

class ProfileComponentsTests: XCTestCase {
    
    // MARK: - AchievementRow Tests
    
    func testAchievementRowCreation() {
        // Given
        let title = "Plant Expert"
        let description = "Won 100 games"
        let icon = "trophy.fill"
        
        // When
        let achievementRow = AchievementRow(
            title: title,
            description: description,
            icon: icon
        )
        
        // Then
        XCTAssertEqual(achievementRow.title, title)
        XCTAssertEqual(achievementRow.description, description)
        XCTAssertEqual(achievementRow.icon, icon)
    }
    
    func testAchievementRowProperties() {
        // Given
        let achievementRow = AchievementRow(
            title: "Speed Demon",
            description: "Answer in under 5 seconds",
            icon: "timer"
        )
        
        // Then
        XCTAssertNotNil(achievementRow.title)
        XCTAssertNotNil(achievementRow.description)
        XCTAssertNotNil(achievementRow.icon)
        XCTAssertFalse(achievementRow.title.isEmpty)
        XCTAssertFalse(achievementRow.description.isEmpty)
        XCTAssertFalse(achievementRow.icon.isEmpty)
    }
    
    // MARK: - StatRow Tests
    
    func testStatRowCreation() {
        // Given
        let label = "Total Trophies"
        let value = "1,247"
        
        // When
        let statRow = StatRow(label: label, value: value)
        
        // Then
        XCTAssertEqual(statRow.label, label)
        XCTAssertEqual(statRow.value, value)
    }
    
    func testStatRowWithNumericValue() {
        // Given
        let label = "Games Played"
        let numericValue = 156
        let value = "\(numericValue)"
        
        // When
        let statRow = StatRow(label: label, value: value)
        
        // Then
        XCTAssertEqual(statRow.label, label)
        XCTAssertEqual(statRow.value, "156")
    }
    
    func testStatRowEmptyValues() {
        // Given
        let label = ""
        let value = ""
        
        // When
        let statRow = StatRow(label: label, value: value)
        
        // Then
        XCTAssertEqual(statRow.label, "")
        XCTAssertEqual(statRow.value, "")
    }
    
    // MARK: - ProfileData Tests
    
    func testProfileDataModel() {
        // Given
        let profileData = ProfileData(
            displayName: "PlantLover42",
            rank: "Expert Botanist",
            totalTrophies: 1247,
            gamesPlayed: 156,
            perfectGames: 23,
            currentStreak: 12,
            achievements: [
                Achievement(title: "Plant Expert", description: "Won 100 games", icon: "trophy.fill"),
                Achievement(title: "Speed Demon", description: "Answer in under 5 seconds", icon: "timer")
            ]
        )
        
        // Then
        XCTAssertEqual(profileData.displayName, "PlantLover42")
        XCTAssertEqual(profileData.rank, "Expert Botanist")
        XCTAssertEqual(profileData.totalTrophies, 1247)
        XCTAssertEqual(profileData.gamesPlayed, 156)
        XCTAssertEqual(profileData.perfectGames, 23)
        XCTAssertEqual(profileData.currentStreak, 12)
        XCTAssertEqual(profileData.achievements.count, 2)
    }
    
    func testAchievementModel() {
        // Given
        let achievement = Achievement(
            title: "Streak Master",
            description: "10 win streak",
            icon: "flame.fill"
        )
        
        // Then
        XCTAssertEqual(achievement.title, "Streak Master")
        XCTAssertEqual(achievement.description, "10 win streak")
        XCTAssertEqual(achievement.icon, "flame.fill")
    }
    
    // MARK: - ProfileViewModel Tests
    
    func testProfileViewModelInitialization() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let mockAuth = MockAuthFeature()
        
        // When
        let viewModel = ProfileViewModel(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // Then
        XCTAssertNotNil(viewModel.authFeature)
        XCTAssertNotNil(viewModel.userDefaultsService)
    }
    
    func testProfileDataGeneration() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.totalTrophies = 500
        mockUserDefaults.gamesPlayed = 75
        mockUserDefaults.perfectGames = 12
        mockUserDefaults.currentStreak = 5
        
        let mockAuth = MockAuthFeature()
        mockAuth.userDisplayName = "TestUser"
        
        let viewModel = ProfileViewModel(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When
        let profileData = viewModel.currentProfileData
        
        // Then
        XCTAssertEqual(profileData.displayName, "TestUser")
        XCTAssertEqual(profileData.totalTrophies, 500)
        XCTAssertEqual(profileData.gamesPlayed, 75)
        XCTAssertEqual(profileData.perfectGames, 12)
        XCTAssertEqual(profileData.currentStreak, 5)
    }
    
    func testWinRateCalculation() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.gamesPlayed = 100
        mockUserDefaults.perfectGames = 75
        
        let mockAuth = MockAuthFeature()
        let viewModel = ProfileViewModel(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When
        let winRate = viewModel.winRate
        
        // Then
        XCTAssertEqual(winRate, 0.75, accuracy: 0.01)
    }
    
    func testWinRateWithZeroGames() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.gamesPlayed = 0
        mockUserDefaults.perfectGames = 0
        
        let mockAuth = MockAuthFeature()
        let viewModel = ProfileViewModel(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When
        let winRate = viewModel.winRate
        
        // Then
        XCTAssertEqual(winRate, 0.0)
    }
    
    // MARK: - Achievement System Tests
    
    func testAchievementUnlocking() {
        // Given
        let achievementSystem = AchievementSystem()
        
        // When
        let unlockedAchievements = achievementSystem.checkAchievements(
            gamesPlayed: 100,
            perfectGames: 75,
            currentStreak: 10,
            totalTrophies: 1000
        )
        
        // Then
        XCTAssertTrue(unlockedAchievements.contains { $0.title == "Centurion" }) // 100 games
        XCTAssertTrue(unlockedAchievements.contains { $0.title == "Streak Master" }) // 10 streak
        XCTAssertTrue(unlockedAchievements.contains { $0.title == "Trophy Hunter" }) // 1000 trophies
    }
    
    func testAchievementRequirements() {
        // Given
        let achievementSystem = AchievementSystem()
        
        // When
        let achievements = achievementSystem.allAchievements
        
        // Then
        XCTAssertTrue(achievements.count > 0)
        
        // Verify specific achievements exist
        let hasPlantExpert = achievements.contains { $0.title == "Plant Expert" }
        let hasSpeedDemon = achievements.contains { $0.title == "Speed Demon" }
        let hasStreakMaster = achievements.contains { $0.title == "Streak Master" }
        
        XCTAssertTrue(hasPlantExpert)
        XCTAssertTrue(hasSpeedDemon)
        XCTAssertTrue(hasStreakMaster)
    }
}

// MARK: - Mock Objects

class MockUserDefaultsService: UserDefaultsServiceProtocol {
    var totalTrophies: Int = 0
    var gamesPlayed: Int = 0
    var perfectGames: Int = 0
    var currentStreak: Int = 0
    var isFirstLaunch: Bool = false
    var tutorialCompleted: Bool = true
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var reducedAnimations: Bool = false
    
    func markFirstLaunchComplete() {
        isFirstLaunch = false
    }
    
    func addTrophies(_ amount: Int) {
        totalTrophies += amount
    }
    
    func incrementGamesPlayed() {
        gamesPlayed += 1
    }
    
    func incrementPerfectGames() {
        perfectGames += 1
    }
    
    func updateStreak(_ streak: Int) {
        currentStreak = streak
    }
}

class MockAuthFeature: AuthFeatureProtocol {
    var isAuthenticated: Bool = true
    var userDisplayName: String? = "MockUser"
    var authState: AuthState = .authenticated(.appleID)
    
    func signOut() async {
        isAuthenticated = false
        userDisplayName = nil
        authState = .notAuthenticated
    }
    
    func checkExistingAuthentication() async {
        // Mock implementation
    }
}

// MARK: - Protocol Definitions

protocol UserDefaultsServiceProtocol {
    var totalTrophies: Int { get set }
    var gamesPlayed: Int { get set }
    var perfectGames: Int { get set }
    var currentStreak: Int { get set }
    var isFirstLaunch: Bool { get }
    var tutorialCompleted: Bool { get set }
    var soundEnabled: Bool { get set }
    var hapticsEnabled: Bool { get set }
    var reducedAnimations: Bool { get set }
    
    func markFirstLaunchComplete()
    func addTrophies(_ amount: Int)
    func incrementGamesPlayed()
    func incrementPerfectGames()
    func updateStreak(_ streak: Int)
}

protocol AuthFeatureProtocol {
    var isAuthenticated: Bool { get }
    var userDisplayName: String? { get }
    var authState: AuthState { get }
    
    func signOut() async
    func checkExistingAuthentication() async
}

// MARK: - Data Models

struct ProfileData {
    let displayName: String
    let rank: String
    let totalTrophies: Int
    let gamesPlayed: Int
    let perfectGames: Int
    let currentStreak: Int
    let achievements: [Achievement]
}

struct Achievement {
    let title: String
    let description: String
    let icon: String
}

// MARK: - ViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    let authFeature: AuthFeatureProtocol
    let userDefaultsService: UserDefaultsServiceProtocol
    
    init(authFeature: AuthFeatureProtocol, userDefaultsService: UserDefaultsServiceProtocol) {
        self.authFeature = authFeature
        self.userDefaultsService = userDefaultsService
    }
    
    var currentProfileData: ProfileData {
        let achievementSystem = AchievementSystem()
        let unlockedAchievements = achievementSystem.checkAchievements(
            gamesPlayed: userDefaultsService.gamesPlayed,
            perfectGames: userDefaultsService.perfectGames,
            currentStreak: userDefaultsService.currentStreak,
            totalTrophies: userDefaultsService.totalTrophies
        )
        
        return ProfileData(
            displayName: authFeature.userDisplayName ?? "Player",
            rank: calculateRank(),
            totalTrophies: userDefaultsService.totalTrophies,
            gamesPlayed: userDefaultsService.gamesPlayed,
            perfectGames: userDefaultsService.perfectGames,
            currentStreak: userDefaultsService.currentStreak,
            achievements: unlockedAchievements
        )
    }
    
    var winRate: Double {
        guard userDefaultsService.gamesPlayed > 0 else { return 0.0 }
        return Double(userDefaultsService.perfectGames) / Double(userDefaultsService.gamesPlayed)
    }
    
    private func calculateRank() -> String {
        let trophies = userDefaultsService.totalTrophies
        switch trophies {
        case 0..<100: return "Novice Botanist"
        case 100..<500: return "Plant Enthusiast"
        case 500..<1000: return "Garden Expert"
        case 1000..<2000: return "Master Botanist"
        default: return "Plant Guru"
        }
    }
}

// MARK: - Achievement System

class AchievementSystem {
    let allAchievements: [Achievement] = [
        Achievement(title: "Plant Expert", description: "Won 100 games", icon: "trophy.fill"),
        Achievement(title: "Speed Demon", description: "Answer in under 5 seconds", icon: "timer"),
        Achievement(title: "Streak Master", description: "10 win streak", icon: "flame.fill"),
        Achievement(title: "Centurion", description: "Played 100 games", icon: "gamecontroller.fill"),
        Achievement(title: "Trophy Hunter", description: "Earned 1000 trophies", icon: "star.fill"),
        Achievement(title: "Perfect Start", description: "First perfect game", icon: "checkmark.circle.fill"),
        Achievement(title: "Dedicated", description: "Played 50 games", icon: "heart.fill"),
        Achievement(title: "Unstoppable", description: "20 win streak", icon: "bolt.fill")
    ]
    
    func checkAchievements(gamesPlayed: Int, perfectGames: Int, currentStreak: Int, totalTrophies: Int) -> [Achievement] {
        var unlocked: [Achievement] = []
        
        if perfectGames >= 100 {
            unlocked.append(allAchievements.first { $0.title == "Plant Expert" }!)
        }
        
        if currentStreak >= 10 {
            unlocked.append(allAchievements.first { $0.title == "Streak Master" }!)
        }
        
        if currentStreak >= 20 {
            unlocked.append(allAchievements.first { $0.title == "Unstoppable" }!)
        }
        
        if gamesPlayed >= 100 {
            unlocked.append(allAchievements.first { $0.title == "Centurion" }!)
        }
        
        if gamesPlayed >= 50 {
            unlocked.append(allAchievements.first { $0.title == "Dedicated" }!)
        }
        
        if totalTrophies >= 1000 {
            unlocked.append(allAchievements.first { $0.title == "Trophy Hunter" }!)
        }
        
        if perfectGames >= 1 {
            unlocked.append(allAchievements.first { $0.title == "Perfect Start" }!)
        }
        
        return unlocked
    }
}