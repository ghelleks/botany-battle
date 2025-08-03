import XCTest
@testable import BotanyBattle

final class PlantDataTests: XCTestCase {
    
    func testPlantDataInitialization() {
        // Given
        let name = "Oak Tree"
        let scientificName = "Quercus robur"
        let imageURL = "https://example.com/oak.jpg"
        let description = "Mighty oak tree with strong wood"
        
        // When
        let plant = PlantData(
            name: name,
            scientificName: scientificName,
            imageURL: imageURL,
            description: description
        )
        
        // Then
        XCTAssertEqual(plant.name, name)
        XCTAssertEqual(plant.scientificName, scientificName)
        XCTAssertEqual(plant.imageURL, imageURL)
        XCTAssertEqual(plant.description, description)
    }
    
    func testPlantDataEquality() {
        // Given
        let plant1 = PlantData(
            name: "Rose",
            scientificName: "Rosa rubiginosa",
            imageURL: "https://example.com/rose.jpg",
            description: "Beautiful flowering plant"
        )
        
        let plant2 = PlantData(
            name: "Rose",
            scientificName: "Rosa rubiginosa",
            imageURL: "https://example.com/rose.jpg",
            description: "Beautiful flowering plant"
        )
        
        let plant3 = PlantData(
            name: "Daisy",
            scientificName: "Bellis perennis",
            imageURL: "https://example.com/daisy.jpg",
            description: "Small white flower"
        )
        
        // When & Then
        XCTAssertEqual(plant1, plant2)
        XCTAssertNotEqual(plant1, plant3)
    }
    
    func testPlantDataIdentifiable() {
        // Given
        let plant1 = PlantData(
            name: "Ivy",
            scientificName: "Hedera helix",
            imageURL: "https://example.com/ivy.jpg",
            description: "Climbing vine plant"
        )
        
        let plant2 = PlantData(
            name: "Ivy",
            scientificName: "Hedera helix",
            imageURL: "https://example.com/ivy.jpg",
            description: "Climbing vine plant"
        )
        
        // When & Then
        // ID should be consistent for same data
        XCTAssertEqual(plant1.id, plant2.id)
    }
    
    func testPlantDataCodable() throws {
        // Given
        let originalPlant = PlantData(
            name: "Fern",
            scientificName: "Pteridium aquilinum",
            imageURL: "https://example.com/fern.jpg",
            description: "Ancient spore-producing plant"
        )
        
        // When
        let encodedData = try JSONEncoder().encode(originalPlant)
        let decodedPlant = try JSONDecoder().decode(PlantData.self, from: encodedData)
        
        // Then
        XCTAssertEqual(originalPlant, decodedPlant)
    }
    
    func testPlantDataValidation() {
        // Given & When & Then
        // Test that plant data handles empty strings appropriately
        let plantWithEmptyName = PlantData(
            name: "",
            scientificName: "Test species",
            imageURL: "https://example.com/test.jpg",
            description: "Test description"
        )
        
        XCTAssertTrue(plantWithEmptyName.name.isEmpty)
        XCTAssertFalse(plantWithEmptyName.scientificName.isEmpty)
    }
    
    func testImageURLValidation() {
        // Given
        let validURL = "https://example.com/plant.jpg"
        let invalidURL = "not-a-url"
        
        // When
        let plantWithValidURL = PlantData(
            name: "Test Plant",
            scientificName: "Testus plantus",
            imageURL: validURL,
            description: "Test"
        )
        
        let plantWithInvalidURL = PlantData(
            name: "Test Plant",
            scientificName: "Testus plantus",
            imageURL: invalidURL,
            description: "Test"
        )
        
        // Then
        XCTAssertEqual(plantWithValidURL.imageURL, validURL)
        XCTAssertEqual(plantWithInvalidURL.imageURL, invalidURL) // Model shouldn't validate URL format
    }
}