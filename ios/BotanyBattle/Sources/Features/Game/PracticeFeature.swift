import Foundation
import Combine

@MainActor
class PracticeFeature: ObservableObject {
    @Published var gameFeature: GameFeature
    @Published var showEducationalContent = true
    @Published var enableHints = true
    @Published var showPlantFacts = true
    @Published var enableDetailedFeedback = true
    @Published var autoAdvance = false
    @Published var studyMode = false
    
    // Educational features
    @Published var currentPlantFact: String = ""
    @Published var showingHint = false
    @Published var hintText: String = ""
    @Published var learnedPlants: Set<String> = []
    @Published var difficultPlants: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsService: UserDefaultsService
    
    // Practice mode statistics
    var totalQuestionsAnswered: Int = 0
    var correctAnswersInSession: Int = 0
    var incorrectAnswersInSession: Int = 0
    var hintsUsed: Int = 0
    
    var sessionAccuracy: Double {
        guard totalQuestionsAnswered > 0 else { return 0 }
        return Double(correctAnswersInSession) / Double(totalQuestionsAnswered)
    }
    
    var hasUsedHints: Bool {
        return hintsUsed > 0
    }
    
    var learningProgress: Double {
        guard !learnedPlants.isEmpty else { return 0 }
        return Double(learnedPlants.count) / Double(learnedPlants.count + difficultPlants.count)
    }
    
    init(gameFeature: GameFeature = GameFeature(), 
         userDefaultsService: UserDefaultsService = UserDefaultsService()) {
        self.gameFeature = gameFeature
        self.userDefaultsService = userDefaultsService
        
        setupObservers()
        loadSettings()
        configureForPractice()
    }
    
    // MARK: - Public Methods
    
    func startPractice() async {
        gameFeature.setGameMode(.practice)
        resetSessionStats()
        await gameFeature.startGame()
    }
    
    func submitAnswer(_ answerIndex: Int) {
        let wasCorrect = gameFeature.currentQuestion?.isCorrectAnswer(answerIndex) ?? false
        let plantName = gameFeature.currentQuestion?.plant.name ?? ""
        
        totalQuestionsAnswered += 1
        
        if wasCorrect {
            correctAnswersInSession += 1
            handleCorrectAnswer(plantName: plantName)
        } else {
            incorrectAnswersInSession += 1
            handleIncorrectAnswer(plantName: plantName)
        }
        
        if showEducationalContent {
            loadPlantFact()
        }
        
        gameFeature.submitAnswer(answerIndex)
        
        if !autoAdvance && studyMode {
            // In study mode, don't auto-advance to allow review
            return
        }
    }
    
    func showHint() {
        guard enableHints, let currentQuestion = gameFeature.currentQuestion else { return }
        
        hintsUsed += 1
        hintText = generateHint(for: currentQuestion)
        showingHint = true
        
        print("💡 Hint shown: \(hintText)")
    }
    
    func hideHint() {
        showingHint = false
        hintText = ""
    }
    
    func markAsLearned(_ plantName: String) {
        learnedPlants.insert(plantName)
        difficultPlants.remove(plantName)
        saveLearningProgress()
    }
    
    func markAsDifficult(_ plantName: String) {
        difficultPlants.insert(plantName)
        saveLearningProgress()
    }
    
    func reviewDifficultPlants() async {
        // Filter questions to only include difficult plants
        studyMode = true
        await startPractice()
    }
    
    func continueToNextQuestion() {
        // Manual advance for study mode
        if gameFeature.currentQuestionIndex < gameFeature.questions.count - 1 {
            gameFeature.currentQuestionIndex += 1
        } else {
            completePracticeSession()
        }
    }
    
    func restartPractice() async {
        resetSessionStats()
        await gameFeature.restartGame()
    }
    
    func endPractice() {
        completePracticeSession()
        gameFeature.stopGame()
    }
    
    // MARK: - Settings
    
    func toggleEducationalContent() {
        showEducationalContent.toggle()
        saveSettings()
    }
    
    func toggleHints() {
        enableHints.toggle()
        saveSettings()
    }
    
    func togglePlantFacts() {
        showPlantFacts.toggle()
        saveSettings()
    }
    
    func toggleDetailedFeedback() {
        enableDetailedFeedback.toggle()
        saveSettings()
    }
    
    func toggleAutoAdvance() {
        autoAdvance.toggle()
        saveSettings()
    }
    
    func toggleStudyMode() {
        studyMode.toggle()
        saveSettings()
    }
    
    // MARK: - Educational Content
    
    func getPlantCareInstructions() -> String {
        guard let plant = gameFeature.currentQuestion?.plant else { return "" }
        
        return generateCareInstructions(for: plant)
    }
    
