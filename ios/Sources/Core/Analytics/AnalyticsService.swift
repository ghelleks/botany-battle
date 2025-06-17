import Foundation
import os.log

// MARK: - Analytics Service

final class AnalyticsService {
    static let shared = AnalyticsService()
    
    private let logger = Logger(subsystem: "com.botanybattle.app", category: "Analytics")
    private let queue = DispatchQueue(label: "analytics.queue", qos: .utility)
    private var events: [AnalyticsEvent] = []
    private let maxEventStorage = 1000
    
    private init() {
        // Start periodic flush
        Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
            self.flushEvents()
        }
    }
    
    // MARK: - Single User Game Analytics
    
    func recordGameStart(mode: GameMode, difficulty: Game.Difficulty) {
        let event = AnalyticsEvent(
            name: "game_started",
            category: .gamePlay,
            parameters: [
                "mode": mode.rawValue,
                "difficulty": difficulty.rawValue
            ]
        )
        recordEvent(event)
    }
    
    func recordGameComplete(
        mode: GameMode,
        difficulty: Game.Difficulty,
        duration: TimeInterval,
        correctAnswers: Int,
        totalAnswers: Int,
        score: Int,
        isNewPersonalBest: Bool
    ) {
        let accuracy = totalAnswers > 0 ? Double(correctAnswers) / Double(totalAnswers) : 0.0
        
        let event = AnalyticsEvent(
            name: "game_completed",
            category: .gamePlay,
            parameters: [
                "mode": mode.rawValue,
                "difficulty": difficulty.rawValue,
                "duration": duration,
                "correct_answers": correctAnswers,
                "total_answers": totalAnswers,
                "accuracy": accuracy,
                "score": score,
                "is_new_personal_best": isNewPersonalBest
            ]
        )
        recordEvent(event)
    }
    
    func recordGameAbandoned(
        mode: GameMode,
        difficulty: Game.Difficulty,
        timeElapsed: TimeInterval,
        questionsAnswered: Int
    ) {
        let event = AnalyticsEvent(
            name: "game_abandoned",
            category: .gamePlay,
            parameters: [
                "mode": mode.rawValue,
                "difficulty": difficulty.rawValue,
                "time_elapsed": timeElapsed,
                "questions_answered": questionsAnswered
            ]
        )
        recordEvent(event)
    }
    
    func recordQuestionAnswer(
        mode: GameMode,
        difficulty: Game.Difficulty,
        plantId: String,
        isCorrect: Bool,
        timeToAnswer: TimeInterval,
        questionIndex: Int
    ) {
        let event = AnalyticsEvent(
            name: "question_answered",
            category: .gamePlay,
            parameters: [
                "mode": mode.rawValue,
                "difficulty": difficulty.rawValue,
                "plant_id": plantId,
                "is_correct": isCorrect,
                "time_to_answer": timeToAnswer,
                "question_index": questionIndex
            ]
        )
        recordEvent(event)
    }
    
    // MARK: - Performance Analytics
    
    func recordPerformanceMetric(
        identifier: String,
        category: String,
        duration: Double,
        timestamp: Date
    ) {
        let event = AnalyticsEvent(
            name: "performance_metric",
            category: .performance,
            parameters: [
                "identifier": identifier,
                "category": category,
                "duration": duration,
                "timestamp": timestamp.timeIntervalSince1970
            ]
        )
        recordEvent(event)
    }
    
    func recordMemoryUsage(_ usage: UInt64) {
        let usageInMB = Double(usage) / 1024.0 / 1024.0
        
        let event = AnalyticsEvent(
            name: "memory_usage",
            category: .performance,
            parameters: [
                "usage_mb": usageInMB,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
        recordEvent(event)
    }
    
    func recordFrameRate(_ fps: Double) {
        let event = AnalyticsEvent(
            name: "frame_rate",
            category: .performance,
            parameters: [
                "fps": fps,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
        recordEvent(event)
    }
    
    // MARK: - Trophy Analytics
    
    func recordTrophiesEarned(
        amount: Int,
        mode: GameMode,
        difficulty: Game.Difficulty,
        breakdown: TrophyBreakdown
    ) {
        let event = AnalyticsEvent(
            name: "trophies_earned",
            category: .progression,
            parameters: [
                "amount": amount,
                "mode": mode.rawValue,
                "difficulty": difficulty.rawValue,
                "base_trophies": breakdown.baseTrophies,
                "accuracy_bonus": breakdown.accuracyBonus,
                "streak_bonus": breakdown.streakBonus,
                "speed_bonus": breakdown.speedBonus,
                "completion_bonus": breakdown.completionBonus,
                "difficulty_multiplier": breakdown.difficultyMultiplier
            ]
        )
        recordEvent(event)
    }
    
    func recordPersonalBestAchieved(
        mode: GameMode,
        difficulty: Game.Difficulty,
        oldScore: Int?,
        newScore: Int,
        improvement: Int?
    ) {
        var parameters: [String: Any] = [
            "mode": mode.rawValue,
            "difficulty": difficulty.rawValue,
            "new_score": newScore
        ]
        
        if let oldScore = oldScore {
            parameters["old_score"] = oldScore
        }
        
        if let improvement = improvement {
            parameters["improvement"] = improvement
        }
        
        let event = AnalyticsEvent(
            name: "personal_best_achieved",
            category: .progression,
            parameters: parameters
        )
        recordEvent(event)
    }
    
    // MARK: - User Interface Analytics
    
    func recordScreenView(_ screenName: String, previousScreen: String? = nil) {
        var parameters: [String: Any] = ["screen_name": screenName]
        
        if let previousScreen = previousScreen {
            parameters["previous_screen"] = previousScreen
        }
        
        let event = AnalyticsEvent(
            name: "screen_view",
            category: .userInterface,
            parameters: parameters
        )
        recordEvent(event)
    }
    
    func recordButtonTap(_ buttonName: String, screenName: String) {
        let event = AnalyticsEvent(
            name: "button_tap",
            category: .userInterface,
            parameters: [
                "button_name": buttonName,
                "screen_name": screenName
            ]
        )
        recordEvent(event)
    }
    
    func recordAccessibilityUsage(_ feature: String, isEnabled: Bool) {
        let event = AnalyticsEvent(
            name: "accessibility_usage",
            category: .accessibility,
            parameters: [
                "feature": feature,
                "is_enabled": isEnabled
            ]
        )
        recordEvent(event)
    }
    
    // MARK: - Error Analytics
    
    func recordError(
        error: Error,
        context: String,
        additionalInfo: [String: Any] = [:]
    ) {
        var parameters: [String: Any] = [
            "error_description": error.localizedDescription,
            "context": context
        ]
        
        // Merge additional info
        for (key, value) in additionalInfo {
            parameters[key] = value
        }
        
        let event = AnalyticsEvent(
            name: "error_occurred",
            category: .error,
            parameters: parameters
        )
        recordEvent(event)
        
        logger.error("Error recorded: \(error.localizedDescription) in \(context)")
    }
    
    // MARK: - Timer Analytics
    
    func recordTimerValidationIssue(
        mode: GameMode,
        issues: [String],
        adjustedTime: TimeInterval?
    ) {
        var parameters: [String: Any] = [
            "mode": mode.rawValue,
            "issues": issues.joined(separator: ", ")
        ]
        
        if let adjustedTime = adjustedTime {
            parameters["adjusted_time"] = adjustedTime
        }
        
        let event = AnalyticsEvent(
            name: "timer_validation_issue",
            category: .antiCheat,
            parameters: parameters
        )
        recordEvent(event)
    }
    
    func recordSuspiciousActivity(
        type: String,
        details: [String: Any]
    ) {
        var parameters = details
        parameters["type"] = type
        
        let event = AnalyticsEvent(
            name: "suspicious_activity",
            category: .antiCheat,
            parameters: parameters
        )
        recordEvent(event)
        
        logger.warning("Suspicious activity detected: \(type)")
    }
    
    // MARK: - Event Management
    
    private func recordEvent(_ event: AnalyticsEvent) {
        queue.async {
            self.events.append(event)
            
            // Trim events if we exceed the limit
            if self.events.count > self.maxEventStorage {
                self.events.removeFirst(self.events.count - self.maxEventStorage)
            }
            
            self.logger.debug("Recorded analytics event: \(event.name)")
        }
    }
    
    private func flushEvents() {
        queue.async {
            guard !self.events.isEmpty else { return }
            
            // In a real app, this would send events to an analytics service
            // For now, we'll just log the event count
            self.logger.info("Flushing \(self.events.count) analytics events")
            
            // Save events to local storage for later upload
            self.saveEventsToStorage(self.events)
            
            // Clear events after successful upload
            self.events.removeAll()
        }
    }
    
    private func saveEventsToStorage(_ events: [AnalyticsEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            let url = getAnalyticsStorageURL()
            try data.write(to: url)
            logger.debug("Saved \(events.count) events to storage")
        } catch {
            logger.error("Failed to save analytics events: \(error.localizedDescription)")
        }
    }
    
    private func getAnalyticsStorageURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("analytics_events.json")
    }
    
    // MARK: - Public Interface
    
    func getEventSummary() -> AnalyticsEventSummary {
        let eventsByCategory = Dictionary(grouping: events) { $0.category }
        
        var summary = AnalyticsEventSummary(
            totalEvents: events.count,
            categoryCounts: [:],
            timeRange: nil
        )
        
        for (category, categoryEvents) in eventsByCategory {
            summary.categoryCounts[category] = categoryEvents.count
        }
        
        if let firstEvent = events.first, let lastEvent = events.last {
            summary.timeRange = (firstEvent.timestamp, lastEvent.timestamp)
        }
        
        return summary
    }
    
    func clearAllEvents() {
        queue.async {
            self.events.removeAll()
            
            // Also clear stored events
            let url = self.getAnalyticsStorageURL()
            try? FileManager.default.removeItem(at: url)
            
            self.logger.info("Cleared all analytics events")
        }
    }
}

// MARK: - Analytics Event

struct AnalyticsEvent: Codable {
    let id: String
    let name: String
    let category: AnalyticsCategory
    let parameters: [String: Any]
    let timestamp: Date
    
    init(name: String, category: AnalyticsCategory, parameters: [String: Any] = [:]) {
        self.id = UUID().uuidString
        self.name = name
        self.category = category
        self.parameters = parameters
        self.timestamp = Date()
    }
    
    // Custom Codable implementation to handle [String: Any]
    enum CodingKeys: String, CodingKey {
        case id, name, category, parameters, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(AnalyticsCategory.self, forKey: .category)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode parameters as [String: AnyCodable]
        let parametersContainer = try container.decode([String: AnyCodable].self, forKey: .parameters)
        parameters = parametersContainer.mapValues { $0.value }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode parameters as [String: AnyCodable]
        let encodableParameters = parameters.mapValues { AnyCodable($0) }
        try container.encode(encodableParameters, forKey: .parameters)
    }
}

// MARK: - Analytics Category

enum AnalyticsCategory: String, Codable, CaseIterable {
    case gamePlay = "game_play"
    case progression = "progression"
    case userInterface = "user_interface"
    case performance = "performance"
    case accessibility = "accessibility"
    case error = "error"
    case antiCheat = "anti_cheat"
}

// MARK: - Analytics Event Summary

struct AnalyticsEventSummary {
    let totalEvents: Int
    var categoryCounts: [AnalyticsCategory: Int]
    var timeRange: (start: Date, end: Date)?
}

// MARK: - AnyCodable Helper

private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported type"
            ))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Unsupported type"
            ))
        }
    }
}

// MARK: - Analytics Extensions

extension GameMode {
    var analyticsName: String {
        return self.rawValue
    }
}

extension Game.Difficulty {
    var analyticsName: String {
        return self.rawValue
    }
}