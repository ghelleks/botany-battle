import SwiftUI
import GameKit

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
                
                if isSearching {
                    VStack(spacing: 16) {
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
                
                Spacer()
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
    
    // Sample plant question with actual plant images
    @State private var currentPlant = PlantQuestion(
        imageName: "🌳",
        correctAnswer: "Oak Tree",
        options: ["Oak Tree", "Maple Tree", "Pine Tree", "Birch Tree"],
        fact: "Oak trees can live for over 1,000 years and support over 500 species of wildlife."
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Text("Question \(currentQuestion)/5")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .foregroundColor(.orange)
                            Text("\(timeRemaining)s")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    HStack {
                        Text("Score: \(score)")
                            .font(.title2)
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
                
                // Plant Image
                VStack(spacing: 16) {
                    Text(currentPlant.imageName)
                        .font(.system(size: 120))
                        .frame(height: 150)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                    
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
                                
                                if selectedAnswer == index {
                                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isCorrect ? .green : .red)
                                }
                            }
                            .padding()
                            .background(getAnswerBackgroundColor(index))
                            .cornerRadius(12)
                        }
                        .disabled(selectedAnswer != nil)
                    }
                }
                
                Spacer()
                
                if showResult && !gameComplete {
                    VStack(spacing: 12) {
                        Text(currentPlant.fact)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
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
            }
            .padding()
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
            startTimer()
        }
    }
    
    private func selectAnswer(_ index: Int) {
        selectedAnswer = index
        isCorrect = currentPlant.options[index] == currentPlant.correctAnswer
        
        if isCorrect {
            score += 10
            correctAnswers += 1
        }
        
        showResult = true
        // No auto-advance - user must click "Next Question" button
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
        
        // Generate new question with diverse plant emojis and facts
        let plants = [
            ("🌳", "Oak Tree", ["Oak Tree", "Maple Tree", "Pine Tree", "Birch Tree"], "Oak trees can live for over 1,000 years and support over 500 species of wildlife."),
            ("🌲", "Pine Tree", ["Pine Tree", "Oak Tree", "Willow Tree", "Cedar Tree"], "Pine trees are evergreen conifers that can survive in harsh winter conditions."),
            ("🍁", "Maple Tree", ["Maple Tree", "Elm Tree", "Ash Tree", "Beech Tree"], "Maple trees produce the sweet sap used to make maple syrup."),
            ("🌴", "Palm Tree", ["Palm Tree", "Bamboo", "Fern", "Cactus"], "Palm trees are tropical plants that can grow up to 200 feet tall."),
            ("🌵", "Cactus", ["Cactus", "Succulent", "Aloe", "Agave"], "Cacti store water in their thick stems and can survive without rain for years."),
            ("🌿", "Fern", ["Fern", "Moss", "Lichen", "Ivy"], "Ferns reproduce through spores rather than seeds and love humid environments."),
            ("🌾", "Wheat", ["Wheat", "Rice", "Corn", "Barley"], "Wheat is one of the world's most important cereal grains and food sources."),
            ("🌻", "Sunflower", ["Sunflower", "Daisy", "Marigold", "Zinnia"], "Sunflowers can grow up to 12 feet tall and always face the sun.")
        ]
        let randomPlant = plants.randomElement()!
        currentPlant = PlantQuestion(
            imageName: randomPlant.0,
            correctAnswer: randomPlant.1,
            options: randomPlant.2.shuffled(),
            fact: randomPlant.3
        )
        
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
        
        // Reset to first plant
        currentPlant = PlantQuestion(
            imageName: "🌳",
            correctAnswer: "Oak Tree",
            options: ["Oak Tree", "Maple Tree", "Pine Tree", "Birch Tree"],
            fact: "Oak trees can live for over 1,000 years and support over 500 species of wildlife."
        )
        
        startTimer()
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
        if selectedAnswer == index {
            return isCorrect ? .white : .white
        }
        return .primary
    }
    
    private func getAnswerBackgroundColor(_ index: Int) -> Color {
        if selectedAnswer == index {
            return isCorrect ? .green : .red
        }
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
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Text("🎉")
                        .font(.system(size: 80))
                    
                    Text("Game Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(gameMode.rawValue)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 24) {
                    // Score Section
                    VStack(spacing: 12) {
                        Text("Your Score")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("\(finalScore)")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(performanceColor)
                    }
                    
                    // Performance Section
                    VStack(spacing: 16) {
                        if elapsedTime != nil {
                            // Time Attack mode - show 4 stats in 2x2 grid
                            VStack(spacing: 16) {
                                HStack(spacing: 32) {
                                    VStack {
                                        Text("\(correctAnswers)")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                        Text("Correct")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack {
                                        Text("\(totalQuestions - correctAnswers)")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                        Text("Wrong")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack(spacing: 32) {
                                    VStack {
                                        Text("\(Int(accuracy * 100))%")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(performanceColor)
                                        Text("Accuracy")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack {
                                        Text(formattedTime)
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                        Text("Time")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            // Other modes - show 3 stats in single row
                            HStack(spacing: 32) {
                                VStack {
                                    Text("\(correctAnswers)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                    Text("Correct")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(totalQuestions - correctAnswers)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Text("Wrong")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(Int(accuracy * 100))%")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(performanceColor)
                                    Text("Accuracy")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                        
                    Text(performanceMessage)
                        .font(.title3)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(performanceColor)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Play Again") {
                        onPlayAgain()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                    
                    Button("Back to Menu") {
                        onExit()
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
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