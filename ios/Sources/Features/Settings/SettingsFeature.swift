import Foundation
import ComposableArchitecture

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var soundEnabled = true
        var musicEnabled = true
        var notificationsEnabled = true
        var hapticFeedbackEnabled = true
        var autoplayEnabled = false
        var difficulty: Game.Difficulty = .medium
        var language: Language = .english
        var theme: Theme = .system
        var isLoading = false
        var error: String?
        
        enum Language: String, CaseIterable {
            case english = "en"
            case spanish = "es"
            case french = "fr"
            case german = "de"
            case swedish = "sv"
            
            var displayName: String {
                switch self {
                case .english: return "English"
                case .spanish: return "Español"
                case .french: return "Français"
                case .german: return "Deutsch"
                case .swedish: return "Svenska"
                }
            }
        }
        
        enum Theme: String, CaseIterable {
            case light = "light"
            case dark = "dark"
            case system = "system"
            
            var displayName: String {
                switch self {
                case .light: return "Light"
                case .dark: return "Dark"
                case .system: return "System"
                }
            }
        }
    }
    
    enum Action {
        case onAppear
        case toggleSound
        case toggleMusic
        case toggleNotifications
        case toggleHapticFeedback
        case toggleAutoplay
        case setDifficulty(Game.Difficulty)
        case setLanguage(State.Language)
        case setTheme(State.Theme)
        case resetToDefaults
        case exportData
        case deleteAccount
        case loadSettings
        case settingsLoaded(State)
        case saveSettings
        case settingsSaved
        case settingsError(String)
        case clearError
    }
    
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.userService) var userService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.loadSettings)
                
            case .toggleSound:
                state.soundEnabled.toggle()
                return .send(.saveSettings)
                
            case .toggleMusic:
                state.musicEnabled.toggle()
                return .send(.saveSettings)
                
            case .toggleNotifications:
                state.notificationsEnabled.toggle()
                return .send(.saveSettings)
                
            case .toggleHapticFeedback:
                state.hapticFeedbackEnabled.toggle()
                return .send(.saveSettings)
                
            case .toggleAutoplay:
                state.autoplayEnabled.toggle()
                return .send(.saveSettings)
                
            case .setDifficulty(let difficulty):
                state.difficulty = difficulty
                return .send(.saveSettings)
                
            case .setLanguage(let language):
                state.language = language
                return .send(.saveSettings)
                
            case .setTheme(let theme):
                state.theme = theme
                return .send(.saveSettings)
                
            case .resetToDefaults:
                state = State()
                return .send(.saveSettings)
                
            case .exportData:
                return .run { send in
                    do {
                        try await userService.exportUserData()
                    } catch {
                        await send(.settingsError(error.localizedDescription))
                    }
                }
                
            case .deleteAccount:
                return .run { send in
                    do {
                        try await userService.deleteAccount()
                    } catch {
                        await send(.settingsError(error.localizedDescription))
                    }
                }
                
            case .loadSettings:
                state.isLoading = true
                return .run { send in
                    let settings = State(
                        soundEnabled: userDefaults.bool(forKey: "soundEnabled") ?? true,
                        musicEnabled: userDefaults.bool(forKey: "musicEnabled") ?? true,
                        notificationsEnabled: userDefaults.bool(forKey: "notificationsEnabled") ?? true,
                        hapticFeedbackEnabled: userDefaults.bool(forKey: "hapticFeedbackEnabled") ?? true,
                        autoplayEnabled: userDefaults.bool(forKey: "autoplayEnabled") ?? false,
                        difficulty: Game.Difficulty(rawValue: userDefaults.string(forKey: "difficulty") ?? "medium") ?? .medium,
                        language: State.Language(rawValue: userDefaults.string(forKey: "language") ?? "en") ?? .english,
                        theme: State.Theme(rawValue: userDefaults.string(forKey: "theme") ?? "system") ?? .system
                    )
                    await send(.settingsLoaded(settings))
                }
                
            case .settingsLoaded(let settings):
                state = settings
                state.isLoading = false
                return .none
                
            case .saveSettings:
                return .run { [state] send in
                    userDefaults.set(state.soundEnabled, forKey: "soundEnabled")
                    userDefaults.set(state.musicEnabled, forKey: "musicEnabled")
                    userDefaults.set(state.notificationsEnabled, forKey: "notificationsEnabled")
                    userDefaults.set(state.hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
                    userDefaults.set(state.autoplayEnabled, forKey: "autoplayEnabled")
                    userDefaults.set(state.difficulty.rawValue, forKey: "difficulty")
                    userDefaults.set(state.language.rawValue, forKey: "language")
                    userDefaults.set(state.theme.rawValue, forKey: "theme")
                    await send(.settingsSaved)
                }
                
            case .settingsSaved:
                return .none
                
            case .settingsError(let error):
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

extension UserDefaults {
    func bool(forKey key: String) -> Bool? {
        if object(forKey: key) != nil {
            return bool(forKey: key)
        }
        return nil
    }
}