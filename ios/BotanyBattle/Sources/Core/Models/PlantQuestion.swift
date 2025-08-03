import Foundation

struct PlantQuestion: Identifiable, Codable, Equatable {
    let id: UUID
    let plant: PlantData
    let options: [String]
    let correctAnswerIndex: Int
    
    init(plant: PlantData, options: [String], correctAnswerIndex: Int) {
        self.id = UUID()
        self.plant = plant
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
    }
    
    // Custom init for testing with fixed UUID
    init(id: UUID = UUID(), plant: PlantData, options: [String], correctAnswerIndex: Int) {
        self.id = id
        self.plant = plant
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
    }
}

// MARK: - Computed Properties
extension PlantQuestion {
    var correctAnswer: String {
        guard correctAnswerIndex >= 0 && correctAnswerIndex < options.count else {
            return ""
        }
        return options[correctAnswerIndex]
    }
    
    var isValid: Bool {
        return correctAnswerIndex >= 0 && 
               correctAnswerIndex < options.count && 
               options.count >= 2 &&
               !plant.name.isEmpty
    }
}

// MARK: - Answer Validation
extension PlantQuestion {
    func isCorrectAnswer(_ selectedIndex: Int) -> Bool {
        guard selectedIndex >= 0 && selectedIndex < options.count else {
            return false
        }
        return selectedIndex == correctAnswerIndex
    }
    
    func isCorrectAnswer(_ selectedOption: String) -> Bool {
        return selectedOption == correctAnswer
    }
}

// MARK: - Factory Methods
extension PlantQuestion {
    static func create(from plant: PlantData, wrongAnswers: [String]) -> PlantQuestion? {
        guard !wrongAnswers.isEmpty else { return nil }
        
        var options = wrongAnswers
        let correctIndex = Int.random(in: 0...wrongAnswers.count)
        options.insert(plant.name, at: correctIndex)
        
        return PlantQuestion(
            plant: plant,
            options: options,
            correctAnswerIndex: correctIndex
        )
    }
    
    static let empty = PlantQuestion(
        plant: PlantData.empty,
        options: [],
        correctAnswerIndex: 0
    )
}