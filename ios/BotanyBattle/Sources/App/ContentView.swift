import SwiftUI

struct ContentView: View {
    @StateObject private var authFeature = AuthFeature()
    @StateObject private var userDefaultsService = UserDefaultsService()
    @State private var showTutorial = false
    
    var body: some View {
        Group {
            if shouldShowTutorial {
                TutorialCoordinator(userDefaultsService: userDefaultsService) {
                    showTutorial = false
                }
            } else if authFeature.isAuthenticated {
                MainTabView()
                    .environmentObject(authFeature)
            } else {
                AuthView(authFeature: authFeature)
            }
        }
        .onAppear {
            checkIfShouldShowTutorial()
        }
        .task {
            await authFeature.checkExistingAuthentication()
        }
    }
    
    private var shouldShowTutorial: Bool {
        return userDefaultsService.isFirstLaunch && !userDefaultsService.tutorialCompleted && showTutorial
    }
    
    private func checkIfShouldShowTutorial() {
        showTutorial = userDefaultsService.isFirstLaunch && !userDefaultsService.tutorialCompleted
    }
}

// MARK: - Removed Tutorial View - now using TutorialCoordinator from TutorialFeature

// MARK: - Preview

#Preview {
    ContentView()
}