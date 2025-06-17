import SwiftUI
import ComposableArchitecture

struct GameModeSelectionView: View {
    @Bindable var store: StoreOf<GameModeSelectionFeature>
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Game Mode")
                        .botanicalStyle(BotanicalTextStyle.largeTitle)
                    Text("Select your preferred way to play")
                        .botanicalStyle(BotanicalTextStyle.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Game Mode Cards
                VStack(spacing: 16) {
                    GameModeCard(
                        mode: .multiplayer,
                        isSelected: store.selectedMode == .multiplayer,
                        personalBest: store.personalBestForSelectedMode
                    ) {
                        store.send(.selectMode(.multiplayer))
                    }
                    
                    GameModeCard(
                        mode: .beatTheClock,
                        isSelected: store.selectedMode == .beatTheClock,
                        personalBest: store.personalBestForSelectedMode,
                        beatTheClockBest: store.beatTheClockBests[store.selectedDifficulty]
                    ) {
                        store.send(.selectMode(.beatTheClock))
                    }
                    
                    GameModeCard(
                        mode: .speedrun,
                        isSelected: store.selectedMode == .speedrun,
                        personalBest: store.personalBestForSelectedMode,
                        speedrunBest: store.speedrunBests[store.selectedDifficulty]
                    ) {
                        store.send(.selectMode(.speedrun))
                    }
                }
                
                // Difficulty Selection (for single-user modes)
                if store.showDifficultySelection {
                    DifficultySelectionSection(
                        selectedDifficulty: store.selectedDifficulty,
                        mode: store.selectedMode,
                        beatTheClockBests: store.beatTheClockBests,
                        speedrunBests: store.speedrunBests
                    ) { difficulty in
                        store.send(.selectDifficulty(difficulty))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Start Game Button
                BotanicalButton(
                    startButtonTitle(for: store.selectedMode),
                    style: .primary,
                    size: .large,
                    isLoading: store.isLoading
                ) {
                    store.send(.startGame)
                }
                .disabled(!store.canStartGame)
                .padding(.horizontal)
                
                // Recent Games Section
                if !store.recentGamesForSelectedMode.isEmpty {
                    RecentGamesSection(
                        mode: store.selectedMode,
                        games: store.recentGamesForSelectedMode
                    )
                }
                
                Spacer(minLength: 24)
            }
            .padding(.horizontal)
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert("Error", isPresented: .constant(store.error != nil)) {
            Button("OK") {
                store.send(.clearError)
            }
        } message: {
            Text(store.error ?? "")
        }
        .animation(.easeInOut(duration: 0.3), value: store.showDifficultySelection)
    }
    
    private func startButtonTitle(for mode: GameMode) -> String {
        switch mode {
        case .multiplayer:
            return "Find Opponent"
        case .beatTheClock:
            return "Start Beat the Clock"
        case .speedrun:
            return "Start Speedrun"
        }
    }
}

// MARK: - Game Mode Card
struct GameModeCard: View {
    let mode: GameMode
    let isSelected: Bool
    let personalBest: PersonalBest?
    let beatTheClockBest: BeatTheClockScore?
    let speedrunBest: SpeedrunScore?
    let action: () -> Void
    
    init(
        mode: GameMode,
        isSelected: Bool,
        personalBest: PersonalBest? = nil,
        beatTheClockBest: BeatTheClockScore? = nil,
        speedrunBest: SpeedrunScore? = nil,
        action: @escaping () -> Void
    ) {
        self.mode = mode
        self.isSelected = isSelected
        self.personalBest = personalBest
        self.beatTheClockBest = beatTheClockBest
        self.speedrunBest = speedrunBest
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: iconName)
                                .font(.title2)
                                .foregroundColor(.botanicalGreen)
                            
