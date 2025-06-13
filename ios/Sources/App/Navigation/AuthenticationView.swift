import SwiftUI
import ComposableArchitecture

struct AuthenticationView: View {
    @Bindable var store: StoreOf<AuthFeature>
    @State private var selectedTab: AuthTab = .login
    
    enum AuthTab: CaseIterable {
        case login
        case signup
        
        var title: String {
            switch self {
            case .login: return "Login"
            case .signup: return "Sign Up"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerView
                
                authTabPicker
                
                if selectedTab == .login {
                    loginForm
                } else {
                    signupForm
                }
                
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
    
    private var authTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    Text(tab.title)
                        .font(.botanicalHeadline)
                        .foregroundColor(selectedTab == tab ? .white : .botanicalGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.botanicalGreen : Color.clear)
                        )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.botanicalGreen, lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }
    
    private var loginForm: some View {
        VStack(spacing: 16) {
            BotanicalTextField(
                "Username",
                text: Binding(
                    get: { store.loginForm.username },
                    set: { store.send(.updateLoginForm(username: $0, password: nil)) }
                )
            )
            
            BotanicalTextField(
                "Password",
                text: Binding(
                    get: { store.loginForm.password },
                    set: { store.send(.updateLoginForm(username: nil, password: $0)) }
                ),
                isSecure: true
            )
            
            BotanicalButton(
                "Login",
                style: .primary,
                size: .large,
                isLoading: store.isLoading,
                isDisabled: !store.loginForm.isValid
            ) {
                store.send(.login(
                    username: store.loginForm.username,
                    password: store.loginForm.password
                ))
            }
            .padding(.top, 8)
        }
    }
    
    private var signupForm: some View {
        VStack(spacing: 16) {
            BotanicalTextField(
                "Username",
                text: Binding(
                    get: { store.signupForm.username },
                    set: { store.send(.updateSignupForm(username: $0, email: nil, password: nil, confirmPassword: nil, displayName: nil)) }
                )
            )
            
            BotanicalTextField(
                "Email",
                text: Binding(
                    get: { store.signupForm.email },
                    set: { store.send(.updateSignupForm(username: nil, email: $0, password: nil, confirmPassword: nil, displayName: nil)) }
                )
            )
            
            BotanicalTextField(
                "Display Name (Optional)",
                text: Binding(
                    get: { store.signupForm.displayName },
                    set: { store.send(.updateSignupForm(username: nil, email: nil, password: nil, confirmPassword: nil, displayName: $0)) }
                )
            )
            
            BotanicalTextField(
                "Password",
                text: Binding(
                    get: { store.signupForm.password },
                    set: { store.send(.updateSignupForm(username: nil, email: nil, password: $0, confirmPassword: nil, displayName: nil)) }
                ),
                isSecure: true
            )
            
            BotanicalTextField(
                "Confirm Password",
                text: Binding(
                    get: { store.signupForm.confirmPassword },
                    set: { store.send(.updateSignupForm(username: nil, email: nil, password: nil, confirmPassword: $0, displayName: nil)) }
                ),
                isSecure: true
            )
            
            BotanicalButton(
                "Sign Up",
                style: .primary,
                size: .large,
                isLoading: store.isLoading,
                isDisabled: !store.signupForm.isValid
            ) {
                store.send(.signup(
                    username: store.signupForm.username,
                    email: store.signupForm.email,
                    password: store.signupForm.password,
                    displayName: store.signupForm.displayName.isEmpty ? nil : store.signupForm.displayName
                ))
            }
            .padding(.top, 8)
        }
    }
}

struct BotanicalTextField: View {
    let title: String
    @Binding var text: String
    let isSecure: Bool
    
    init(_ title: String, text: Binding<String>, isSecure: Bool = false) {
        self.title = title
        self._text = text
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .botanicalStyle(.callout)
                .foregroundColor(.textSecondary)
            
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(.botanicalBody)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.botanicalGreen.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

extension Binding<String> {
    func sending<Action>(_ action: @escaping (String?) -> Action) -> Binding<String> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                // This would typically send the action to the store
                // For now, we'll just update the binding
            }
        )
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