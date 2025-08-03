import SwiftUI
import GameKit

// Simple iNaturalist API service
struct SimplePlantAPIService {
    static func generateInterestingFact(for plantName: String, scientificName: String) -> String {
        // General plant facts
        let generalFacts = [
            "This plant can photosynthesize sunlight into energy through its leaves.",
            "Like all plants, this species produces oxygen as a byproduct of photosynthesis.",
            "This plant species has adapted to survive in various environmental conditions.",
            "The leaves of this plant contain chlorophyll, giving them their green color.",
            "This species can reproduce both sexually through seeds and asexually through vegetative propagation."
        ]
        
        // Specific plant facts based on common names
        let specificFacts: [String: String] = [
            "ivy": "Ivy plants are excellent climbers and can attach to surfaces using aerial rootlets.",
            "oak": "Oak trees can live for hundreds of years and support over 500 species of wildlife.",
            "maple": "Maple trees are famous for their brilliant fall colors and sweet sap used to make syrup.",
            "rose": "Roses have been cultivated for over 5,000 years and come in thousands of varieties.",
            "fern": "Ferns are among the oldest plant groups on Earth, reproducing through spores instead of seeds.",
            "moss": "Mosses are non-vascular plants that absorb water and nutrients directly through their leaves.",
            "grass": "Grasses are monocots with parallel leaf veins and can regrow from their base when cut.",
            "pine": "Pine trees are conifers that produce cones and keep their needle-like leaves year-round.",
            "willow": "Willow bark contains salicin, which was used historically as a pain reliever.",
            "mint": "Mint plants contain menthol oils that give them their characteristic cooling sensation.",
            "sage": "Sage has been used for centuries in both culinary and medicinal applications.",
            "lavender": "Lavender is known for its calming fragrance and is often used in aromatherapy.",
            "daisy": "Daisies are composite flowers, meaning what looks like one flower is actually many tiny flowers.",
            "sunflower": "Sunflowers can grow up to 12 feet tall and their heads follow the sun across the sky.",
            "violet": "Violets are edible flowers often used to decorate cakes and salads.",
            "thistle": "Thistles have spiny leaves as protection but produce nectar that attracts butterflies and bees.",
            "clover": "Clover plants fix nitrogen in the soil, making it more fertile for other plants.",
            "dandelion": "Every part of a dandelion is edible, from the flowers to the roots.",
            "mustard": "Mustard plants belong to the same family as broccoli, cabbage, and kale.",
            "plantain": "Plantain leaves have natural antibiotic properties and were called 'nature's bandage' by early settlers.",
            "yarrow": "Yarrow has been used medicinally for thousands of years to help heal wounds and reduce inflammation.",
            "nettle": "Stinging nettles are rich in vitamins and minerals and can be cooked like spinach when young."
        ]
        
        // Check if plant name contains any of our specific keywords
        let lowerName = plantName.lowercased()
        for (keyword, specificFact) in specificFacts {
            if lowerName.contains(keyword) {
                return specificFact
            }
        }
        
        // Return a random general fact if no specific match found
        return generalFacts.randomElement() ?? generalFacts[0]
    }
    
    static func fetchPlants() async -> [PlantData] {
        guard let url = URL(string: "https://api.inaturalist.org/v1/taxa?taxon_id=47126&rank=species&per_page=20&order_by=observations_count&order=desc&photos=true&min_observations=1000") else {
            print("❌ Invalid URL")
            return []
        }
        
        do {
            print("🌐 Fetching plants from iNaturalist API...")
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(iNaturalistResponse.self, from: data)
            
            let plants = response.results.compactMap { taxon -> PlantData? in
                guard let photo = taxon.default_photo?.medium_url,
                      let name = taxon.preferred_common_name ?? taxon.name.split(separator: " ").last.map(String.init) else {
                    return nil
                }
                
                return PlantData(
                    name: name,
                    scientificName: taxon.name,
                    imageURL: photo,
                    description: generateInterestingFact(for: name, scientificName: taxon.name)
                )
            }
            
            print("✅ Successfully fetched \(plants.count) real plants from iNaturalist!")
            return plants
        } catch {
            print("❌ Error fetching plants: \(error)")
            return []
        }
    }
}

// Data structures for iNaturalist API
struct iNaturalistResponse: Codable {
    let results: [Taxon]
}

