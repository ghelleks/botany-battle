import SwiftUI
import ComposableArchitecture

struct GameResultsScreen: View {
    let session: SingleUserGameSession
    let finalScore: Any // Could be BeatTheClockScore or SpeedrunScore
    let personalBest: PersonalBest?
    let isNewPersonalBest: Bool
    let trophiesEarned: Int
    let onPlayAgain: () -> Void
    let onReturnToMenu: () -> Void
    let onViewLeaderboard: () -> Void
    
    @State private var showCelebration = false
    @State private var showDetails = false
    @State private var animateElements = false
    
    var body: some View {
        ZStack {
            // Background
            ResultsBackground(mode: session.mode, isNewRecord: isNewPersonalBest)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with celebration
                    ResultsHeader(
                        session: session,
                        isNewPersonalBest: isNewPersonalBest,
                        showCelebration: $showCelebration
                    )
                    
                    // Score Summary Card
                    ScoreSummaryCard(
                        session: session,
                        finalScore: finalScore,
                        isNewPersonalBest: isNewPersonalBest
                    )
                    
                    // Personal Best Comparison
                    PersonalBestComparisonCard(
                        session: session,
                        personalBest: personalBest,
                        isNewPersonalBest: isNewPersonalBest
                    )
                    
                    // Trophy Rewards
                    TrophyRewardsCard(
                        trophiesEarned: trophiesEarned,
                        session: session
                    )
                    
                    // Performance Analytics
                    PerformanceAnalyticsCard(
                        session: session,
                        showDetails: $showDetails
                    )
                    
                    // Achievement Showcase
                    AchievementShowcaseCard(session: session)
                    
                    // Action Buttons
                    ResultsActionButtons(
                        session: session,
                        onPlayAgain: onPlayAgain,
                        onReturnToMenu: onReturnToMenu,
                        onViewLeaderboard: onViewLeaderboard
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            
            // Celebration Effects
            if showCelebration {
                CelebrationEffectsView(mode: session.mode, isNewRecord: isNewPersonalBest)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startResultsAnimation()
        }
    }
    
    private func startResultsAnimation() {
        // Stagger animations for dramatic effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animateElements = true
            }
        }
        
        if isNewPersonalBest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showCelebration = true
                }
            }
        }
    }
}

// MARK: - Results Background
struct ResultsBackground: View {
    let mode: GameMode
    let isNewRecord: Bool
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: backgroundColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated particles
            if isNewRecord {
                ParticleEffectView(color: modeColor)
            }
        }
    }
    
    private var backgroundColors: [Color] {
        let baseColor = modeColor
        return [
            baseColor.opacity(0.1),
            baseColor.opacity(0.05),
            Color(.systemBackground).opacity(0.95)
        ]
    }
    
    private var modeColor: Color {
        switch mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

// MARK: - Results Header
struct ResultsHeader: View {
    let session: SingleUserGameSession
    let isNewPersonalBest: Bool
    @Binding var showCelebration: Bool
    @State private var headerScale: CGFloat = 0.8
    
    var body: some View {
        VStack(spacing: 16) {
            // Game mode icon
            Image(systemName: modeIcon)
                .font(.system(size: 60))
                .foregroundColor(modeColor)
                .scaleEffect(headerScale)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        headerScale = 1.0
                    }
                }
            
            // Main result message
            Text(resultMessage)
                .botanicalStyle(BotanicalTextStyle.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(modeColor)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(session.mode.displayName)
                .botanicalStyle(BotanicalTextStyle.title2)
                .foregroundColor(.secondary)
            
            Text(session.difficulty.displayName)
                .botanicalStyle(BotanicalTextStyle.subheadline)
                .foregroundColor(.secondary)
            
            // New record badge
            if isNewPersonalBest {
                NewRecordBadge()
            }
        }
        .padding()
    }
    
    private var resultMessage: String {
        if isNewPersonalBest {
            return "New Personal Best!"
        } else {
            switch session.mode {
            case .multiplayer:
                return "Game Complete!"
            case .beatTheClock:
                return "Time's Up!"
            case .speedrun:
                return "Speedrun Complete!"
            }
        }
    }
    
    private var modeIcon: String {
        switch session.mode {
        case .multiplayer: return "gamecontroller.fill"
        case .beatTheClock: return "timer"
        case .speedrun: return "bolt.circle.fill"
        }
    }
    
    private var modeColor: Color {
        switch session.mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

// MARK: - New Record Badge
struct NewRecordBadge: View {
    @State private var badgeScale: CGFloat = 0.0
    @State private var badgeRotation: Double = -10
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundColor(.yellow)
            
            Text("NEW RECORD")
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.red, .orange]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .scaleEffect(badgeScale)
        .rotationEffect(.degrees(badgeRotation))
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                badgeScale = 1.0
                badgeRotation = 0
            }
        }
    }
}

