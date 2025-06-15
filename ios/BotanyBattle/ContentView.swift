import SwiftUI
import GameKit

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isLoading = true
    @State private var showTutorial = false
    @State private var currentTab = 0
    @State private var authenticationError: String?
    
    var body: some View {
        Group {
            if isLoading {
                GameCenterAuthenticationView()
            } else if showTutorial {
                SimpleTutorialView(showTutorial: $showTutorial)
            } else if isAuthenticated {
                SimpleMainTabView(currentTab: $currentTab)
            } else {
                GameCenterAuthenticationFailedView {
                    authenticateWithGameCenter()
                }
            }
        }
        .onAppear {
            authenticateWithGameCenter()
        }
        .alert("Authentication Error", isPresented: .constant(authenticationError != nil)) {
            Button("Retry") {
                authenticationError = nil
                authenticateWithGameCenter()
            }
            Button("Cancel", role: .cancel) {
                authenticationError = nil
                isLoading = false
            }
        } message: {
            if let error = authenticationError {
                Text(error)
            }
        }
    }
    
    private func authenticateWithGameCenter() {
        isLoading = true
        authenticationError = nil
        
        // Check if user has chosen to skip Game Center (development mode)
        if UserDefaults.standard.bool(forKey: "skipGameCenter") {
            withAnimation {
                isAuthenticated = true
                isLoading = false
                showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenTutorial")
            }
            return
        }
        
        // Check if Game Center is available
        if !isGameCenterAvailable() {
            authenticationError = "Game Center is not available on this device. Please enable Game Center in Settings or use a device that supports Game Center."
            isLoading = false
            return
        }
        
        // Check if already authenticated
        if GKLocalPlayer.local.isAuthenticated {
            withAnimation {
                isAuthenticated = true
                isLoading = false
                showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenTutorial")
            }
            return
        }
        
        // Set up timeout to prevent hanging
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if isLoading {
                    authenticationError = "Game Center authentication timed out. Please check your Game Center settings and try again."
                    isLoading = false
                }
            }
        }
        
        // Attempt authentication
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            DispatchQueue.main.async {
                timeoutTimer.invalidate() // Cancel timeout since we got a response
                
                if let error = error {
                    let nsError = error as NSError
                    // Check for specific Game Center error codes
                    if nsError.domain == "GKErrorDomain" {
                        switch nsError.code {
                        case 2: // GKErrorNotSupported
                            authenticationError = "Game Center is not available. Please enable Game Center in Settings."
                        case 3: // GKErrorNotAuthenticated
                            authenticationError = "Please sign in to Game Center in Settings, then restart the app."
                        case 4: // GKErrorAuthenticationInProgress
                            authenticationError = "Game Center authentication is already in progress. Please wait."
                        case 17: // GKErrorGameUnrecognized
                            authenticationError = "This game is not recognized by Game Center. Please contact support."
                        default:
                            authenticationError = "Game Center authentication failed: \(error.localizedDescription)"
                        }
                    } else {
                        authenticationError = "Game Center authentication failed. Please check your settings and try again."
                    }
                    isLoading = false
                    return
                }
                
                if let viewController = viewController {
                    // In a real app, you would present this view controller
                    // For simulator testing, we'll treat this as requiring manual setup
                    authenticationError = "Game Center requires sign-in. Please sign in to Game Center in the iOS Settings app, then restart the game."
                    isLoading = false
                    return
                }
                
                if GKLocalPlayer.local.isAuthenticated {
                    withAnimation {
                        isAuthenticated = true
                        isLoading = false
                        // Check if user needs tutorial
                        showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenTutorial")
                    }
                } else {
                    authenticationError = "Game Center authentication is required to play. Please sign in to Game Center in Settings."
                    isLoading = false
                }
            }
        }
    }
    
    private func isGameCenterAvailable() -> Bool {
        // Check if running on iOS (always true for iOS app)
        // Check if Game Center is supported (always true on modern iOS)
        // Check if the local player object exists
        return GKLocalPlayer.local != nil
    }
}

struct GameCenterAuthenticationView: View {
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
            
            VStack(spacing: 16) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.green)
                
                Text("Connecting to Game Center...")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                Text("Please wait while we authenticate with Game Center")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct GameCenterAuthenticationFailedView: View {
    let onRetry: () -> Void
    @State private var showDevMode = false
    
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
            
            VStack(spacing: 16) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Game Center Required")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                Text("This game requires Game Center authentication to play against other players. Please sign in to Game Center in your device Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                VStack(spacing: 12) {
                    Button("Retry Connection") {
                        onRetry()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                    
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Development/Testing mode - hidden by default
                    if showDevMode {
                        Button("Continue Without Game Center (Testing Only)") {
                            // For development/testing purposes only
                            UserDefaults.standard.set(true, forKey: "skipGameCenter")
                            onRetry()
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .onTapGesture(count: 5) {
                    showDevMode.toggle()
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}