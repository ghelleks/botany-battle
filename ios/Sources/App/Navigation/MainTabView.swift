import SwiftUI
import ComposableArchitecture

struct MainTabView: View {
    @Bindable var store: StoreOf<AppFeature>
    
    var body: some View {
        TabView(selection: Binding(
            get: { store.currentTab },
            set: { store.send(.tabChanged($0)) }
        )) {
            // Game tab - always available
            GameView(store: store.scope(state: \.game, action: \.game))
                .tabItem {
                    Image(systemName: "gamecontroller.fill")
                    Text("Game")
                }
                .tag(AppFeature.State.Tab.game)
            
            // Profile tab - conditional on authentication or preference
            if store.availableTabs.contains(.profile) {
                ProfileView(store: store.scope(state: \.profile, action: \.profile))
                    .tabItem {
                        Image(systemName: store.isAuthenticated ? "person.fill" : "person.badge.plus")
                        Text(store.isAuthenticated ? "Profile" : "Connect")
                    }
                    .tag(AppFeature.State.Tab.profile)
            }
            
            // Shop tab - always available (single-user items don't require auth)
            ShopView(store: store.scope(state: \.shop, action: \.shop))
                .tabItem {
                    Image(systemName: "bag.fill")
                    Text("Shop")
                }
                .tag(AppFeature.State.Tab.shop)
            
            // Settings tab - always available
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
        .sheet(isPresented: .constant(store.showConnectPrompt)) {
            AuthenticationPromptView(store: store)
        }
    }
}

struct GameView: View {
    let store: StoreOf<GameFeature>
    
