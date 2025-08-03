import SwiftUI
import Combine

// MARK: - Settings Feature

@MainActor
class SettingsFeature: ObservableObject {
    @Published var settingsData: SettingsData
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSignOutAlert = false
    @Published var showingResetAlert = false
    @Published var showingExportSheet = false
    @Published var exportText = ""
    
    let authFeature: AuthFeature
    let userDefaultsService: UserDefaultsService
    private var cancellables = Set<AnyCancellable>()
    
    init(authFeature: AuthFeature, userDefaultsService: UserDefaultsService) {
        self.authFeature = authFeature
        self.userDefaultsService = userDefaultsService
        
        // Initialize settings data from user defaults
        self.settingsData = SettingsData(
            soundEnabled: userDefaultsService.soundEnabled,
            musicEnabled: true, // Placeholder - would be stored in UserDefaults
            hapticsEnabled: userDefaultsService.hapticsEnabled,
            reducedAnimations: userDefaultsService.reducedAnimations,
            notifications: true, // Placeholder - would be stored in UserDefaults
            selectedTheme: Theme(rawValue: UserDefaults.standard.string(forKey: "selectedTheme") ?? "system") ?? .system,
            selectedDifficulty: Difficulty(rawValue: UserDefaults.standard.string(forKey: "selectedDifficulty") ?? "medium") ?? .medium
        )
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for authentication changes
        authFeature.$authState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Setting Updates
    
    func updateSetting(_ setting: SettingType, value: Any) {
        switch setting {
        case .soundEnabled:
            if let boolValue = value as? Bool {
                userDefaultsService.soundEnabled = boolValue
                settingsData.soundEnabled = boolValue
            }
        case .musicEnabled:
            if let boolValue = value as? Bool {
                UserDefaults.standard.set(boolValue, forKey: "musicEnabled")
                settingsData.musicEnabled = boolValue
            }
        case .hapticsEnabled:
            if let boolValue = value as? Bool {
                userDefaultsService.hapticsEnabled = boolValue
                settingsData.hapticsEnabled = boolValue
            }
        case .reducedAnimations:
            if let boolValue = value as? Bool {
                userDefaultsService.reducedAnimations = boolValue
                settingsData.reducedAnimations = boolValue
            }
        case .notifications:
            if let boolValue = value as? Bool {
                UserDefaults.standard.set(boolValue, forKey: "notifications")
                settingsData.notifications = boolValue
            }
        case .theme:
            if let themeValue = value as? Theme {
                UserDefaults.standard.set(themeValue.rawValue, forKey: "selectedTheme")
                settingsData.selectedTheme = themeValue
            }
        case .difficulty:
            if let difficultyValue = value as? Difficulty {
                UserDefaults.standard.set(difficultyValue.rawValue, forKey: "selectedDifficulty")
                settingsData.selectedDifficulty = difficultyValue
            }
        }
        
        // Trigger haptic feedback for setting changes
        if settingsData.hapticsEnabled {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    func resetToDefaults() {
        showingResetAlert = true
    }
    
    func confirmResetToDefaults() {
        let defaults = SettingsData.defaults
        
        userDefaultsService.soundEnabled = defaults.soundEnabled
        userDefaultsService.hapticsEnabled = defaults.hapticsEnabled
        userDefaultsService.reducedAnimations = defaults.reducedAnimations
        
        UserDefaults.standard.set(defaults.musicEnabled, forKey: "musicEnabled")
        UserDefaults.standard.set(defaults.notifications, forKey: "notifications")
        UserDefaults.standard.set(defaults.selectedTheme.rawValue, forKey: "selectedTheme")
        UserDefaults.standard.set(defaults.selectedDifficulty.rawValue, forKey: "selectedDifficulty")
        
        settingsData = defaults
        showingResetAlert = false
        
        // Show success feedback
        if settingsData.hapticsEnabled {
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        }
    }
    
    // MARK: - Authentication Actions
    
    func signOut() async {
        showingSignOutAlert = true
    }
    
    func confirmSignOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            await authFeature.signOut()
            showingSignOutAlert = false
        } catch {
            errorMessage = "Failed to sign out. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Data Export/Import
    
    func exportSettings() {
        let settingsDict: [String: Any] = [
            "soundEnabled": settingsData.soundEnabled,
            "musicEnabled": settingsData.musicEnabled,
            "hapticsEnabled": settingsData.hapticsEnabled,
            "reducedAnimations": settingsData.reducedAnimations,
            "notifications": settingsData.notifications,
            "selectedTheme": settingsData.selectedTheme.rawValue,
            "selectedDifficulty": settingsData.selectedDifficulty.rawValue,
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: settingsDict, options: .prettyPrinted)
            exportText = String(data: jsonData, encoding: .utf8) ?? ""
            showingExportSheet = true
        } catch {
            errorMessage = "Failed to export settings"
        }
    }
    
    func importSettings(from json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            errorMessage = "Invalid settings format"
            return false
        }
        
        // Import each setting with validation
        if let soundEnabled = dictionary["soundEnabled"] as? Bool {
            updateSetting(.soundEnabled, value: soundEnabled)
        }
        
        if let musicEnabled = dictionary["musicEnabled"] as? Bool {
            updateSetting(.musicEnabled, value: musicEnabled)
        }
        
        if let hapticsEnabled = dictionary["hapticsEnabled"] as? Bool {
            updateSetting(.hapticsEnabled, value: hapticsEnabled)
        }
        
        if let reducedAnimations = dictionary["reducedAnimations"] as? Bool {
            updateSetting(.reducedAnimations, value: reducedAnimations)
        }
        
        if let notifications = dictionary["notifications"] as? Bool {
            updateSetting(.notifications, value: notifications)
        }
        
        if let themeString = dictionary["selectedTheme"] as? String,
           let theme = Theme(rawValue: themeString) {
            updateSetting(.theme, value: theme)
        }
        
        if let difficultyString = dictionary["selectedDifficulty"] as? String,
           let difficulty = Difficulty(rawValue: difficultyString) {
            updateSetting(.difficulty, value: difficulty)
        }
        
        return true
    }
    
    // MARK: - Computed Properties
    
    var userDisplayName: String {
        return authFeature.userDisplayName ?? "Guest"
    }
    
    var isAuthenticated: Bool {
        return authFeature.isAuthenticated
    }
    
    var canExportData: Bool {
        return isAuthenticated
    }
}

// MARK: - Settings Data Model

struct SettingsData: Equatable {
    var soundEnabled: Bool
    var musicEnabled: Bool
    var hapticsEnabled: Bool
    var reducedAnimations: Bool
    var notifications: Bool
    var selectedTheme: Theme
    var selectedDifficulty: Difficulty
    
