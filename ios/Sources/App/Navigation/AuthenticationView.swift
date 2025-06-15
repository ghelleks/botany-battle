import SwiftUI
import ComposableArchitecture

struct AuthenticationView: View {
    @Bindable var store: StoreOf<AuthFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                headerView
                
                gameCenterLoginButton
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
            .alert("Authentication Error", isPresented: .constant(store.error != nil)) {
                Button("OK") {
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
            
            Text("Test your plant knowledge against other players")
                .botanicalStyle(.subheadline)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 20)
    }
    
    private var gameCenterLoginButton: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundColor(.botanicalGreen)
            
            Text("Sign in with Game Center")
                .botanicalStyle(.title2)
                .multilineTextAlignment(.center)
            
            Text("Connect with Game Center to play against friends and track your achievements")
                .botanicalStyle(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            BotanicalButton(
                "Sign in with Game Center",
                style: .primary,
                size: .large,
                isLoading: store.isLoading
            ) {
                store.send(.authenticateWithGameCenter)
            }
            .padding(.top, 16)
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