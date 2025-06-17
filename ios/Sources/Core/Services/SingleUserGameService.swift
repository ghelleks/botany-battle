import Foundation
import Dependencies

protocol SingleUserGameServiceProtocol {
    func startGame(mode: GameMode, difficulty: Game.Difficulty) -> SingleUserGameSession
    func getCurrentQuestion(for session: SingleUserGameSession) async throws -> (plant: Plant, options: [String])
    func submitAnswer(session: inout SingleUserGameSession, selectedAnswer: String, correctAnswer: String, plantId: String) -> SingleUserGameSession.SingleUserAnswer
    func pauseGame(session: inout SingleUserGameSession)
    func resumeGame(session: inout SingleUserGameSession)
    func completeGame(session: inout SingleUserGameSession) -> PersonalBest?
    func saveGameSession(_ session: SingleUserGameSession)
    func loadGameSession() -> SingleUserGameSession?
    func clearSavedSession()
}

final class SingleUserGameService: SingleUserGameServiceProtocol {
    @Dependency(\.userDefaults) var userDefaults
    @Dependency(\.personalBestService) var personalBestService
    
    private let savedSessionKey = "current_single_user_session"
    
    func startGame(mode: GameMode, difficulty: Game.Difficulty) -> SingleUserGameSession {
        let session = SingleUserGameSession(
            mode: mode,
            difficulty: difficulty
        )
        
        saveGameSession(session)
        return session
    }
    
    func getCurrentQuestion(for session: SingleUserGameSession) async throws -> (plant: Plant, options: [String]) {
        // For now, return mock data. This will be replaced with actual plant fetching logic
        let mockPlant = Plant(
            id: UUID().uuidString,
            scientificName: "Mockus planticus \(session.currentQuestionIndex + 1)",
            commonNames: ["Mock Plant \(session.currentQuestionIndex + 1)", "Test Plant"],
            family: "Mockaceae",
            genus: "Mockus",
            species: "planticus",
            imageURL: "https://example.com/plant.jpg",
            thumbnailURL: "https://example.com/plant-thumb.jpg",
            description: "A mock plant for testing purposes",
            difficulty: session.difficulty.rawValue.hashValue % 100,
            rarity: .common,
            habitat: ["Mock habitat"],
            regions: ["Mock region"],
            characteristics: Plant.Characteristics(
                leafType: "Mock leaf",
                flowerColor: ["Mock color"],
                bloomTime: ["Mock season"],
                height: Plant.Characteristics.HeightRange(min: 10, max: 50, unit: "cm"),
                sunRequirement: "Full sun",
                waterRequirement: "Moderate",
                soilType: ["Mock soil"]
            ),
            iNaturalistId: nil
        )
        
        let correctAnswer = mockPlant.primaryCommonName
        let wrongAnswers = [
            "Wrong Plant A",
            "Wrong Plant B", 
            "Wrong Plant C"
        ]
        
        let allOptions = ([correctAnswer] + wrongAnswers).shuffled()
        
        return (plant: mockPlant, options: allOptions)
    }
    
    func submitAnswer(
        session: inout SingleUserGameSession,
        selectedAnswer: String,
        correctAnswer: String,
        plantId: String
    ) -> SingleUserGameSession.SingleUserAnswer {
        let timeToAnswer = Date().timeIntervalSince(session.startedAt) - session.totalPausedTime
        let isCorrect = selectedAnswer == correctAnswer
        
        let answer = SingleUserGameSession.SingleUserAnswer(
            id: UUID().uuidString,
            questionIndex: session.currentQuestionIndex,
            plantId: plantId,
            selectedAnswer: selectedAnswer,
            correctAnswer: correctAnswer,
            isCorrect: isCorrect,
            timeToAnswer: timeToAnswer,
            answeredAt: Date()
        )
        
        session.addAnswer(answer)
        saveGameSession(session)
        
        return answer
    }
    
    func pauseGame(session: inout SingleUserGameSession) {
        session.pause()
        saveGameSession(session)
    }
    
    func resumeGame(session: inout SingleUserGameSession) {
        session.resume()
        saveGameSession(session)
    }
    
    func completeGame(session: inout SingleUserGameSession) -> PersonalBest? {
        session.state = .completed
        saveGameSession(session)
        
        let newPersonalBest = personalBestService.updatePersonalBest(session)
        
        // Clear the saved session since the game is complete
        clearSavedSession()
        
        return newPersonalBest
    }
    