    func getRelatedPlants() -> [String] {
        guard let currentPlant = gameFeature.currentQuestion?.plant else { return [] }
        
        // In a real implementation, this would query a plant database
        return generateRelatedPlants(for: currentPlant)
    }
    
    func getPlantClassification() -> PlantClassification {
        guard let plant = gameFeature.currentQuestion?.plant else { 
            return PlantClassification.unknown 
        }
        
        return classifyPlant(plant)
    }
    
    // MARK: - Statistics and Progress
    
    func getSessionSummary() -> PracticeSessionSummary {
        return PracticeSessionSummary(
            questionsAnswered: totalQuestionsAnswered,
            correctAnswers: correctAnswersInSession,
            incorrectAnswers: incorrectAnswersInSession,
            accuracy: sessionAccuracy,
            hintsUsed: hintsUsed,
            plantsLearned: learnedPlants.count,
            difficultPlants: difficultPlants.count,
            sessionDuration: gameFeature.averageTimePerQuestion * Double(totalQuestionsAnswered)
        )
    }
    
    func exportLearningProgress() -> [String: Any] {
        return [
            "learnedPlants": Array(learnedPlants),
            "difficultPlants": Array(difficultPlants),
            "totalSessions": userDefaultsService.integer(forKey: "practice_totalSessions"),
            "totalQuestionsAnswered": userDefaultsService.integer(forKey: "practice_totalQuestions"),
            "overallAccuracy": userDefaultsService.double(forKey: "practice_overallAccuracy")
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        gameFeature.$gameState
            .sink { [weak self] gameState in
                self?.handleGameStateChange(gameState)
            }
            .store(in: &cancellables)
        
        gameFeature.$currentQuestionIndex
            .sink { [weak self] _ in
                self?.loadPlantFact()
            }
            .store(in: &cancellables)
    }
    
    private func configureForPractice() {
        gameFeature.setGameMode(.practice)
    }
    
    private func handleGameStateChange(_ gameState: GameState) {
        switch gameState {
        case .completed:
            completePracticeSession()
        case .idle:
            resetSessionStats()
        default:
            break
        }
    }
    
    private func handleCorrectAnswer(plantName: String) {
        if enableDetailedFeedback {
            print("✅ Correct! Great job identifying \(plantName)")
        }
        
        // Mark as learned if answered correctly multiple times
        let correctCount = userDefaultsService.integer(forKey: "correct_\(plantName)") + 1
        userDefaultsService.set(correctCount, forKey: "correct_\(plantName)")
        
        if correctCount >= 3 {
            markAsLearned(plantName)
        }
    }
    
    private func handleIncorrectAnswer(plantName: String) {
        if enableDetailedFeedback {
            let correctAnswer = gameFeature.currentQuestion?.correctAnswer ?? ""
            print("❌ Incorrect. The correct answer was \(correctAnswer)")
        }
        
        markAsDifficult(plantName)
    }
    
    private func completePracticeSession() {
        // Update overall statistics
        let currentTotal = userDefaultsService.integer(forKey: "practice_totalQuestions")
        userDefaultsService.set(currentTotal + totalQuestionsAnswered, forKey: "practice_totalQuestions")
        
        let currentSessions = userDefaultsService.integer(forKey: "practice_totalSessions")
        userDefaultsService.set(currentSessions + 1, forKey: "practice_totalSessions")
        
        // Update overall accuracy
        let currentCorrect = userDefaultsService.integer(forKey: "practice_totalCorrect")
        userDefaultsService.set(currentCorrect + correctAnswersInSession, forKey: "practice_totalCorrect")
        
        print("📚 Practice session completed: \(correctAnswersInSession)/\(totalQuestionsAnswered) correct")
    }
    
    private func resetSessionStats() {
        totalQuestionsAnswered = 0
        correctAnswersInSession = 0
        incorrectAnswersInSession = 0
        hintsUsed = 0
        currentPlantFact = ""
        showingHint = false
    }
    
    private func loadPlantFact() {
        guard showPlantFacts, let plant = gameFeature.currentQuestion?.plant else {
            currentPlantFact = ""
            return
        }
        
        currentPlantFact = plant.description
    }
    
    private func generateHint(for question: PlantQuestion) -> String {
        let plant = question.plant
        let correctAnswer = question.correctAnswer
        
        // Generate contextual hints
        let hints = [
            "Look at the leaf shape and arrangement",
            "Consider the plant's growing environment",
            "Notice the flower or fruit characteristics",
            "The answer starts with '\(correctAnswer.prefix(1))'",
            "This plant is commonly found in \(getPlantHabitat(plant))",
            "The scientific name gives a clue: \(plant.scientificName)"
        ]
        
        return hints.randomElement() ?? "Take your time and observe the details"
    }
    
    private func generateCareInstructions(for plant: PlantData) -> String {
        // In a real implementation, this would come from a plant care database
        return "Provide adequate sunlight, water regularly but avoid overwatering, and ensure good drainage. Check specific care requirements for \(plant.name)."
    }
    
    private func generateRelatedPlants(for plant: PlantData) -> [String] {
        // In a real implementation, this would query a taxonomy database
        let genus = plant.scientificName.components(separatedBy: " ").first ?? ""
        return ["Other \(genus) species", "Plants in the same family", "Similar-looking plants"]
    }
    
    private func classifyPlant(_ plant: PlantData) -> PlantClassification {
        // Simple classification based on name patterns
        let name = plant.name.lowercased()
        
        if name.contains("tree") || name.contains("oak") || name.contains("maple") {
            return .tree
        } else if name.contains("flower") || name.contains("rose") || name.contains("daisy") {
            return .flower
        } else if name.contains("fern") || name.contains("moss") {
            return .fern
        } else if name.contains("grass") {
            return .grass
        } else {
            return .herb
        }
    }
    
    private func getPlantHabitat(_ plant: PlantData) -> String {
        // Simple habitat classification
        let name = plant.name.lowercased()
        
        if name.contains("water") || name.contains("pond") {
            return "aquatic environments"
        } else if name.contains("desert") || name.contains("cactus") {
            return "arid regions"
        } else if name.contains("forest") || name.contains("tree") {
            return "forests"
        } else {
            return "temperate regions"
        }
    }
    
    private func loadSettings() {
        showEducationalContent = userDefaultsService.bool(forKey: "practice_showEducationalContent")
        enableHints = userDefaultsService.bool(forKey: "practice_enableHints")
        showPlantFacts = userDefaultsService.bool(forKey: "practice_showPlantFacts")
        enableDetailedFeedback = userDefaultsService.bool(forKey: "practice_enableDetailedFeedback")
        autoAdvance = userDefaultsService.bool(forKey: "practice_autoAdvance")
        studyMode = userDefaultsService.bool(forKey: "practice_studyMode")
        
        // Load learning progress
        if let learnedData = userDefaultsService.data(forKey: "practice_learnedPlants"),
           let learned = try? JSONDecoder().decode(Set<String>.self, from: learnedData) {
            learnedPlants = learned
        }
        
        if let difficultData = userDefaultsService.data(forKey: "practice_difficultPlants"),
           let difficult = try? JSONDecoder().decode(Set<String>.self, from: difficultData) {
            difficultPlants = difficult
        }
    }
    
    private func saveSettings() {
        userDefaultsService.set(showEducationalContent, forKey: "practice_showEducationalContent")
        userDefaultsService.set(enableHints, forKey: "practice_enableHints")
        userDefaultsService.set(showPlantFacts, forKey: "practice_showPlantFacts")
        userDefaultsService.set(enableDetailedFeedback, forKey: "practice_enableDetailedFeedback")
        userDefaultsService.set(autoAdvance, forKey: "practice_autoAdvance")
        userDefaultsService.set(studyMode, forKey: "practice_studyMode")
    }
    
    private func saveLearningProgress() {
        if let learnedData = try? JSONEncoder().encode(learnedPlants) {
            userDefaultsService.set(learnedData, forKey: "practice_learnedPlants")
        }
        
        if let difficultData = try? JSONEncoder().encode(difficultPlants) {
            userDefaultsService.set(difficultData, forKey: "practice_difficultPlants")
        }
    }
}

// MARK: - Supporting Types

struct PracticeSessionSummary {
    let questionsAnswered: Int
    let correctAnswers: Int
    let incorrectAnswers: Int
    let accuracy: Double
    let hintsUsed: Int
    let plantsLearned: Int
    let difficultPlants: Int
    let sessionDuration: TimeInterval
    
    var grade: String {
        switch accuracy {
        case 0.9...1.0:
            return "A+"
        case 0.8..<0.9:
            return "A"
        case 0.7..<0.8:
            return "B"
        case 0.6..<0.7:
            return "C"
        default:
            return "Keep practicing!"
        }
    }
}

enum PlantClassification: String, CaseIterable {
    case tree = "Tree"
    case flower = "Flower"
    case fern = "Fern"
    case grass = "Grass"
    case herb = "Herb"
    case shrub = "Shrub"
    case vine = "Vine"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .tree:
            return "tree"
        case .flower:
            return "flower"
        case .fern:
            return "leaf"
        case .grass:
            return "grass"
        case .herb:
            return "herbs"
        case .shrub:
            return "bush"
        case .vine:
            return "vine"
        case .unknown:
            return "questionmark"
        }
    }
}