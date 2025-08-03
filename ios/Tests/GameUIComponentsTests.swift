import XCTest
import SwiftUI
@testable import BotanyBattle

class GameUIComponentsTests: XCTestCase {
    
    // MARK: - GameTimerView Tests
    
    func testGameTimerViewCreation() {
        // Given
        let timeRemaining = 30
        let totalTime = 60
        
        // When
        let timerView = GameTimerView(
            timeRemaining: timeRemaining,
            totalTime: totalTime
        )
        
        // Then
        XCTAssertEqual(timerView.timeRemaining, timeRemaining)
        XCTAssertEqual(timerView.totalTime, totalTime)
    }
    
    func testGameTimerProgress() {
        // Given
        let timeRemaining = 15
        let totalTime = 60
        let expectedProgress = 0.25 // 15/60
        
        // When
        let timerView = GameTimerView(
            timeRemaining: timeRemaining,
            totalTime: totalTime
        )
        
        // Then
        XCTAssertEqual(timerView.progress, expectedProgress, accuracy: 0.01)
    }
    
    func testGameTimerIsUrgent() {
        // Given
        let urgentTime = 5
        let normalTime = 30
        let totalTime = 60
        
        // When
        let urgentTimer = GameTimerView(timeRemaining: urgentTime, totalTime: totalTime)
        let normalTimer = GameTimerView(timeRemaining: normalTime, totalTime: totalTime)
        
        // Then
        XCTAssertTrue(urgentTimer.isUrgent)
        XCTAssertFalse(normalTimer.isUrgent)
    }
    
    // MARK: - GameScoreView Tests
    
    func testGameScoreViewCreation() {
        // Given
        let score = 150
        let currentRound = 3
        let totalRounds = 5
        
        // When
        let scoreView = GameScoreView(
            score: score,
            currentRound: currentRound,
            totalRounds: totalRounds
        )
        
        // Then
        XCTAssertEqual(scoreView.score, score)
        XCTAssertEqual(scoreView.currentRound, currentRound)
        XCTAssertEqual(scoreView.totalRounds, totalRounds)
    }
    
    func testGameScoreProgress() {
        // Given
        let currentRound = 3
        let totalRounds = 5
        let expectedProgress = 0.6 // 3/5
        
        // When
        let scoreView = GameScoreView(
            score: 100,
            currentRound: currentRound,
            totalRounds: totalRounds
        )
        
        // Then
        XCTAssertEqual(scoreView.roundProgress, expectedProgress, accuracy: 0.01)
    }
    
    // MARK: - PlantImageView Tests
    
    func testPlantImageViewCreation() {
        // Given
        let imageURL = "https://example.com/plant.jpg"
        let plantName = "Rose"
        
        // When
        let imageView = PlantImageView(
            imageURL: imageURL,
            plantName: plantName
        )
        
        // Then
        XCTAssertEqual(imageView.imageURL, imageURL)
        XCTAssertEqual(imageView.plantName, plantName)
    }
    
    func testPlantImageViewWithEmptyURL() {
        // Given
        let imageURL = ""
        let plantName = "Unknown Plant"
        
        // When
        let imageView = PlantImageView(
            imageURL: imageURL,
            plantName: plantName
        )
        
        // Then
        XCTAssertEqual(imageView.imageURL, "")
        XCTAssertTrue(imageView.showPlaceholder)
    }
    
    // MARK: - AnswerOptionButton Tests
    
    func testAnswerOptionButtonCreation() {
        // Given
        let option = "Rosa rubiginosa"
        let isSelected = false
        let isCorrect = true
        let showResult = false
        
        // When
        let button = AnswerOptionButton(
            option: option,
            isSelected: isSelected,
            isCorrect: isCorrect,
            showResult: showResult
        ) {
            // Action
        }
        
        // Then
        XCTAssertEqual(button.option, option)
        XCTAssertFalse(button.isSelected)
        XCTAssertTrue(button.isCorrect)
        XCTAssertFalse(button.showResult)
    }
    
