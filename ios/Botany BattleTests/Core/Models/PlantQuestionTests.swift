import XCTest
@testable import BotanyBattle

final class PlantQuestionTests: XCTestCase {
    
    func testPlantQuestionInitialization() {
        // Given
        let plant = PlantData(
            name: "Sunflower",
            scientificName: "Helianthus annuus",
            imageURL: "https://example.com/sunflower.jpg",
            description: "Large yellow flower"
        )
        let options = ["Sunflower", "Daisy", "Rose", "Tulip"]
        let correctAnswerIndex = 0
        
        // When
        let question = PlantQuestion(
            plant: plant,
            options: options,
            correctAnswerIndex: correctAnswerIndex
        )
        
        // Then
        XCTAssertEqual(question.plant, plant)
        XCTAssertEqual(question.options, options)
        XCTAssertEqual(question.correctAnswerIndex, correctAnswerIndex)
    }
    
    func testCorrectAnswer() {
        // Given
        let plant = PlantData(
            name: "Maple",
            scientificName: "Acer saccharum",
            imageURL: "https://example.com/maple.jpg",
            description: "Tree with sweet sap"
        )
        let options = ["Oak", "Maple", "Pine", "Birch"]
        let correctIndex = 1
        
        // When
        let question = PlantQuestion(
            plant: plant,
            options: options,
            correctAnswerIndex: correctIndex
        )
        
        // Then
        XCTAssertEqual(question.correctAnswer, "Maple")
        XCTAssertEqual(question.options[question.correctAnswerIndex], question.correctAnswer)
    }
    
    func testIsCorrectAnswer() {
        // Given
        let plant = PlantData(
            name: "Rose",
            scientificName: "Rosa rubiginosa",
            imageURL: "https://example.com/rose.jpg",
            description: "Thorny flowering plant"
        )
        let options = ["Rose", "Daisy", "Lily", "Iris"]
        let question = PlantQuestion(
            plant: plant,
            options: options,
            correctAnswerIndex: 0
        )
        
        // When & Then
        XCTAssertTrue(question.isCorrectAnswer(0))
        XCTAssertFalse(question.isCorrectAnswer(1))
        XCTAssertFalse(question.isCorrectAnswer(2))
        XCTAssertFalse(question.isCorrectAnswer(3))
    }
    
    func testIsCorrectAnswerWithInvalidIndex() {
        // Given
        let plant = PlantData(
            name: "Oak",
            scientificName: "Quercus robur",
            imageURL: "https://example.com/oak.jpg",
            description: "Strong hardwood tree"
        )
        let options = ["Oak", "Pine", "Fir", "Cedar"]
        let question = PlantQuestion(
            plant: plant,
            options: options,
            correctAnswerIndex: 0
        )
        
        // When & Then
        XCTAssertFalse(question.isCorrectAnswer(-1))
        XCTAssertFalse(question.isCorrectAnswer(4))
        XCTAssertFalse(question.isCorrectAnswer(100))
    }
    
    func testQuestionDifficultyBasedOnOptionsCount() {
        // Given
        let plant = PlantData(
            name: "Pine",
            scientificName: "Pinus sylvestris",
            imageURL: "https://example.com/pine.jpg",
            description: "Coniferous evergreen tree"
        )
        
        let easyOptions = ["Pine", "Oak"]
        let normalOptions = ["Pine", "Oak", "Maple", "Birch"]
        let hardOptions = ["Pine", "Fir", "Spruce", "Cedar", "Hemlock", "Larch"]
        
        // When
        let easyQuestion = PlantQuestion(plant: plant, options: easyOptions, correctAnswerIndex: 0)
        let normalQuestion = PlantQuestion(plant: plant, options: normalOptions, correctAnswerIndex: 0)
        let hardQuestion = PlantQuestion(plant: plant, options: hardOptions, correctAnswerIndex: 0)
        
        // Then
        XCTAssertEqual(easyQuestion.options.count, 2)
        XCTAssertEqual(normalQuestion.options.count, 4)
        XCTAssertEqual(hardQuestion.options.count, 6)
    }
    
    func testQuestionEquality() {
        // Given
        let plant = PlantData(
            name: "Fern",
            scientificName: "Pteridium aquilinum",
            imageURL: "https://example.com/fern.jpg",
            description: "Spore-producing plant"
        )
        let options = ["Fern", "Moss", "Algae", "Lichen"]
        
        let question1 = PlantQuestion(plant: plant, options: options, correctAnswerIndex: 0)
        let question2 = PlantQuestion(plant: plant, options: options, correctAnswerIndex: 0)
        let question3 = PlantQuestion(plant: plant, options: options, correctAnswerIndex: 1)
        
        // When & Then
        XCTAssertEqual(question1, question2)
        XCTAssertNotEqual(question1, question3)
    }
    
    func testQuestionCodable() throws {
        // Given
        let plant = PlantData(
            name: "Lavender",
            scientificName: "Lavandula angustifolia",
            imageURL: "https://example.com/lavender.jpg",
            description: "Aromatic purple flower"
        )
        let options = ["Lavender", "Sage", "Rosemary", "Thyme"]
        let originalQuestion = PlantQuestion(
            plant: plant,
            options: options,
            correctAnswerIndex: 0
        )
        
        // When
        let encodedData = try JSONEncoder().encode(originalQuestion)
        let decodedQuestion = try JSONDecoder().decode(PlantQuestion.self, from: encodedData)
        
        // Then
        XCTAssertEqual(originalQuestion, decodedQuestion)
    }
    
    func testQuestionValidation() {
        // Given
        let plant = PlantData(
            name: "Mint",
            scientificName: "Mentha piperita",
            imageURL: "https://example.com/mint.jpg",
            description: "Cooling herb"
        )
        let options = ["Mint", "Basil", "Oregano", "Parsley"]
        
        // When & Then
        // Test that correct answer index is within bounds
        let validQuestion = PlantQuestion(plant: plant, options: options, correctAnswerIndex: 2)
        XCTAssertTrue(validQuestion.correctAnswerIndex >= 0)
        XCTAssertTrue(validQuestion.correctAnswerIndex < options.count)
        
        // Test minimum options requirement
        XCTAssertGreaterThanOrEqual(options.count, 2, "Questions should have at least 2 options")
    }
}