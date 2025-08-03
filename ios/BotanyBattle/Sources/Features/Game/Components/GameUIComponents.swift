import SwiftUI

// MARK: - Game Timer View

struct GameTimerView: View {
    let timeRemaining: Int
    let totalTime: Int
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalTime)
    }
    
    var isUrgent: Bool {
        return timeRemaining <= 10
    }
    
    var timerColor: Color {
        if isUrgent {
            return .red
        } else if timeRemaining <= 20 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundColor(timerColor)
                .font(.headline)
            
            Text("\(timeRemaining)s")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(timerColor)
                .monospacedDigit()
            
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(timerColor, lineWidth: 3)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: progress)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(timerColor.opacity(0.1))
        .cornerRadius(20)
        .scaleEffect(isUrgent ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isUrgent)
    }
}

// MARK: - Game Score View

struct GameScoreView: View {
    let score: Int
    let currentRound: Int
    let totalRounds: Int
    
    var roundProgress: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(currentRound) / Double(totalRounds)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Score: \(score)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("Round \(currentRound)/\(totalRounds)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: roundProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(x: 1, y: 1.5)
        }
    }
}

// MARK: - Plant Image View

struct PlantImageView: View {
    let imageURL: String
    let plantName: String
    @State private var imageLoadError = false
    
    var showPlaceholder: Bool {
        return imageURL.isEmpty || imageLoadError
    }
    
    var body: some View {
        Group {
            if showPlaceholder {
                PlantImagePlaceholder(plantName: plantName)
            } else {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    PlantImagePlaceholder(plantName: plantName, isLoading: true)
                }
                .onFailure {
                    imageLoadError = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .clipped()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green, lineWidth: 2)
        )
    }
}

