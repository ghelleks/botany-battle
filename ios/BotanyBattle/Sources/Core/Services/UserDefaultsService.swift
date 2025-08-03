import Foundation

protocol UserDefaultsProtocol {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func bool(forKey defaultName: String) -> Bool
    func integer(forKey defaultName: String) -> Int
    func double(forKey defaultName: String) -> Double
    func string(forKey defaultName: String) -> String?
    func data(forKey defaultName: String) -> Data?
    func removeObject(forKey defaultName: String)
    func synchronize() -> Bool
}

extension UserDefaults: UserDefaultsProtocol {}

@MainActor
class UserDefaultsService: ObservableObject {
    private let userDefaults: UserDefaultsProtocol
    
    init(userDefaults: UserDefaultsProtocol = UserDefaults.standard) {
        self.userDefaults = userDefaults
    }
    
    // MARK: - First Launch
    
    var isFirstLaunch: Bool {
        get {
            return !userDefaults.bool(forKey: GameConstants.UserDefaultsKeys.isFirstLaunch)
        }
    }
    
    func markFirstLaunchComplete() {
        userDefaults.set(true, forKey: GameConstants.UserDefaultsKeys.isFirstLaunch)
    }
    
    // MARK: - Tutorial
    
    var tutorialCompleted: Bool {
        get {
            return userDefaults.bool(forKey: GameConstants.UserDefaultsKeys.tutorialCompleted)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.tutorialCompleted)
        }
    }
    
    // MARK: - High Scores
    
    var practiceHighScore: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.practiceHighScore)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.practiceHighScore)
        }
    }
    
    func updatePracticeHighScore(_ score: Int) {
        guard score >= 0 else { return }
        if score > practiceHighScore {
            practiceHighScore = score
            print("🏆 New practice high score: \(score)")
        }
    }
    
    var speedrunBestTime: Double {
        get {
            let time = userDefaults.double(forKey: GameConstants.UserDefaultsKeys.speedrunBestTime)
            return time == 0 ? Double.greatestFiniteMagnitude : time
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.speedrunBestTime)
        }
    }
    
    func updateSpeedrunBestTime(_ time: Double) {
        guard time > 0 else { return }
        if time < speedrunBestTime {
            speedrunBestTime = time
            print("🏆 New speedrun best time: \(time)s")
        }
    }
    
    var timeAttackHighScore: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.timeAttackHighScore)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.timeAttackHighScore)
        }
    }
    
    func updateTimeAttackHighScore(_ score: Int) {
        guard score >= 0 else { return }
        if score > timeAttackHighScore {
            timeAttackHighScore = score
            print("🏆 New time attack high score: \(score)")
        }
    }
    
    // MARK: - Trophies (Currency)
    
    var totalTrophies: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.totalTrophies)
        }
        set {
            let clampedValue = max(0, newValue) // Prevent negative trophies
            userDefaults.set(clampedValue, forKey: GameConstants.UserDefaultsKeys.totalTrophies)
        }
    }
    
    func addTrophies(_ amount: Int) {
        guard amount > 0 else { return }
        totalTrophies += amount
        print("🏆 Earned \(amount) trophies! Total: \(totalTrophies)")
    }
    
    func spendTrophies(_ amount: Int) -> Bool {
        guard amount > 0 && totalTrophies >= amount else {
            print("❌ Insufficient trophies. Need: \(amount), Have: \(totalTrophies)")
            return false
        }
        totalTrophies -= amount
        print("💰 Spent \(amount) trophies. Remaining: \(totalTrophies)")
        return true
    }
    
    func canAfford(_ amount: Int) -> Bool {
        return totalTrophies >= amount
    }
    
    // MARK: - Game Statistics
    
    var gamesPlayed: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.gamesPlayed)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.gamesPlayed)
        }
    }
    
    func incrementGamesPlayed() {
        gamesPlayed += 1
    }
    
    var perfectGames: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.perfectGames)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.perfectGames)
        }
    }
    
    var totalCorrectAnswers: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.totalCorrectAnswers)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.totalCorrectAnswers)
        }
    }
    
    func recordGameCompletion(correctAnswers: Int, wasPerfect: Bool) {
        incrementGamesPlayed()
        totalCorrectAnswers += correctAnswers
        
        if wasPerfect {
            perfectGames += 1
        }
        
        updateLastPlayDate()
    }
    
    // MARK: - Streaks
    
    var currentStreak: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.currentStreak)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.currentStreak)
        }
    }
    
    var longestStreak: Int {
        get {
            return userDefaults.integer(forKey: GameConstants.UserDefaultsKeys.longestStreak)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.longestStreak)
        }
    }
    
    func incrementStreak() {
        currentStreak += 1
        if currentStreak > longestStreak {
            longestStreak = currentStreak
            print("🔥 New longest streak: \(longestStreak)")
        }
    }
    
    func resetStreak() {
        currentStreak = 0
    }
    
    // MARK: - Last Play Date
    
    var lastPlayDate: Date? {
        get {
            guard let data = userDefaults.data(forKey: GameConstants.UserDefaultsKeys.lastPlayDate) else {
                return nil
            }
            return try? JSONDecoder().decode(Date.self, from: data)
        }
        set {
            if let date = newValue,
               let data = try? JSONEncoder().encode(date) {
                userDefaults.set(data, forKey: GameConstants.UserDefaultsKeys.lastPlayDate)
            } else {
                userDefaults.removeObject(forKey: GameConstants.UserDefaultsKeys.lastPlayDate)
            }
        }
    }
    
    func updateLastPlayDate() {
        lastPlayDate = Date()
    }
    
    // MARK: - Shop Items
    
    var ownedShopItems: Set<Int> {
        get {
            guard let data = userDefaults.data(forKey: GameConstants.UserDefaultsKeys.ownedShopItems),
                  let items = try? JSONDecoder().decode(Set<Int>.self, from: data) else {
                return Set<Int>()
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: GameConstants.UserDefaultsKeys.ownedShopItems)
            }
        }
    }
    
    var equippedItems: Set<Int> {
        get {
            guard let data = userDefaults.data(forKey: GameConstants.UserDefaultsKeys.equippedItems),
                  let items = try? JSONDecoder().decode(Set<Int>.self, from: data) else {
                return Set<Int>()
            }
            return items
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                userDefaults.set(data, forKey: GameConstants.UserDefaultsKeys.equippedItems)
            }
        }
    }
    
    func ownsItem(_ itemID: Int) -> Bool {
        return ownedShopItems.contains(itemID)
    }
    
    func purchaseItem(_ itemID: Int) {
        var owned = ownedShopItems
        owned.insert(itemID)
        ownedShopItems = owned
        print("🛒 Purchased item \(itemID)")
    }
    
    func isItemEquipped(_ itemID: Int) -> Bool {
        return equippedItems.contains(itemID)
    }
    
    func equipItem(_ itemID: Int) {
        guard ownsItem(itemID) else {
            print("❌ Cannot equip item \(itemID): not owned")
            return
        }
        
        var equipped = equippedItems
        equipped.insert(itemID)
        equippedItems = equipped
        print("✨ Equipped item \(itemID)")
    }
    
    func unequipItem(_ itemID: Int) {
        var equipped = equippedItems
        equipped.remove(itemID)
        equippedItems = equipped
        print("🔄 Unequipped item \(itemID)")
    }
    
    // MARK: - Settings
    
    var soundEnabled: Bool {
        get {
            // Default to true if not set
            return userDefaults.object(forKey: GameConstants.UserDefaultsKeys.soundEnabled) == nil ? 
                   true : userDefaults.bool(forKey: GameConstants.UserDefaultsKeys.soundEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.soundEnabled)
        }
    }
    
    var hapticsEnabled: Bool {
        get {
            // Default to true if not set
            return userDefaults.object(forKey: GameConstants.UserDefaultsKeys.hapticsEnabled) == nil ? 
                   true : userDefaults.bool(forKey: GameConstants.UserDefaultsKeys.hapticsEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.hapticsEnabled)
        }
    }
    
    var reducedAnimations: Bool {
        get {
            return userDefaults.bool(forKey: GameConstants.UserDefaultsKeys.reducedAnimations)
        }
        set {
            userDefaults.set(newValue, forKey: GameConstants.UserDefaultsKeys.reducedAnimations)
        }
    }
    
    // MARK: - Data Management
    
    func resetAllData() {
        let keys = [
            GameConstants.UserDefaultsKeys.isFirstLaunch,
            GameConstants.UserDefaultsKeys.tutorialCompleted,
            GameConstants.UserDefaultsKeys.practiceHighScore,
            GameConstants.UserDefaultsKeys.speedrunBestTime,
            GameConstants.UserDefaultsKeys.timeAttackHighScore,
            GameConstants.UserDefaultsKeys.totalTrophies,
            GameConstants.UserDefaultsKeys.gamesPlayed,
            GameConstants.UserDefaultsKeys.perfectGames,
            GameConstants.UserDefaultsKeys.totalCorrectAnswers,
            GameConstants.UserDefaultsKeys.currentStreak,
            GameConstants.UserDefaultsKeys.longestStreak,
            GameConstants.UserDefaultsKeys.lastPlayDate,
            GameConstants.UserDefaultsKeys.ownedShopItems,
            GameConstants.UserDefaultsKeys.equippedItems,
            GameConstants.UserDefaultsKeys.soundEnabled,
            GameConstants.UserDefaultsKeys.hapticsEnabled,
            GameConstants.UserDefaultsKeys.reducedAnimations
        ]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
        }
        
        print("🔄 All user data has been reset")
    }
    
    func exportData() -> [String: Any] {
        return [
            "isFirstLaunch": !isFirstLaunch,
            "tutorialCompleted": tutorialCompleted,
            "practiceHighScore": practiceHighScore,
            "speedrunBestTime": speedrunBestTime == Double.greatestFiniteMagnitude ? 0 : speedrunBestTime,
            "timeAttackHighScore": timeAttackHighScore,
            "totalTrophies": totalTrophies,
            "gamesPlayed": gamesPlayed,
            "perfectGames": perfectGames,
            "totalCorrectAnswers": totalCorrectAnswers,
            "currentStreak": currentStreak,
            "longestStreak": longestStreak,
            "lastPlayDate": lastPlayDate?.timeIntervalSince1970 ?? 0,
            "ownedShopItems": Array(ownedShopItems),
            "equippedItems": Array(equippedItems),
            "soundEnabled": soundEnabled,
            "hapticsEnabled": hapticsEnabled,
            "reducedAnimations": reducedAnimations
        ]
    }
    
    // MARK: - Computed Properties
    
    var averageScore: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(totalCorrectAnswers) / Double(gamesPlayed)
    }
    
    var perfectGamePercentage: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(perfectGames) / Double(gamesPlayed) * 100
    }
    
    var isVeteranPlayer: Bool {
        return gamesPlayed >= 50
    }
    
    var isStreakMaster: Bool {
        return longestStreak >= 10
    }
}