    func saveGameSession(_ session: SingleUserGameSession) {
        do {
            let data = try JSONEncoder().encode(session)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            userDefaults.set(jsonString, forKey: savedSessionKey)
        } catch {
            print("Failed to save game session: \(error)")
        }
    }
    
    func loadGameSession() -> SingleUserGameSession? {
        guard let jsonString = userDefaults.string(forKey: savedSessionKey),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let session = try JSONDecoder().decode(SingleUserGameSession.self, from: data)
            
            // Check if session is still valid (not expired or too old)
            let sessionAge = Date().timeIntervalSince(session.startedAt)
            if sessionAge > 3600 { // 1 hour max
                clearSavedSession()
                return nil
            }
            
            return session
        } catch {
            print("Failed to load game session: \(error)")
            clearSavedSession()
            return nil
        }
    }
    
    func clearSavedSession() {
        userDefaults.removeObject(forKey: savedSessionKey)
    }
}

extension DependencyValues {
    var singleUserGameService: SingleUserGameServiceProtocol {
        get { self[SingleUserGameServiceKey.self] }
        set { self[SingleUserGameServiceKey.self] = newValue }
    }
}

private enum SingleUserGameServiceKey: DependencyKey {
    static let liveValue: SingleUserGameServiceProtocol = SingleUserGameService()
    static let testValue: SingleUserGameServiceProtocol = MockSingleUserGameService()
}

// Mock service for testing
final class MockSingleUserGameService: SingleUserGameServiceProtocol {
    private var savedSession: SingleUserGameSession?
    
    func startGame(mode: GameMode, difficulty: Game.Difficulty) -> SingleUserGameSession {
        let session = SingleUserGameSession(mode: mode, difficulty: difficulty)
        savedSession = session
        return session
    }
    
    func getCurrentQuestion(for session: SingleUserGameSession) async throws -> (plant: Plant, options: [String]) {
        let mockPlant = Plant(
            id: UUID().uuidString,
            scientificName: "Testus planticus \(session.currentQuestionIndex + 1)",
            commonNames: ["Test Plant \(session.currentQuestionIndex + 1)"],
            family: "Testaceae",
            genus: "Testus",
            species: "planticus",
            imageURL: "https://example.com/test-plant.jpg",
            thumbnailURL: nil,
            description: "A test plant",
            difficulty: 25,
            rarity: .common,
            habitat: ["Test habitat"],
            regions: ["Test region"],
            characteristics: Plant.Characteristics(
                leafType: nil,
                flowerColor: [],
                bloomTime: [],
                height: nil,
                sunRequirement: nil,
                waterRequirement: nil,
                soilType: []
            ),
            iNaturalistId: nil
        )
        
        let options = [mockPlant.primaryCommonName, "Wrong A", "Wrong B", "Wrong C"].shuffled()
        return (plant: mockPlant, options: options)
    }
    
    func submitAnswer(
        session: inout SingleUserGameSession,
        selectedAnswer: String,
        correctAnswer: String,
        plantId: String
    ) -> SingleUserGameSession.SingleUserAnswer {
        let answer = SingleUserGameSession.SingleUserAnswer(
            id: UUID().uuidString,
            questionIndex: session.currentQuestionIndex,
            plantId: plantId,
            selectedAnswer: selectedAnswer,
            correctAnswer: correctAnswer,
            isCorrect: selectedAnswer == correctAnswer,
            timeToAnswer: 5.0,
            answeredAt: Date()
        )
        
        session.addAnswer(answer)
        savedSession = session
        return answer
    }
    
    func pauseGame(session: inout SingleUserGameSession) {
        session.pause()
        savedSession = session
    }
    
    func resumeGame(session: inout SingleUserGameSession) {
        session.resume()
        savedSession = session
    }
    
    func completeGame(session: inout SingleUserGameSession) -> PersonalBest? {
        session.state = .completed
        savedSession = nil
        return session.toPersonalBest()
    }
    
    func saveGameSession(_ session: SingleUserGameSession) {
        savedSession = session
    }
    
    func loadGameSession() -> SingleUserGameSession? {
        return savedSession
    }
    
    func clearSavedSession() {
        savedSession = nil
    }
}