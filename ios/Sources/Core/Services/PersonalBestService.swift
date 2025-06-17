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
    @Dependency(\.userDefaults) var userDefaults
    
    private let personalBestsKey = "personal_bests"
    
    func getPersonalBest(for mode: GameMode, difficulty: Game.Difficulty) -> PersonalBest? {
        let allBests = getAllPersonalBests()
        return allBests.first { $0.mode == mode && $0.difficulty == difficulty }
    }
    
    func getAllPersonalBests() -> [PersonalBest] {
        guard let data = userDefaults.string(forKey: personalBestsKey)?.data(using: .utf8) else {
            return []
        }
        
        do {
            let personalBests = try JSONDecoder().decode([PersonalBest].self, from: data)
            return personalBests.sorted { $0.achievedAt > $1.achievedAt }
        } catch {
            print("Failed to decode personal bests: \(error)")
            return []
        }
    }
    
    func savePersonalBest(_ personalBest: PersonalBest) -> Bool {
        var allBests = getAllPersonalBests()
        
        // Remove existing personal best for same mode/difficulty
        allBests.removeAll { $0.mode == personalBest.mode && $0.difficulty == personalBest.difficulty }
        
        // Add new personal best
        allBests.append(personalBest)
        
        return saveAllPersonalBests(allBests)
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
        userDefaults.removeObject(forKey: personalBestsKey)
    }
    
    private func saveAllPersonalBests(_ personalBests: [PersonalBest]) -> Bool {
        do {
            let data = try JSONEncoder().encode(personalBests)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            userDefaults.set(jsonString, forKey: personalBestsKey)
            return true
        } catch {
            print("Failed to encode personal bests: \(error)")
            return false
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