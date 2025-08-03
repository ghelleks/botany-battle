import SwiftUI
import Combine

// MARK: - Profile Feature

@MainActor
class ProfileFeature: ObservableObject {
    @Published var profileData: ProfileData
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authFeature: AuthFeature
    private let userDefaultsService: UserDefaultsService
    private let achievementSystem: AchievementSystem
    private var cancellables = Set<AnyCancellable>()
    
    init(authFeature: AuthFeature, userDefaultsService: UserDefaultsService) {
        self.authFeature = authFeature
        self.userDefaultsService = userDefaultsService
        self.achievementSystem = AchievementSystem()
        
        // Initialize with current data
        self.profileData = ProfileData(
            displayName: authFeature.userDisplayName ?? "Player",
            rank: Self.calculateRank(trophies: userDefaultsService.totalTrophies),
            totalTrophies: userDefaultsService.totalTrophies,
            gamesPlayed: userDefaultsService.gamesPlayed,
            perfectGames: userDefaultsService.perfectGames,
            currentStreak: userDefaultsService.currentStreak,
            achievements: []
        )
        
        setupBindings()
        refreshData()
    }
    
    private func setupBindings() {
        // Listen for auth changes
        authFeature.$userDisplayName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] displayName in
                self?.updateDisplayName(displayName ?? "Player")
            }
            .store(in: &cancellables)
        
        // Listen for user defaults changes
        Publishers.CombineLatest4(
            userDefaultsService.$totalTrophies,
            userDefaultsService.$gamesPlayed,
            userDefaultsService.$perfectGames,
            userDefaultsService.$currentStreak
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] trophies, gamesPlayed, perfectGames, currentStreak in
            self?.updateStats(
                trophies: trophies,
                gamesPlayed: gamesPlayed,
                perfectGames: perfectGames,
                currentStreak: currentStreak
            )
        }
        .store(in: &cancellables)
    }
    
    private func updateDisplayName(_ displayName: String) {
        profileData = ProfileData(
            displayName: displayName,
            rank: profileData.rank,
            totalTrophies: profileData.totalTrophies,
            gamesPlayed: profileData.gamesPlayed,
            perfectGames: profileData.perfectGames,
            currentStreak: profileData.currentStreak,
            achievements: profileData.achievements
        )
    }
    
    private func updateStats(trophies: Int, gamesPlayed: Int, perfectGames: Int, currentStreak: Int) {
        let newRank = Self.calculateRank(trophies: trophies)
        let newAchievements = achievementSystem.checkAchievements(
            gamesPlayed: gamesPlayed,
            perfectGames: perfectGames,
            currentStreak: currentStreak,
            totalTrophies: trophies
        )
        
        profileData = ProfileData(
            displayName: profileData.displayName,
            rank: newRank,
            totalTrophies: trophies,
            gamesPlayed: gamesPlayed,
            perfectGames: perfectGames,
            currentStreak: currentStreak,
            achievements: newAchievements
        )
    }
    
    func refreshData() {
        isLoading = true
        errorMessage = nil
        
        // Simulate async data refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoading = false
        }
    }
    
    var winRate: Double {
        guard profileData.gamesPlayed > 0 else { return 0.0 }
        return Double(profileData.perfectGames) / Double(profileData.gamesPlayed)
    }
    
    var formattedWinRate: String {
        return String(format: "%.1f%%", winRate * 100)
    }
    
    static func calculateRank(trophies: Int) -> String {
        switch trophies {
        case 0..<100: return "Novice Botanist"
        case 100..<500: return "Plant Enthusiast"
        case 500..<1000: return "Garden Expert"
        case 1000..<2000: return "Master Botanist"
        default: return "Plant Guru"
        }
    }
}

// MARK: - Profile Data Model

struct ProfileData: Equatable {
    let displayName: String
    let rank: String
    let totalTrophies: Int
    let gamesPlayed: Int
    let perfectGames: Int
    let currentStreak: Int
    let achievements: [Achievement]
}

// MARK: - Achievement Model

struct Achievement: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    
    init(title: String, description: String, icon: String, isUnlocked: Bool = true) {
        self.title = title
        self.description = description
        self.icon = icon
        self.isUnlocked = isUnlocked
    }
}

// MARK: - Achievement System

class AchievementSystem {
    let allAchievements: [Achievement] = [
        Achievement(title: "First Steps", description: "Complete your first game", icon: "leaf.fill"),
        Achievement(title: "Getting Started", description: "Play 10 games", icon: "seedling"),
        Achievement(title: "Dedicated", description: "Play 50 games", icon: "heart.fill"),
        Achievement(title: "Centurion", description: "Play 100 games", icon: "gamecontroller.fill"),
        Achievement(title: "Perfect Start", description: "Win your first game", icon: "checkmark.circle.fill"),
        Achievement(title: "On a Roll", description: "5 win streak", icon: "flame"),
        Achievement(title: "Streak Master", description: "10 win streak", icon: "flame.fill"),
        Achievement(title: "Unstoppable", description: "20 win streak", icon: "bolt.fill"),
        Achievement(title: "Plant Expert", description: "Win 100 games", icon: "trophy.fill"),
        Achievement(title: "First Coins", description: "Earn 100 trophies", icon: "star.circle"),
        Achievement(title: "Trophy Hunter", description: "Earn 1000 trophies", icon: "star.fill"),
        Achievement(title: "Wealthy", description: "Earn 5000 trophies", icon: "crown.fill"),
        Achievement(title: "Speed Demon", description: "Answer in under 5 seconds", icon: "timer"),
        Achievement(title: "Perfectionist", description: "Get 3 perfect games in a row", icon: "target")
    ]
    