struct Taxon: Codable {
    let name: String
    let preferred_common_name: String?
    let observations_count: Int
    let default_photo: Photo?
}

struct Photo: Codable {
    let medium_url: String
}

struct PlantData {
    let name: String
    let scientificName: String
    let imageURL: String
    let description: String
}

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
    @State private var selectedGameMode: GameMode?
    @State private var difficulty = "Medium"
    @State private var isSearching = false
    @State private var showGameCenterPrompt = false
    @State private var showGameScreen = false
    @State private var currentGameMode: GameMode?
    
    let difficulties = ["Easy", "Medium", "Hard", "Expert"]
    
    enum GameMode: String, CaseIterable {
        case practice = "Practice Mode"
        case timeAttack = "Time Attack"
        case dailyChallenge = "Daily Challenge"
        case multiplayer = "Multiplayer Battle"
        
        var description: String {
            switch self {
            case .practice:
                return "Learn at your own pace with unlimited time"
            case .timeAttack:
                return "Race against the clock to identify plants"
            case .dailyChallenge:
                return "Complete today's special challenge"
            case .multiplayer:
                return "Battle other players in real-time"
            }
        }
        
        var icon: String {
            switch self {
            case .practice:
                return "book.fill"
            case .timeAttack:
                return "timer"
            case .dailyChallenge:
                return "calendar.badge.plus"
            case .multiplayer:
                return "person.2.fill"
            }
        }
        
        var requiresGameCenter: Bool {
            return self == .multiplayer
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Plant Battle Arena")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Choose your adventure")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Game Mode Selection
                VStack(spacing: 16) {
                    Text("Game Mode")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        ForEach(GameMode.allCases, id: \.self) { mode in
                            Button(action: {
                                selectGameMode(mode)
                            }) {
                                HStack {
                                    Image(systemName: mode.icon)
                                        .font(.title2)
                                        .foregroundColor(.green)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mode.rawValue)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(mode.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if mode.requiresGameCenter {
                                        Image(systemName: "gamecontroller.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
                
                // Fixed height container to prevent jumping
                VStack(spacing: 16) {
                    if isSearching {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.green)
                        
                        Text("Starting game...")
                            .font(.title2)
                        
                        Button("Cancel") {
                            isSearching = false
                        }
                        .foregroundColor(.red)
                    }
                }
                .frame(minHeight: 120) // Reserve space to prevent jumping
            }
            .padding()
            .navigationTitle("Botany Battle")
            .sheet(isPresented: $showGameCenterPrompt) {
                GameCenterPromptView(onConnect: connectToGameCenter, onCancel: {
                    showGameCenterPrompt = false
                })
            }
            .fullScreenCover(isPresented: $showGameScreen) {
                if let gameMode = currentGameMode {
                    GameScreenView(gameMode: gameMode, onExit: {
                        showGameScreen = false
                        currentGameMode = nil
                    })
                }
            }
        }
    }
    
    private func selectGameMode(_ mode: GameMode) {
        selectedGameMode = mode
        
        if mode.requiresGameCenter {
            // Check if Game Center is already authenticated
            if GKLocalPlayer.local.isAuthenticated {
                startMultiplayerGame()
            } else {
                showGameCenterPrompt = true
            }
        } else {
            startSinglePlayerGame(mode: mode)
        }
    }
    
    private func startSinglePlayerGame(mode: GameMode) {
        isSearching = true
        currentGameMode = mode
        // Simulate game start delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            showGameScreen = true
        }
    }
    
    private func startMultiplayerGame() {
        isSearching = true
        // Simulate finding opponent
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isSearching = false
            // Here you would start matchmaking and navigate to multiplayer game
            print("Starting multiplayer game")
        }
    }
    
    private func connectToGameCenter() {
        showGameCenterPrompt = false
        
        // Attempt Game Center authentication
        GKLocalPlayer.local.authenticateHandler = { viewController, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Game Center authentication failed: \(error.localizedDescription)")
                    return
                }
                
                if let viewController = viewController {
                    // In a real app, present the view controller
                    print("Present Game Center authentication view controller")
                    return
                }
                
                if GKLocalPlayer.local.isAuthenticated {
                    startMultiplayerGame()
                } else {
                    print("Game Center authentication failed")
                }
            }
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
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private let tutorialSteps = [
        TutorialStep(title: "Welcome to Botany Battle!", description: "Test your botanical knowledge in head-to-head battles!", icon: "leaf.fill"),
        TutorialStep(title: "How to Play", description: "Each battle has 5 rounds. Identify plants from 4 options.", icon: "gamecontroller.fill"),
        TutorialStep(title: "Choose Your Challenge", description: "Pick from Easy (30s) to Expert (10s) difficulty levels.", icon: "speedometer"),
        TutorialStep(title: "During the Game", description: "Answer quickly and correctly to win rounds!", icon: "timer"),
        TutorialStep(title: "Ready to Battle!", description: "You're all set! Time to test your plant knowledge.", icon: "checkmark.circle.fill")
    ]
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        
        VStack(spacing: 0) {
            // Progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("Tutorial")
                        .font(isLandscape ? .subheadline : .headline)
                    
                    Spacer()
                    
                    Text("\(currentStep + 1) of \(tutorialSteps.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: Double(currentStep), total: Double(tutorialSteps.count - 1))
                    .tint(.green)
            }
            .padding(isLandscape ? 12 : 16)
            .background(Color(.systemGray6))
            
            // Content
            if isLandscape {
                // Landscape Layout: Side-by-side
                HStack(spacing: 32) {
                    // Left side: Icon
                    Image(systemName: tutorialSteps[currentStep].icon)
                        .font(.system(size: isLandscape ? 50 : 60))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity)
                    
                    // Right side: Text content
                    VStack(spacing: 16) {
                        Text(tutorialSteps[currentStep].title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.leading)
                        
                        Text(tutorialSteps[currentStep].description)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Portrait Layout: Original vertical layout
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
            }
            
            // Navigation
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Previous") {
                            currentStep -= 1
                        }
                        .frame(maxWidth: .infinity)
                        .padding(isLandscape ? 12 : 16)
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
                        .padding(isLandscape ? 12 : 16)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    } else {
                        Button("Start Playing!") {
                            showTutorial = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding(isLandscape ? 12 : 16)
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
            .padding(isLandscape ? 12 : 16)
        }
    }
}

