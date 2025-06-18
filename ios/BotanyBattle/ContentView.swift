import SwiftUI
import GameKit

struct ContentView: View {
    @State private var showTutorial = false
    @State private var currentTab = 0
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                SplashScreenView()
            } else if showTutorial {
                SimpleTutorialView(showTutorial: $showTutorial)
            } else {
                SimpleMainTabView(currentTab: $currentTab)
            }
        }
        .onAppear {
            // Simple startup flow - no forced authentication
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    isLoading = false
                    showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenTutorial")
                }
            }
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Botany Battle")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Test your botanical knowledge")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(.green)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}