    func testAnswerOptionButtonStates() {
        // Given
        let option = "Test Plant"
        
        // When
        let correctSelected = AnswerOptionButton(
            option: option,
            isSelected: true,
            isCorrect: true,
            showResult: true
        ) {}
        
        let incorrectSelected = AnswerOptionButton(
            option: option,
            isSelected: true,
            isCorrect: false,
            showResult: true
        ) {}
        
        let correctNotSelected = AnswerOptionButton(
            option: option,
            isSelected: false,
            isCorrect: true,
            showResult: true
        ) {}
        
        // Then
        XCTAssertEqual(correctSelected.buttonState, .correctSelected)
        XCTAssertEqual(incorrectSelected.buttonState, .incorrectSelected)
        XCTAssertEqual(correctNotSelected.buttonState, .correctNotSelected)
    }
    
    // MARK: - GameResultsView Tests
    
    func testGameResultsViewCreation() {
        // Given
        let gameMode = GameMode.practice
        let finalScore = 200
        let correctAnswers = 4
        let totalQuestions = 5
        let elapsedTime: TimeInterval = 120.5
        
        // When
        let resultsView = GameResultsView(
            gameMode: gameMode,
            finalScore: finalScore,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            elapsedTime: elapsedTime,
            onPlayAgain: {},
            onExit: {}
        )
        
        // Then
        XCTAssertEqual(resultsView.gameMode, gameMode)
        XCTAssertEqual(resultsView.finalScore, finalScore)
        XCTAssertEqual(resultsView.correctAnswers, correctAnswers)
        XCTAssertEqual(resultsView.totalQuestions, totalQuestions)
        XCTAssertEqual(resultsView.elapsedTime, elapsedTime, accuracy: 0.1)
    }
    
    func testGameResultsAccuracy() {
        // Given
        let correctAnswers = 3
        let totalQuestions = 5
        let expectedAccuracy = 0.6 // 3/5
        
        // When
        let resultsView = GameResultsView(
            gameMode: .practice,
            finalScore: 150,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            elapsedTime: 60,
            onPlayAgain: {},
            onExit: {}
        )
        
        // Then
        XCTAssertEqual(resultsView.accuracy, expectedAccuracy, accuracy: 0.01)
    }
    
    func testGameResultsPerformanceMessage() {
        // Given
        let perfectGame = GameResultsView(
            gameMode: .practice,
            finalScore: 250,
            correctAnswers: 5,
            totalQuestions: 5,
            elapsedTime: 60,
            onPlayAgain: {},
            onExit: {}
        )
        
        let goodGame = GameResultsView(
            gameMode: .practice,
            finalScore: 200,
            correctAnswers: 4,
            totalQuestions: 5,
            elapsedTime: 60,
            onPlayAgain: {},
            onExit: {}
        )
        
        // When & Then
        XCTAssertTrue(perfectGame.performanceMessage.contains("Perfect"))
        XCTAssertTrue(goodGame.performanceMessage.contains("Excellent") || goodGame.performanceMessage.contains("Good"))
    }
    
    func testGameResultsFormattedTime() {
        // Given
        let timeInSeconds: TimeInterval = 125.7 // 2:05
        let resultsView = GameResultsView(
            gameMode: .speedrun,
            finalScore: 300,
            correctAnswers: 5,
            totalQuestions: 5,
            elapsedTime: timeInSeconds,
            onPlayAgain: {},
            onExit: {}
        )
        
        // When
        let formattedTime = resultsView.formattedTime
        
        // Then
        XCTAssertEqual(formattedTime, "2:05")
    }
    
    // MARK: - FeedbackView Tests
    
