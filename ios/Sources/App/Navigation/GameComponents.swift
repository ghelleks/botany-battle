import SwiftUI

// MARK: - Difficulty Button
struct DifficultyButton: View {
    let title: String
    let timeLimit: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .botanicalStyle(BotanicalTextStyle.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(timeLimit)
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.botanicalGreen : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Game History Card
struct GameHistoryCard: View {
    let game: Game
    
    private var userPlayer: Game.Player? {
        // In a real app, this would check the current user ID
        game.players.first
    }
    
    private var opponentPlayer: Game.Player? {
        game.players.first { $0.id != userPlayer?.id }
    }
    
    private var gameResult: String {
        guard let user = userPlayer, let opponent = opponentPlayer else {
            return "Unknown"
        }
        
        if user.score > opponent.score {
            return "Victory"
        } else if user.score < opponent.score {
            return "Defeat"
        } else {
            return "Draw"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("vs \(opponentPlayer?.username ?? "Unknown")")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                
                Text("\(userPlayer?.score ?? 0) - \(opponentPlayer?.score ?? 0)")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(gameResult)
                .botanicalStyle(BotanicalTextStyle.caption)
                .foregroundColor(gameResult == "Victory" ? .green : gameResult == "Defeat" ? .red : .orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Game Progress Header
struct GameProgressHeader: View {
    let currentRound: Int
    let totalRounds: Int
    let timeRemaining: TimeInterval
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Round \(currentRound) of \(totalRounds)")
                    .botanicalStyle(BotanicalTextStyle.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(timeRemaining < 5 ? .red : .botanicalGreen)
                    
                    Text("\(Int(timeRemaining))s")
                        .botanicalStyle(BotanicalTextStyle.headline)
                        .foregroundColor(timeRemaining < 5 ? .red : .botanicalGreen)
                        .monospacedDigit()
                }
            }
            
            ProgressView(value: Double(currentRound), total: Double(totalRounds))
                .tint(.botanicalGreen)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Plant Image View
struct PlantImageView: View {
    let plant: Plant
    
    var body: some View {
        AsyncImage(url: URL(string: plant.imageUrl)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } placeholder: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .overlay(
                    VStack {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.botanicalGreen)
                        
                        Text("Loading plant...")
                            .botanicalStyle(BotanicalTextStyle.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
        .padding()
    }
}

// MARK: - Answer Options View
struct AnswerOptionsView: View {
    let options: [String]
    let selectedAnswer: String?
    let hasAnswered: Bool
    let canAnswer: Bool
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(options, id: \.self) { option in
                AnswerOptionButton(
                    text: option,
                    isSelected: selectedAnswer == option,
                    hasAnswered: hasAnswered,
                    canAnswer: canAnswer
                ) {
                    onSelect(option)
                }
            }
        }
    }
}

// MARK: - Answer Option Button
struct AnswerOptionButton: View {
    let text: String
    let isSelected: Bool
    let hasAnswered: Bool
    let canAnswer: Bool
    let action: () -> Void
    
    var backgroundColor: Color {
        if isSelected {
            return hasAnswered ? .botanicalGreen : .blue
        }
        return Color(.systemGray6)
    }
    
    var textColor: Color {
        if isSelected {
            return .white
        }
        return canAnswer ? .primary : .secondary
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .botanicalStyle(BotanicalTextStyle.body)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .disabled(!canAnswer)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Results Header View
struct ResultsHeaderView: View {
    let game: Game
    
    private var userPlayer: Game.Player? {
        // In a real app, this would check the current user ID
        game.players.first
    }
    
    private var opponentPlayer: Game.Player? {
        game.players.first { $0.id != userPlayer?.id }
    }
    
    private var gameResult: GameResult {
        guard let user = userPlayer, let opponent = opponentPlayer else {
            return .draw
        }
        
        if user.score > opponent.score {
            return .victory
        } else if user.score < opponent.score {
            return .defeat
        } else {
            return .draw
        }
    }
    
    enum GameResult {
        case victory, defeat, draw
        
        var title: String {
            switch self {
            case .victory: return "Victory!"
            case .defeat: return "Defeat"
            case .draw: return "Draw"
            }
        }
        
        var color: Color {
            switch self {
            case .victory: return .green
            case .defeat: return .red
            case .draw: return .orange
            }
        }
        
        var icon: String {
            switch self {
            case .victory: return "trophy.fill"
            case .defeat: return "xmark.circle.fill"
            case .draw: return "equal.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: gameResult.icon)
                .font(.system(size: 60))
                .foregroundColor(gameResult.color)
            
            Text(gameResult.title)
                .botanicalStyle(BotanicalTextStyle.largeTitle)
                .foregroundColor(gameResult.color)
            
            if let opponent = opponentPlayer {
                Text("vs \(opponent.username)")
                    .botanicalStyle(BotanicalTextStyle.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Score Summary View
struct ScoreSummaryView: View {
    let game: Game
    
    private var userPlayer: Game.Player? {
        game.players.first
    }
    
    private var opponentPlayer: Game.Player? {
        game.players.first { $0.id != userPlayer?.id }
    }
    
    var body: some View {
        HStack {
            if let user = userPlayer {
                PlayerScoreCard(player: user, isCurrentUser: true)
            }
            
            Spacer()
            
            VStack {
                Text("Final Score")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.secondary)
                
                Text("\(userPlayer?.score ?? 0) - \(opponentPlayer?.score ?? 0)")
                    .botanicalStyle(BotanicalTextStyle.title)
            }
            
            Spacer()
            
            if let opponent = opponentPlayer {
                PlayerScoreCard(player: opponent, isCurrentUser: false)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Player Score Card
struct PlayerScoreCard: View {
    let player: Game.Player
    let isCurrentUser: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(isCurrentUser ? "You" : player.username)
                .botanicalStyle(BotanicalTextStyle.headline)
            
            Text("\(player.score)")
                .botanicalStyle(BotanicalTextStyle.largeTitle)
                .foregroundColor(.botanicalGreen)
        }
    }
}

// MARK: - Round Results View
struct RoundResultsView: View {
    let game: Game
    
    private var userPlayer: Game.Player? {
        game.players.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Round by Round")
                .botanicalStyle(BotanicalTextStyle.headline)
            
            if let user = userPlayer {
                ForEach(user.answers) { answer in
                    RoundResultCard(answer: answer)
                }
            }
        }
    }
}

// MARK: - Round Result Card
struct RoundResultCard: View {
    let answer: Game.Player.Answer
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Round \(answer.roundNumber)")
                    .botanicalStyle(BotanicalTextStyle.subheadline)
                
                Text("Your answer: \(answer.selectedAnswer)")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(answer.isCorrect ? .green : .red)
                
                if !answer.isCorrect {
                    Text("Correct: \(answer.correctAnswer)")
                        .botanicalStyle(BotanicalTextStyle.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: answer.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(answer.isCorrect ? .green : .red)
                
                Text("+\(answer.pointsEarned)")
                    .botanicalStyle(BotanicalTextStyle.caption)
                    .foregroundColor(.botanicalGreen)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}