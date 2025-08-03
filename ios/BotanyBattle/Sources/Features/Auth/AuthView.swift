import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var authFeature: AuthFeature
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundGradient
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Logo and Title Section
                    logoSection
                    
                    Spacer()
                    
                    // Authentication Buttons
                    if authFeature.isSigningIn {
                        loadingSection
                    } else {
                        authenticationSection
                    }
                    
                    // Error Message
                    if let errorMessage = authFeature.errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationBarHidden(true)
        }
        .task {
            await authFeature.checkExistingAuthentication()
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.green.opacity(0.1),
                Color.blue.opacity(0.05)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var logoSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                .accessibilityLabel("Botany Battle Logo")
            
            VStack(spacing: 8) {
                Text("Botany Battle")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Test your botanical knowledge")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.green)
            
            Text("Signing in...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200) // Match the height of auth buttons section
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signing in, please wait")
    }
    
    private var authenticationSection: some View {
        VStack(spacing: 16) {
            // Apple ID Sign In (if available)
            if authFeature.canUseAppleID {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        await handleAppleIDResult(result)
                    }
                }
                .frame(height: 50)
                .cornerRadius(12)
                .accessibilityIdentifier("appleSignInButton")
            }
            
            // Game Center Sign In
            if authFeature.canUseGameCenter {
                Button {
                    Task {
                        await signInWithGameCenter()
                    }
                } label: {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                        Text("Sign In with Game Center")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .accessibilityIdentifier("gameCenterSignInButton")
            }
            
            // Guest Mode
            Button {
                Task {
                    await signInAsGuest()
                }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle")
                    Text("Continue as Guest")
                }
                .font(.headline)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 1)
                )
                .cornerRadius(12)
            }
            .accessibilityIdentifier("guestSignInButton")
            
            // Privacy Note
            Text("Guest mode provides full access to single-player features. Sign in for multiplayer and cloud sync.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
            
            Button("Dismiss") {
                clearError()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
    
    // MARK: - Actions
    
    func signInAsGuest() async {
        await authFeature.signInAsGuest()
    }
    
    func signInWithGameCenter() async {
        await authFeature.signInWithGameCenter()
    }
    
    func signInWithAppleID() async {
        await authFeature.signInWithAppleID()
    }
    
    func clearError() {
        authFeature.clearError()
    }
    
    private func handleAppleIDResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                await authFeature.signInWithAppleID()
            }
        case .failure(let error):
            authFeature.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView(authFeature: AuthFeature())
}