    var body: some View {
        NavigationStack {
            Group {
                if store.showResults {
                    SingleUserGameResultsView(store: store)
                } else if store.showModeSelection {
                    GameModeSelectionView(store: store.scope(state: \.modeSelection, action: \.modeSelection))
                } else if store.currentGame == nil && store.singleUserSession == nil {
                    GameMenuView(
                        store: store,
                        isAuthenticated: store.isAuthenticated,
                        onRequestAuthentication: {
                            // This would need to be passed from the parent
                            // For now, we'll handle this in the GameFeature
                        }
                    )
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

// MARK: - Game Menu View (Single-User First)
struct GameMenuView: View {
    let store: StoreOf<GameFeature>
    let isAuthenticated: Bool
    let onRequestAuthentication: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Text("Plant Identification")
                        .botanicalStyle(BotanicalTextStyle.largeTitle)
                    Text("Challenge yourself with plant knowledge")
                        .botanicalStyle(BotanicalTextStyle.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Single-User Game Modes (Priority)
                VStack(spacing: 16) {
                    HStack {
                        Text("Quick Play")
                            .botanicalStyle(BotanicalTextStyle.headline)
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        // Beat the Clock Mode
                        SingleUserModeCard(
                            title: "Beat the Clock",
                            description: "Answer as many plants as you can in 60 seconds",
                            icon: "timer",
                            color: .orange,
                            isRecommended: true
                        ) {
                            store.send(.showModeSelection(true))
                            store.send(.modeSelection(.selectMode(.beatTheClock)))
                        }
                        
                        // Speedrun Mode
                        SingleUserModeCard(
                            title: "Speedrun Challenge",
                            description: "Identify 25 plants as quickly as possible",
                            icon: "bolt.fill",
                            color: .blue
                        ) {
                            store.send(.showModeSelection(true))
                            store.send(.modeSelection(.selectMode(.speedrun)))
                        }
                    }
                }
                
                // Multiplayer Section (Optional/Secondary)
                VStack(spacing: 16) {
                    HStack {
                        Text("Multiplayer")
                            .botanicalStyle(BotanicalTextStyle.headline)
                        Spacer()
                        if !store.isAuthenticated {
                            Text("Requires Game Center")
                                .botanicalStyle(BotanicalTextStyle.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    MultiplayerModeCard(
                        store: store,
                        isAuthenticated: isAuthenticated,
                        onRequestAuthentication: onRequestAuthentication
                    )
                }
                
                // Recent Games Section
                if !store.gameHistory.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Recent Games")
                                .botanicalStyle(BotanicalTextStyle.headline)
                            Spacer()
                        }
                        
                        LazyVStack(spacing: 8) {
                            ForEach(store.gameHistory.prefix(3)) { game in
                                GameHistoryCard(game: game)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 24)
            }
            .padding(.horizontal)
        }
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

// MARK: - Single User Game Results View
struct SingleUserGameResultsView: View {
    let store: StoreOf<GameFeature>
    
    var body: some View {
        Group {
            if let beatTheClockScore = store.beatTheClockScore {
                GameResultsScreen(
                    session: createSessionFromBeatTheClockScore(beatTheClockScore),
                    finalScore: beatTheClockScore,
                    personalBest: store.beatTheClockPersonalBest.map { createPersonalBestFromBeatTheClockScore($0) },
                    isNewPersonalBest: isNewBeatTheClockRecord(beatTheClockScore),
                    trophiesEarned: store.trophyReward?.totalTrophies ?? 0,
                    onPlayAgain: {
                        store.send(.hideGameResults)
                        store.send(.startSingleUserGame(.beatTheClock, beatTheClockScore.difficulty))
                    },
                    onReturnToMenu: {
                        store.send(.hideGameResults)
                        store.send(.showModeSelection(true))
                    },
                    onViewLeaderboard: {
                        // TODO: Navigate to leaderboard
                    }
                )
            } else if let speedrunScore = store.speedrunScore {
                GameResultsScreen(
                    session: createSessionFromSpeedrunScore(speedrunScore),
                    finalScore: speedrunScore,
                    personalBest: store.speedrunPersonalBest.map { createPersonalBestFromSpeedrunScore($0) },
                    isNewPersonalBest: isNewSpeedrunRecord(speedrunScore),
                    trophiesEarned: store.trophyReward?.totalTrophies ?? 0,
                    onPlayAgain: {
                        store.send(.hideGameResults)
                        store.send(.startSingleUserGame(.speedrun, speedrunScore.difficulty))
                    },
                    onReturnToMenu: {
                        store.send(.hideGameResults)
                        store.send(.showModeSelection(true))
                    },
                    onViewLeaderboard: {
                        // TODO: Navigate to leaderboard
                    }
                )
            } else {
                // Fallback for missing results data
                VStack(spacing: 20) {
                    Text("Game Complete!")
                        .botanicalStyle(BotanicalTextStyle.largeTitle)
                    
                    BotanicalButton("Return to Menu", style: .primary, size: .large) {
                        store.send(.hideGameResults)
                        store.send(.showModeSelection(true))
                    }
                }
                .padding()
            }
        }
    }
    
    private func createSessionFromBeatTheClockScore(_ score: BeatTheClockScore) -> SingleUserGameSession {
        var session = SingleUserGameSession(mode: .beatTheClock, difficulty: score.difficulty)
        session.correctAnswers = score.correctAnswers
        session.questionsAnswered = score.totalAnswers
        session.totalGameTime = score.timeUsed
        session.state = .completed
        return session
    }
    
    private func createSessionFromSpeedrunScore(_ score: SpeedrunScore) -> SingleUserGameSession {
        var session = SingleUserGameSession(mode: .speedrun, difficulty: score.difficulty)
        session.correctAnswers = score.correctAnswers
        session.questionsAnswered = score.totalQuestions
        session.totalGameTime = score.completionTime
        session.state = .completed
        return session
    }
    
    private func createPersonalBestFromBeatTheClockScore(_ score: BeatTheClockScore) -> PersonalBest {
        return PersonalBest(
            id: UUID().uuidString,
            mode: .beatTheClock,
            difficulty: score.difficulty,
            score: score.correctAnswers * 10, // Convert to points
            correctAnswers: score.correctAnswers,
            totalGameTime: score.timeUsed,
            accuracy: score.accuracy,
            achievedAt: score.achievedAt
        )
    }
    
    private func createPersonalBestFromSpeedrunScore(_ score: SpeedrunScore) -> PersonalBest {
        return PersonalBest(
            id: UUID().uuidString,
            mode: .speedrun,
            difficulty: score.difficulty,
            score: Int(score.rating),
            correctAnswers: score.correctAnswers,
            totalGameTime: score.completionTime,
            accuracy: Double(score.correctAnswers) / Double(score.totalQuestions),
            achievedAt: score.achievedAt
        )
    }
    
    private func isNewBeatTheClockRecord(_ score: BeatTheClockScore) -> Bool {
        guard let personalBest = store.beatTheClockPersonalBest else { return true }
        return score.correctAnswers > personalBest.correctAnswers
    }
    
    private func isNewSpeedrunRecord(_ score: SpeedrunScore) -> Bool {
        guard let personalBest = store.speedrunPersonalBest else { return true }
        return score.rating > personalBest.rating
    }
}

// MARK: - Single User Mode Card
struct SingleUserModeCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isRecommended: Bool
    let action: () -> Void
    
    init(
        title: String,
        description: String,
        icon: String,
        color: Color,
        isRecommended: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.isRecommended = isRecommended
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(color.opacity(0.15))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .botanicalStyle(BotanicalTextStyle.headline)
                            .foregroundColor(.primary)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .botanicalStyle(BotanicalTextStyle.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.botanicalGreen)
                                )
                        }
                        
                        Spacer()
                    }
                    
                    Text(description)
                        .botanicalStyle(BotanicalTextStyle.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Multiplayer Mode Card
struct MultiplayerModeCard: View {
    let store: StoreOf<GameFeature>
    let isAuthenticated: Bool
    let onRequestAuthentication: () -> Void
    
    var body: some View {
        Button(action: {
            if isAuthenticated {
                // Show difficulty selection for multiplayer
                store.send(.showModeSelection(true))
                store.send(.modeSelection(.selectMode(.multiplayer)))
            } else {
                // Request authentication for multiplayer
                onRequestAuthentication()
            }
        }) {
            HStack(spacing: 16) {
                // Icon with authentication state
                ZStack {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(isAuthenticated ? .botanicalGreen : .gray)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill((isAuthenticated ? Color.botanicalGreen : .gray).opacity(0.15))
                        )
                    
                    if !isAuthenticated {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 16, height: 16)
                            )
                            .offset(x: 12, y: -12)
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Battle Other Players")
                        .botanicalStyle(BotanicalTextStyle.headline)
                        .foregroundColor(isAuthenticated ? .primary : .secondary)
                    
                    Text(isAuthenticated 
                         ? "Compete in real-time matches against other players"
                         : "Connect with Game Center to unlock multiplayer battles"
                    )
                        .botanicalStyle(BotanicalTextStyle.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Action indicator
                if isAuthenticated {
                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("Connect")
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.botanicalGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.botanicalGreen.opacity(0.15))
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isAuthenticated ? Color(.systemGray4) : Color.botanicalGreen.opacity(0.3),
                                lineWidth: isAuthenticated ? 1 : 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Authentication Prompt View
struct AuthenticationPromptView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.botanicalGreen)
                    
                    Text("Connect with Game Center")
                        .botanicalStyle(BotanicalTextStyle.largeTitle)
                        .multilineTextAlignment(.center)
                    
                    Text(store.authPromptMessage)
                        .botanicalStyle(BotanicalTextStyle.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Benefits
                VStack(spacing: 12) {
                    ForEach(store.authenticationBenefits, id: \.self) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.botanicalGreen)
                            
                            Text(benefit)
                                .botanicalStyle(BotanicalTextStyle.body)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    BotanicalButton(
                        "Connect with Game Center",
                        style: .primary,
                        size: .large
                    ) {
                        store.send(.requestAuthentication)
                        dismiss()
                    }
                    
                    BotanicalButton(
                        "Maybe Later",
                        style: .secondary,
                        size: .large
                    ) {
                        store.send(.hideConnectPrompt)
                        dismiss()
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        store.send(.hideConnectPrompt)
                        dismiss()
                    }
                }
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