struct GameCenterPromptView: View {
    let onConnect: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Game Center Required")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Multiplayer battles require Game Center to connect with other players. You can enjoy single-player modes without Game Center.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 12) {
                    Button("Connect to Game Center") {
                        onConnect()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                    
                    Button("Try Single-Player Instead") {
                        onCancel()
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
            .padding()
            .navigationTitle("Multiplayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

struct GameScreenView: View {
    let gameMode: SimpleGameView.GameMode
    let onExit: () -> Void
    
    @State private var currentQuestion = 1
    @State private var score = 0
    @State private var timeRemaining = 30
    @State private var selectedAnswer: Int?
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var gameComplete = false
    @State private var correctAnswers = 0
    @State private var gameStartTime = Date()
    @State private var gameEndTime = Date()
    @State private var isLoadingPlants = true
    @State private var availablePlants: [PlantData] = []
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    // Sample plant question - will be replaced with real data
    @State private var currentPlant = PlantQuestion(
        imageName: "🌱",
        correctAnswer: "Loading...",
        options: ["Loading...", "Please wait...", "Fetching plants...", "Almost ready..."],
        fact: "Loading real plant data from iNaturalist..."
    )
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        
        NavigationView {
            VStack(spacing: isLandscape ? 8 : 24) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Text("Question \(currentQuestion)/5")
                            .font(isLandscape ? .subheadline : .headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .foregroundColor(.orange)
                            Text("\(timeRemaining)s")
                                .font(isLandscape ? .subheadline : .headline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    HStack {
                        Text("Score: \(score)")
                            .font(isLandscape ? .headline : .title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(gameMode.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(isLandscape ? 12 : 16)
                
                if isLandscape {
                    // Landscape Layout: Image left, controls right
                    HStack(spacing: 16) {
                        // Left side: Plant Image (60% width)
                        VStack(spacing: 8) {
                            if isLoadingPlants {
                                ProgressView("Loading plants...")
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            } else if currentPlant.imageName.hasPrefix("http") {
                                AsyncImage(url: URL(string: currentPlant.imageName)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .frame(height: 120)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .clipped()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green, lineWidth: 2)
                                )
                            } else {
                                Text(currentPlant.imageName)
                                    .font(.system(size: 80))
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                            }
                            
                            Text("What plant is this?")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right side: Answer Options (40% width)
                        VStack(spacing: 8) {
                            ForEach(Array(currentPlant.options.enumerated()), id: \.offset) { index, option in
                                Button(action: {
                                    selectAnswer(index)
                                }) {
                                    HStack {
                                        Text(option)
                                            .font(.subheadline)
                                            .foregroundColor(getAnswerTextColor(index))
                                            .lineLimit(2)
                                        
                                        Spacer()
                                        
                                        if selectedAnswer != nil {
                                            if isCorrectAnswer(index) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.white)
                                            } else if selectedAnswer == index && !isCorrect {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(getAnswerBackgroundColor(index))
                                    .cornerRadius(8)
                                }
                                .disabled(selectedAnswer != nil)
                            }
                            
                            // Compact feedback in landscape
                            if selectedAnswer != nil {
                                VStack(spacing: 4) {
                                    HStack {
                                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(isCorrect ? .green : .red)
                                        
                                        Text(isCorrect ? "Correct!" : "Incorrect")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(isCorrect ? .green : .red)
                                        
                                        Spacer()
                                    }
                                    
                                    if !isCorrect {
                                        HStack {
                                            Text("Answer: \(currentPlant.correctAnswer)")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }
                            
                            if showResult && !gameComplete {
                                Button("Next Question") {
                                    nextQuestion()
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                } else {
                    // Portrait Layout: Original vertical layout
                    VStack(spacing: 16) {
                        // Plant Image
                        VStack(spacing: 16) {
                            if isLoadingPlants {
                                ProgressView("Loading plants...")
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            } else if currentPlant.imageName.hasPrefix("http") {
                                AsyncImage(url: URL(string: currentPlant.imageName)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .clipped()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green, lineWidth: 2)
                                )
                            } else {
                                Text(currentPlant.imageName)
                                    .font(.system(size: 120))
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                            }
                            
                            Text("What plant is this?")
                                .font(.title2)
                                .fontWeight(.medium)
                        }
                        
                        // Answer Options
                        VStack(spacing: 12) {
                            ForEach(Array(currentPlant.options.enumerated()), id: \.offset) { index, option in
                                Button(action: {
                                    selectAnswer(index)
                                }) {
                                    HStack {
                                        Text(option)
                                            .font(.headline)
                                            .foregroundColor(getAnswerTextColor(index))
                                        
                                        Spacer()
                                        
                                        if selectedAnswer != nil {
                                            if isCorrectAnswer(index) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.white)
                                            } else if selectedAnswer == index && !isCorrect {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(getAnswerBackgroundColor(index))
                                    .cornerRadius(12)
                                }
                                .disabled(selectedAnswer != nil)
                            }
                        }
                        
                        // Feedback Box
                        if selectedAnswer != nil {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isCorrect ? .green : .red)
                                    
                                    Text(isCorrect ? "Correct!" : "Incorrect")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(isCorrect ? .green : .red)
                                    
                                    Spacer()
                                }
                                
                                if !isCorrect {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        
                                        Text("Correct answer:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(currentPlant.correctAnswer)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                    }
                                }
                                
                                if !currentPlant.fact.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        Text(currentPlant.fact)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(nil)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .frame(height: 80)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        if showResult && !gameComplete {
                            Button("Next Question") {
                                nextQuestion()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Plant Battle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") {
                        onExit()
                    }
                    .foregroundColor(.red)
                }
            }
            .fullScreenCover(isPresented: $gameComplete) {
                GameResultsView(
                    gameMode: gameMode,
                    finalScore: score,
                    correctAnswers: correctAnswers,
                    totalQuestions: 5,
                    elapsedTime: gameEndTime.timeIntervalSince(gameStartTime),
                    onPlayAgain: {
                        resetGame()
                    },
                    onExit: onExit
                )
            }
        }
        .onAppear {
            gameStartTime = Date()
            loadPlantsAndStartGame()
        }
    }
    
    private func isCorrectAnswer(_ index: Int) -> Bool {
        let selectedOption = currentPlant.options[index].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let correctAnswer = currentPlant.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return selectedOption == correctAnswer
    }
    
    private func selectAnswer(_ index: Int) {
        selectedAnswer = index
        isCorrect = isCorrectAnswer(index)
        
        if isCorrect {
            score += 10
            correctAnswers += 1
        }
        
        showResult = true
    }
    
    private func loadPlantsAndStartGame() {
        Task {
            let plants = await SimplePlantAPIService.fetchPlants()
            await MainActor.run {
                self.availablePlants = plants
                self.isLoadingPlants = false
                
                if !plants.isEmpty {
                    generateNewQuestion()
                    startTimer()
                } else {
                    // Show error if API fails - no fallback data
                    print("❌ API failed - no plants available")
                    currentPlant = PlantQuestion(
                        imageName: "⚠️",
                        correctAnswer: "Error",
                        options: ["Error loading plants", "Check internet connection", "Try again later", "API unavailable"],
                        fact: "Unable to load plants from iNaturalist API. Please check your internet connection and try again."
                    )
                }
            }
        }
    }
    
    private func generateNewQuestion() {
        guard availablePlants.count >= 4 else { return }
        
        // Pick a random correct plant
        let correctPlant = availablePlants.randomElement()!
        
        // Pick 3 random wrong answers
        var wrongOptions = availablePlants.filter { $0.name != correctPlant.name }.shuffled().prefix(3).map { $0.name }
        wrongOptions.append(correctPlant.name)
        
        currentPlant = PlantQuestion(
            imageName: correctPlant.imageURL,
            correctAnswer: correctPlant.name,
            options: Array(wrongOptions.shuffled()),
            fact: correctPlant.description
        )
    }
    
    private func nextQuestion() {
        if currentQuestion >= 5 {
            // Game over - show results
            gameEndTime = Date()
            gameComplete = true
            return
        }
        
        currentQuestion += 1
        selectedAnswer = nil
        showResult = false
        timeRemaining = getTimeForGameMode()
        
        generateNewQuestion()
        startTimer()
    }
    
    private func resetGame() {
        currentQuestion = 1
        score = 0
        correctAnswers = 0
        selectedAnswer = nil
        showResult = false
        gameComplete = false
        gameStartTime = Date()
        gameEndTime = Date()
        isLoadingPlants = true
        
        // Reset to loading state and reload plants from API
        currentPlant = PlantQuestion(
            imageName: "🌱",
            correctAnswer: "Loading...",
            options: ["Loading...", "Please wait...", "Fetching plants...", "Almost ready..."],
            fact: "Loading real plant data from iNaturalist..."
        )
        
        // Reload plants from API
        loadPlantsAndStartGame()
    }
    
    private func startTimer() {
        timeRemaining = getTimeForGameMode()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 && selectedAnswer == nil {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                if selectedAnswer == nil {
                    // Time's up
                    nextQuestion()
                }
            }
        }
    }
    
    private func getTimeForGameMode() -> Int {
        switch gameMode {
        case .practice: return 60 // Unlimited time for practice
        case .timeAttack: return 15
        case .dailyChallenge: return 30
        case .multiplayer: return 20
        }
    }
    
    private func getAnswerTextColor(_ index: Int) -> Color {
        // If an answer has been selected, adjust text colors for readability
        if selectedAnswer != nil {
            // White text on green background for correct answer
            if isCorrectAnswer(index) {
                return .white
            }
            // White text on red background for selected wrong answer
            else if selectedAnswer == index && !isCorrect {
                return .white
            }
            // Darker text for grayed out options
            else {
                return .secondary
            }
        }
        // Default text color before answer selection
        return .primary
    }
    
    private func getAnswerBackgroundColor(_ index: Int) -> Color {
        // If an answer has been selected, show feedback
        if selectedAnswer != nil {
            // Highlight the correct answer in green
            if isCorrectAnswer(index) {
                return .green
            }
            // Show selected wrong answer in red
            else if selectedAnswer == index && !isCorrect {
                return .red
            }
            // Gray out other options
            else {
                return Color(.systemGray5)
            }
        }
        // Default state before answer selection
        return Color(.systemGray6)
    }
}

struct GameResultsView: View {
    let gameMode: SimpleGameView.GameMode
    let finalScore: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let elapsedTime: TimeInterval?
    let onPlayAgain: () -> Void
    let onExit: () -> Void
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var accuracy: Double {
        return Double(correctAnswers) / Double(totalQuestions)
    }
    
    private var performanceMessage: String {
        switch accuracy {
        case 1.0: return "Perfect! You're a true botanist! 🌟"
        case 0.8...0.99: return "Excellent work! You know your plants! 🌿"
        case 0.6...0.79: return "Good job! Keep learning about plants! 🌱"
        case 0.4...0.59: return "Not bad! Practice makes perfect! 🌳"
        default: return "Keep trying! Every expert was once a beginner! 🌿"
        }
    }
    
    private var performanceColor: Color {
        switch accuracy {
        case 0.8...1.0: return .green
        case 0.6...0.79: return .orange
        default: return .red
        }
    }
    
    private var formattedTime: String {
        guard let elapsedTime = elapsedTime else { return "" }
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        
        NavigationView {
            ScrollView {
                VStack(spacing: isLandscape ? 8 : 16) {
                    Spacer(minLength: isLandscape ? 10 : 20)
                    
                    if isLandscape {
                    // Landscape Layout: Compact horizontal layout
                    HStack(spacing: 24) {
                        // Left side: Header and Score
                        VStack(spacing: 8) {
                            Text("🎉")
                                .font(.system(size: 32))
                            
                            Text("Game Complete!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(gameMode.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Your Score")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            
                            Text("\(finalScore)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(performanceColor)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Right side: Stats and Message
                        VStack(spacing: 12) {
                            // Stats
                            if elapsedTime != nil {
                                // Time Attack mode - compact 2x2 grid
                                VStack(spacing: 8) {
                                    HStack(spacing: 12) {
                                        VStack(spacing: 2) {
                                            Text("\(correctAnswers)")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                            Text("Correct")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack(spacing: 2) {
                                            Text("\(totalQuestions - correctAnswers)")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.red)
                                            Text("Wrong")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HStack(spacing: 12) {
                                        VStack(spacing: 2) {
                                            Text("\(Int(accuracy * 100))%")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(performanceColor)
                                            Text("Accuracy")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack(spacing: 2) {
                                            Text(formattedTime)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                            Text("Time")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            } else {
                                // Other modes - horizontal stats
                                HStack(spacing: 16) {
                                    VStack(spacing: 2) {
                                        Text("\(correctAnswers)")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                        Text("Correct")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Text("\(totalQuestions - correctAnswers)")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                        Text("Wrong")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Text("\(Int(accuracy * 100))%")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(performanceColor)
                                        Text("Accuracy")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Text(performanceMessage)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .foregroundColor(performanceColor)
                                .padding(.top, 4)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // Portrait Layout: Compact vertical layout
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Text("🎉")
                                .font(.system(size: 50))
                            
                            Text("Game Complete!")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text(gameMode.rawValue)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Score
                        VStack(spacing: 8) {
                            Text("Your Score")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("\(finalScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(performanceColor)
                        }
                        
                        // Stats
                        VStack(spacing: 12) {
                            if elapsedTime != nil {
                                // Time Attack mode - 2x2 grid
                                VStack(spacing: 12) {
                                    HStack(spacing: 24) {
                                        VStack(spacing: 4) {
                                            Text("\(correctAnswers)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                            Text("Correct")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack(spacing: 4) {
                                            Text("\(totalQuestions - correctAnswers)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.red)
                                            Text("Wrong")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HStack(spacing: 24) {
                                        VStack(spacing: 4) {
                                            Text("\(Int(accuracy * 100))%")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(performanceColor)
                                            Text("Accuracy")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack(spacing: 4) {
                                            Text(formattedTime)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                            Text("Time")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            } else {
                                // Other modes - horizontal stats
                                HStack(spacing: 24) {
                                    VStack(spacing: 4) {
                                        Text("\(correctAnswers)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                        Text("Correct")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("\(totalQuestions - correctAnswers)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                        Text("Wrong")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("\(Int(accuracy * 100))%")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(performanceColor)
                                        Text("Accuracy")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        Text(performanceMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundColor(performanceColor)
                            .padding(.horizontal, 20)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: isLandscape ? 10 : 20)
                
                // Action Buttons
                VStack(spacing: 10) {
                    Button("Play Again") {
                        onPlayAgain()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(isLandscape ? 10 : 14)
                    .background(Color.green)
                    .cornerRadius(12)
                    
                    Button("Back to Menu") {
                        onExit()
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(isLandscape ? 10 : 14)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, isLandscape ? 10 : 20)
                }
                .padding(isLandscape ? 12 : 16)
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}

struct PlantQuestion {
    let imageName: String
    let correctAnswer: String
    let options: [String]
    let fact: String
}

struct TutorialStep {
    let title: String
    let description: String
    let icon: String
}

#Preview {
    SimpleContentView()
}