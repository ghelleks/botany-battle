import SwiftUI

// MARK: - Accessibility Extensions for Single User Game Components

extension View {
    /// Adds comprehensive accessibility support for game mode buttons
    func gameModeAccessibility(
        mode: GameMode,
        difficulty: Game.Difficulty,
        isSelected: Bool = false
    ) -> some View {
        self
            .accessibilityLabel("\(mode.displayName) mode, \(difficulty.displayName) difficulty")
            .accessibilityHint("Double tap to start \(mode.displayName) game on \(difficulty.displayName) difficulty")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
    
    /// Adds accessibility support for timer displays
    func timerAccessibility(
        timeRemaining: TimeInterval,
        mode: GameMode,
        isUrgent: Bool = false
    ) -> some View {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        let timeDescription = minutes > 0 ? "\(minutes) minutes and \(seconds) seconds" : "\(seconds) seconds"
        
        let modeContext = switch mode {
        case .beatTheClock: "remaining in Beat the Clock mode"
        case .speedrun: "elapsed in Speedrun mode"
        case .multiplayer: "remaining"
        }
        
        return self
            .accessibilityLabel("Timer: \(timeDescription) \(modeContext)")
            .accessibilityValue(isUrgent ? "Time is running low" : "")
            .accessibilityAddTraits(isUrgent ? [.updatesFrequently] : [])
    }
    
    /// Adds accessibility support for score displays
    func scoreAccessibility(
        score: Int,
        correctAnswers: Int,
        totalAnswers: Int,
        mode: GameMode
    ) -> some View {
        let accuracy = totalAnswers > 0 ? Double(correctAnswers) / Double(totalAnswers) * 100 : 0
        let accuracyDescription = String(format: "%.1f percent accuracy", accuracy)
        
        let scoreDescription = switch mode {
        case .beatTheClock: "\(correctAnswers) correct answers out of \(totalAnswers) total, \(accuracyDescription)"
        case .speedrun: "\(correctAnswers) correct answers out of \(totalAnswers) questions, \(accuracyDescription)"
        case .multiplayer: "\(score) points, \(correctAnswers) correct answers"
        }
        
        return self
            .accessibilityLabel("Current score: \(scoreDescription)")
            .accessibilityAddTraits([.updatesFrequently])
    }
    
    /// Adds accessibility support for plant images
    func plantImageAccessibility(plant: Plant) -> some View {
        self
            .accessibilityLabel("Plant image: \(plant.primaryCommonName)")
            .accessibilityHint("This is the plant you need to identify. The answer options are below.")
            .accessibilityAddTraits([.isImage])
    }
    
    /// Adds accessibility support for answer option buttons
    func answerOptionAccessibility(
        option: String,
        isSelected: Bool,
        isCorrect: Bool?,
        isWrong: Bool?,
        hasAnswered: Bool
    ) -> some View {
        var label = "Answer option: \(option)"
        var hint = "Double tap to select this answer"
        var traits: AccessibilityTraits = [.isButton]
        
        if isSelected {
            label += ", selected"
            traits.insert(.isSelected)
        }
        
        if hasAnswered {
            if let isCorrect = isCorrect, isCorrect {
                label += ", correct answer"
                hint = "This was the correct answer"
                traits.remove(.isButton)
            } else if let isWrong = isWrong, isWrong {
                label += ", incorrect answer"
                hint = "This was an incorrect answer"
                traits.remove(.isButton)
            }
        }
        
        return self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(traits)
    }
    
    /// Adds accessibility support for progress indicators
    func progressAccessibility(
        current: Int,
        total: Int,
        mode: GameMode
    ) -> some View {
        let progressDescription = switch mode {
        case .beatTheClock: "Question \(current) answered in Beat the Clock mode"
        case .speedrun: "Question \(current) of \(total) in Speedrun mode"
        case .multiplayer: "Round \(current) of \(total)"
        }
        
        let percentComplete = total > 0 ? Double(current) / Double(total) * 100 : 0
        
        return self
            .accessibilityLabel("Progress: \(progressDescription)")
            .accessibilityValue(String(format: "%.0f percent complete", percentComplete))
            .accessibilityAddTraits([.updatesFrequently])
    }
    
    /// Adds accessibility support for trophy rewards
    func trophyRewardAccessibility(reward: TrophyReward) -> some View {
        let componentsDescription = reward.breakdown.components
            .map { "\($0.amount) trophies for \($0.description)" }
            .joined(separator: ", ")
        
        return self
            .accessibilityLabel("Trophy reward: \(reward.totalTrophies) total trophies earned")
            .accessibilityHint("Breakdown: \(componentsDescription)")
            .accessibilityAddTraits([.staticText])
    }
    
    /// Adds accessibility support for achievement badges
    func achievementAccessibility(achievement: AchievementData) -> some View {
        self
            .accessibilityLabel("Achievement unlocked: \(achievement.title)")
            .accessibilityHint(achievement.description)
            .accessibilityAddTraits([.staticText])
    }
    
    /// Adds accessibility support for personal best comparisons
    func personalBestAccessibility(
        currentScore: String,
        previousBest: String?,
        improvement: String?,
        isImprovement: Bool
    ) -> some View {
        var description = "Current performance: \(currentScore)"
        
        if let previousBest = previousBest {
            description += ", previous best: \(previousBest)"
            
            if let improvement = improvement {
                let improvementType = isImprovement ? "improvement" : "decline"
                description += ", \(improvementType) of \(improvement)"
            }
        } else {
            description += ", this is your first attempt"
        }
        
        return self
            .accessibilityLabel(description)
            .accessibilityAddTraits([.staticText])
    }
    
    /// Adds accessibility support for game controls
    func gameControlAccessibility(
        action: String,
        isEnabled: Bool = true,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(action)
            .accessibilityHint(hint ?? "Double tap to \(action.lowercased())")
            .accessibilityAddTraits(isEnabled ? [.isButton] : [.isButton, .notEnabled])
    }
    
    /// Adds accessibility support for game statistics
    func gameStatsAccessibility(session: SingleUserGameSession) -> some View {
        let accuracy = session.accuracy * 100
        let timeDescription = formatTimeInterval(session.totalGameTime)
        
        let statsDescription = """
        Game statistics: \(session.correctAnswers) correct answers out of \(session.questionsAnswered) total, \
        \(String(format: "%.1f", accuracy)) percent accuracy, \
        total time: \(timeDescription), \
        difficulty: \(session.difficulty.displayName)
        """
        
        return self
            .accessibilityLabel(statsDescription)
            .accessibilityAddTraits([.staticText])
    }
}

// MARK: - Accessibility Helper Functions

private func formatTimeInterval(_ interval: TimeInterval) -> String {
    let minutes = Int(interval) / 60
    let seconds = Int(interval) % 60
    
    if minutes > 0 {
        return "\(minutes) minutes and \(seconds) seconds"
    } else {
        return "\(seconds) seconds"
    }
}

// MARK: - Custom Accessibility Actions

extension View {
    /// Adds custom accessibility actions for game screens
    func gameScreenAccessibilityActions(
        onPause: (() -> Void)? = nil,
        onResume: (() -> Void)? = nil,
        onLeave: (() -> Void)? = nil,
        onShowStats: (() -> Void)? = nil
    ) -> some View {
        var actions: [AccessibilityAction] = []
        
        if let onPause = onPause {
            actions.append(AccessibilityAction(name: "Pause Game", action: onPause))
        }
        
        if let onResume = onResume {
            actions.append(AccessibilityAction(name: "Resume Game", action: onResume))
        }
        
        if let onLeave = onLeave {
            actions.append(AccessibilityAction(name: "Leave Game", action: onLeave))
        }
        
        if let onShowStats = onShowStats {
            actions.append(AccessibilityAction(name: "Show Statistics", action: onShowStats))
        }
        
        return self.accessibilityActions(actions)
    }
    