                            Text(mode.displayName)
                                .botanicalStyle(BotanicalTextStyle.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Text(mode.description)
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.botanicalGreen)
                    }
                }
                
                // Personal Best Info
                if let bestInfo = personalBestInfo {
                    Divider()
                    
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text(bestInfo)
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.botanicalGreen : Color(.systemGray4),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconName: String {
        switch mode {
        case .multiplayer: return "person.2.fill"
        case .beatTheClock: return "timer"
        case .speedrun: return "bolt.fill"
        }
    }
    
    private var personalBestInfo: String? {
        switch mode {
        case .multiplayer:
            return personalBest?.displayScore
        case .beatTheClock:
            if let best = beatTheClockBest {
                return "Best: \(best.displayScore)"
            }
            return nil
        case .speedrun:
            if let best = speedrunBest {
                return "Best: \(best.displayTime) (\(best.ratingTier.rawValue))"
            }
            return nil
        }
    }
}

// MARK: - Difficulty Selection Section
struct DifficultySelectionSection: View {
    let selectedDifficulty: Game.Difficulty
    let mode: GameMode
    let beatTheClockBests: [Game.Difficulty: BeatTheClockScore]
    let speedrunBests: [Game.Difficulty: SpeedrunScore]
    let onSelect: (Game.Difficulty) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Select Difficulty")
                    .botanicalStyle(BotanicalTextStyle.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(Game.Difficulty.allCases, id: \.self) { difficulty in
                    DifficultyButton(
                        difficulty: difficulty,
                        mode: mode,
                        isSelected: selectedDifficulty == difficulty,
                        beatTheClockBest: beatTheClockBests[difficulty],
                        speedrunBest: speedrunBests[difficulty]
                    ) {
                        onSelect(difficulty)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Difficulty Button
struct DifficultyButton: View {
    let difficulty: Game.Difficulty
    let mode: GameMode
    let isSelected: Bool
    let beatTheClockBest: BeatTheClockScore?
    let speedrunBest: SpeedrunScore?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(difficulty.displayName)
                        .botanicalStyle(BotanicalTextStyle.body)
                        .foregroundColor(.primary)
                    
                    Text(difficultyDescription)
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let bestInfo = personalBestInfo {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Best")
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.secondary)
                        
                        Text(bestInfo)
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.botanicalGreen)
                            .fontWeight(.semibold)
                    }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.botanicalGreen)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.botanicalGreen.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? Color.botanicalGreen : Color(.systemGray4),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var difficultyDescription: String {
        switch mode {
        case .multiplayer:
            return "\(Int(difficulty.timePerRound))s per round"
        case .beatTheClock:
            return "60 seconds total"
        case .speedrun:
            return "25 questions"
        }
    }
    
    private var personalBestInfo: String? {
        switch mode {
        case .multiplayer:
            return nil
        case .beatTheClock:
            return beatTheClockBest?.displayScore
        case .speedrun:
            if let best = speedrunBest {
                return best.displayTime
            }
            return nil
        }
    }
}

// MARK: - Recent Games Section
struct RecentGamesSection: View {
    let mode: GameMode
    let games: [GameHistoryItem]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent \(mode.displayName) Games")
                    .botanicalStyle(BotanicalTextStyle.headline)
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(games) { game in
                    RecentGameCard(game: game)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Recent Game Card
struct RecentGameCard: View {
    let game: GameHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.difficulty.displayName)
                    .botanicalStyle(BotanicalTextStyle.body)
                    .fontWeight(.medium)
                
                Text(RelativeDateTimeFormatter().localizedString(for: game.completedAt, relativeTo: Date()))
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(game.displayScore)
                    .botanicalStyle(BotanicalTextStyle.body)
                    .fontWeight(.semibold)
                
                Text(game.displayAccuracy)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
            }
            
            if game.isNewPersonalBest {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemBackground))
        )
    }
}

#Preview {
    NavigationView {
        GameModeSelectionView(
            store: Store(
                initialState: GameModeSelectionFeature.State(),
                reducer: { GameModeSelectionFeature() }
            )
        )
        .navigationTitle("Game Modes")
        .navigationBarTitleDisplayMode(.inline)
    }
}