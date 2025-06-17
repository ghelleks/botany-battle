import SwiftUI

struct AnswerOptionsView: View {
    let options: [String]
    let selectedAnswer: String?
    let hasAnswered: Bool
    let canAnswer: Bool
    let correctAnswer: String?
    let mode: GameMode?
    let timeRemaining: TimeInterval?
    let onAnswer: (String) -> Void
    
    @State private var buttonStates: [String: ButtonState] = [:]
    @State private var showShuffleAnimation = false
    
    init(
        options: [String],
        selectedAnswer: String?,
        hasAnswered: Bool,
        canAnswer: Bool,
        correctAnswer: String? = nil,
        mode: GameMode? = nil,
        timeRemaining: TimeInterval? = nil,
        onAnswer: @escaping (String) -> Void
    ) {
        self.options = options
        self.selectedAnswer = selectedAnswer
        self.hasAnswered = hasAnswered
        self.canAnswer = canAnswer
        self.correctAnswer = correctAnswer
        self.mode = mode
        self.timeRemaining = timeRemaining
        self.onAnswer = onAnswer
    }
    
    enum ButtonState {
        case normal
        case selected
        case correct
        case incorrect
        case disabled
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Question prompt with mode-specific styling
            QuestionPrompt(
                mode: mode,
                timeRemaining: timeRemaining,
                hasAnswered: hasAnswered
            )
            
            // Answer grid
            LazyVGrid(
                columns: gridColumns,
                spacing: 12
            ) {
                ForEach(options, id: \.self) { option in
                    AnswerOptionButton(
                        text: option,
                        state: buttonState(for: option),
                        mode: mode,
                        isEnabled: canAnswer,
                        animationDelay: animationDelay(for: option)
                    ) {
                        handleAnswerSelection(option)
                    }
                }
            }
            
            // Answer feedback section
            if hasAnswered, let correct = correctAnswer {
                AnswerFeedbackSection(
                    selectedAnswer: selectedAnswer,
                    correctAnswer: correct,
                    mode: mode
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: hasAnswered)
        .onAppear {
            initializeButtonStates()
        }
        .onChange(of: options) { _, _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                showShuffleAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                initializeButtonStates()
                showShuffleAnimation = false
            }
        }
    }
    
    // MARK: - Grid Configuration
    
    private var gridColumns: [GridItem] {
        if options.count <= 2 {
            return [GridItem(.flexible())]
        } else {
            return [
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
        }
    }
    
    // MARK: - Button State Logic
    
    private func buttonState(for option: String) -> ButtonState {
        if !canAnswer && !hasAnswered {
            return .disabled
        }
        
        if hasAnswered {
            if let correct = correctAnswer {
                if option == correct {
                    return .correct
                } else if option == selectedAnswer {
                    return .incorrect
                } else {
                    return .disabled
                }
            }
        }
        
        if selectedAnswer == option {
            return .selected
        }
        
        return .normal
    }
    
    private func initializeButtonStates() {
        for option in options {
            buttonStates[option] = .normal
        }
    }
    
    private func handleAnswerSelection(_ option: String) {
        guard canAnswer else { return }
        
        // Immediate visual feedback
        withAnimation(.easeOut(duration: 0.2)) {
            buttonStates[option] = .selected
        }
        
        // Haptic feedback based on mode
        if let mode = mode {
            switch mode {
            case .multiplayer:
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            case .beatTheClock:
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            case .speedrun:
                let impact = UIImpactFeedbackGenerator(style: .rigid)
                impact.impactOccurred()
            }
        }
        
        onAnswer(option)
    }
    
    private func animationDelay(for option: String) -> Double {
        guard let index = options.firstIndex(of: option) else { return 0 }
        return Double(index) * 0.1
    }
}

// MARK: - Question Prompt
struct QuestionPrompt: View {
    let mode: GameMode?
    let timeRemaining: TimeInterval?
    let hasAnswered: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("What plant is this?")
                    .botanicalStyle(BotanicalTextStyle.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let mode = mode, mode != .multiplayer {
                    ModeIndicator(mode: mode)
                }
            }
            
            if let urgencyMessage = urgencyMessage {
                Text(urgencyMessage)
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(urgencyColor)
                    .fontWeight(.medium)
            }
        }
    }
    
    private var urgencyMessage: String? {
        guard let mode = mode, let time = timeRemaining else { return nil }
        
        switch mode {
        case .beatTheClock:
            if time <= 5 {
                return "Time almost up!"
            } else if time <= 15 {
                return "Hurry up!"
            }
        case .speedrun:
            if !hasAnswered {
                return "Speed matters!"
            }
        case .multiplayer:
            if time <= 3 {
                return "Time's running out!"
            }
        }
        
        return nil
    }
    
    private var urgencyColor: Color {
        guard let time = timeRemaining else { return .primary }
        
        if time <= 5 {
            return .red
        } else if time <= 15 {
            return .orange
        } else {
            return .yellow
        }
    }
}

