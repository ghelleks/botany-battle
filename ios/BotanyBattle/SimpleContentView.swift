import SwiftUI

// Simple demo version without external dependencies
struct SimpleContentView: View {
    @State private var isAuthenticated = false
    @State private var currentTab = 0
    @State private var showTutorial = true
    
    var body: some View {
        Group {
            if showTutorial {
                SimpleTutorialView(showTutorial: $showTutorial)
            } else if isAuthenticated {
                SimpleMainTabView(currentTab: $currentTab)
            } else {
                SimpleAuthView(isAuthenticated: $isAuthenticated)
            }
        }
    }
}

struct SimpleAuthView: View {
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        NavigationView {
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
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button("Sign In with Apple") {
                        withAnimation {
                            isAuthenticated = true
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
                    
                    Button("Continue as Guest") {
                        withAnimation {
                            isAuthenticated = true
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Welcome")
            .navigationBarHidden(true)
        }
    }
}

struct SimpleMainTabView: View {
    @Binding var currentTab: Int
    
    var body: some View {
        TabView(selection: $currentTab) {
            SimpleGameView()
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text("Game")
                }
                .tag(0)
            
            SimpleProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(1)
            
            SimpleShopView()
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text("Shop")
                }
                .tag(2)
            
            SimpleSettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.green)
    }
}

struct SimpleGameView: View {
    @State private var isSearching = false
    @State private var difficulty = "Medium"
    
    let difficulties = ["Easy", "Medium", "Hard", "Expert"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Plant Battle Arena")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Test your botanical knowledge")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 16) {
                    Text("Choose Difficulty")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        ForEach(difficulties, id: \.self) { diff in
                            Button(action: {
                                difficulty = diff
                                isSearching = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    isSearching = false
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(diff)
                                            .font(.headline)
                                            .foregroundColor(difficulty == diff ? .white : .primary)
                                        
                                        Text(timeForDifficulty(diff))
                                            .font(.caption)
                                            .foregroundColor(difficulty == diff ? .white.opacity(0.8) : .secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if difficulty == diff {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(difficulty == diff ? Color.green : Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                if isSearching {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.green)
                        
                        Text("Finding an opponent...")
                            .font(.title2)
                        
                        Button("Cancel") {
                            isSearching = false
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Botany Battle")
        }
    }
    
    private func timeForDifficulty(_ diff: String) -> String {
        switch diff {
        case "Easy": return "30s per round"
        case "Medium": return "20s per round"
        case "Hard": return "15s per round"
        case "Expert": return "10s per round"
        default: return "20s per round"
        }
    }
}

struct SimpleProfileView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("PlantLover42")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Rank: Expert Botanist")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 16) {
                        HStack {
                            VStack {
                                Text("156")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Text("Wins")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("23")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                Text("Losses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("1,247")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                                Text("Trophies")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Achievements")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            AchievementRow(title: "Plant Expert", description: "Won 100 games", icon: "trophy.fill")
                            AchievementRow(title: "Speed Demon", description: "Answer in under 5 seconds", icon: "timer")
                            AchievementRow(title: "Streak Master", description: "10 win streak", icon: "flame.fill")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
}

struct AchievementRow: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SimpleShopView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(shopItems, id: \.id) { item in
                        ShopItemCard(item: item)
                    }
                }
                .padding()
            }
            .navigationTitle("Shop")
        }
    }
    
    private var shopItems: [ShopItem] {
        [
            ShopItem(id: 1, name: "Forest Theme", price: 100, icon: "tree.fill", owned: false),
            ShopItem(id: 2, name: "Desert Theme", price: 150, icon: "sun.max.fill", owned: true),
            ShopItem(id: 3, name: "Rainbow Avatar", price: 200, icon: "rainbow", owned: false),
            ShopItem(id: 4, name: "Golden Frame", price: 300, icon: "star.fill", owned: false),
            ShopItem(id: 5, name: "Expert Badge", price: 500, icon: "crown.fill", owned: false),
            ShopItem(id: 6, name: "Victory Dance", price: 250, icon: "figure.dancing", owned: false)
        ]
    }
}

struct ShopItem {
    let id: Int
    let name: String
    let price: Int
    let icon: String
    let owned: Bool
}

struct ShopItemCard: View {
    let item: ShopItem
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            if item.owned {
                Text("OWNED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            } else {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.orange)
                    Text("\(item.price)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct SimpleSettingsView: View {
    @State private var soundEnabled = true
    @State private var musicEnabled = true
    @State private var notifications = true
    @State private var hapticFeedback = true
    @State private var selectedDifficulty = "Medium"
    @State private var selectedTheme = "System"
    
    var body: some View {
        NavigationView {
            List {
                Section("Audio") {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                    Toggle("Music", isOn: $musicEnabled)
                }
                
                Section("Gameplay") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                    
                    Picker("Default Difficulty", selection: $selectedDifficulty) {
                        Text("Easy").tag("Easy")
                        Text("Medium").tag("Medium")
                        Text("Hard").tag("Hard")
                        Text("Expert").tag("Expert")
                    }
                }
                
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                        Text("System").tag("System")
                    }
                }
                
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notifications)
                }
                
                Section("Help & Support") {
                    Button("Help & FAQ") {
                        // Help action
                    }
                    .foregroundColor(.green)
                    
                    Button("Restart Tutorial") {
                        // Tutorial action
                    }
                    .foregroundColor(.green)
                    
                    Button("Contact Support") {
                        // Support action
                    }
                    .foregroundColor(.green)
                }
                
                Section("Account") {
                    Button("Export My Data") {
                        // Export action
                    }
                    .foregroundColor(.green)
                    
                    Button("Reset to Defaults") {
                        // Reset action
                    }
                    .foregroundColor(.orange)
                    
                    Button("Delete Account") {
                        // Delete action
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SimpleTutorialView: View {
    @Binding var showTutorial: Bool
    @State private var currentStep = 0
    
    private let tutorialSteps = [
        TutorialStep(title: "Welcome to Botany Battle!", description: "Test your botanical knowledge in head-to-head battles!", icon: "leaf.fill"),
        TutorialStep(title: "How to Play", description: "Each battle has 5 rounds. Identify plants from 4 options.", icon: "gamecontroller.fill"),
        TutorialStep(title: "Choose Your Challenge", description: "Pick from Easy (30s) to Expert (10s) difficulty levels.", icon: "speedometer"),
        TutorialStep(title: "During the Game", description: "Answer quickly and correctly to win rounds!", icon: "timer"),
        TutorialStep(title: "Ready to Battle!", description: "You're all set! Time to test your plant knowledge.", icon: "checkmark.circle.fill")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("Tutorial")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(currentStep + 1) of \(tutorialSteps.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(currentStep), total: Double(tutorialSteps.count - 1))
                    .tint(.green)
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)
                    
                    Image(systemName: tutorialSteps[currentStep].icon)
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 16) {
                        Text(tutorialSteps[currentStep].title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(tutorialSteps[currentStep].description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 32)
            }
            
            // Navigation
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Previous") {
                            currentStep -= 1
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                    
                    if currentStep < tutorialSteps.count - 1 {
                        Button("Next") {
                            currentStep += 1
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    } else {
                        Button("Start Playing!") {
                            showTutorial = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                if currentStep < tutorialSteps.count - 1 {
                    Button("Skip Tutorial") {
                        showTutorial = false
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

struct TutorialStep {
    let title: String
    let description: String
    let icon: String
}

#Preview {
    SimpleContentView()
}