struct PlantImagePlaceholder: View {
    let plantName: String
    var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                Text("🌱")
                    .font(.system(size: 60))
            }
            
            Text(isLoading ? "Loading..." : "Image unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Answer Option Button

struct AnswerOptionButton: View {
    let option: String
    let isSelected: Bool
    let isCorrect: Bool
    let showResult: Bool
    let action: () -> Void
    
    enum ButtonState {
        case normal
        case selected
        case correctSelected
        case incorrectSelected
        case correctNotSelected
        case disabled
    }
    
    var buttonState: ButtonState {
        if !showResult {
            return isSelected ? .selected : .normal
        }
        
        if isSelected {
            return isCorrect ? .correctSelected : .incorrectSelected
        } else if isCorrect {
            return .correctNotSelected
        } else {
            return .disabled
        }
    }
    
    var backgroundColor: Color {
        switch buttonState {
        case .normal:
            return Color(.systemGray6)
        case .selected:
            return Color.blue.opacity(0.3)
        case .correctSelected, .correctNotSelected:
            return Color.green
        case .incorrectSelected:
            return Color.red
        case .disabled:
            return Color(.systemGray5)
        }
    }
    
    var textColor: Color {
        switch buttonState {
        case .normal, .selected:
            return .primary
        case .correctSelected, .incorrectSelected, .correctNotSelected:
            return .white
        case .disabled:
            return .secondary
        }
    }
    
    var iconName: String? {
        switch buttonState {
        case .correctSelected, .correctNotSelected:
            return "checkmark.circle.fill"
        case .incorrectSelected:
            return "xmark.circle.fill"
        default:
            return nil
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(option)
                    .font(.headline)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if let iconName = iconName {
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected && !showResult ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .disabled(showResult)
        .animation(.easeInOut(duration: 0.3), value: buttonState)
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    let feedback: GameFeedback
    
    var body: some View {
        if feedback.showFeedback {
            VStack(spacing: 12) {
                // Result header
                HStack {
                    Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(feedback.isCorrect ? .green : .red)
                        .font(.title2)
                    
                    Text(feedback.isCorrect ? "Correct!" : "Incorrect")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(feedback.isCorrect ? .green : .red)
                    
                    Spacer()
                }
                
                // Correct answer (if incorrect)
                if !feedback.isCorrect {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("Correct answer:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(feedback.correctAnswer)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Spacer()
                    }
                }
                
                // Explanation
                if !feedback.explanation.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Text(feedback.explanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Game Progress Header

struct GameProgressHeader: View {
    let progress: GameProgress
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Question \(progress.currentQuestion)/\(progress.totalQuestions)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Score: \(progress.score)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                if progress.totalTime > 0 {
                    GameTimerView(
                        timeRemaining: progress.timeRemaining,
                        totalTime: progress.totalTime
                    )
                }
            }
            
            // Progress bar
            ProgressView(value: progress.questionProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(x: 1, y: 2)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Game Results View

struct GameResultsView: View {
    let gameMode: GameMode
    let finalScore: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let elapsedTime: TimeInterval?
    let onPlayAgain: () -> Void
    let onExit: () -> Void
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var accuracy: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(correctAnswers) / Double(totalQuestions)
    }
    
    var performanceMessage: String {
        switch accuracy {
        case 1.0: return "Perfect! You're a true botanist! 🌟"
        case 0.8...0.99: return "Excellent work! You know your plants! 🌿"
        case 0.6...0.79: return "Good job! Keep learning about plants! 🌱"
        case 0.4...0.59: return "Not bad! Practice makes perfect! 🌳"
        default: return "Keep trying! Every expert was once a beginner! 🌿"
        }
    }
    
    var performanceColor: Color {
        switch accuracy {
        case 0.8...1.0: return .green
        case 0.6...0.79: return .orange
        default: return .red
        }
    }
    
    var formattedTime: String {
        guard let elapsedTime = elapsedTime else { return "" }
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        
        NavigationView {
            ScrollView {
                VStack(spacing: isLandscape ? 16 : 24) {
                    Spacer(minLength: isLandscape ? 10 : 20)
                    
                    // Header
                    VStack(spacing: 12) {
                        Text("🎉")
                            .font(.system(size: isLandscape ? 40 : 60))
                        
                        Text("Game Complete!")
                            .font(isLandscape ? .title2 : .title)
                            .fontWeight(.bold)
                        
                        Text(gameMode.rawValue)
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Score
                    VStack(spacing: 8) {
                        Text("Your Score")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("\(finalScore)")
                            .font(.system(size: isLandscape ? 36 : 48, weight: .bold, design: .rounded))
                            .foregroundColor(performanceColor)
                    }
                    
                    // Statistics
                    GameResultsStatsView(
                        correctAnswers: correctAnswers,
                        totalQuestions: totalQuestions,
                        accuracy: accuracy,
                        elapsedTime: elapsedTime,
                        performanceColor: performanceColor,
                        isCompact: isLandscape
                    )
                    
                    // Performance Message
                    Text(performanceMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .foregroundColor(performanceColor)
                        .padding()
                        .background(performanceColor.opacity(0.1))
                        .cornerRadius(12)
                    
                    Spacer(minLength: isLandscape ? 10 : 20)
                    
                    // Action Buttons
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
                }
                .padding()
            }
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Game Results Stats View

struct GameResultsStatsView: View {
    let correctAnswers: Int
    let totalQuestions: Int
    let accuracy: Double
    let elapsedTime: TimeInterval?
    let performanceColor: Color
    let isCompact: Bool
    
    var formattedTime: String {
        guard let elapsedTime = elapsedTime else { return "" }
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: isCompact ? 4 : 2)
        
        LazyVGrid(columns: columns, spacing: 16) {
            StatCard(
                title: "Correct",
                value: "\(correctAnswers)",
                color: .green,
                isCompact: isCompact
            )
            
            StatCard(
                title: "Wrong",
                value: "\(totalQuestions - correctAnswers)",
                color: .red,
                isCompact: isCompact
            )
            
            StatCard(
                title: "Accuracy",
                value: String(format: "%.0f%%", accuracy * 100),
                color: performanceColor,
                isCompact: isCompact
            )
            
            if elapsedTime != nil {
                StatCard(
                    title: "Time",
                    value: formattedTime,
                    color: .blue,
                    isCompact: isCompact
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let isCompact: Bool
    
    var body: some View {
        VStack(spacing: isCompact ? 4 : 8) {
            Text(value)
                .font(isCompact ? .headline : .title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(isCompact ? .caption : .caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Data Models

struct GameFeedback {
    let isCorrect: Bool
    let correctAnswer: String
    let explanation: String
    let showFeedback: Bool
}

struct GameProgress {
    let currentQuestion: Int
    let totalQuestions: Int
    let score: Int
    let timeRemaining: Int
    let totalTime: Int
    
    var questionProgress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentQuestion) / Double(totalQuestions)
    }
}

enum GameMode: String, CaseIterable {
    case practice = "Practice"
    case timeAttack = "Time Attack"
    case speedrun = "Speedrun"
    case multiplayer = "Multiplayer"
}

// MARK: - AsyncImage Extension

extension AsyncImage {
    func onFailure(_ action: @escaping () -> Void) -> some View {
        self.overlay(
            EmptyView()
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AsyncImageLoadFailed"))) { _ in
                    action()
                }
        )
    }
}

// MARK: - Preview

#Preview("Game Timer") {
    VStack(spacing: 20) {
        GameTimerView(timeRemaining: 45, totalTime: 60)
        GameTimerView(timeRemaining: 15, totalTime: 60)
        GameTimerView(timeRemaining: 5, totalTime: 60)
    }
    .padding()
}

#Preview("Answer Options") {
    VStack(spacing: 12) {
        AnswerOptionButton(
            option: "Rosa rubiginosa",
            isSelected: false,
            isCorrect: false,
            showResult: false
        ) {}
        
        AnswerOptionButton(
            option: "Helianthus annuus",
            isSelected: true,
            isCorrect: true,
            showResult: true
        ) {}
        
        AnswerOptionButton(
            option: "Quercus alba",
            isSelected: true,
            isCorrect: false,
            showResult: true
        ) {}
        
        AnswerOptionButton(
            option: "Acer saccharum",
            isSelected: false,
            isCorrect: true,
            showResult: true
        ) {}
    }
    .padding()
}