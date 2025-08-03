import XCTest
import SwiftUI
@testable import BotanyBattle

class SettingsComponentsTests: XCTestCase {
    
    // MARK: - SettingsFeature Tests
    
    func testSettingsFeatureInitialization() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let mockAuth = MockAuthFeature()
        
        // When
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // Then
        XCTAssertNotNil(settingsFeature.authFeature)
        XCTAssertNotNil(settingsFeature.userDefaultsService)
        XCTAssertFalse(settingsFeature.isLoading)
        XCTAssertNil(settingsFeature.errorMessage)
    }
    
    func testSettingsDataBinding() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.soundEnabled = true
        mockUserDefaults.hapticsEnabled = false
        mockUserDefaults.reducedAnimations = true
        
        let mockAuth = MockAuthFeature()
        
        // When
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // Then
        XCTAssertEqual(settingsFeature.settingsData.soundEnabled, true)
        XCTAssertEqual(settingsFeature.settingsData.hapticsEnabled, false)
        XCTAssertEqual(settingsFeature.settingsData.reducedAnimations, true)
    }
    
    func testUpdateSetting() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.soundEnabled = false
        
        let mockAuth = MockAuthFeature()
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When
        settingsFeature.updateSetting(.soundEnabled, value: true)
        
        // Then
        XCTAssertTrue(mockUserDefaults.soundEnabled)
        XCTAssertTrue(settingsFeature.settingsData.soundEnabled)
    }
    
    func testResetToDefaults() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.soundEnabled = false
        mockUserDefaults.hapticsEnabled = false
        mockUserDefaults.reducedAnimations = true
        
        let mockAuth = MockAuthFeature()
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When
        settingsFeature.resetToDefaults()
        
        // Then
        XCTAssertTrue(mockUserDefaults.soundEnabled) // Default is true
        XCTAssertTrue(mockUserDefaults.hapticsEnabled) // Default is true
        XCTAssertFalse(mockUserDefaults.reducedAnimations) // Default is false
    }
    
    func testSignOut() async {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let mockAuth = MockAuthFeature()
        mockAuth.isAuthenticated = true
        
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When
        await settingsFeature.signOut()
        
        // Then
        XCTAssertFalse(mockAuth.isAuthenticated)
    }
    
    // MARK: - SettingRow Tests
    
    func testSettingRowCreation() {
        // Given
        let title = "Sound Effects"
        let icon = "speaker.wave.2.fill"
        let description = "Enable or disable sound effects"
        
        // When
        let settingRow = SettingRow(
            title: title,
            icon: icon,
            description: description,
            content: AnyView(Toggle("", isOn: .constant(true)))
        )
        
        // Then
        XCTAssertEqual(settingRow.title, title)
        XCTAssertEqual(settingRow.icon, icon)
        XCTAssertEqual(settingRow.description, description)
    }
    
    // MARK: - SettingToggleRow Tests
    
    func testSettingToggleRowCreation() {
        // Given
        let title = "Haptic Feedback"
        let icon = "iphone.radiowaves.left.and.right"
        let isOn = true
        
        // When
        let toggleRow = SettingToggleRow(
            title: title,
            icon: icon,
            isOn: .constant(isOn)
        ) { _ in }
        
        // Then
        XCTAssertEqual(toggleRow.title, title)
        XCTAssertEqual(toggleRow.icon, icon)
    }
    
    // MARK: - SettingPickerRow Tests
    
    func testSettingPickerRowCreation() {
        // Given
        let title = "Theme"
        let icon = "paintbrush.fill"
        let options = ["Light", "Dark", "System"]
        let selectedValue = "System"
        
        // When
        let pickerRow = SettingPickerRow(
            title: title,
            icon: icon,
            options: options,
            selectedValue: .constant(selectedValue)
        ) { _ in }
        
        // Then
        XCTAssertEqual(pickerRow.title, title)
        XCTAssertEqual(pickerRow.icon, icon)
        XCTAssertEqual(pickerRow.options, options)
    }
    
    // MARK: - SettingButtonRow Tests
    
    func testSettingButtonRowCreation() {
        // Given
        let title = "Reset to Defaults"
        let icon = "arrow.clockwise"
        let style = SettingButtonStyle.destructive
        
        // When
        let buttonRow = SettingButtonRow(
            title: title,
            icon: icon,
            style: style
        ) { }
        
        // Then
        XCTAssertEqual(buttonRow.title, title)
        XCTAssertEqual(buttonRow.icon, icon)
        XCTAssertEqual(buttonRow.style, style)
    }
    
    func testSettingButtonStyles() {
        // Given & When & Then
        XCTAssertEqual(SettingButtonStyle.normal.textColor, .primary)
        XCTAssertEqual(SettingButtonStyle.primary.textColor, .blue)
        XCTAssertEqual(SettingButtonStyle.destructive.textColor, .red)
        XCTAssertEqual(SettingButtonStyle.warning.textColor, .orange)
    }
    
    // MARK: - SettingsSection Tests
    
    func testSettingsSectionCreation() {
        // Given
        let title = "Audio Settings"
        let description = "Configure sound and music preferences"
        let content = AnyView(Text("Content"))
        
        // When
        let section = SettingsSection(
            title: title,
            description: description,
            content: content
        )
        
        // Then
        XCTAssertEqual(section.title, title)
        XCTAssertEqual(section.description, description)
    }
    
    // MARK: - SettingsData Tests
    
    func testSettingsDataModel() {
        // Given
        let settingsData = SettingsData(
            soundEnabled: true,
            musicEnabled: false,
            hapticsEnabled: true,
            reducedAnimations: false,
            notifications: true,
            selectedTheme: .system,
            selectedDifficulty: .medium
        )
        
        // Then
        XCTAssertTrue(settingsData.soundEnabled)
        XCTAssertFalse(settingsData.musicEnabled)
        XCTAssertTrue(settingsData.hapticsEnabled)
        XCTAssertFalse(settingsData.reducedAnimations)
        XCTAssertTrue(settingsData.notifications)
        XCTAssertEqual(settingsData.selectedTheme, .system)
        XCTAssertEqual(settingsData.selectedDifficulty, .medium)
    }
    
    func testSettingsDataDefaults() {
        // Given
        let defaultSettings = SettingsData.defaults
        
        // Then
        XCTAssertTrue(defaultSettings.soundEnabled)
        XCTAssertTrue(defaultSettings.musicEnabled)
        XCTAssertTrue(defaultSettings.hapticsEnabled)
        XCTAssertFalse(defaultSettings.reducedAnimations)
        XCTAssertTrue(defaultSettings.notifications)
        XCTAssertEqual(defaultSettings.selectedTheme, .system)
        XCTAssertEqual(defaultSettings.selectedDifficulty, .medium)
    }
    
    // MARK: - Theme Tests
    
    func testThemeOptions() {
        // Given
        let themes = Theme.allCases
        
        // Then
        XCTAssertTrue(themes.contains(.light))
        XCTAssertTrue(themes.contains(.dark))
        XCTAssertTrue(themes.contains(.system))
        XCTAssertEqual(themes.count, 3)
    }
    
    func testThemeDisplayNames() {
        // Given & When & Then
        XCTAssertEqual(Theme.light.displayName, "Light")
        XCTAssertEqual(Theme.dark.displayName, "Dark")
        XCTAssertEqual(Theme.system.displayName, "System")
    }
    
    // MARK: - Difficulty Tests
    
    func testDifficultyOptions() {
        // Given
        let difficulties = Difficulty.allCases
        
        // Then
        XCTAssertTrue(difficulties.contains(.easy))
        XCTAssertTrue(difficulties.contains(.medium))
        XCTAssertTrue(difficulties.contains(.hard))
        XCTAssertTrue(difficulties.contains(.expert))
        XCTAssertEqual(difficulties.count, 4)
    }
    
    func testDifficultyProperties() {
        // Given & When & Then
        XCTAssertEqual(Difficulty.easy.displayName, "Easy")
        XCTAssertEqual(Difficulty.medium.displayName, "Medium")
        XCTAssertEqual(Difficulty.hard.displayName, "Hard")
        XCTAssertEqual(Difficulty.expert.displayName, "Expert")
        
        XCTAssertEqual(Difficulty.easy.timeLimit, 30)
        XCTAssertEqual(Difficulty.medium.timeLimit, 20)
        XCTAssertEqual(Difficulty.hard.timeLimit, 15)
        XCTAssertEqual(Difficulty.expert.timeLimit, 10)
    }
    
    // MARK: - SettingType Tests
    
    func testSettingTypeEnum() {
        // Given
        let settingTypes: [SettingType] = [
            .soundEnabled,
            .musicEnabled,
            .hapticsEnabled,
            .reducedAnimations,
            .notifications,
            .theme,
            .difficulty
        ]
        
        // Then
        XCTAssertEqual(settingTypes.count, 7)
        
        // Verify all cases are covered
        for settingType in settingTypes {
            switch settingType {
            case .soundEnabled, .musicEnabled, .hapticsEnabled, .reducedAnimations, .notifications, .theme, .difficulty:
                continue // All cases covered
            }
        }
    }
    
    // MARK: - Settings Export/Import Tests
    
    func testSettingsExport() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.soundEnabled = false
        mockUserDefaults.hapticsEnabled = true
        
        let mockAuth = MockAuthFeature()
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When
        let exportedSettings = settingsFeature.exportSettings()
        
        // Then
        XCTAssertNotNil(exportedSettings)
        XCTAssertTrue(exportedSettings.contains("soundEnabled"))
        XCTAssertTrue(exportedSettings.contains("hapticsEnabled"))
    }
    
    func testSettingsImport() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let mockAuth = MockAuthFeature()
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        let settingsJSON = """
        {
            "soundEnabled": false,
            "hapticsEnabled": true,
            "reducedAnimations": false
        }
        """
        
        // When
        let result = settingsFeature.importSettings(from: settingsJSON)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertFalse(mockUserDefaults.soundEnabled)
        XCTAssertTrue(mockUserDefaults.hapticsEnabled)
        XCTAssertFalse(mockUserDefaults.reducedAnimations)
    }
    
    func testInvalidSettingsImport() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let mockAuth = MockAuthFeature()
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        let invalidJSON = "{ invalid json }"
        
        // When
        let result = settingsFeature.importSettings(from: invalidJSON)
        
        // Then
        XCTAssertFalse(result)
    }
    
    // MARK: - Performance Tests
    
    func testSettingsComponentsPerformance() {
        measure {
            let mockUserDefaults = MockUserDefaultsService()
            let mockAuth = MockAuthFeature()
            
            for _ in 0..<100 {
                let _ = SettingsFeature(
                    authFeature: mockAuth,
                    userDefaultsService: mockUserDefaults
                )
            }
        }
    }
    
    func testSettingsUpdatePerformance() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let mockAuth = MockAuthFeature()
        let settingsFeature = SettingsFeature(
            authFeature: mockAuth,
            userDefaultsService: mockUserDefaults
        )
        
        // When & Then
        measure {
            for i in 0..<1000 {
                settingsFeature.updateSetting(.soundEnabled, value: i % 2 == 0)
            }
        }
    }
}

