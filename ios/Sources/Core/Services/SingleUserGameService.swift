import Foundation
import Dependencies

enum SingleUserGameError: Error, LocalizedError {
    case noPlantDataAvailable
    case sessionNotFound
    case invalidGameState
    
    var errorDescription: String? {
        switch self {
        case .noPlantDataAvailable:
            return "No plant data available for game session"
        case .sessionNotFound:
            return "Game session not found"
        case .invalidGameState:
            return "Invalid game state"
        }
    }
}

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
    @Dependency(\.plantAPIService) var plantAPIService
    @Dependency(\.plantCacheService) var plantCacheService
    
    private let savedSessionKey = "current_single_user_session"
    
    // Cache for current game session plants to avoid repeated API calls
    private var sessionPlantCache: [String: Plant] = [:]
    private var sessionPlantOptions: [String: [String]] = [:]
    
    func startGame(mode: GameMode, difficulty: Game.Difficulty) -> SingleUserGameSession {
        // Clear any existing session cache
        sessionPlantCache.removeAll()
        sessionPlantOptions.removeAll()
        
        let session = SingleUserGameSession(
            mode: mode,
            difficulty: difficulty
        )
        
        saveGameSession(session)
        return session
    }
    
    func getCurrentQuestion(for session: SingleUserGameSession) async throws -> (plant: Plant, options: [String]) {
        let questionKey = "\(session.id)_\(session.currentQuestionIndex)"
        
        // Check if we already have this question cached
        if let cachedPlant = sessionPlantCache[questionKey],
           let cachedOptions = sessionPlantOptions[questionKey] {
            return (plant: cachedPlant, options: cachedOptions)
        }
        
        // Offline-first approach: Try cache first, then API
        var plants: [Plant] = []
        
        do {
            // First try to get cached plants for this difficulty
            let cachedPlants = try await plantCacheService.getCachedPlants(
                forDifficulty: session.difficulty, 
                limit: 20
            )
            
            if cachedPlants.count >= 4 {
                // We have enough cached plants, use them
                plants = Array(cachedPlants.shuffled().prefix(4))
            } else {
                // Not enough cached plants, try to fetch from API
                do {
                    let fetchedPlants = try await plantAPIService.fetchPopularPlants(
                        difficulty: session.difficulty,
                        limit: 4
                    )
                    
                    // Cache the newly fetched plants for future offline use
                    try await plantCacheService.cachePlants(fetchedPlants)
                    plants = fetchedPlants
                    
                } catch {
                    // API failed, use whatever cached plants we have
                    if !cachedPlants.isEmpty {
                        plants = cachedPlants
                    } else {
                        throw SingleUserGameError.noPlantDataAvailable
                    }
                }
            }
        } catch {
            // Cache also failed, try API as last resort
            do {
                plants = try await plantAPIService.fetchPopularPlants(
                    difficulty: session.difficulty,
                    limit: 4
                )
            } catch {
                throw SingleUserGameError.noPlantDataAvailable
            }
        }
        
        guard let targetPlant = plants.first else {
            throw SingleUserGameError.noPlantDataAvailable
        }
        
        // Record plant usage for cache management
        try? await plantCacheService.recordPlantUsage(targetPlant.id)
        
        // Generate multiple choice options
        let correctAnswer = targetPlant.primaryCommonName
        
        // Get wrong answers from other plants, preferably from same family for realistic distractors
        var wrongAnswers: [String] = []
        let otherPlants = Array(plants.dropFirst())
        
        // First, try to get plants from the same family for better distractors
        let sameFamilyPlants = otherPlants.filter { $0.family == targetPlant.family && $0.primaryCommonName != correctAnswer }
        
        // Add same family distractors first
        for plant in sameFamilyPlants.prefix(2) {
            wrongAnswers.append(plant.primaryCommonName)
        }
        
        // Fill remaining slots with any other plants
        for plant in otherPlants where wrongAnswers.count < 3 && plant.primaryCommonName != correctAnswer {
            wrongAnswers.append(plant.primaryCommonName)
        }
        
        // If we still need more options, try to get from same family in cache
        if wrongAnswers.count < 3 {
            do {
                let sameFamilyCached = try await plantCacheService.getCachedPlantsForFamily(
                    targetPlant.family, 
                    limit: 5
                )
                
                for plant in sameFamilyCached where wrongAnswers.count < 3 && plant.primaryCommonName != correctAnswer {
                    wrongAnswers.append(plant.primaryCommonName)
                }
            } catch {
                // Ignore cache errors for fallback options
            }
        }
        
        // If we still need more options, add some generic wrong answers
        while wrongAnswers.count < 3 {
            let genericOptions = [
                "Unknown Species A",
                "Unknown Species B", 
                "Unknown Species C",
                "Common Garden Plant",
                "Wild Specimen"
            ]
            for option in genericOptions.shuffled() {
                if wrongAnswers.count < 3 && option != correctAnswer {
                    wrongAnswers.append(option)
                }
            }
        }
        
        // Shuffle all options
        let allOptions = ([correctAnswer] + Array(wrongAnswers.prefix(3))).shuffled()
        
        // Cache the question for this session
        sessionPlantCache[questionKey] = targetPlant
        sessionPlantOptions[questionKey] = allOptions
        
        return (plant: targetPlant, options: allOptions)
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
        sessionPlantCache.removeAll()
        sessionPlantOptions.removeAll()
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