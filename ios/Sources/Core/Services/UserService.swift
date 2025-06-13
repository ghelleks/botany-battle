import Foundation
import Dependencies

protocol UserServiceProtocol {
    func getCurrentUserProfile() async throws -> User
    func updateProfile(displayName: String, bio: String, isPrivate: Bool) async throws -> User
    func uploadAvatar(imageData: Data) async throws -> String
    func deleteAvatar() async throws
    func updatePassword(currentPassword: String, newPassword: String) async throws
    func deleteAccount() async throws
    func getProfileSettings() async throws -> ProfileSettings
    func updateProfileSettings(_ settings: ProfileSettings) async throws -> ProfileSettings
    func getLeaderboard() async throws -> [ProfileFeature.State.LeaderboardEntry]
    func getAchievements() async throws -> [ProfileFeature.State.Achievement]
}

final class UserService: UserServiceProtocol {
    @Dependency(\.networkService) var networkService
    
    func getCurrentUserProfile() async throws -> User {
        let response: UserProfileResponse = try await networkService.request(
            .user(.profile),
            method: .get,
            parameters: nil,
            headers: nil
        )
        
        return response.user
    }
    
    func updateProfile(displayName: String, bio: String, isPrivate: Bool) async throws -> User {
        let parameters = [
            "displayName": displayName,
            "bio": bio,
            "isPrivate": isPrivate
        ] as [String : Any]
        
        let response: UserProfileResponse = try await networkService.request(
            .user(.update),
            method: .put,
            parameters: parameters,
            headers: nil
        )
        
        return response.user
    }
    
    func getLeaderboard() async throws -> [ProfileFeature.State.LeaderboardEntry] {
        let response: LeaderboardResponse = try await networkService.request(
            .user(.leaderboard),
            method: .get,
            parameters: nil,
            headers: nil
        )
        
        return response.entries
    }
    
    func getAchievements() async throws -> [ProfileFeature.State.Achievement] {
        let response: AchievementsResponse = try await networkService.request(
            .user(.stats),
            method: .get,
            parameters: nil,
            headers: nil
        )
        
        return response.achievements
    }
    
    func uploadAvatar(imageData: Data) async throws -> String {
        let response: AvatarUploadResponse = try await networkService.upload(
            .user(.avatar),
            data: imageData,
            filename: "avatar.jpg",
            mimeType: "image/jpeg"
        )
        
        return response.avatarURL
    }
    
    func deleteAvatar() async throws {
        try await networkService.request(
            .user(.avatar),
            method: .delete,
            parameters: nil,
            headers: nil
        )
    }
    
    func updatePassword(currentPassword: String, newPassword: String) async throws {
        let parameters = [
            "currentPassword": currentPassword,
            "newPassword": newPassword
        ]
        
        try await networkService.request(
            .user(.password),
            method: .put,
            parameters: parameters,
            headers: nil
        )
    }
    
    func deleteAccount() async throws {
        try await networkService.request(
            .user(.delete),
            method: .delete,
            parameters: nil,
            headers: nil
        )
    }
    
    func getProfileSettings() async throws -> ProfileSettings {
        let response: ProfileSettingsResponse = try await networkService.request(
            .user(.settings),
            method: .get,
            parameters: nil,
            headers: nil
        )
        
        return response.settings
    }
    
    func updateProfileSettings(_ settings: ProfileSettings) async throws -> ProfileSettings {
        let response: ProfileSettingsResponse = try await networkService.request(
            .user(.settings),
            method: .put,
            parameters: settings.dictionary,
            headers: nil
        )
        
        return response.settings
    }
}

struct UserProfileResponse: Codable {
    let user: User
}

struct LeaderboardResponse: Codable {
    let entries: [ProfileFeature.State.LeaderboardEntry]
}

struct AchievementsResponse: Codable {
    let achievements: [ProfileFeature.State.Achievement]
}

struct AvatarUploadResponse: Codable {
    let avatarURL: String
}

struct ProfileSettingsResponse: Codable {
    let settings: ProfileSettings
}

struct ProfileSettings: Codable {
    var notificationsEnabled: Bool
    var emailUpdates: Bool
    var pushNotifications: Bool
    var soundEnabled: Bool
    var hapticFeedback: Bool
    var dataUsageOptimization: Bool
    var autoMatchmaking: Bool
    var privacyMode: Bool
    var showOnlineStatus: Bool
    var allowDirectMessages: Bool
    
    init() {
        self.notificationsEnabled = true
        self.emailUpdates = true
        self.pushNotifications = true
        self.soundEnabled = true
        self.hapticFeedback = true
        self.dataUsageOptimization = false
        self.autoMatchmaking = true
        self.privacyMode = false
        self.showOnlineStatus = true
        self.allowDirectMessages = true
    }
    
    var dictionary: [String: Any] {
        return [
            "notificationsEnabled": notificationsEnabled,
            "emailUpdates": emailUpdates,
            "pushNotifications": pushNotifications,
            "soundEnabled": soundEnabled,
            "hapticFeedback": hapticFeedback,
            "dataUsageOptimization": dataUsageOptimization,
            "autoMatchmaking": autoMatchmaking,
            "privacyMode": privacyMode,
            "showOnlineStatus": showOnlineStatus,
            "allowDirectMessages": allowDirectMessages
        ]
    }
}

extension DependencyValues {
    var userService: UserServiceProtocol {
        get { self[UserServiceKey.self] }
        set { self[UserServiceKey.self] = newValue }
    }
}

private enum UserServiceKey: DependencyKey {
    static let liveValue: UserServiceProtocol = UserService()
}