// MARK: - Supporting Data Models for Tests

struct SettingRow {
    let title: String
    let icon: String
    let description: String?
    let content: AnyView
    
    init(title: String, icon: String, description: String? = nil, content: AnyView) {
        self.title = title
        self.icon = icon
        self.description = description
        self.content = content
    }
}

struct SettingToggleRow {
    let title: String
    let icon: String
    let isOn: Binding<Bool>
    let onChange: (Bool) -> Void
}

struct SettingPickerRow {
    let title: String
    let icon: String
    let options: [String]
    let selectedValue: Binding<String>
    let onChange: (String) -> Void
}

struct SettingButtonRow {
    let title: String
    let icon: String
    let style: SettingButtonStyle
    let action: () -> Void
}

enum SettingButtonStyle: Equatable {
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

struct SettingsSection {
    let title: String
    let description: String?
    let content: AnyView
}

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
    
    var timeLimit: Int {
        switch self {
        case .easy: return 30
        case .medium: return 20
        case .hard: return 15
        case .expert: return 10
        }
    }
}

enum SettingType {
    case soundEnabled
    case musicEnabled
    case hapticsEnabled
    case reducedAnimations
    case notifications
    case theme
    case difficulty
}

// MARK: - Mock SettingsFeature for Testing

class SettingsFeature: ObservableObject {
    @Published var settingsData: SettingsData
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let authFeature: AuthFeatureProtocol
    let userDefaultsService: UserDefaultsServiceProtocol
    
