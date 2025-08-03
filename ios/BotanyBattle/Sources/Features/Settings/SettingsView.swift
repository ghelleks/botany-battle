import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsFeature: SettingsFeature
    @State private var showingAbout = false
    @State private var showingHelp = false
    @State private var showingImportSheet = false
    @State private var importText = ""
    
    init(authFeature: AuthFeature, userDefaultsService: UserDefaultsService) {
        self._settingsFeature = StateObject(wrappedValue: SettingsFeature(
            authFeature: authFeature,
            userDefaultsService: userDefaultsService
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // User Profile Section
                if settingsFeature.isAuthenticated {
                    UserProfileSection(
                        displayName: settingsFeature.userDisplayName,
                        isAuthenticated: settingsFeature.isAuthenticated
                    )
                }
                
                // Audio Settings
                SettingsSection(
                    title: "Audio",
                    description: "Configure sound and music preferences"
                ) {
                    SettingToggleRow(
                        title: "Sound Effects",
                        icon: "speaker.wave.2.fill",
                        description: "Enable or disable sound effects",
                        isOn: $settingsFeature.settingsData.soundEnabled
                    ) { value in
                        settingsFeature.updateSetting(.soundEnabled, value: value)
                    }
                    
                    SettingToggleRow(
                        title: "Background Music",
                        icon: "music.note",
                        description: "Play background music during games",
                        isOn: $settingsFeature.settingsData.musicEnabled
                    ) { value in
                        settingsFeature.updateSetting(.musicEnabled, value: value)
                    }
                }
                
                // Gameplay Settings
                SettingsSection(
                    title: "Gameplay",
                    description: "Customize your gaming experience"
                ) {
                    SettingToggleRow(
                        title: "Haptic Feedback",
                        icon: "iphone.radiowaves.left.and.right",
                        description: "Feel vibrations for game events",
                        isOn: $settingsFeature.settingsData.hapticsEnabled
                    ) { value in
                        settingsFeature.updateSetting(.hapticsEnabled, value: value)
                    }
                    
                    DifficultyPickerRow(
                        selectedDifficulty: $settingsFeature.settingsData.selectedDifficulty
                    ) { difficulty in
                        settingsFeature.updateSetting(.difficulty, value: difficulty)
                    }
                }
                
                // Appearance Settings
                SettingsSection(
                    title: "Appearance",
                    description: "Customize the app's look and feel"
                ) {
                    ThemePickerRow(
                        selectedTheme: $settingsFeature.settingsData.selectedTheme
                    ) { theme in
                        settingsFeature.updateSetting(.theme, value: theme)
                    }
                    
                    SettingToggleRow(
                        title: "Reduce Animations",
                        icon: "slowmo",
                        description: "Minimize motion for better accessibility",
                        isOn: $settingsFeature.settingsData.reducedAnimations
                    ) { value in
                        settingsFeature.updateSetting(.reducedAnimations, value: value)
                    }
                }
                
                // Notifications Settings
                SettingsSection(
                    title: "Notifications",
                    description: "Manage app notifications"
                ) {
                    SettingToggleRow(
                        title: "Push Notifications",
                        icon: "bell.fill",
                        description: "Receive game updates and reminders",
                        isOn: $settingsFeature.settingsData.notifications
                    ) { value in
                        settingsFeature.updateSetting(.notifications, value: value)
                    }
                }
                
                // Data & Privacy Settings
                SettingsSection(
                    title: "Data & Privacy",
                    description: "Manage your data and privacy settings"
                ) {
                    if settingsFeature.canExportData {
                        SettingButtonRow(
                            title: "Export My Data",
                            icon: "square.and.arrow.up",
                            description: "Download your game data",
                            style: .primary
                        ) {
                            settingsFeature.exportSettings()
                        }
                        
                        SettingButtonRow(
                            title: "Import Settings",
                            icon: "square.and.arrow.down",
                            description: "Restore settings from backup",
                            style: .primary
                        ) {
                            showingImportSheet = true
                        }
                    }
                    
                    SettingButtonRow(
                        title: "Reset to Defaults",
                        icon: "arrow.clockwise",
                        description: "Restore all settings to default values",
                        style: .warning
                    ) {
                        settingsFeature.resetToDefaults()
                    }
                }
                
                // Help & Support Settings
                SettingsSection(
                    title: "Help & Support",
                    description: "Get help and learn more about the app"
                ) {
                    SettingButtonRow(
                        title: "Help & FAQ",
                        icon: "questionmark.circle.fill",
                        description: "Find answers to common questions"
                    ) {
                        showingHelp = true
                    }
                    
                    SettingButtonRow(
                        title: "About Botany Battle",
                        icon: "info.circle.fill",
                        description: "App version and credits"
                    ) {
                        showingAbout = true
                    }
                    
                    SettingButtonRow(
                        title: "Contact Support",
                        icon: "envelope.fill",
                        description: "Get in touch with our support team"
                    ) {
                        openSupportEmail()
                    }
                }
                
                // Account Settings
                if settingsFeature.isAuthenticated {
                    SettingsSection(
                        title: "Account",
                        description: "Manage your account"
                    ) {
                        SettingButtonRow(
                            title: "Sign Out",
                            icon: "person.crop.circle.badge.minus",
                            description: "Sign out of your account",
                            style: .destructive
                        ) {
                            Task {
                                await settingsFeature.signOut()
                            }
                        }
                    }
                }
                
                // Version Info
                AppVersionFooter()
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if settingsFeature.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .alert("Error", isPresented: .constant(settingsFeature.errorMessage != nil)) {
            Button("OK") {
                settingsFeature.errorMessage = nil
            }
        } message: {
            Text(settingsFeature.errorMessage ?? "")
        }
        .alert("Sign Out", isPresented: $settingsFeature.showingSignOutAlert) {
            Button("Cancel", role: .cancel) {
                settingsFeature.showingSignOutAlert = false
            }
            Button("Sign Out", role: .destructive) {
                Task {
                    await settingsFeature.confirmSignOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out? Your progress will be saved locally.")
        }
        .alert("Reset Settings", isPresented: $settingsFeature.showingResetAlert) {
            Button("Cancel", role: .cancel) {
                settingsFeature.showingResetAlert = false
            }
            Button("Reset", role: .destructive) {
                settingsFeature.confirmResetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .sheet(isPresented: $settingsFeature.showingExportSheet) {
            ExportDataSheet(exportText: settingsFeature.exportText)
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportDataSheet(
                importText: $importText,
                onImport: { text in
                    let success = settingsFeature.importSettings(from: text)
                    if success {
                        showingImportSheet = false
                        importText = ""
                    }
                }
            )
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
    }
    
    private func openSupportEmail() {
        let email = "support@botanybattle.com"
        let subject = "Botany Battle Support Request"
        let body = "Please describe your issue or question:\n\n"
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - User Profile Section

struct UserProfileSection: View {
    let displayName: String
    let isAuthenticated: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isAuthenticated ? "person.circle.fill" : "person.circle")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(isAuthenticated ? "Signed In" : "Guest User")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Theme Picker Row

struct ThemePickerRow: View {
    @Binding var selectedTheme: Theme
    let onChange: (Theme) -> Void
    
    var body: some View {
        SettingRow(
            title: "Theme",
            icon: "paintbrush.fill",
            description: "Choose your preferred app appearance"
        ) {
            Menu {
                ForEach(Theme.allCases, id: \.self) { theme in
                    Button(action: {
                        selectedTheme = theme
                        onChange(theme)
                    }) {
                        HStack {
                            Image(systemName: theme.icon)
                            Text(theme.displayName)
                            
                            if theme == selectedTheme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedTheme.icon)
                        .font(.caption)
                    Text(selectedTheme.displayName)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Difficulty Picker Row

struct DifficultyPickerRow: View {
    @Binding var selectedDifficulty: Difficulty
    let onChange: (Difficulty) -> Void
    
    var body: some View {
        SettingRow(
            title: "Default Difficulty",
            icon: "speedometer",
            description: "Set your preferred game difficulty"
        ) {
            Menu {
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    Button(action: {
                        selectedDifficulty = difficulty
                        onChange(difficulty)
                    }) {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: difficulty.icon)
                                Text(difficulty.displayName)
                                
                                if difficulty == selectedDifficulty {
                                    Image(systemName: "checkmark")
                                }
                            }
                            
                            Text(difficulty.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: selectedDifficulty.icon)
                        .font(.caption)
                    Text(selectedDifficulty.displayName)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Export Data Sheet

struct ExportDataSheet: View {
    let exportText: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Your settings data has been exported. You can copy this data to backup your settings.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                
                ScrollView {
                    Text(exportText)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
                
                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = exportText
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Import Data Sheet

struct ImportDataSheet: View {
    @Binding var importText: String
    let onImport: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Paste your exported settings data below to restore your settings.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                
                TextEditor(text: $importText)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(minHeight: 200)
                
                Button("Import Settings") {
                    onImport(importText)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(importText.isEmpty ? Color.gray : Color.green)
                .cornerRadius(12)
                .disabled(importText.isEmpty)
            }
            .padding()
            .navigationTitle("Import Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - App Version Footer

struct AppVersionFooter: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Botany Battle")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Made with 🌱 by the Botany Battle Team")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 8) {
                        Text("Botany Battle")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Test your botanical knowledge in exciting plant identification challenges!")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features:")
                            .font(.headline)
                        
                        FeatureRow(icon: "gamecontroller.fill", title: "Multiple Game Modes", description: "Practice, Time Attack, and Speedrun modes")
                        FeatureRow(icon: "person.2.fill", title: "Multiplayer Battles", description: "Challenge friends in real-time")
                        FeatureRow(icon: "trophy.fill", title: "Achievement System", description: "Earn trophies and unlock rewards")
                        FeatureRow(icon: "leaf.fill", title: "Real Plant Data", description: "Powered by iNaturalist API")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    VStack(spacing: 8) {
                        Text("Credits")
                            .font(.headline)
                        
                        Text("Plant data provided by iNaturalist")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Made with ❤️ using SwiftUI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HelpSection(
                        title: "Getting Started",
                        icon: "play.circle.fill",
                        questions: [
                            FAQItem(question: "How do I start playing?", answer: "Choose a game mode from the main screen. Practice mode is great for beginners!"),
                            FAQItem(question: "What are the different game modes?", answer: "Practice (unlimited time), Time Attack (race the clock), Speedrun (identify 25 plants quickly), and Multiplayer (battle other players)."),
                            FAQItem(question: "Do I need an account?", answer: "No! You can play as a guest. Creating an account lets you save progress across devices and play multiplayer.")
                        ]
                    )
                    
                    HelpSection(
                        title: "Gameplay",
                        icon: "gamecontroller.fill",
                        questions: [
                            FAQItem(question: "How do I identify plants?", answer: "Look at the plant image and choose the correct name from four options. The faster you answer correctly, the more points you earn!"),
                            FAQItem(question: "What happens if I get an answer wrong?", answer: "You'll see the correct answer and learn interesting facts about the plant. Use this as a learning opportunity!"),
                            FAQItem(question: "How is my score calculated?", answer: "You earn points for correct answers and speed bonuses for quick responses. Perfect games earn extra trophies!")
                        ]
                    )
                    
                    HelpSection(
                        title: "Trophies & Shop",
                        icon: "trophy.fill",
                        questions: [
                            FAQItem(question: "How do I earn trophies?", answer: "Win games, achieve perfect scores, maintain win streaks, and complete achievements to earn trophies."),
                            FAQItem(question: "What can I buy in the shop?", answer: "Use trophies to purchase themes, avatar frames, badges, and special effects to customize your experience."),
                            FAQItem(question: "Can I get refunds for purchases?", answer: "Shop purchases are final, but you can always earn more trophies by playing games!")
                        ]
                    )
                    
                    HelpSection(
                        title: "Troubleshooting",
                        icon: "wrench.fill",
                        questions: [
                            FAQItem(question: "The app is running slowly", answer: "Try closing other apps, restarting the app, or enabling 'Reduce Animations' in Settings."),
                            FAQItem(question: "Images aren't loading", answer: "Check your internet connection. The app needs internet to load plant images from our database."),
                            FAQItem(question: "I lost my progress", answer: "If you were playing as a guest, progress is stored locally. Sign in with Game Center to save progress across devices.")
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct HelpSection: View {
    let title: String
    let icon: String
    let questions: [FAQItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.green)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 12) {
                ForEach(questions) { item in
                    FAQRow(item: item)
                }
            }
        }
    }
}

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

struct FAQRow: View {
    let item: FAQItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(item.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(item.answer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SettingsView(
            authFeature: MockAuthFeature(),
            userDefaultsService: MockUserDefaultsService()
        )
    }
}