    func testFeedbackViewCreation() {
        // Given
        let feedback = GameFeedback(
            isCorrect: true,
            correctAnswer: "Rose",
            explanation: "This is a beautiful flowering plant.",
            showFeedback: true
        )
        
        // When
        let feedbackView = FeedbackView(feedback: feedback)
        
        // Then
        XCTAssertEqual(feedbackView.feedback.isCorrect, true)
        XCTAssertEqual(feedbackView.feedback.correctAnswer, "Rose")
        XCTAssertEqual(feedbackView.feedback.explanation, "This is a beautiful flowering plant.")
        XCTAssertTrue(feedbackView.feedback.showFeedback)
    }
    
    func testFeedbackViewIncorrectAnswer() {
        // Given
        let feedback = GameFeedback(
            isCorrect: false,
            correctAnswer: "Sunflower",
            explanation: "Sunflowers are known for following the sun.",
            showFeedback: true
        )
        
        // When
        let feedbackView = FeedbackView(feedback: feedback)
        
        // Then
        XCTAssertFalse(feedbackView.feedback.isCorrect)
        XCTAssertEqual(feedbackView.feedback.correctAnswer, "Sunflower")
        XCTAssertNotNil(feedbackView.feedback.explanation)
    }
    
    // MARK: - GameProgressHeader Tests
    
    func testGameProgressHeaderCreation() {
        // Given
        let gameProgress = GameProgress(
            currentQuestion: 3,
            totalQuestions: 5,
            score: 150,
            timeRemaining: 45,
            totalTime: 60
        )
        
        // When
        let header = GameProgressHeader(progress: gameProgress)
        
        // Then
        XCTAssertEqual(header.progress.currentQuestion, 3)
        XCTAssertEqual(header.progress.totalQuestions, 5)
        XCTAssertEqual(header.progress.score, 150)
        XCTAssertEqual(header.progress.timeRemaining, 45)
        XCTAssertEqual(header.progress.totalTime, 60)
    }
    
    func testGameProgressCompletion() {
        // Given
        let gameProgress = GameProgress(
            currentQuestion: 3,
            totalQuestions: 5,
            score: 150,
            timeRemaining: 45,
            totalTime: 60
        )
        
        // When
        let completion = gameProgress.questionProgress
        
        // Then
        XCTAssertEqual(completion, 0.6, accuracy: 0.01) // 3/5
    }
    
    // MARK: - Performance Tests
    
    func testGameUIComponentsPerformance() {
        measure {
            for _ in 0..<100 {
                let _ = GameTimerView(timeRemaining: 30, totalTime: 60)
                let _ = GameScoreView(score: 100, currentRound: 3, totalRounds: 5)
                let _ = PlantImageView(imageURL: "https://example.com/plant.jpg", plantName: "Rose")
            }
        }
    }
}

// MARK: - Supporting Data Models

struct GameTimerView {
    let timeRemaining: Int
    let totalTime: Int
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalTime)
    }
    
    var isUrgent: Bool {
        return timeRemaining <= 10
    }
}

struct GameScoreView {
    let score: Int
    let currentRound: Int
    let totalRounds: Int
    
    var roundProgress: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(currentRound) / Double(totalRounds)
    }
}

struct PlantImageView {
    let imageURL: String
    let plantName: String
    
    var showPlaceholder: Bool {
        return imageURL.isEmpty
    }
}

struct AnswerOptionButton {
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
}

struct GameResultsView {
    let gameMode: GameMode
    let finalScore: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let elapsedTime: TimeInterval?
    let onPlayAgain: () -> Void
    let onExit: () -> Void
    
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
    
    var formattedTime: String {
        guard let elapsedTime = elapsedTime else { return "" }
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct GameFeedback {
    let isCorrect: Bool
    let correctAnswer: String
    let explanation: String
    let showFeedback: Bool
}

struct FeedbackView {
    let feedback: GameFeedback
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
    
    var timeProgress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(timeRemaining) / Double(totalTime)
    }
}

struct GameProgressHeader {
    let progress: GameProgress
}

enum GameMode: String, CaseIterable {
    case practice = "Practice"
    case timeAttack = "Time Attack"
    case speedrun = "Speedrun"
    case multiplayer = "Multiplayer"
}