    /// Adds custom accessibility actions for results screen
    func resultsScreenAccessibilityActions(
        onPlayAgain: @escaping () -> Void,
        onReturnToMenu: @escaping () -> Void,
        onViewLeaderboard: @escaping () -> Void
    ) -> some View {
        self.accessibilityActions([
            AccessibilityAction(name: "Play Again", action: onPlayAgain),
            AccessibilityAction(name: "Return to Main Menu", action: onReturnToMenu),
            AccessibilityAction(name: "View Leaderboard", action: onViewLeaderboard)
        ])
    }
}

// MARK: - Accessibility Announcements

struct AccessibilityAnnouncements {
    /// Announces game events to VoiceOver users
    static func announceGameEvent(_ event: GameEvent) {
        let announcement = switch event {
        case .gameStarted(let mode):
            "\(mode.displayName) game started"
        case .questionLoaded:
            "New plant question loaded"
        case .correctAnswer:
            "Correct answer!"
        case .incorrectAnswer:
            "Incorrect answer"
        case .gameCompleted:
            "Game completed"
        case .newPersonalBest:
            "Congratulations! New personal best achieved!"
        case .trophiesEarned(let amount):
            "\(amount) trophies earned"
        case .gamePaused:
            "Game paused"
        case .gameResumed:
            "Game resumed"
        case .timeWarning:
            "Time is running low"
        case .achievementUnlocked(let title):
            "Achievement unlocked: \(title)"
        }
        
        AccessibilityNotification.Announcement(announcement).post()
    }
    
