import SwiftUI

struct GameStatsOverlay: View {
    let session: SingleUserGameSession?
    let game: Game?
    let mode: GameMode
    let isVisible: Bool
    let onDismiss: () -> Void
    
    @State private var animationOffset: CGFloat = -100
    @State private var backgroundOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .opacity(backgroundOpacity)
                .onTapGesture {
                    dismissOverlay()
                }
            
            // Stats panel
            VStack(spacing: 0) {
                StatsHeader(mode: mode, onDismiss: dismissOverlay)
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let session = session {
                            SingleUserStatsContent(session: session, mode: mode)
                        } else if let game = game {
                            MultiplayerStatsContent(game: game)
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(16, corners: [.topLeft, .topRight])
            .offset(y: animationOffset)
        }
        .ignoresSafeArea()
        .onAppear {
            showOverlay()
        }
        .onChange(of: isVisible) { _, visible in
            if visible {
                showOverlay()
            } else {
                dismissOverlay()
            }
        }
    }
    
    private func showOverlay() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            animationOffset = 0
            backgroundOpacity = 1
        }
    }
    
    private func dismissOverlay() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            animationOffset = -100
            backgroundOpacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Stats Header
struct StatsHeader: View {
    let mode: GameMode
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Game Stats")
                    .botanicalStyle(BotanicalTextStyle.title2)
                    .fontWeight(.bold)
                
                Text(mode.displayName)
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Single User Stats Content
struct SingleUserStatsContent: View {
    let session: SingleUserGameSession
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 24) {
            // Performance Overview
            PerformanceOverviewCard(session: session, mode: mode)
            
            // Detailed Stats
            DetailedStatsCard(session: session, mode: mode)
            
            // Progress Chart
            if session.questionsAnswered > 0 {
                ProgressChartCard(session: session, mode: mode)
            }
            
            // Achievement Indicators
            AchievementIndicatorsCard(session: session, mode: mode)
        }
    }
}

// MARK: - Performance Overview Card
struct PerformanceOverviewCard: View {
    let session: SingleUserGameSession
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Performance Overview")
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                OverviewStatItem(
                    title: "Score",
                    value: "\(session.score)",
                    icon: "star.fill",
                    color: .orange
                )
                
                OverviewStatItem(
                    title: "Accuracy",
                    value: String(format: "%.1f%%", session.accuracy * 100),
                    icon: "target",
                    color: .blue
                )
                
                OverviewStatItem(
                    title: modeSpecificTitle,
                    value: modeSpecificValue,
                    icon: modeSpecificIcon,
                    color: modeSpecificColor
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var modeSpecificTitle: String {
        switch mode {
        case .beatTheClock: return "Per Min"
        case .speedrun: return "Speed"
        case .multiplayer: return "Bonus"
        }
    }
    
    private var modeSpecificValue: String {
        switch mode {
        case .beatTheClock:
            let perMinute = session.totalGameTime > 0 ? (Double(session.correctAnswers) / session.totalGameTime) * 60 : 0
            return String(format: "%.1f", perMinute)
        case .speedrun:
            let avgTime = session.questionsAnswered > 0 ? session.totalGameTime / Double(session.questionsAnswered) : 0
            return String(format: "%.1fs", avgTime)
        case .multiplayer:
            return "N/A"
        }
    }
    
    private var modeSpecificIcon: String {
        switch mode {
        case .beatTheClock: return "clock.fill"
        case .speedrun: return "bolt.fill"
        case .multiplayer: return "gift.fill"
        }
    }
    
    private var modeSpecificColor: Color {
        switch mode {
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        case .multiplayer: return .purple
        }
    }
}

// MARK: - Overview Stat Item
struct OverviewStatItem: View {
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
                .botanicalStyle(BotanicalTextStyle.title3)
                .fontWeight(.bold)
                .fontDesign(.monospaced)
            
            Text(title)
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detailed Stats Card
struct DetailedStatsCard: View {
    let session: SingleUserGameSession
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Detailed Statistics")
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DetailStatRow(
                    title: "Questions Answered",
                    value: "\(session.questionsAnswered)",
                    icon: "questionmark.circle.fill"
                )
                
                DetailStatRow(
                    title: "Correct Answers",
                    value: "\(session.correctAnswers)",
                    icon: "checkmark.circle.fill"
                )
                
