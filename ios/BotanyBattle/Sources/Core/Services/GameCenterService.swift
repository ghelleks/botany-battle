import Foundation
import GameKit

enum GameCategory: String, CaseIterable {
    case practice = "practice"
    case speedrun = "speedrun"
    case timeAttack = "timeAttack"
    case multiplayer = "multiplayer"
    
    var leaderboardID: String {
        return "\(GameConstants.GameCenter.leaderboardID).\(rawValue)"
    }
}

@MainActor
class GameCenterService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authenticationError: Error?
    
    // For testing - can inject mock
    var localPlayer: GKLocalPlayerProtocol
    
    override init() {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Running in test environment - will be injected
            self.localPlayer = GKLocalPlayer.local
        } else {
            self.localPlayer = GKLocalPlayer.local
        }
        super.init()
    }
    
    // MARK: - Authentication
    
    func authenticate() async -> Bool {
        // Check if already authenticated
        if localPlayer.isAuthenticated {
            isAuthenticated = true
            return true
        }
        
        return await withCheckedContinuation { continuation in
            localPlayer.authenticate { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Game Center authentication failed: \(error.localizedDescription)")
                        self?.authenticationError = error
                        self?.isAuthenticated = false
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Game Center authentication successful")
                        self?.isAuthenticated = true
                        self?.authenticationError = nil
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }
    
    func signOut() {
        isAuthenticated = false
        authenticationError = nil
        print("🔓 Signed out of Game Center")
    }
    
    // MARK: - Player Information
    
    var playerDisplayName: String? {
        guard isAuthenticated else { return nil }
        return localPlayer.displayName
    }
    
    var playerID: String? {
        guard isAuthenticated else { return nil }
        return localPlayer.playerID
    }
    
    // MARK: - Leaderboards
    
    func submitScore(_ score: Int, category: GameCategory) async -> Bool {
        guard isAuthenticated else {
            print("❌ Cannot submit score: not authenticated")
            return false
        }
        
        guard score >= 0 else {
            print("❌ Cannot submit negative score: \(score)")
            return false
        }
        
        let gkScore = GKScore(leaderboardIdentifier: category.leaderboardID)
        gkScore.value = Int64(score)
        
        return await withCheckedContinuation { continuation in
            GKScore.report([gkScore]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to submit score: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Score submitted successfully: \(score) for \(category.rawValue)")
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }
    
    func loadLeaderboardScores(category: GameCategory, timeScope: GKLeaderboard.TimeScope = .allTime) async -> [GKLeaderboard.Entry] {
        guard isAuthenticated else {
            print("❌ Cannot load leaderboard: not authenticated")
            return []
        }
        
        do {
            let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: [category.leaderboardID]).first
            guard let leaderboard = leaderboard else {
                print("❌ Leaderboard not found for category: \(category.rawValue)")
                return []
            }
            
            let (localPlayerEntry, regularEntries, _) = try await leaderboard.loadEntries(
                for: .global,
                timeScope: timeScope,
                range: NSRange(location: 1, length: 25)
            )
            
            var allEntries = regularEntries
            if let localEntry = localPlayerEntry {
                allEntries.insert(localEntry, at: 0)
            }
            
            print("✅ Loaded \(allEntries.count) leaderboard entries for \(category.rawValue)")
            return allEntries
            
        } catch {
            print("❌ Failed to load leaderboard: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Achievements
    
    func reportAchievement(_ achievementID: String, percentComplete: Double) async -> Bool {
        guard isAuthenticated else {
            print("❌ Cannot report achievement: not authenticated")
            return false
        }
        
        guard percentComplete >= 0 && percentComplete <= 100 else {
            print("❌ Invalid achievement percentage: \(percentComplete)")
            return false
        }
        
        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = percentComplete == 100.0
        
        return await withCheckedContinuation { continuation in
            GKAchievement.report([achievement]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to report achievement: \(error.localizedDescription)")
                        continuation.resume(returning: false)
                    } else {
                        print("✅ Achievement reported: \(achievementID) - \(percentComplete)%")
                        continuation.resume(returning: true)
                    }
                }
            }
        }
    }
    
    func loadAchievements() async -> [GKAchievement] {
        guard isAuthenticated else {
            print("❌ Cannot load achievements: not authenticated")
            return []
        }
        
        do {
            let achievements = try await GKAchievement.loadAchievements()
            print("✅ Loaded \(achievements.count) achievements")
            return achievements
        } catch {
            print("❌ Failed to load achievements: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Social Features
    
    func sendChallenge(to playerID: String, message: String) async -> Bool {
        guard isAuthenticated else {
            print("❌ Cannot send challenge: not authenticated")
            return false
        }
        
        // In a real implementation, this would use Game Center's challenge system
        // For now, we'll simulate the behavior
        return await withCheckedContinuation { continuation in
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                DispatchQueue.main.async {
                    print("✅ Challenge sent to \(playerID): \(message)")
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    func loadFriends() async -> [GKPlayer] {
        guard isAuthenticated else {
            print("❌ Cannot load friends: not authenticated")
            return []
        }
        
        do {
            let friends = try await GKLocalPlayer.local.loadRecentPlayers()
            print("✅ Loaded \(friends.count) recent players")
            return friends
        } catch {
            print("❌ Failed to load friends: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Convenience Methods
    
    func reportGameCompletion(score: Int, category: GameCategory, perfectGame: Bool = false) async {
        // Submit score
        await submitScore(score, category: category)
        
        // Report relevant achievements
        if score > 0 {
            await reportAchievement(GameConstants.GameCenter.Achievements.firstWin, percentComplete: 100.0)
        }
        
        if perfectGame {
            await reportAchievement(GameConstants.GameCenter.Achievements.perfectGame, percentComplete: 100.0)
        }
        
        if category == .speedrun && score < GameConstants.speedDemonThreshold {
            await reportAchievement(GameConstants.GameCenter.Achievements.speedDemon, percentComplete: 100.0)
        }
    }
    
    // MARK: - Error Handling
    
    private func handleGameCenterError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.authenticationError = error
        }
        
        if let gkError = error as? GKError {
            switch gkError.code {
            case .notConnectedToInternet:
                print("❌ Game Center: No internet connection")
            case .cancelled:
                print("⚠️ Game Center: Operation cancelled by user")
            case .notAuthenticated:
                print("❌ Game Center: Player not authenticated")
            default:
                print("❌ Game Center error: \(gkError.localizedDescription)")
            }
        } else {
            print("❌ Game Center error: \(error.localizedDescription)")
        }
    }
}

// MARK: - GKLocalPlayer Extension for Protocol Conformance

extension GKLocalPlayer: GKLocalPlayerProtocol {
    func authenticate(completion: @escaping (Error?) -> Void) {
        authenticateHandler = { viewController, error in
            completion(error)
        }
    }
    
    func submitScore(_ score: MockGKScore, completion: @escaping (Error?) -> Void) {
        let gkScore = GKScore(leaderboardIdentifier: score.leaderboardID)
        gkScore.value = score.value
        GKScore.report([gkScore], withCompletionHandler: completion)
    }
    
    func reportAchievement(_ achievement: MockGKAchievement, completion: @escaping (Error?) -> Void) {
        let gkAchievement = GKAchievement(identifier: achievement.identifier)
        gkAchievement.percentComplete = achievement.percentComplete
        GKAchievement.report([gkAchievement], withCompletionHandler: completion)
    }
    
    func sendChallenge(playerID: String, message: String, completion: @escaping (Error?) -> Void) {
        // Simulate challenge sending
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            completion(nil)
        }
    }
}