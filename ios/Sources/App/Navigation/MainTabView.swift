import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        TabView(selection: Binding(
            get: { store.currentTab },
            set: { store.send(.tabChanged($0)) }
        )) {
            GameView(store: store.scope(state: \.game, action: \.game))
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text("Game")
                }
                .tag(AppFeature.State.Tab.game)
            
            ProfileView(store: store.scope(state: \.profile, action: \.profile))
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(AppFeature.State.Tab.profile)
            
            ShopView(store: store.scope(state: \.shop, action: \.shop))
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text("Shop")
                }
                .tag(AppFeature.State.Tab.shop)
            
            SettingsView(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(AppFeature.State.Tab.settings)
        }
        .accentColor(.botanicalGreen)
        .onAppear {
            store.send(.onAppear)
        }
        .fullScreenCover(isPresented: .constant(store.tutorial.isPresented)) {
            TutorialView(store: store.scope(state: \.tutorial, action: \.tutorial))
        }
        .sheet(isPresented: .constant(store.help.isPresented)) {
            HelpView(store: store.scope(state: \.help, action: \.help))
        }
    }
}

struct GameView: View {
    let store: StoreOf<GameFeature>
    
    var body: some View {
        NavigationStack {
            Group {
                if store.showModeSelection {
                    GameModeSelectionView(store: store.scope(state: \.modeSelection, action: \.modeSelection))
                } else if store.currentGame == nil && store.singleUserSession == nil {
                    GameMenuView(store: store)
                } else if store.isSearchingForGame {
                    GameSearchingView(store: store)
                } else if let session = store.singleUserSession {
                    SingleUserGameView(store: store, session: session)
                } else if let game = store.currentGame {
                    if game.state == .waiting {
                        GameWaitingView(store: store)
                    } else if game.state == .inProgress {
                        if let round = store.currentRound {
                            GamePlayView(store: store, round: round)
                        } else {
                            GameTransitionView(store: store, game: game)
                        }
                    } else if game.state == .completed {
                        GameResultsView(store: store, game: game)
                    }
                }
            }
            .navigationTitle("Botany Battle")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Game Error", isPresented: .constant(store.error != nil)) {
                Button("OK") {
                    store.send(.clearError)
                }
            } message: {
                Text(store.error ?? "")
            }
        }
    }
}

// MARK: - Game Menu View
struct GameMenuView: View {
    let store: StoreOf<GameFeature>
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Plant Battle Arena")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                Text("Test your botanical knowledge")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                Text("Choose Difficulty")
                    .botanicalStyle(BotanicalTextStyle.headline)
                
                VStack(spacing: 12) {
                    ForEach(Game.Difficulty.allCases, id: \.self) { difficulty in
                        DifficultyButton(
                            title: difficulty.displayName,
                            timeLimit: "\(Int(difficulty.timePerRound))s per round",
                            isSelected: store.selectedDifficulty == difficulty
                        ) {
                            store.send(.searchForGame(difficulty))
                        }
                    }
                }
            }
            
            if !store.gameHistory.isEmpty {
                VStack(spacing: 8) {
                    Text("Recent Games")
                        .botanicalStyle(BotanicalTextStyle.headline)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(store.gameHistory.prefix(3)) { game in
                            GameHistoryCard(game: game)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            store.send(.loadGameHistory)
        }
    }
}

// MARK: - Game Searching View
struct GameSearchingView: View {
    let store: StoreOf<GameFeature>
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.botanicalGreen)
                
                Text("Finding an opponent...")
                    .botanicalStyle(BotanicalTextStyle.title2)
                
                Text("Difficulty: \(store.selectedDifficulty.displayName)")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            BotanicalButton("Cancel", style: .secondary, size: .large) {
                store.send(.leaveGame)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Game Waiting View
struct GameWaitingView: View {
    let store: StoreOf<GameFeature>
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Game Found!")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                
                if let game = store.currentGame {
                    VStack(spacing: 8) {
                        Text("Players:")
                            .botanicalStyle(BotanicalTextStyle.headline)
                        
                        ForEach(game.players) { player in
                            HStack {
                                Image(systemName: player.isReady ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(player.isReady ? .green : .gray)
                                Text(player.username)
                                    .botanicalStyle(BotanicalTextStyle.body)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Text("Game starting soon...")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            BotanicalButton("Leave Game", style: .secondary, size: .large) {
                store.send(.leaveGame)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Game Play View
struct GamePlayView: View {
    let store: StoreOf<GameFeature>
    let round: Round
    @State private var showStats = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Enhanced Game Progress Header
                GameProgressHeader(
                    currentRound: round.roundNumber,
                    totalRounds: store.currentGame?.totalRounds ?? 5,
                    timeRemaining: store.timeRemaining,
                    mode: .multiplayer,
                    difficulty: store.selectedDifficulty,
                    score: store.currentScore,
                    correctAnswers: store.currentGame?.players.first?.correctAnswers,
                    onLeave: { store.send(.leaveGame) }
                )
                
                // Enhanced Plant Image
                PlantImageView(plant: round.plant, mode: .multiplayer)
                    .frame(maxHeight: .infinity)
                
                // Enhanced Answer Options
                AnswerOptionsView(
                    options: round.options,
                    selectedAnswer: store.selectedAnswer,
                    hasAnswered: store.hasAnswered,
                    canAnswer: store.canAnswer,
                    correctAnswer: store.hasAnswered ? round.plant.primaryCommonName : nil,
                    mode: .multiplayer,
                    timeRemaining: store.timeRemaining
                ) { answer in
                    store.send(.submitAnswer(answer))
                }
                .padding()
            }
            .background(Color(.systemBackground))
            
            // Stats overlay
            if showStats {
                GameStatsOverlay(
                    session: nil,
                    game: store.currentGame,
                    mode: .multiplayer,
                    isVisible: showStats
                ) {
                    showStats = false
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showStats = true }) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.botanicalGreen)
                }
            }
        }
    }
}

// MARK: - Game Transition View
struct GameTransitionView: View {
    let store: StoreOf<GameFeature>
    let game: Game
    @State private var showTransition = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("Round \(game.currentRound)")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                    .scaleEffect(showTransition ? 1.2 : 1.0)
                    .opacity(showTransition ? 1.0 : 0.0)
                
                Text("Get ready for the next plant!")
                    .botanicalStyle(BotanicalTextStyle.title2)
                    .opacity(showTransition ? 1.0 : 0.0)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                showTransition = true
            }
        }
    }
}

