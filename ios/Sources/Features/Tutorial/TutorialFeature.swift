import Foundation
import ComposableArchitecture

@Reducer
struct TutorialFeature {
    @ObservableState
    struct State: Equatable {
        var currentStep: TutorialStep = .welcome
        var hasCompletedTutorial = false
        var isPresented = false
        var canSkip = true
        
        enum TutorialStep: Int, CaseIterable {
            case welcome = 0
            case gameRules = 1
            case difficulty = 2
            case gameplay = 3
            case scoring = 4
            case shop = 5
            case profile = 6
            case complete = 7
            
            var title: String {
                switch self {
                case .welcome: return "Welcome to Botany Battle!"
                case .gameRules: return "How to Play"
                case .difficulty: return "Choose Your Challenge"
                case .gameplay: return "During the Game"
                case .scoring: return "Scoring System"
                case .shop: return "The Shop"
                case .profile: return "Your Profile"
                case .complete: return "Ready to Battle!"
                }
            }
            
            var description: String {
                switch self {
                case .welcome:
                    return "Test your botanical knowledge in head-to-head battles with plant enthusiasts from around the world!"
                case .gameRules:
                    return "Each battle consists of 5 rounds. In each round, you'll see a plant image and must identify it from 4 options."
                case .difficulty:
                    return "Choose from Easy (30s), Medium (20s), Hard (15s), or Expert (10s) difficulty levels."
                case .gameplay:
                    return "Answer quickly and correctly to score points. If both players are correct, the fastest answer wins the round!"
                case .scoring:
                    return "Win rounds to earn points. Win games to earn Trophies, our in-game currency."
                case .shop:
                    return "Spend your hard-earned Trophies on cosmetic items, themes, and collectible badges."
                case .profile:
                    return "Track your wins, losses, and ranking. Show off your achievements and customizations."
                case .complete:
                    return "You're all set! Time to put your plant knowledge to the test. Good luck!"
                }
            }
            
            var imageName: String {
                switch self {
                case .welcome: return "leaf.fill"
                case .gameRules: return "gamecontroller.fill"
                case .difficulty: return "speedometer"
                case .gameplay: return "timer"
                case .scoring: return "trophy.fill"
                case .shop: return "bag.fill"
                case .profile: return "person.fill"
                case .complete: return "checkmark.circle.fill"
                }
            }
            
            var next: TutorialStep? {
                guard let nextRawValue = TutorialStep(rawValue: self.rawValue + 1) else {
                    return nil
                }
                return nextRawValue
            }
            
            var previous: TutorialStep? {
                guard self.rawValue > 0,
                      let previousRawValue = TutorialStep(rawValue: self.rawValue - 1) else {
                    return nil
                }
                return previousRawValue
            }
        }
    }
    
    enum Action {
        case startTutorial
        case nextStep
        case previousStep
        case goToStep(State.TutorialStep)
        case skipTutorial
        case completeTutorial
        case dismissTutorial
        case checkTutorialStatus
        case tutorialStatusLoaded(Bool)
    }
    
    @Dependency(\.userDefaults) var userDefaults
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startTutorial:
                state.isPresented = true
                state.currentStep = .welcome
                return .none
                
            case .nextStep:
                if let nextStep = state.currentStep.next {
                    state.currentStep = nextStep
                } else {
                    return .send(.completeTutorial)
                }
                return .none
                
            case .previousStep:
                if let previousStep = state.currentStep.previous {
                    state.currentStep = previousStep
                }
                return .none
                
            case .goToStep(let step):
                state.currentStep = step
                return .none
                
            case .skipTutorial:
                return .send(.completeTutorial)
                
            case .completeTutorial:
                state.hasCompletedTutorial = true
                state.isPresented = false
                userDefaults.set(true, forKey: "hasCompletedTutorial")
                return .none
                
            case .dismissTutorial:
                state.isPresented = false
                return .none
                
            case .checkTutorialStatus:
                let hasCompleted = userDefaults.bool(forKey: "hasCompletedTutorial")
                return .send(.tutorialStatusLoaded(hasCompleted))
                
            case .tutorialStatusLoaded(let hasCompleted):
                state.hasCompletedTutorial = hasCompleted
                if !hasCompleted {
                    state.isPresented = true
                }
                return .none
            }
        }
    }
}