// MARK: - Score Summary Card
struct ScoreSummaryCard: View {
    let session: SingleUserGameSession
    let finalScore: Any
    let isNewPersonalBest: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Final Score")
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.semibold)
            
            // Main score display
            VStack(spacing: 8) {
                Text(primaryScoreText)
                    .botanicalStyle(BotanicalTextStyle.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                    .foregroundColor(scoreColor)
                
                Text(scoreDescription)
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Secondary metrics
            HStack(spacing: 30) {
                ScoreMetric(
                    title: "Accuracy",
                    value: String(format: "%.1f%%", session.accuracy * 100),
                    icon: "target",
                    color: accuracyColor
                )
                
                ScoreMetric(
                    title: "Questions",
                    value: "\(session.correctAnswers)/\(session.questionsAnswered)",
                    icon: "questionmark.circle.fill",
                    color: .blue
                )
                
                ScoreMetric(
                    title: modeSpecificTitle,
                    value: modeSpecificValue,
                    icon: modeSpecificIcon,
                    color: modeColor
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var primaryScoreText: String {
        switch session.mode {
        case .multiplayer:
            return "\(session.score)"
        case .beatTheClock:
            return "\(session.correctAnswers)"
        case .speedrun:
            let minutes = Int(session.totalGameTime) / 60
            let seconds = Int(session.totalGameTime) % 60
            let milliseconds = Int((session.totalGameTime.truncatingRemainder(dividingBy: 1)) * 100)
            return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
        }
    }
    
    private var scoreDescription: String {
        switch session.mode {
        case .multiplayer:
            return "Total Points"
        case .beatTheClock:
            return "Correct Answers"
        case .speedrun:
            return "Completion Time"
        }
    }
    
    private var scoreColor: Color {
        switch session.mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
    
    private var accuracyColor: Color {
        let accuracy = session.accuracy
        if accuracy >= 0.9 { return .green }
        else if accuracy >= 0.7 { return .blue }
        else if accuracy >= 0.5 { return .orange }
        else { return .red }
    }
    
    private var modeSpecificTitle: String {
        switch session.mode {
        case .multiplayer: return "Bonus"
        case .beatTheClock: return "Rate"
        case .speedrun: return "Average"
        }
    }
    
    private var modeSpecificValue: String {
        switch session.mode {
        case .multiplayer:
            return "N/A"
        case .beatTheClock:
            let rate = session.totalGameTime > 0 ? (Double(session.correctAnswers) / session.totalGameTime) * 60 : 0
            return String(format: "%.1f/min", rate)
        case .speedrun:
            let avg = session.questionsAnswered > 0 ? session.totalGameTime / Double(session.questionsAnswered) : 0
            return String(format: "%.2fs", avg)
        }
    }
    
    private var modeSpecificIcon: String {
        switch session.mode {
        case .multiplayer: return "gift.fill"
        case .beatTheClock: return "speedometer"
        case .speedrun: return "stopwatch"
        }
    }
    
    private var modeColor: Color {
        switch session.mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

// MARK: - Score Metric
struct ScoreMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.bold)
                .fontDesign(.monospaced)
            
            Text(title)
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Personal Best Comparison Card
struct PersonalBestComparisonCard: View {
    let session: SingleUserGameSession
    let personalBest: PersonalBest?
    let isNewPersonalBest: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Personal Best Comparison")
                    .botanicalStyle(BotanicalTextStyle.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isNewPersonalBest {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
            
            if let best = personalBest {
                ComparisonRow(
                    title: "Previous Best",
                    currentValue: currentScoreText,
                    previousValue: previousScoreText(best),
                    improvement: improvementText(best),
                    isImprovement: isNewPersonalBest
                )
                
                if session.mode != .multiplayer {
                    ComparisonRow(
                        title: "Accuracy",
                        currentValue: String(format: "%.1f%%", session.accuracy * 100),
                        previousValue: String(format: "%.1f%%", best.accuracy * 100),
                        improvement: String(format: "%+.1f%%", (session.accuracy - best.accuracy) * 100),
                        isImprovement: session.accuracy >= best.accuracy
                    )
                }
            } else {
                FirstTimeMessage(mode: session.mode)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var currentScoreText: String {
        switch session.mode {
        case .multiplayer:
            return "\(session.score) pts"
        case .beatTheClock:
            return "\(session.correctAnswers) correct"
        case .speedrun:
            return String(format: "%.2fs", session.totalGameTime)
        }
    }
    
    private func previousScoreText(_ best: PersonalBest) -> String {
        switch session.mode {
        case .multiplayer:
            return "\(best.score) pts"
        case .beatTheClock:
            return "\(best.correctAnswers) correct"
        case .speedrun:
            return String(format: "%.2fs", best.totalGameTime)
        }
    }
    
    private func improvementText(_ best: PersonalBest) -> String {
        switch session.mode {
        case .multiplayer:
            let diff = session.score - best.score
            return diff >= 0 ? "+\(diff)" : "\(diff)"
        case .beatTheClock:
            let diff = session.correctAnswers - best.correctAnswers
            return diff >= 0 ? "+\(diff)" : "\(diff)"
        case .speedrun:
            let diff = best.totalGameTime - session.totalGameTime
            return String(format: "%+.2fs", diff)
        }
    }
}

// MARK: - Comparison Row
struct ComparisonRow: View {
    let title: String
    let currentValue: String
    let previousValue: String
    let improvement: String
    let isImprovement: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .botanicalStyle(BotanicalTextStyle.body)
                    .fontWeight(.medium)
                
                Text("Previous: \(previousValue)")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(currentValue)
                    .botanicalStyle(BotanicalTextStyle.body)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
                
                Text(improvement)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isImprovement ? .green : .red)
            }
        }
    }
}

// MARK: - First Time Message
struct FirstTimeMessage: View {
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("First Time!")
                .botanicalStyle(BotanicalTextStyle.title2)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
            
            Text("This is your first \(mode.displayName) game. Great job setting your personal best!")
                .botanicalStyle(BotanicalTextStyle.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Trophy Rewards Card
struct TrophyRewardsCard: View {
    let trophiesEarned: Int
    let session: SingleUserGameSession
    @State private var showTrophyAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Trophies Earned")
                    .botanicalStyle(BotanicalTextStyle.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }
            
            HStack(spacing: 20) {
                // Trophy count display
                VStack(spacing: 8) {
                    Text("\(trophiesEarned)")
                        .botanicalStyle(BotanicalTextStyle.largeTitle)
                        .fontWeight(.bold)
                        .fontDesign(.monospaced)
                        .foregroundColor(.yellow)
                        .scaleEffect(showTrophyAnimation ? 1.2 : 1.0)
                    
                    Text("Trophies")
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Trophy breakdown
                VStack(alignment: .trailing, spacing: 4) {
                    TrophyBredownRow(
                        title: "Base Score",
                        amount: baseTrophies
                    )
                    
                    if accuracyBonus > 0 {
                        TrophyBredownRow(
                            title: "Accuracy Bonus",
                            amount: accuracyBonus
                        )
                    }
                    
                    if streakBonus > 0 {
                        TrophyBredownRow(
                            title: "Streak Bonus",
                            amount: streakBonus
                        )
                    }
                    
                    if completionBonus > 0 {
                        TrophyBredownRow(
                            title: "Completion Bonus",
                            amount: completionBonus
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showTrophyAnimation = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showTrophyAnimation = false
                }
            }
        }
    }
    
    private var baseTrophies: Int {
        session.correctAnswers * 5 // 5 trophies per correct answer
    }
    
    private var accuracyBonus: Int {
        if session.accuracy >= 0.9 {
            return 50
        } else if session.accuracy >= 0.8 {
            return 25
        } else if session.accuracy >= 0.7 {
            return 10
        }
        return 0
    }
    
    private var streakBonus: Int {
        let maxStreak = calculateMaxStreak()
        if maxStreak >= 10 {
            return 30
        } else if maxStreak >= 5 {
            return 15
        }
        return 0
    }
    
    private var completionBonus: Int {
        switch session.mode {
        case .speedrun:
            return session.questionsAnswered >= 25 ? 100 : 0
        case .beatTheClock:
            return session.questionsAnswered >= 15 ? 75 : 0
        case .multiplayer:
            return 0
        }
    }
    
    private func calculateMaxStreak() -> Int {
        var maxStreak = 0
        var currentStreak = 0
        
        for answer in session.answers {
            if answer.isCorrect {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return maxStreak
    }
}

// MARK: - Trophy Breakdown Row
struct TrophyBredownRow: View {
    let title: String
    let amount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(.secondary)
            
            Text("+\(amount)")
                .botanicalStyle(BotanicalTextStyle.caption)
                .fontWeight(.semibold)
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - Performance Analytics Card
struct PerformanceAnalyticsCard: View {
    let session: SingleUserGameSession
    @Binding var showDetails: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: { showDetails.toggle() }) {
                HStack {
                    Text("Performance Analytics")
                        .botanicalStyle(BotanicalTextStyle.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if showDetails {
                VStack(spacing: 12) {
                    AnalyticsRow(
                        title: "Total Time",
                        value: timeString(session.totalGameTime),
                        icon: "clock.fill"
                    )
                    
                    if session.totalPausedTime > 0 {
                        AnalyticsRow(
                            title: "Paused Time",
                            value: timeString(session.totalPausedTime),
                            icon: "pause.circle.fill"
                        )
                    }
                    
                    if session.questionsAnswered > 0 {
                        AnalyticsRow(
                            title: "Avg per Question",
                            value: String(format: "%.2fs", session.totalGameTime / Double(session.questionsAnswered)),
                            icon: "speedometer"
                        )
                    }
                    
                    AnalyticsRow(
                        title: "Questions Attempted",
                        value: "\(session.questionsAnswered)",
                        icon: "questionmark.circle.fill"
                    )
                    
                    AnalyticsRow(
                        title: "Success Rate",
                        value: String(format: "%.1f%%", session.accuracy * 100),
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .animation(.easeInOut(duration: 0.3), value: showDetails)
    }
    
    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Analytics Row
struct AnalyticsRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.botanicalGreen)
                .frame(width: 20)
            
            Text(title)
                .botanicalStyle(BotanicalTextStyle.body)
            
            Spacer()
            
            Text(value)
                .botanicalStyle(BotanicalTextStyle.body)
                .fontWeight(.semibold)
                .fontDesign(.monospaced)
        }
    }
}

// MARK: - Achievement Showcase Card
struct AchievementShowcaseCard: View {
    let session: SingleUserGameSession
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Achievements Unlocked")
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.semibold)
            
            let achievements = unlockedAchievements
            
            if achievements.isEmpty {
                EmptyAchievementsView()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(achievements, id: \.title) { achievement in
                        AchievementBadgeView(achievement: achievement)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var unlockedAchievements: [AchievementData] {
        var achievements: [AchievementData] = []
        
        // Accuracy achievements
        if session.accuracy >= 0.95 {
            achievements.append(AchievementData(
                title: "Perfectionist",
                description: "95%+ accuracy",
                icon: "star.fill",
                color: .yellow
            ))
        } else if session.accuracy >= 0.9 {
            achievements.append(AchievementData(
                title: "Expert",
                description: "90%+ accuracy",
                icon: "target",
                color: .green
            ))
        }
        
        // Speed achievements
        if session.mode == .speedrun && session.questionsAnswered > 0 {
            let avgTime = session.totalGameTime / Double(session.questionsAnswered)
            if avgTime < 2.0 {
                achievements.append(AchievementData(
                    title: "Lightning Fast",
                    description: "Under 2s per question",
                    icon: "bolt.fill",
                    color: .blue
                ))
            }
        }
        
        // Volume achievements
        if session.mode == .beatTheClock {
            if session.correctAnswers >= 20 {
                achievements.append(AchievementData(
                    title: "Speed Demon",
                    description: "20+ correct answers",
                    icon: "flame.fill",
                    color: .red
                ))
            } else if session.correctAnswers >= 15 {
                achievements.append(AchievementData(
                    title: "Quick Thinker",
                    description: "15+ correct answers",
                    icon: "brain.head.profile",
                    color: .orange
                ))
            }
        }
        
        // Completion achievements
        if session.mode == .speedrun && session.questionsAnswered >= 25 {
            achievements.append(AchievementData(
                title: "Marathon Runner",
                description: "Completed 25 questions",
                icon: "figure.run",
                color: .purple
            ))
        }
        
        return achievements
    }
}

// MARK: - Achievement Data
struct AchievementData {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

// MARK: - Achievement Badge View
struct AchievementBadgeView: View {
    let achievement: AchievementData
    @State private var badgeScale: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.title)
                .foregroundColor(achievement.color)
            
            VStack(spacing: 2) {
                Text(achievement.title)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(achievement.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(achievement.color, lineWidth: 1)
                )
        )
        .scaleEffect(badgeScale)
        .onAppear {
            let delay = Double.random(in: 0.1...0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    badgeScale = 1.0
                }
            }
        }
    }
}

// MARK: - Empty Achievements View
struct EmptyAchievementsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No achievements this time")
                .botanicalStyle(BotanicalTextStyle.body)
                .foregroundColor(.secondary)
            
            Text("Keep playing to unlock achievements!")
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Results Action Buttons
struct ResultsActionButtons: View {
    let session: SingleUserGameSession
    let onPlayAgain: () -> Void
    let onReturnToMenu: () -> Void
    let onViewLeaderboard: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            BotanicalButton(
                "Play Again",
                style: .primary,
                size: .large
            ) {
                onPlayAgain()
            }
            
            HStack(spacing: 12) {
                BotanicalButton(
                    "Leaderboard",
                    style: .secondary,
                    size: .medium
                ) {
                    onViewLeaderboard()
                }
                
                BotanicalButton(
                    "Main Menu",
                    style: .secondary,
                    size: .medium
                ) {
                    onReturnToMenu()
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Celebration Effects
struct CelebrationEffectsView: View {
    let mode: GameMode
    let isNewRecord: Bool
    
    var body: some View {
        ZStack {
            // Confetti or sparkles
            if isNewRecord {
                ConfettiView()
            }
            
            // Fireworks for exceptional performance
            FireworksView(color: modeColor)
        }
        .allowsHitTesting(false)
    }
    
    private var modeColor: Color {
        switch mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

// MARK: - Particle Effects
struct ParticleEffectView: View {
    let color: Color
    
    var body: some View {
        // Simplified particle effect
        ZStack {
            ForEach(0..<20, id: \.self) { _ in
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        .linear(duration: Double.random(in: 2...5))
                        .repeatForever(autoreverses: false),
                        value: UUID()
                    )
            }
        }
    }
}

// MARK: - Confetti View
struct ConfettiView: View {
    var body: some View {
        Text("🎉")
            .font(.system(size: 100))
            .opacity(0.8)
    }
}

// MARK: - Fireworks View
struct FireworksView: View {
    let color: Color
    
    var body: some View {
        Text("✨")
            .font(.system(size: 60))
            .opacity(0.7)
    }
}

#Preview {
    GameResultsScreen(
        session: SingleUserGameSession(mode: .beatTheClock, difficulty: .medium),
        finalScore: BeatTheClockScore(
            id: "1",
            difficulty: .medium,
            correctAnswers: 15,
            totalAnswers: 18,
            timeUsed: 60.0,
            accuracy: 0.83,
            pointsPerSecond: 0.25,
            achievedAt: Date(),
            isNewRecord: true
        ),
        personalBest: nil,
        isNewPersonalBest: true,
        trophiesEarned: 150,
        onPlayAgain: {},
        onReturnToMenu: {},
        onViewLeaderboard: {}
    )
}