// MARK: - Game Results View
struct GameResultsView: View {
    let store: StoreOf<GameFeature>
    let game: Game
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Victory/Defeat Header
                ResultsHeaderView(game: game)
                
                // Score Summary
                ScoreSummaryView(game: game)
                
                // Round by Round Results
                RoundResultsView(game: game)
                
                // Action Buttons
                VStack(spacing: 12) {
                    BotanicalButton("Play Again", style: .primary, size: .large) {
                        store.send(.searchForGame(game.difficulty))
                    }
                    
                    BotanicalButton("Return to Menu", style: .secondary, size: .large) {
                        store.send(.leaveGame)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

struct ProfileView: View {
    let store: StoreOf<ProfileFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Profile View")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                Text("Your stats and achievements")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                
                Spacer()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            store.send(.loadProfile)
        }
    }
}

struct ShopView: View {
    let store: StoreOf<ShopFeature>
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Shop View")
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                Text("Power-ups and customizations")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                
                Spacer()
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            store.send(.loadShopItems)
        }
    }
}

struct SettingsView: View {
    let store: StoreOf<SettingsFeature>
    
    var body: some View {
        NavigationStack {
            List {
                Section("Audio") {
                    Toggle("Sound Effects", isOn: .init(
                        get: { store.soundEnabled },
                        set: { _ in store.send(.toggleSound) }
                    ))
                    
                    Toggle("Music", isOn: .init(
                        get: { store.musicEnabled },
                        set: { _ in store.send(.toggleMusic) }
                    ))
                }
                
                Section("Gameplay") {
                    Toggle("Haptic Feedback", isOn: .init(
                        get: { store.hapticFeedbackEnabled },
                        set: { _ in store.send(.toggleHapticFeedback) }
                    ))
                    
                    Toggle("Auto-play Next Round", isOn: .init(
                        get: { store.autoplayEnabled },
                        set: { _ in store.send(.toggleAutoplay) }
                    ))
                    
                    Picker("Default Difficulty", selection: .init(
                        get: { store.difficulty },
                        set: { store.send(.setDifficulty($0)) }
                    )) {
                        ForEach(Game.Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                }
                
                Section("Appearance") {
                    Picker("Theme", selection: .init(
                        get: { store.theme },
                        set: { store.send(.setTheme($0)) }
                    )) {
                        ForEach(SettingsFeature.State.Theme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                }
                
                Section("Notifications") {
                    Toggle("Push Notifications", isOn: .init(
                        get: { store.notificationsEnabled },
                        set: { _ in store.send(.toggleNotifications) }
                    ))
                }
                
                Section("Language") {
                    Picker("Language", selection: .init(
                        get: { store.language },
                        set: { store.send(.setLanguage($0)) }
                    )) {
                        ForEach(SettingsFeature.State.Language.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }
                
                Section("Help & Support") {
                    Button("Help & FAQ") {
                        // This would need to be handled via the parent store
                        // For now, just a placeholder
                    }
                    .foregroundColor(.botanicalGreen)
                    
                    Button("Restart Tutorial") {
                        // This would need to be handled via the parent store
                        // For now, just reset tutorial status
                    }
                    .foregroundColor(.botanicalGreen)
                    
                    Button("Contact Support") {
                        // This would open email or support form
                    }
                    .foregroundColor(.botanicalGreen)
                }
                
                Section("Data") {
                    Button("Export My Data") {
                        store.send(.exportData)
                    }
                    .foregroundColor(.botanicalGreen)
                    
                    Button("Reset to Defaults") {
                        store.send(.resetToDefaults)
                    }
                    .foregroundColor(.orange)
                }
                
                Section("Account") {
                    Button("Delete Account") {
                        store.send(.deleteAccount)
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Help") {
                        // This would need to be handled via the parent store
                        // For now, just a placeholder
                    }
                    .foregroundColor(.botanicalGreen)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .alert("Settings Error", isPresented: .constant(store.error != nil)) {
                Button("OK") {
                    store.send(.clearError)
                }
            } message: {
                Text(store.error ?? "")
            }
        }
    }
}

#Preview {
    MainTabView(
        store: Store(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
    )
}