                DetailStatRow(
                    title: "Total Time",
                    value: timeString(session.totalGameTime),
                    icon: "clock.fill"
                )
                
                if session.totalPausedTime > 0 {
                    DetailStatRow(
                        title: "Paused Time",
                        value: timeString(session.totalPausedTime),
                        icon: "pause.circle.fill"
                    )
                }
                
                if mode == .speedrun && session.questionsAnswered > 0 {
                    DetailStatRow(
                        title: "Average per Question",
                        value: String(format: "%.2fs", session.totalGameTime / Double(session.questionsAnswered)),
                        icon: "speedometer"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Detail Stat Row
struct DetailStatRow: View {
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

// MARK: - Progress Chart Card
struct ProgressChartCard: View {
    let session: SingleUserGameSession
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Answer Timeline")
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.semibold)
            
            AnswerTimelineChart(answers: session.answers, mode: mode)
                .frame(height: 120)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Answer Timeline Chart
struct AnswerTimelineChart: View {
    let answers: [SingleUserAnswer]
    let mode: GameMode
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(answers.enumerated()), id: \.offset) { index, answer in
                    let height = geometry.size.height * (answer.isCorrect ? 1.0 : 0.3)
                    
                    Rectangle()
                        .fill(answer.isCorrect ? Color.green : Color.red)
                        .frame(
                            width: max(2, geometry.size.width / CGFloat(max(answers.count, 10))),
                            height: height
                        )
                        .cornerRadius(1)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .overlay(
            HStack {
                Text("Incorrect")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text("Correct")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.green)
            },
            alignment: .top
        )
    }
}

// MARK: - Achievement Indicators Card
struct AchievementIndicatorsCard: View {
    let session: SingleUserGameSession
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Achievements")
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(achievements, id: \.title) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var achievements: [Achievement] {
        var results: [Achievement] = []
        
        // Accuracy achievements
        if session.accuracy >= 0.9 {
            results.append(Achievement(
                title: "Perfect Score",
                description: "90%+ accuracy",
                icon: "star.fill",
                color: .yellow,
                isUnlocked: true
            ))
        }
        
        // Speed achievements (for speedrun mode)
        if mode == .speedrun && session.questionsAnswered > 0 {
            let avgTime = session.totalGameTime / Double(session.questionsAnswered)
            if avgTime < 3.0 {
                results.append(Achievement(
                    title: "Lightning Fast",
                    description: "Under 3s per question",
                    icon: "bolt.fill",
                    color: .blue,
                    isUnlocked: true
                ))
            }
        }
        
        // Volume achievements (for beat the clock)
        if mode == .beatTheClock && session.correctAnswers >= 15 {
            results.append(Achievement(
                title: "Speed Demon",
                description: "15+ correct in 60s",
                icon: "flame.fill",
                color: .orange,
                isUnlocked: true
            ))
        }
        
        // Consistency achievements
        let recentAnswers = session.answers.suffix(5)
        if recentAnswers.count == 5 && recentAnswers.allSatisfy({ $0.isCorrect }) {
            results.append(Achievement(
                title: "Hot Streak",
                description: "5 correct in a row",
                icon: "fire.fill",
                color: .red,
                isUnlocked: true
            ))
        }
        
        return results
    }
}

// MARK: - Achievement Data
struct Achievement {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(achievement.isUnlocked ? achievement.color : .gray)
            
            VStack(spacing: 2) {
                Text(achievement.title)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(achievement.description)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(achievement.isUnlocked ? achievement.color.opacity(0.1) : Color(.systemGray5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(achievement.isUnlocked ? achievement.color : .gray, lineWidth: 1)
        )
        .saturation(achievement.isUnlocked ? 1.0 : 0.3)
    }
}

// MARK: - Multiplayer Stats Content
struct MultiplayerStatsContent: View {
    let game: Game
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Multiplayer stats coming soon...")
                .botanicalStyle(BotanicalTextStyle.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    GameStatsOverlay(
        session: SingleUserGameSession(mode: .beatTheClock, difficulty: .medium),
        game: nil,
        mode: .beatTheClock,
        isVisible: true
    ) {
        print("Dismissed")
    }
}