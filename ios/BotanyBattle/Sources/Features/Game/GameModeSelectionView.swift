import SwiftUI

struct GameModeSelectionView: View {
    @ObservedObject var gameFeature: GameFeature
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 24) {
                    headerSection
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(GameMode.allCases, id: \.self) { mode in
                                GameModeCard(
                                    mode: mode,
                                    isSelected: mode == gameFeature.currentMode,
                                    onSelect: {
                                        gameFeature.setGameMode(mode)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    startGameButton
                }
                .padding(.top)
            }
            .navigationTitle("Game Modes")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.green.opacity(0.05),
                Color.clear
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            
            Text("Choose Your Challenge")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Test your botanical knowledge in different ways")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
    
    private var startGameButton: some View {
        VStack(spacing: 16) {
            if gameFeature.isLoading {
                ProgressView("Loading plants...")
                    .tint(.green)
            } else {
                Button {
                    Task {
                        await gameFeature.startGame()
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start \(gameFeature.currentMode.displayName)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(gameFeature.isLoading)
            }
            
            if let errorMessage = gameFeature.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
}

// MARK: - Game Mode Card

struct GameModeCard: View {
    let mode: GameMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .green : .primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(mode.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                
                // Mode-specific details
                modeDetailsSection
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var modeDetailsSection: some View {
        switch mode {
        case .practice:
            HStack {
                Label("Unlimited time", systemImage: "clock")
                Spacer()
                Label("Learn at your pace", systemImage: "brain.head.profile")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
        case .timeAttack:
            HStack {
                Label("\(GameConstants.timeAttackLimit)s timer", systemImage: "timer")
                Spacer()
                Label("High score challenge", systemImage: "trophy")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
        case .speedrun:
            HStack {
                Label("\(GameConstants.speedrunQuestionCount) questions", systemImage: "number")
                Spacer()
                Label("Best time wins", systemImage: "stopwatch")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Statistics Section

struct GameModeStatsView: View {
    let mode: GameMode
    @ObservedObject var userDefaultsService: UserDefaultsService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Best")
                .font(.caption)
                .foregroundColor(.secondary)
            
            switch mode {
            case .practice:
                HStack {
                    Text("High Score:")
                    Spacer()
                    Text("\(userDefaultsService.practiceHighScore)")
                        .fontWeight(.semibold)
                }
                
            case .timeAttack:
                HStack {
                    Text("High Score:")
                    Spacer()
                    Text("\(userDefaultsService.timeAttackHighScore)")
                        .fontWeight(.semibold)
                }
                
            case .speedrun:
                HStack {
                    Text("Best Time:")
                    Spacer()
                    if userDefaultsService.speedrunBestTime == Double.greatestFiniteMagnitude {
                        Text("--:--")
                            .fontWeight(.semibold)
                    } else {
                        Text(formatTime(userDefaultsService.speedrunBestTime))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .font(.caption)
        .foregroundColor(.primary)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Preview

#Preview {
    GameModeSelectionView(gameFeature: GameFeature())
}