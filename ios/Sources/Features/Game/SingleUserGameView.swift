import SwiftUI
import ComposableArchitecture

struct SingleUserGameView: View {
    let store: StoreOf<GameFeature>
    let session: SingleUserGameSession
    
    var body: some View {
        VStack(spacing: 0) {
            // Game Header
            SingleUserGameHeader(
                session: session,
                timeRemaining: store.timeRemaining,
                gameProgress: store.gameProgress,
                onPause: { store.send(.pauseGame) },
                onResume: { store.send(.resumeGame) },
                onLeave: { store.send(.leaveGame) }
            )
            
            // Plant Question Area
            if let question = store.currentQuestion {
                PlantQuestionView(
                    plant: question.plant,
                    options: question.options,
                    selectedAnswer: store.selectedAnswer,
                    hasAnswered: store.hasAnswered,
                    canAnswer: store.canAnswer,
                    mode: session.mode
                ) { answer in
                    store.send(.submitAnswer(answer))
                }
            } else {
                LoadingQuestionView(mode: session.mode)
            }
            
            // Game Stats Footer
            SingleUserGameStats(session: session)
        }
        .background(Color(.systemBackground))
        .alert("Game Paused", isPresented: .constant(store.isPaused)) {
            Button("Resume") {
                store.send(.resumeGame)
            }
            Button("Leave Game") {
                store.send(.leaveGame)
            }
        } message: {
            Text("Game is paused. Choose an option to continue.")
        }
    }
}

// MARK: - Single User Game Header
struct SingleUserGameHeader: View {
    let session: SingleUserGameSession
    let timeRemaining: TimeInterval
    let gameProgress: Double
    let onPause: () -> Void
    let onResume: () -> Void
    let onLeave: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onLeave) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(session.mode.displayName)
                        .botanicalStyle(BotanicalTextStyle.headline)
                    Text(session.difficulty.displayName)
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if session.state == .active {
                    Button(action: onPause) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                            .foregroundColor(.botanicalGreen)
                    }
                } else {
                    Button(action: onResume) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundColor(.botanicalGreen)
                    }
                }
            }
            
            // Progress and Timer
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progressText)
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: gameProgress)
                        .tint(.botanicalGreen)
                        .frame(height: 4)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timerLabel)
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                    
                    Text(timerText)
                        .botanicalStyle(BotanicalTextStyle.headline)
                        .fontDesign(.monospaced)
                        .foregroundColor(timerColor)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var progressText: String {
        switch session.mode {
        case .beatTheClock:
            return "Answered: \(session.questionsAnswered)"
        case .speedrun:
            return "Progress: \(session.questionsAnswered)/25"
        case .multiplayer:
            return ""
        }
    }
    
    private var timerLabel: String {
        switch session.mode {
        case .beatTheClock:
            return "Time Left"
        case .speedrun:
            return "Elapsed Time"
        case .multiplayer:
            return ""
        }
    }
    
    private var timerText: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var timerColor: Color {
        switch session.mode {
        case .beatTheClock:
            return timeRemaining < 10 ? .red : .primary
        case .speedrun:
            return .primary
        case .multiplayer:
            return .primary
        }
    }
}

// MARK: - Plant Question View
struct PlantQuestionView: View {
    let plant: Plant
    let options: [String]
    let selectedAnswer: String?
    let hasAnswered: Bool
    let canAnswer: Bool
    let mode: GameMode
    let onAnswer: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Plant Image
            AsyncImage(url: URL(string: plant.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        ProgressView()
                            .tint(.botanicalGreen)
                    )
            }
            .frame(maxHeight: .infinity)
            .clipped()
            
            // Answer Options
            VStack(spacing: 12) {
                Text("What plant is this?")
                    .botanicalStyle(BotanicalTextStyle.title2)
                    .padding(.top)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        AnswerButton(
                            text: option,
                            isSelected: selectedAnswer == option,
                            isCorrect: hasAnswered && option == plant.primaryCommonName,
                            isWrong: hasAnswered && selectedAnswer == option && option != plant.primaryCommonName,
                            isEnabled: canAnswer
                        ) {
                            onAnswer(option)
                        }
                    }
                }
                
                if hasAnswered {
                    AnswerFeedbackView(
                        isCorrect: selectedAnswer == plant.primaryCommonName,
                        correctAnswer: plant.primaryCommonName,
                        plant: plant
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Answer Button
struct AnswerButton: View {
    let text: String
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .botanicalStyle(BotanicalTextStyle.body)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
    
    private var backgroundColor: Color {
        if isCorrect {
            return .green.opacity(0.2)
        } else if isWrong {
            return .red.opacity(0.2)
        } else if isSelected {
            return .botanicalGreen.opacity(0.1)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var textColor: Color {
        if isCorrect {
            return .green
        } else if isWrong {
            return .red
        } else {
            return .primary
        }
    }
    
    private var borderColor: Color {
        if isCorrect {
            return .green
        } else if isWrong {
            return .red
        } else if isSelected {
            return .botanicalGreen
        } else {
            return Color(.systemGray4)
        }
    }
}

// MARK: - Answer Feedback View
struct AnswerFeedbackView: View {
    let isCorrect: Bool
    let correctAnswer: String
    let plant: Plant
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isCorrect ? .green : .red)
                
                Text(isCorrect ? "Correct!" : "Incorrect")
                    .botanicalStyle(BotanicalTextStyle.headline)
                    .foregroundColor(isCorrect ? .green : .red)
            }
            
            if !isCorrect {
                Text("The correct answer is: \(correctAnswer)")
                    .botanicalStyle(BotanicalTextStyle.body)
                    .foregroundColor(.secondary)
            }
            
            if let fact = plant.interestingFact {
                Text(fact)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Loading Question View
struct LoadingQuestionView: View {
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(.botanicalGreen)
            
            Text("Loading next question...")
                .botanicalStyle(BotanicalTextStyle.title2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Single User Game Stats
struct SingleUserGameStats: View {
    let session: SingleUserGameSession
    
    var body: some View {
        HStack(spacing: 24) {
            StatItem(
                title: "Score",
                value: "\(session.score)",
                icon: "star.fill",
                color: .orange
            )
            
            StatItem(
                title: "Accuracy",
                value: String(format: "%.1f%%", session.accuracy * 100),
                icon: "target",
                color: .blue
            )
            
            StatItem(
                title: "Correct",
                value: "\(session.correctAnswers)/\(session.questionsAnswered)",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text(value)
                .botanicalStyle(BotanicalTextStyle.headline)
                .fontDesign(.monospaced)
            
            Text(title)
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SingleUserGameView(
        store: Store(
            initialState: GameFeature.State(),
            reducer: { GameFeature() }
        ),
        session: SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
    )
}