import XCTest
import ComposableArchitecture
@testable import BotanyBattle

@MainActor
final class UserServiceIntegrationTests: XCTestCase {
    
    var mockNetworkService: MockNetworkService!
    var userService: UserService!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService()
        userService = UserService()
    }
    
    override func tearDown() {
        mockNetworkService = nil
        userService = nil
        super.tearDown()
    }
    
    func testGetCurrentUserProfile() async throws {
        let expectedUser = User(
            id: "user-123",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            avatarURL: "https://example.com/avatar.jpg",
            createdAt: Date(),
            stats: User.UserStats(
                totalGamesPlayed: 10,
                totalWins: 7,
                currentStreak: 3,
                longestStreak: 5,
                eloRating: 1200,
                rank: "Sprout",
                plantsIdentified: 25,
                accuracyRate: 0.85
            ),
            currency: User.Currency(coins: 500, gems: 10, tokens: 2)
        )
        
        mockNetworkService.mockResponse = UserProfileResponse(user: expectedUser)
        
        let userService = UserService()
        let result = try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.getCurrentUserProfile()
        }
        
        XCTAssertEqual(result.id, expectedUser.id)
        XCTAssertEqual(result.username, expectedUser.username)
        XCTAssertEqual(result.email, expectedUser.email)
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/profile")
        XCTAssertEqual(mockNetworkService.lastMethod, .get)
    }
    
    func testUpdateProfile() async throws {
        let updatedUser = User(
            id: "user-123",
            username: "testuser",
            email: "test@example.com",
            displayName: "Updated User",
            avatarURL: nil,
            createdAt: Date(),
            stats: User.UserStats(
                totalGamesPlayed: 10,
                totalWins: 7,
                currentStreak: 3,
                longestStreak: 5,
                eloRating: 1200,
                rank: "Sprout",
                plantsIdentified: 25,
                accuracyRate: 0.85
            ),
            currency: User.Currency(coins: 500, gems: 10, tokens: 2)
        )
        
        mockNetworkService.mockResponse = UserProfileResponse(user: updatedUser)
        
        let result = try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.updateProfile(
                displayName: "Updated User",
                bio: "New bio",
                isPrivate: true
            )
        }
        
        XCTAssertEqual(result.displayName, "Updated User")
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/update")
        XCTAssertEqual(mockNetworkService.lastMethod, .put)
        
        let parameters = mockNetworkService.lastParameters
        XCTAssertEqual(parameters?["displayName"] as? String, "Updated User")
        XCTAssertEqual(parameters?["bio"] as? String, "New bio")
        XCTAssertEqual(parameters?["isPrivate"] as? Bool, true)
    }
    
    func testUploadAvatar() async throws {
        let expectedURL = "https://example.com/new-avatar.jpg"
        mockNetworkService.mockResponse = AvatarUploadResponse(avatarURL: expectedURL)
        
        let imageData = Data("fake image data".utf8)
        
        let result = try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.uploadAvatar(imageData: imageData)
        }
        
        XCTAssertEqual(result, expectedURL)
        XCTAssertEqual(mockNetworkService.lastUploadEndpoint?.path, "/user/avatar")
        XCTAssertEqual(mockNetworkService.lastUploadData, imageData)
        XCTAssertEqual(mockNetworkService.lastUploadFilename, "avatar.jpg")
        XCTAssertEqual(mockNetworkService.lastUploadMimeType, "image/jpeg")
    }
    
    func testDeleteAvatar() async throws {
        try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.deleteAvatar()
        }
        
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/avatar")
        XCTAssertEqual(mockNetworkService.lastMethod, .delete)
    }
    
    func testUpdatePassword() async throws {
        try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.updatePassword(
                currentPassword: "oldpass123",
                newPassword: "newpass456"
            )
        }
        
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/password")
        XCTAssertEqual(mockNetworkService.lastMethod, .put)
        
        let parameters = mockNetworkService.lastParameters
        XCTAssertEqual(parameters?["currentPassword"] as? String, "oldpass123")
        XCTAssertEqual(parameters?["newPassword"] as? String, "newpass456")
    }
    
    func testDeleteAccount() async throws {
        try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.deleteAccount()
        }
        
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/delete")
        XCTAssertEqual(mockNetworkService.lastMethod, .delete)
    }
    
    func testGetProfileSettings() async throws {
        let expectedSettings = ProfileSettings()
        mockNetworkService.mockResponse = ProfileSettingsResponse(settings: expectedSettings)
        
        let result = try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.getProfileSettings()
        }
        
        XCTAssertEqual(result.notificationsEnabled, expectedSettings.notificationsEnabled)
        XCTAssertEqual(result.emailUpdates, expectedSettings.emailUpdates)
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/settings")
        XCTAssertEqual(mockNetworkService.lastMethod, .get)
    }
    
    func testUpdateProfileSettings() async throws {
        var settings = ProfileSettings()
        settings.notificationsEnabled = false
        settings.pushNotifications = false
        settings.privacyMode = true
        
        mockNetworkService.mockResponse = ProfileSettingsResponse(settings: settings)
        
        let result = try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.updateProfileSettings(settings)
        }
        
        XCTAssertEqual(result.notificationsEnabled, false)
        XCTAssertEqual(result.pushNotifications, false)
        XCTAssertEqual(result.privacyMode, true)
        
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/settings")
        XCTAssertEqual(mockNetworkService.lastMethod, .put)
        
        let parameters = mockNetworkService.lastParameters
        XCTAssertEqual(parameters?["notificationsEnabled"] as? Bool, false)
        XCTAssertEqual(parameters?["pushNotifications"] as? Bool, false)
        XCTAssertEqual(parameters?["privacyMode"] as? Bool, true)
    }
    
    func testGetLeaderboard() async throws {
        let expectedEntries = [
            ProfileFeature.State.LeaderboardEntry(
                rank: 1,
                username: "topplayer",
                displayName: "Top Player",
                eloRating: 1500,
                totalWins: 50,
                avatarURL: "https://example.com/avatar1.jpg"
            ),
            ProfileFeature.State.LeaderboardEntry(
                rank: 2,
                username: "secondplace",
                displayName: "Second Place",
                eloRating: 1450,
                totalWins: 45,
                avatarURL: nil
            )
        ]
        
        mockNetworkService.mockResponse = LeaderboardResponse(entries: expectedEntries)
        
        let result = try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.getLeaderboard()
        }
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].rank, 1)
        XCTAssertEqual(result[0].username, "topplayer")
        XCTAssertEqual(result[1].rank, 2)
        XCTAssertEqual(result[1].username, "secondplace")
        
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/leaderboard")
        XCTAssertEqual(mockNetworkService.lastMethod, .get)
    }
    
    func testGetAchievements() async throws {
        let expectedAchievements = [
            ProfileFeature.State.Achievement(
                id: "first_win",
                title: "First Victory",
                description: "Win your first game",
                iconName: "trophy",
                isUnlocked: true,
                unlockedDate: Date(),
                progress: 1,
                maxProgress: 1
            ),
            ProfileFeature.State.Achievement(
                id: "plant_master",
                title: "Plant Master",
                description: "Identify 100 plants",
                iconName: "leaf",
                isUnlocked: false,
                unlockedDate: nil,
                progress: 25,
                maxProgress: 100
            )
        ]
        
        mockNetworkService.mockResponse = AchievementsResponse(achievements: expectedAchievements)
        
        let result = try await withDependencies {
            $0.networkService = mockNetworkService
        } operation: {
            try await userService.getAchievements()
        }
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, "first_win")
        XCTAssertTrue(result[0].isUnlocked)
        XCTAssertEqual(result[1].id, "plant_master")
        XCTAssertFalse(result[1].isUnlocked)
        XCTAssertEqual(result[1].progress, 25)
        
        XCTAssertEqual(mockNetworkService.lastEndpoint?.path, "/user/stats")
        XCTAssertEqual(mockNetworkService.lastMethod, .get)
    }
    
    func testNetworkErrorHandling() async {
        mockNetworkService.shouldFail = true
        
        do {
            _ = try await withDependencies {
                $0.networkService = mockNetworkService
            } operation: {
                try await userService.getCurrentUserProfile()
            }
            XCTFail("Expected network error")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
}

// MARK: - Mock Network Service
final class MockNetworkService: NetworkServiceProtocol {
    var mockResponse: Any?
    var shouldFail = false
    var error: Error = NetworkError.requestFailed(AFError.responseValidationFailed(reason: .dataFileNil))
    
    var lastEndpoint: APIEndpoint?
    var lastMethod: HTTPMethod?
    var lastParameters: [String: Any]?
    var lastHeaders: HTTPHeaders?
    
    var lastUploadEndpoint: APIEndpoint?
    var lastUploadData: Data?
    var lastUploadFilename: String?
    var lastUploadMimeType: String?
    
    func request<T: Codable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        parameters: [String: Any]?,
        headers: HTTPHeaders?
    ) async throws -> T {
        lastEndpoint = endpoint
        lastMethod = method
        lastParameters = parameters
        lastHeaders = headers
        
        if shouldFail {
            throw error
        }
        
        guard let response = mockResponse as? T else {
            throw NetworkError.invalidResponse
        }
        
        return response
    }
    
    func upload<T: Codable>(
        _ endpoint: APIEndpoint,
        data: Data,
        filename: String,
        mimeType: String
    ) async throws -> T {
        lastUploadEndpoint = endpoint
        lastUploadData = data
        lastUploadFilename = filename
        lastUploadMimeType = mimeType
        
        if shouldFail {
            throw error
        }
        
        guard let response = mockResponse as? T else {
            throw NetworkError.invalidResponse
        }
        
        return response
    }
}

import Alamofire

extension NetworkError {
    static func testError() -> NetworkError {
        return .requestFailed(AFError.responseValidationFailed(reason: .dataFileNil))
    }
}