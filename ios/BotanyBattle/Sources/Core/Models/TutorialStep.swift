import Foundation

struct TutorialStep: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let order: Int
    let isCompleted: Bool
    
    init(title: String, description: String, icon: String, order: Int = 0, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.icon = icon
        self.order = order
        self.isCompleted = isCompleted
    }
    
    // Custom init for testing with fixed UUID
    init(id: UUID = UUID(), title: String, description: String, icon: String, 
         order: Int = 0, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.order = order
        self.isCompleted = isCompleted
    }
}

// MARK: - Tutorial Content
extension TutorialStep {
    static let defaultSteps: [TutorialStep] = [
        TutorialStep(
            title: "Welcome to Botany Battle!",
            description: "Test your plant knowledge in exciting battles and challenges. Learn to identify plants while having fun!",
            icon: "leaf.fill",
            order: 1
        ),
        TutorialStep(
            title: "Choose Your Game Mode",
            description: "Practice without pressure, race against time in Beat the Clock, or go for speed in Speedrun mode.",
            icon: "gamecontroller.fill",
            order: 2
        ),
        TutorialStep(
            title: "Identify Plants",
            description: "Look at the plant image and select the correct name from the multiple choice options.",
            icon: "eye.fill",
            order: 3
        ),
        TutorialStep(
            title: "Learn Plant Facts",
            description: "After each question, discover interesting facts about the plants you encounter.",
            icon: "book.fill",
            order: 4
        ),
        TutorialStep(
            title: "Earn Trophies",
            description: "Gain trophies for correct answers and achievements. Use them to buy cosmetic items in the shop!",
            icon: "trophy.fill",
            order: 5
        ),
        TutorialStep(
            title: "Track Your Progress",
            description: "Monitor your personal bests, view your achievements, and see how much you've learned.",
            icon: "chart.line.uptrend.xyaxis",
            order: 6
        ),
        TutorialStep(
            title: "Ready to Play!",
            description: "You're all set! Start with Practice mode to get comfortable, then try the other game modes.",
            icon: "checkmark.circle.fill",
            order: 7
        )
    ]
}

// MARK: - Progress Tracking
extension TutorialStep {
    func markCompleted() -> TutorialStep {
        return TutorialStep(
            id: self.id,
            title: self.title,
            description: self.description,
            icon: self.icon,
            order: self.order,
            isCompleted: true
        )
    }
    
    func markIncomplete() -> TutorialStep {
        return TutorialStep(
            id: self.id,
            title: self.title,
            description: self.description,
            icon: self.icon,
            order: self.order,
            isCompleted: false
        )
    }
}

// MARK: - Comparable
extension TutorialStep: Comparable {
    static func < (lhs: TutorialStep, rhs: TutorialStep) -> Bool {
        return lhs.order < rhs.order
    }
}