    /// Announces timer updates at key intervals
    static func announceTimerUpdate(timeRemaining: TimeInterval, mode: GameMode) {
        let shouldAnnounce = switch mode {
        case .beatTheClock:
            timeRemaining == 30.0 || timeRemaining == 10.0 || timeRemaining == 5.0
        case .speedrun:
            false // Don't announce for speedrun as it's elapsed time
        case .multiplayer:
            timeRemaining == 10.0 || timeRemaining == 5.0
        }
        
        if shouldAnnounce {
            let announcement = switch mode {
            case .beatTheClock:
                "\(Int(timeRemaining)) seconds remaining"
            case .multiplayer:
                "\(Int(timeRemaining)) seconds remaining"
            case .speedrun:
                ""
            }
            
            if !announcement.isEmpty {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
    }
}

// MARK: - Game Event Enumeration

enum GameEvent {
    case gameStarted(GameMode)
    case questionLoaded
    case correctAnswer
    case incorrectAnswer
    case gameCompleted
    case newPersonalBest
    case trophiesEarned(Int)
    case gamePaused
    case gameResumed
    case timeWarning
    case achievementUnlocked(String)
}

// MARK: - Accessibility Preferences

struct AccessibilityPreferences {
    static let shared = AccessibilityPreferences()
    
    var isVoiceOverEnabled: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    var isReduceTransparencyEnabled: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }
    
    var prefersCrossFadeTransitions: Bool {
        UIAccessibility.prefersCrossFadeTransitions
    }
    
    var isInvertColorsEnabled: Bool {
        UIAccessibility.isInvertColorsEnabled
    }
    
    var isDarkerSystemColorsEnabled: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    var isBoldTextEnabled: Bool {
        UIAccessibility.isBoldTextEnabled
    }
    
    var isButtonShapesEnabled: Bool {
        UIAccessibility.isButtonShapesEnabled
    }
}

// MARK: - Accessibility-Aware Animations

extension View {
    /// Applies animations that respect accessibility preferences
    func accessibleAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V
    ) -> some View {
        if AccessibilityPreferences.shared.isReduceMotionEnabled {
            return self.animation(nil, value: value)
        } else {
            return self.animation(animation, value: value)
        }
    }
    
    /// Applies transitions that respect accessibility preferences
    func accessibleTransition(_ transition: AnyTransition) -> some View {
        if AccessibilityPreferences.shared.isReduceMotionEnabled || 
           AccessibilityPreferences.shared.prefersCrossFadeTransitions {
            return self.transition(.opacity)
        } else {
            return self.transition(transition)
        }
    }
}