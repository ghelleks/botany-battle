import XCTest
@testable import BotanyBattle

final class BasicUnitTests: XCTestCase {
    
    func testUserModelBasics() {
        let user = User(
            id: "test-id",
            username: "testuser",
            email: "test@example.com",
            displayName: "Test User",
            avatarURL: nil,
            eloRating: 1200,
            totalWins: 5,
            totalLosses: 3,
            totalMatches: 8,
            winRate: 0.625,
            trophies: 150,
            rank: 1,
            isOnline: true,
            lastActive: Date(),
            createdAt: Date(),
            achievements: [],
            level: 1,
            experience: 100,
            experienceToNextLevel: 900
        )
        
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.eloRating, 1200)
        XCTAssertEqual(user.winRate, 0.625)
        XCTAssertEqual(user.totalWins, 5)
    }
    
    func testPlantModelBasics() {
        let plant = Plant(
            id: "test-plant",
            commonName: "Test Plant",
            scientificName: "Testus plantus",
            imageURLs: ["https://example.com/plant.jpg"],
            description: "A test plant for testing",
            facts: ["This is a test fact"],
            difficulty: .medium,
            family: "Testaceae"
        )
        
        XCTAssertEqual(plant.commonName, "Test Plant")
        XCTAssertEqual(plant.difficulty, .medium)
        XCTAssertEqual(plant.facts.count, 1)
    }
    
    func testGameModelBasics() {
        let game = Game(
            id: "test-game",
            state: .waitingForPlayers,
            currentRound: 1,
            maxRounds: 5,
            players: [],
            rounds: [],
            winner: nil,
            createdAt: Date(),
            startedAt: nil,
            endedAt: nil,
            isRanked: true,
            difficulty: .medium
        )
        
        XCTAssertEqual(game.id, "test-game")
        XCTAssertEqual(game.state, .waitingForPlayers)
        XCTAssertEqual(game.maxRounds, 5)
        XCTAssertTrue(game.isRanked)
    }
    
    func testNetworkErrorDescriptions() {
        let afError = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))
        let networkError = NetworkError.requestFailed(afError)
        
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("Request failed"))
    }
    
    func testAPIEndpointPaths() {
        let authEndpoint = APIEndpoint.auth(.login)
        XCTAssertEqual(authEndpoint.path, "/auth/login")
        
        let userEndpoint = APIEndpoint.user(.profile)
        XCTAssertEqual(userEndpoint.path, "/user/profile")
        
        let gameEndpoint = APIEndpoint.game(.create)
        XCTAssertEqual(gameEndpoint.path, "/game/create")
    }
}