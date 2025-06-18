import SwiftUI
import ComposableArchitecture

struct GameProgressHeader: View {
    let currentRound: Int
    let totalRounds: Int
    let timeRemaining: TimeInterval
    let mode: GameMode?
    let difficulty: Game.Difficulty?
    let score: Int?
    let correctAnswers: Int?
    let onLeave: (() -> Void)?
    let onPause: (() -> Void)?
    
    init(
        currentRound: Int,
        totalRounds: Int,
        timeRemaining: TimeInterval,
        mode: GameMode? = nil,
        difficulty: Game.Difficulty? = nil,
        score: Int? = nil,
        correctAnswers: Int? = nil,
        onLeave: (() -> Void)? = nil,
        onPause: (() -> Void)? = nil
    ) {
        self.currentRound = currentRound
        self.totalRounds = totalRounds
        self.timeRemaining = timeRemaining
        self.mode = mode
        self.difficulty = difficulty
        self.score = score
        self.correctAnswers = correctAnswers
        self.onLeave = onLeave
        self.onPause = onPause
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Top Row: Mode, Difficulty, Controls
            HStack {
                // Leave button
                if let onLeave = onLeave {
                    Button(action: onLeave) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .gameControlAccessibility(action: "Leave Game")
                    .accessibilityHint("Double tap to leave the current game and return to the main menu")
                } else {
                    Spacer().frame(width: 24)
                }
                
                Spacer()
                
                // Mode and Difficulty
                VStack(spacing: 2) {
                    if let mode = mode {
                        Text(mode.displayName)
                            .botanicalStyle(BotanicalTextStyle.headline)
                    }
                    if let difficulty = difficulty {
                        Text(difficulty.displayName)
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Pause button (for single-user modes)
                if let onPause = onPause {
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                            .foregroundColor(.botanicalGreen)
                    }
                } else {
                    Spacer().frame(width: 24)
                }
            }
            
            // Progress and Timer Section
            HStack(spacing: 16) {
                // Progress Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(progressText)
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                        .progressAccessibility(
                            current: currentRound,
                            total: totalRounds,
                            mode: mode ?? .multiplayer
                        )
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 6)
                                .cornerRadius(3)
                            
                            Rectangle()
                                .fill(progressBarColor)
                                .frame(width: geometry.size.width * progressPercentage, height: 6)
                                .cornerRadius(3)
                                .animation(.easeInOut(duration: 0.3), value: progressPercentage)
                        }
                    }
                    .frame(height: 6)
                }
                
                // Timer and Score
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 12) {
                        // Score (if available)
                        if let score = score, let correctAnswers = correctAnswers, let mode = mode {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Score")
                                    .botanicalStyle(BotanicalTextStyle.caption)
                                    .foregroundColor(.secondary)
                                Text("\(score)")
                                    .botanicalStyle(BotanicalTextStyle.body)
                                    .fontWeight(.semibold)
                                    .fontDesign(.monospaced)
                            }
                            .scoreAccessibility(
                                score: score,
                                correctAnswers: correctAnswers,
                                totalAnswers: currentRound,
                                mode: mode
                            )
                        }
                        
                        // Timer
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(timerLabel)
                                .botanicalStyle(BotanicalTextStyle.caption)
                                .foregroundColor(.secondary)
                            Text(timerText)
                                .botanicalStyle(BotanicalTextStyle.headline)
                                .fontWeight(.bold)
                                .fontDesign(.monospaced)
                                .foregroundColor(timerColor)
                        }
                        .timerAccessibility(
                            timeRemaining: timeRemaining,
                            mode: mode ?? .multiplayer,
                            isUrgent: timeRemaining <= 10
                        )
                    }
                }
            }
            
            // Achievement Indicators (if applicable)
            if let achievementInfo = achievementInfo {
                AchievementBanner(info: achievementInfo)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemGray6),
                    Color(.systemGray6).opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Computed Properties
    
    private var progressText: String {
        if let mode = mode {
            switch mode {
            case .multiplayer:
                return "Round \(currentRound) of \(totalRounds)"
            case .beatTheClock:
                if let correct = correctAnswers {
                    return "Answered: \(correct)"
                }
                return "Beat the Clock"
            case .speedrun:
                return "Questions: \(currentRound)/25"
            }
        }
        return "Round \(currentRound) of \(totalRounds)"
    }
    
    private var progressPercentage: Double {
        if let mode = mode {
            switch mode {
            case .multiplayer:
                return Double(currentRound) / Double(totalRounds)
            case .beatTheClock:
                // Progress based on time (60 seconds)
                return min(1.0, max(0.0, 1.0 - (timeRemaining / 60.0)))
            case .speedrun:
                return Double(currentRound) / 25.0
            }
        }
        return Double(currentRound) / Double(totalRounds)
    }
    
    private var progressBarColor: Color {
        if let mode = mode {
            switch mode {
            case .multiplayer:
                return .botanicalGreen
            case .beatTheClock:
                return timeRemaining < 10 ? .red : .orange
            case .speedrun:
                return .blue
            }
        }
        return .botanicalGreen
    }
    
    private var timerLabel: String {
        if let mode = mode {
            switch mode {
            case .multiplayer:
                return "Time Left"
            case .beatTheClock:
                return "Time Left"
            case .speedrun:
                return "Elapsed"
            }
        }
        return "Time Left"
    }
    
    private var timerText: String {
        let minutes = Int(abs(timeRemaining)) / 60
        let seconds = Int(abs(timeRemaining)) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var timerColor: Color {
        if let mode = mode {
            switch mode {
            case .multiplayer:
                return timeRemaining < 5 ? .red : .primary
            case .beatTheClock:
                if timeRemaining < 5 {
                    return .red
                } else if timeRemaining < 15 {
                    return .orange
                } else {
                    return .primary
                }
            case .speedrun:
                return .primary
            }
        }
        return timeRemaining < 5 ? .red : .primary
    }
    
    private var achievementInfo: AchievementInfo? {
        // Return achievement info if certain milestones are reached
        if let mode = mode, let correct = correctAnswers {
            switch mode {
            case .beatTheClock:
                if correct >= 10 && correct % 5 == 0 {
                    return AchievementInfo(
                        icon: "flame.fill",
                        text: "On Fire! \(correct) correct!",
                        color: .orange
                    )
                }
            case .speedrun:
                if currentRound >= 10 && timeRemaining < 60 {
                    return AchievementInfo(
                        icon: "bolt.fill",
                        text: "Lightning Fast!",
                        color: .yellow
                    )
                }
            case .multiplayer:
                break
            }
        }
        return nil
    }
}

// MARK: - Achievement Banner
struct AchievementInfo {
    let icon: String
    let text: String
    let color: Color
}

struct AchievementBanner: View {
    let info: AchievementInfo
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: info.icon)
                .foregroundColor(info.color)
            
            Text(info.text)
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(info.color)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(info.color.opacity(0.15))
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
            
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GameProgressHeader(
            currentRound: 3,
            totalRounds: 5,
            timeRemaining: 15.0,
            mode: .multiplayer,
            difficulty: .medium,
            score: 850,
            correctAnswers: 3
        )
        
        GameProgressHeader(
            currentRound: 12,
            totalRounds: 25,
            timeRemaining: 45.0,
            mode: .beatTheClock,
            difficulty: .hard,
            score: 12,
            correctAnswers: 12
        )
        
        GameProgressHeader(
            currentRound: 18,
            totalRounds: 25,
            timeRemaining: 89.5,
            mode: .speedrun,
            difficulty: .expert,
            score: 750,
            correctAnswers: 16
        )
    }
}