    static let defaults = SettingsData(
        soundEnabled: true,
        musicEnabled: true,
        hapticsEnabled: true,
        reducedAnimations: false,
        notifications: true,
        selectedTheme: .system,
        selectedDifficulty: .medium
    )
}

// MARK: - Theme Enum

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
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gear"
        }
    }
}

// MARK: - Difficulty Enum

enum Difficulty: String, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }
    
    var icon: String {
        switch self {
        case .easy: return "tortoise.fill"
        case .medium: return "figure.walk"
        case .hard: return "hare.fill"
        case .expert: return "bolt.fill"
        }
    }
    
    var timeLimit: Int {
        switch self {
        case .easy: return 30
        case .medium: return 20
        case .hard: return 15
        case .expert: return 10
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "\(timeLimit) seconds per question"
        case .medium: return "\(timeLimit) seconds per question"
        case .hard: return "\(timeLimit) seconds per question"
        case .expert: return "\(timeLimit) seconds per question - for experts only!"
        }
    }
}

// MARK: - Setting Type Enum

enum SettingType {
    case soundEnabled
    case musicEnabled
    case hapticsEnabled
    case reducedAnimations
    case notifications
    case theme
    case difficulty
}

// MARK: - Settings Components

struct SettingRow<Content: View>: View {
    let title: String
    let icon: String
    let description: String?
    let content: () -> Content
    
    init(title: String, icon: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.description = description
        self.content = content
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 4)
    }
}

struct SettingToggleRow: View {
    let title: String
    let icon: String
    let description: String?
    @Binding var isOn: Bool
    let onChange: (Bool) -> Void
    
    init(title: String, icon: String, description: String? = nil, isOn: Binding<Bool>, onChange: @escaping (Bool) -> Void) {
        self.title = title
        self.icon = icon
        self.description = description
        self._isOn = isOn
        self.onChange = onChange
    }
    
    var body: some View {
        SettingRow(title: title, icon: icon, description: description) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { newValue in
                    onChange(newValue)
                }
        }
    }
}

struct SettingPickerRow<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    let icon: String
    let description: String?
    @Binding var selectedValue: T
    let onChange: (T) -> Void
    
    init(title: String, icon: String, description: String? = nil, selectedValue: Binding<T>, onChange: @escaping (T) -> Void) {
        self.title = title
        self.icon = icon
        self.description = description
        self._selectedValue = selectedValue
        self.onChange = onChange
    }
    
    var body: some View {
        SettingRow(title: title, icon: icon, description: description) {
            Menu {
                ForEach(Array(T.allCases), id: \.self) { option in
                    Button(action: {
                        selectedValue = option
                        onChange(option)
                    }) {
                        HStack {
                            if let displayable = option as? any CustomStringConvertible {
                                Text(String(describing: displayable))
                            } else {
                                Text(option.rawValue.capitalized)
                            }
                            
                            if option == selectedValue {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let displayable = selectedValue as? any CustomStringConvertible {
                        Text(String(describing: displayable))
                    } else {
                        Text(selectedValue.rawValue.capitalized)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }
        }
    }
}

struct SettingButtonRow: View {
    let title: String
    let icon: String
    let description: String?
    let style: SettingButtonStyle
    let action: () -> Void
    
    init(title: String, icon: String, description: String? = nil, style: SettingButtonStyle = .normal, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.description = description
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            SettingRow(title: title, icon: icon, description: description) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .foregroundColor(style.textColor)
        .buttonStyle(PlainButtonStyle())
    }
}

enum SettingButtonStyle {
    case normal
    case primary
    case destructive
    case warning
    
    var textColor: Color {
        switch self {
        case .normal: return .primary
        case .primary: return .blue
        case .destructive: return .red
        case .warning: return .orange
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let description: String?
    let content: () -> Content
    
    init(title: String, description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.description = description
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                content()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Custom Toggle Style

struct SettingsToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            Button(action: {
                configuration.isOn.toggle()
            }) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? Color.green : Color(.systemGray4))
                    .frame(width: 51, height: 31)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .shadow(radius: 1)
                            .padding(2)
                            .offset(x: configuration.isOn ? 10 : -10)
                    )
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}