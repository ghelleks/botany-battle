import XCTest
@testable import BotanyBattle

final class AnalyticsTests: XCTestCase {
    
    func testUserAnalyticsDataStructure() {
        // Test that user analytics data is properly structured
        let user = User(
            id: "analytics-user",
            username: "analyticsuser",
            email: "analytics@example.com",
            displayName: "Analytics User",
            avatarURL: nil,
            eloRating: 1500,
            totalWins: 25,
            totalLosses: 15,
            totalMatches: 40,
            winRate: 0.625,
            trophies: 500,
            rank: 50,
            isOnline: true,
            lastActive: Date(),
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60), // 30 days ago
            achievements: [],
            level: 5,
            experience: 2500,
            experienceToNextLevel: 500
        )
        
        // Verify analytics-relevant data
        XCTAssertEqual(user.totalMatches, 40)
        XCTAssertEqual(user.winRate, 0.625)
        XCTAssertEqual(user.level, 5)
        XCTAssertEqual(user.rank, 50)
        
        // Test calculated analytics
        let averageMatchesPerDay = Double(user.totalMatches) / 30.0
        XCTAssertGreaterThan(averageMatchesPerDay, 1.0)
    }
    
    func testGameAnalyticsTracking() {
        // Test that game analytics are properly tracked
        let game = Game(
            id: "analytics-game",
            state: .finished,
            currentRound: 5,
            maxRounds: 5,
            players: [],
            rounds: [],
            winner: "player1",
            createdAt: Date().addingTimeInterval(-600), // 10 minutes ago
            startedAt: Date().addingTimeInterval(-600),
            endedAt: Date(),
            isRanked: true,
            difficulty: .hard
        )
        
        // Calculate game duration for analytics
        let gameDuration = game.endedAt!.timeIntervalSince(game.startedAt!)
        XCTAssertEqual(gameDuration, 600) // 10 minutes
        
        // Verify analytics-relevant game data
        XCTAssertEqual(game.currentRound, 5)
        XCTAssertEqual(game.difficulty, .hard)
        XCTAssertTrue(game.isRanked)
        XCTAssertNotNil(game.winner)
    }
    
    func testPlantAnalyticsData() {
        // Test that plant analytics data is captured
        let plant = Plant(
            id: "analytics-plant",
            commonName: "Analytics Plant",
            scientificName: "Analyticus plantus",
            imageURLs: ["https://example.com/plant.jpg"],
            description: "A plant for analytics testing",
            facts: ["Analytics fact 1", "Analytics fact 2"],
            difficulty: .hard,
            family: "Analyticaceae"
        )
        
        // Verify analytics-relevant plant data
        XCTAssertEqual(plant.difficulty, .hard)
        XCTAssertEqual(plant.facts.count, 2)
        XCTAssertNotNil(plant.family)
    }
    
    func testPerformanceMetrics() {
        // Test that performance metrics can be calculated
        let startTime = Date()
        
        // Simulate some processing time
        Thread.sleep(forTimeInterval: 0.01) // 10ms
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        XCTAssertGreaterThan(processingTime, 0.009) // At least 9ms
        XCTAssertLessThan(processingTime, 0.1) // Less than 100ms
    }
    
    func testEngagementMetrics() {
        // Test engagement metrics calculation
        let sessions = [
            Date().addingTimeInterval(-3600), // 1 hour ago
            Date().addingTimeInterval(-7200), // 2 hours ago
            Date().addingTimeInterval(-86400) // 1 day ago
        ]
        
        let recentSessions = sessions.filter { session in
            session.timeIntervalSinceNow > -24 * 60 * 60 // Last 24 hours
        }
        
        XCTAssertEqual(recentSessions.count, 2)
    }
}