    func checkAchievements(gamesPlayed: Int, perfectGames: Int, currentStreak: Int, totalTrophies: Int) -> [Achievement] {
        var unlocked: [Achievement] = []
        
        // Games played achievements
        if gamesPlayed >= 1 {
            unlocked.append(allAchievements.first { $0.title == "First Steps" }!)
        }
        if gamesPlayed >= 10 {
            unlocked.append(allAchievements.first { $0.title == "Getting Started" }!)
        }
        if gamesPlayed >= 50 {
            unlocked.append(allAchievements.first { $0.title == "Dedicated" }!)
        }
        if gamesPlayed >= 100 {
            unlocked.append(allAchievements.first { $0.title == "Centurion" }!)
        }
        
        // Perfect games achievements
        if perfectGames >= 1 {
            unlocked.append(allAchievements.first { $0.title == "Perfect Start" }!)
        }
        if perfectGames >= 100 {
            unlocked.append(allAchievements.first { $0.title == "Plant Expert" }!)
        }
        
        // Streak achievements
        if currentStreak >= 5 {
            unlocked.append(allAchievements.first { $0.title == "On a Roll" }!)
        }
        if currentStreak >= 10 {
            unlocked.append(allAchievements.first { $0.title == "Streak Master" }!)
        }
        if currentStreak >= 20 {
            unlocked.append(allAchievements.first { $0.title == "Unstoppable" }!)
        }
        
        // Trophy achievements
        if totalTrophies >= 100 {
            unlocked.append(allAchievements.first { $0.title == "First Coins" }!)
        }
        if totalTrophies >= 1000 {
            unlocked.append(allAchievements.first { $0.title == "Trophy Hunter" }!)
        }
        if totalTrophies >= 5000 {
            unlocked.append(allAchievements.first { $0.title == "Wealthy" }!)
        }
        
        return unlocked
    }
    
    func getNextAchievement(gamesPlayed: Int, perfectGames: Int, currentStreak: Int, totalTrophies: Int) -> Achievement? {
        // Find the next achievement to unlock
        let lockedAchievements = allAchievements.filter { achievement in
            !checkAchievements(gamesPlayed: gamesPlayed, perfectGames: perfectGames, currentStreak: currentStreak, totalTrophies: totalTrophies).contains(achievement)
        }
        
        return lockedAchievements.first
    }
}

// MARK: - Profile Components

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? .green : .secondary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String?
    
    init(label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.green)
                    .frame(width: 20)
            }
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct ProfileHeaderView: View {
    let profileData: ProfileData
    let authFeature: AuthFeature
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            if authFeature.isAuthenticated {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "person.circle")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
            }
            
            // Name and Rank
            VStack(spacing: 4) {
                Text(profileData.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(profileData.rank)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

struct StatsGridView: View {
    let profileData: ProfileData
    let winRate: String
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            StatCard(
                title: "Total Trophies",
                value: "\(profileData.totalTrophies)",
                icon: "trophy.fill",
                color: .orange
            )
            
            StatCard(
                title: "Games Played",
                value: "\(profileData.gamesPlayed)",
                icon: "gamecontroller.fill",
                color: .blue
            )
            
            StatCard(
                title: "Perfect Games",
                value: "\(profileData.perfectGames)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Win Rate",
                value: winRate,
                icon: "percent",
                color: .purple
            )
            
            StatCard(
                title: "Current Streak",
                value: "\(profileData.currentStreak)",
                icon: "flame.fill",
                color: .red
            )
            
            StatCard(
                title: "Achievements",
                value: "\(profileData.achievements.count)",
                icon: "star.fill",
                color: .yellow
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AchievementsListView: View {
    let achievements: [Achievement]
    let allAchievements: [Achievement]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                
                Spacer()
                
                Text("\(achievements.count)/\(allAchievements.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            
            LazyVStack(spacing: 8) {
                // Show unlocked achievements first
                ForEach(achievements.prefix(3)) { achievement in
                    AchievementRow(achievement: achievement)
                }
                
                // Show a few locked achievements
                ForEach(allAchievements.filter { !achievements.contains($0) }.prefix(2)) { achievement in
                    AchievementRow(achievement: Achievement(
                        title: achievement.title,
                        description: achievement.description,
                        icon: achievement.icon,
                        isUnlocked: false
                    ))
                }
                
                if allAchievements.count > 5 {
                    Button("View All Achievements") {
                        // Navigate to full achievements view
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
                }
            }
        }
    }
}