// MARK: - Mode Indicator
struct ModeIndicator: View {
    let mode: GameMode
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(mode.displayName)
                .botanicalStyle(BotanicalTextStyle.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundColor(color)
    }
    
    private var icon: String {
        switch mode {
        case .multiplayer: return "person.2.fill"
        case .beatTheClock: return "timer"
        case .speedrun: return "bolt.fill"
        }
    }
    
    private var color: Color {
        switch mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

// MARK: - Answer Option Button
struct AnswerOptionButton: View {
    let text: String
    let state: AnswerOptionsView.ButtonState
    let mode: GameMode?
    let isEnabled: Bool
    let animationDelay: Double
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var hasAppeared = false
    
    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            Text(text)
                .botanicalStyle(BotanicalTextStyle.body)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .scaleEffect(isPressed ? 0.95 : (hasAppeared ? 1.0 : 0.9))
                .opacity(hasAppeared ? 1.0 : 0.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .answerOptionAccessibility(
            option: text,
            isSelected: state == .selected,
            isCorrect: state == .correct ? true : nil,
            isWrong: state == .incorrect ? true : nil,
            hasAnswered: state == .correct || state == .incorrect
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    hasAppeared = true
                }
            }
        }
    }
    
    // MARK: - Button Styling
    
    private var backgroundColor: Color {
        switch state {
        case .normal:
            return Color(.systemBackground)
        case .selected:
            return modeColor.opacity(0.2)
        case .correct:
            return Color.green.opacity(0.2)
        case .incorrect:
            return Color.red.opacity(0.2)
        case .disabled:
            return Color(.systemGray6)
        }
    }
    
    private var textColor: Color {
        switch state {
        case .normal:
            return .primary
        case .selected:
            return modeColor
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .disabled:
            return .secondary
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .normal:
            return Color(.systemGray4)
        case .selected:
            return modeColor
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .disabled:
            return Color(.systemGray5)
        }
    }
    
    private var borderWidth: CGFloat {
        switch state {
        case .normal, .disabled:
            return 1
        case .selected, .correct, .incorrect:
            return 2
        }
    }
    
    private var modeColor: Color {
        guard let mode = mode else { return .botanicalGreen }
        
        switch mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

// MARK: - Answer Feedback Section
struct AnswerFeedbackSection: View {
    let selectedAnswer: String?
    let correctAnswer: String
    let mode: GameMode?
    
    var body: some View {
        VStack(spacing: 12) {
            // Feedback header
            HStack(spacing: 8) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCorrect ? .green : .red)
                
                Text(feedbackText)
                    .botanicalStyle(BotanicalTextStyle.headline)
                    .foregroundColor(isCorrect ? .green : .red)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let mode = mode, mode != .multiplayer {
                    ScoreIndicator(mode: mode, isCorrect: isCorrect)
                }
            }
            
            // Show correct answer if incorrect
            if !isCorrect {
                HStack {
                    Text("Correct answer:")
                        .botanicalStyle(BotanicalTextStyle.body)
                        .foregroundColor(.secondary)
                    
                    Text(correctAnswer)
                        .botanicalStyle(BotanicalTextStyle.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var isCorrect: Bool {
        selectedAnswer == correctAnswer
    }
    
    private var feedbackText: String {
        if isCorrect {
            return "Correct!"
        } else {
            return "Incorrect"
        }
    }
}

// MARK: - Score Indicator
struct ScoreIndicator: View {
    let mode: GameMode
    let isCorrect: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.caption)
                .foregroundColor(modeColor)
            
            Text("+\(pointsEarned)")
                .botanicalStyle(BotanicalTextStyle.caption)
                .fontWeight(.bold)
                .foregroundColor(modeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(modeColor.opacity(0.15))
        )
    }
    
    private var pointsEarned: Int {
        guard isCorrect else { return 0 }
        
        switch mode {
        case .multiplayer:
            return 100
        case .beatTheClock:
            return 1
        case .speedrun:
            return 50
        }
    }
    
    private var modeColor: Color {
        switch mode {
        case .multiplayer: return .botanicalGreen
        case .beatTheClock: return .orange
        case .speedrun: return .blue
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            AnswerOptionsView(
                options: ["Rose", "Tulip", "Sunflower", "Daisy"],
                selectedAnswer: nil,
                hasAnswered: false,
                canAnswer: true,
                mode: .beatTheClock,
                timeRemaining: 45.0
            ) { answer in
                print("Selected: \(answer)")
            }
            
            AnswerOptionsView(
                options: ["Oak Tree", "Maple Tree", "Pine Tree", "Birch Tree"],
                selectedAnswer: "Maple Tree",
                hasAnswered: true,
                canAnswer: false,
                correctAnswer: "Oak Tree",
                mode: .speedrun
            ) { answer in
                print("Selected: \(answer)")
            }
        }
        .padding()
    }
}