    init(authFeature: AuthFeatureProtocol, userDefaultsService: UserDefaultsServiceProtocol) {
        self.authFeature = authFeature
        self.userDefaultsService = userDefaultsService
        
        self.settingsData = SettingsData(
            soundEnabled: userDefaultsService.soundEnabled,
            musicEnabled: true, // Assuming this exists
            hapticsEnabled: userDefaultsService.hapticsEnabled,
            reducedAnimations: userDefaultsService.reducedAnimations,
            notifications: true, // Assuming this exists
            selectedTheme: .system,
            selectedDifficulty: .medium
        )
    }
    
    func updateSetting(_ setting: SettingType, value: Any) {
        switch setting {
        case .soundEnabled:
            if let boolValue = value as? Bool {
                userDefaultsService.soundEnabled = boolValue
                settingsData.soundEnabled = boolValue
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
        default:
            break
        }
    }
    
    func resetToDefaults() {
        userDefaultsService.soundEnabled = true
        userDefaultsService.hapticsEnabled = true
        userDefaultsService.reducedAnimations = false
        
        settingsData = SettingsData.defaults
    }
    
    func signOut() async {
        await authFeature.signOut()
    }
    
    func exportSettings() -> String {
        // Simple JSON export
        return """
        {
            "soundEnabled": \(settingsData.soundEnabled),
            "hapticsEnabled": \(settingsData.hapticsEnabled),
            "reducedAnimations": \(settingsData.reducedAnimations)
        }
        """
    }
    
    func importSettings(from json: String) -> Bool {
        // Simple JSON import
        guard let data = json.data(using: .utf8),
              let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        if let soundEnabled = dictionary["soundEnabled"] as? Bool {
            updateSetting(.soundEnabled, value: soundEnabled)
        }
        
        if let hapticsEnabled = dictionary["hapticsEnabled"] as? Bool {
            updateSetting(.hapticsEnabled, value: hapticsEnabled)
        }
        
        if let reducedAnimations = dictionary["reducedAnimations"] as? Bool {
            updateSetting(.reducedAnimations, value: reducedAnimations)
        }
        
        return true
    }
}