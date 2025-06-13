import Foundation
import ComposableArchitecture

@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var user: User?
        var isLoading = false
        var error: String?
        var isEditingProfile = false
        var editForm = EditProfileForm()
        var leaderboard: [LeaderboardEntry] = []
        var achievements: [Achievement] = []
        
        struct EditProfileForm: Equatable {
            var displayName = ""
            var bio = ""
            var isPrivate = false
            
            var isValid: Bool {
                !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        
        struct LeaderboardEntry: Equatable, Identifiable {
            let id: String
            let rank: Int
            let username: String
            let displayName: String?
            let eloRating: Int
            let totalWins: Int
            let winRate: Double
            let isCurrentUser: Bool
        }
        
        struct Achievement: Equatable, Identifiable {
            let id: String
            let title: String
            let description: String
            let iconName: String
            let isUnlocked: Bool
            let unlockedAt: Date?
            let progress: Progress?
            
            struct Progress: Equatable {
                let current: Int
                let total: Int
                let percentage: Double
            }
        }
    }
    
    enum Action {
        case loadProfile
        case profileLoaded(User)
        case startEditingProfile
        case cancelEditingProfile
        case updateEditForm(displayName: String?, bio: String?, isPrivate: Bool?)
        case saveProfile
        case profileSaved(User)
        case loadLeaderboard
        case leaderboardLoaded([State.LeaderboardEntry])
        case loadAchievements
        case achievementsLoaded([State.Achievement])
        case profileError(String)
        case clearError
    }
    
    @Dependency(\.userService) var userService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadProfile:
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        let user = try await userService.getCurrentUserProfile()
                        await send(.profileLoaded(user))
                    } catch {
                        await send(.profileError(error.localizedDescription))
                    }
                }
                
            case .profileLoaded(let user):
                state.isLoading = false
                state.user = user
                state.editForm.displayName = user.displayName ?? user.username
                return .none
                
            case .startEditingProfile:
                guard let user = state.user else { return .none }
                state.isEditingProfile = true
                state.editForm.displayName = user.displayName ?? user.username
                return .none
                
            case .cancelEditingProfile:
                state.isEditingProfile = false
                if let user = state.user {
                    state.editForm.displayName = user.displayName ?? user.username
                }
                return .none
                
            case .updateEditForm(let displayName, let bio, let isPrivate):
                if let displayName = displayName {
                    state.editForm.displayName = displayName
                }
                if let bio = bio {
                    state.editForm.bio = bio
                }
                if let isPrivate = isPrivate {
                    state.editForm.isPrivate = isPrivate
                }
                return .none
                
            case .saveProfile:
                guard state.editForm.isValid else { return .none }
                state.isLoading = true
                return .run { [editForm = state.editForm] send in
                    do {
                        let updatedUser = try await userService.updateProfile(
                            displayName: editForm.displayName,
                            bio: editForm.bio,
                            isPrivate: editForm.isPrivate
                        )
                        await send(.profileSaved(updatedUser))
                    } catch {
                        await send(.profileError(error.localizedDescription))
                    }
                }
                
            case .profileSaved(let user):
                state.isLoading = false
                state.isEditingProfile = false
                state.user = user
                return .none
                
            case .loadLeaderboard:
                return .run { send in
                    do {
                        let leaderboard = try await userService.getLeaderboard()
                        await send(.leaderboardLoaded(leaderboard))
                    } catch {
                        await send(.profileError(error.localizedDescription))
                    }
                }
                
            case .leaderboardLoaded(let leaderboard):
                state.leaderboard = leaderboard
                return .none
                
            case .loadAchievements:
                return .run { send in
                    do {
                        let achievements = try await userService.getAchievements()
                        await send(.achievementsLoaded(achievements))
                    } catch {
                        await send(.profileError(error.localizedDescription))
                    }
                }
                
            case .achievementsLoaded(let achievements):
                state.achievements = achievements
                return .none
                
            case .profileError(let error):
                state.isLoading = false
                state.error = error
                return .none
                
            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}