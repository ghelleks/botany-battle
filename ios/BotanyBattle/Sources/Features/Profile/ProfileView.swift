import SwiftUI

struct ProfileView: View {
    @StateObject private var profileFeature: ProfileFeature
    @Environment(\.presentationMode) var presentationMode
    
    init(authFeature: AuthFeature, userDefaultsService: UserDefaultsService) {
        self._profileFeature = StateObject(wrappedValue: ProfileFeature(
            authFeature: authFeature,
            userDefaultsService: userDefaultsService
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                ProfileHeaderView(
                    profileData: profileFeature.profileData,
                    authFeature: profileFeature.authFeature
                )
                
                // Stats Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    StatsGridView(
                        profileData: profileFeature.profileData,
                        winRate: profileFeature.formattedWinRate
                    )
                }
                
                // Achievements Section
                AchievementsListView(
                    achievements: profileFeature.profileData.achievements,
                    allAchievements: profileFeature.achievementSystem.allAchievements
                )
                
                // Action Buttons
                VStack(spacing: 12) {
                    if profileFeature.authFeature.isAuthenticated {
                        Button("View Full Achievements") {
                            // Navigate to achievements view
                        }
                        .font(.headline)
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        Button("Share Profile") {
                            // Share profile functionality
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        Button("Sign In to Save Progress") {
                            // Navigate to authentication
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            profileFeature.refreshData()
        }
        .overlay {
            if profileFeature.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .alert("Error", isPresented: .constant(profileFeature.errorMessage != nil)) {
            Button("OK") {
                profileFeature.errorMessage = nil
            }
        } message: {
            Text(profileFeature.errorMessage ?? "")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ProfileView(
            authFeature: MockAuthFeature(),
            userDefaultsService: MockUserDefaultsService()
        )
    }
}

// MARK: - Mock Objects for Preview

class MockAuthFeature: AuthFeature {
    override init() {
        super.init()
        self.authState = .authenticated(.appleID)
        self.userDisplayName = "PlantLover42"
    }
}

class MockUserDefaultsService: UserDefaultsService {
    override init() {
        super.init()
        self.totalTrophies = 1247
        self.gamesPlayed = 156
        self.perfectGames = 98
        self.currentStreak = 12
    }
}