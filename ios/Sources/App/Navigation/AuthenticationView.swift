import SwiftUI
import ComposableArchitecture

struct AuthenticationView: View {
    @Bindable var store: StoreOf<AuthFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                headerView
                
                if store.isLoading {
                    loadingView
                } else {
                    authenticationOptions
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
            .alert("Authentication Error", isPresented: .constant(store.error != nil)) {
                Button("Retry") {
                    store.send(.retryAuthentication)
                }
                Button("Skip") {
                    store.send(.skipAuthentication)
                }
                Button("Cancel") {
                    store.send(.clearError)
                }
            } message: {
                if let error = store.error {
                    Text(error)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 80))
                .foregroundColor(.botanicalGreen)
                .padding(.top, 40)
            
            Text("Botany Battle")
                .botanicalStyle(.largeTitle)
            
            Text(headerSubtitle)
                .botanicalStyle(.subheadline)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 20)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundColor(.botanicalGreen)
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(.botanicalGreen)
            
            Text("Connecting to Game Center...")
                .botanicalStyle(.title2)
                .multilineTextAlignment(.center)
            
            Text("Please wait while we authenticate your Game Center account")
                .botanicalStyle(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
    
    private var authenticationOptions: some View {
        VStack(spacing: 24) {
            // Game Center Option
            VStack(spacing: 16) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.botanicalGreen)
                
                Text("Connect with Game Center")
                    .botanicalStyle(.title2)
                    .multilineTextAlignment(.center)
                
                Text("Play against friends, track achievements, and sync progress across devices")
                    .botanicalStyle(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                BotanicalButton(
                    "Connect with Game Center",
                    style: .primary,
                    size: .large
                ) {
                    store.send(.authenticateWithGameCenter)
                }
            }
            
            // Optional: Guest Mode
            if store.authenticationMode != .required {
                VStack(spacing: 12) {
                    Text("or")
                        .botanicalStyle(.caption)
                        .foregroundColor(.secondary)
                    
                    BotanicalButton(
                        "Continue as Guest",
                        style: .secondary,
                        size: .large
                    ) {
                        store.send(.skipAuthentication)
                    }
                    
                    Text("Play single-player modes without an account")
                        .botanicalStyle(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var headerSubtitle: String {
        switch store.authenticationMode {
        case .required:
            return "Game Center authentication required to continue"
        case .optional, .onDemand:
            return "Test your plant knowledge and challenge yourself"
        case .disabled:
            return "Enjoy plant identification in guest mode"
        }
    }
    
}

#Preview {
    AuthenticationView(
        store: Store(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        )
    )
}