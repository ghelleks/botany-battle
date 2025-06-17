import Foundation
import Dependencies

protocol PersonalBestServiceProtocol {
    func getPersonalBest(for mode: GameMode, difficulty: Game.Difficulty) -> PersonalBest?
    func getAllPersonalBests() -> [PersonalBest]
    func savePersonalBest(_ personalBest: PersonalBest) -> Bool
    func isNewPersonalBest(_ session: SingleUserGameSession) -> Bool
    func updatePersonalBest(_ session: SingleUserGameSession) -> PersonalBest?
    func clearAllPersonalBests()
}

final class PersonalBestService: PersonalBestServiceProtocol {
    @Dependency(\.persistenceService) var persistenceService
    
    func getPersonalBest(for mode: GameMode, difficulty: Game.Difficulty) -> PersonalBest? {
        return persistenceService.getPersonalBest(mode: mode, difficulty: difficulty)
    }
    
    func getAllPersonalBests() -> [PersonalBest] {
        return persistenceService.getAllPersonalBests()
    }
    
    func savePersonalBest(_ personalBest: PersonalBest) -> Bool {
        do {
            try persistenceService.savePersonalBest(personalBest)
            return true
        } catch {
            print("Failed to save personal best: \(error)")
            return false
        }
    }
    
    func isNewPersonalBest(_ session: SingleUserGameSession) -> Bool {
        guard session.isComplete else { return false }
        
        guard let existingBest = getPersonalBest(for: session.mode, difficulty: session.difficulty) else {
            return true // First time playing this mode/difficulty
        }
        
        switch session.mode {
        case .multiplayer:
            return false // Not applicable for multiplayer
        case .beatTheClock:
            return session.correctAnswers > existingBest.score
        case .speedrun:
            guard session.questionsAnswered >= 25 else { return false }
            return session.score > existingBest.score // Higher score means faster time
        }
    }
    
    func updatePersonalBest(_ session: SingleUserGameSession) -> PersonalBest? {
        guard isNewPersonalBest(session) else { return nil }
        
        let newPersonalBest = session.toPersonalBest()
        
        if savePersonalBest(newPersonalBest) {
            return newPersonalBest
        }
        
        return nil
    }
    
    func clearAllPersonalBests() {
        // Clear all personal bests for all modes and difficulties
        for mode in GameMode.allCases {
            for difficulty in Game.Difficulty.allCases {
                do {
                    try persistenceService.deletePersonalBest(mode: mode, difficulty: difficulty)
                } catch {
                    print("Failed to delete personal best for \(mode) \(difficulty): \(error)")
                }
            }
        }
    }
}

extension DependencyValues {
    var personalBestService: PersonalBestServiceProtocol {
        get { self[PersonalBestServiceKey.self] }
        set { self[PersonalBestServiceKey.self] = newValue }
    }
}

private enum PersonalBestServiceKey: DependencyKey {
    static let liveValue: PersonalBestServiceProtocol = PersonalBestService()
    static let testValue: PersonalBestServiceProtocol = MockPersonalBestService()
}

// Mock service for testing
final class MockPersonalBestService: PersonalBestServiceProtocol {
    private var personalBests: [PersonalBest] = []
    
    func getPersonalBest(for mode: GameMode, difficulty: Game.Difficulty) -> PersonalBest? {
        return personalBests.first { $0.mode == mode && $0.difficulty == difficulty }
    }
    
    func getAllPersonalBests() -> [PersonalBest] {
        return personalBests.sorted { $0.achievedAt > $1.achievedAt }
    }
    
    func savePersonalBest(_ personalBest: PersonalBest) -> Bool {
        personalBests.removeAll { $0.mode == personalBest.mode && $0.difficulty == personalBest.difficulty }
        personalBests.append(personalBest)
        return true
    }
    
    func isNewPersonalBest(_ session: SingleUserGameSession) -> Bool {
        guard session.isComplete else { return false }
        
        guard let existingBest = getPersonalBest(for: session.mode, difficulty: session.difficulty) else {
            return true
        }
        
        switch session.mode {
        case .multiplayer:
            return false
        case .beatTheClock:
            return session.correctAnswers > existingBest.score
        case .speedrun:
            guard session.questionsAnswered >= 25 else { return false }
            return session.score > existingBest.score
        }
    }
    
    func updatePersonalBest(_ session: SingleUserGameSession) -> PersonalBest? {
        guard isNewPersonalBest(session) else { return nil }
        
        let newPersonalBest = session.toPersonalBest()
        
        if savePersonalBest(newPersonalBest) {
            return newPersonalBest
        }
        
        return nil
    }
    
    func clearAllPersonalBests() {
        personalBests.removeAll()
    }
}