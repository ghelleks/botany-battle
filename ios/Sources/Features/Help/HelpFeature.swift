import Foundation
import ComposableArchitecture

@Reducer
struct HelpFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTopic: HelpTopic?
        var searchText = ""
        var isPresented = false
        
        var filteredTopics: [HelpTopic] {
            if searchText.isEmpty {
                return HelpTopic.allTopics
            }
            return HelpTopic.allTopics.filter { topic in
                topic.title.localizedCaseInsensitiveContains(searchText) ||
                topic.content.localizedCaseInsensitiveContains(searchText) ||
                topic.keywords.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    enum Action {
        case selectTopic(HelpTopic)
        case clearSelection
        case updateSearchText(String)
        case presentHelp
        case dismissHelp
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .selectTopic(let topic):
                state.selectedTopic = topic
                return .none
                
            case .clearSelection:
                state.selectedTopic = nil
                return .none
                
            case .updateSearchText(let text):
                state.searchText = text
                return .none
                
            case .presentHelp:
                state.isPresented = true
                return .none
                
            case .dismissHelp:
                state.isPresented = false
                state.selectedTopic = nil
                state.searchText = ""
                return .none
            }
        }
    }
}

// MARK: - Help Topic Model
struct HelpTopic: Identifiable, Equatable {
    let id = UUID()
    let category: Category
    let title: String
    let content: String
    let keywords: [String]
    
    enum Category: String, CaseIterable {
        case gameplay = "Gameplay"
        case account = "Account"
        case technical = "Technical"
        case shop = "Shop & Currency"
        case social = "Social"
        
        var icon: String {
            switch self {
            case .gameplay: return "gamecontroller.fill"
            case .account: return "person.fill"
            case .technical: return "gear"
            case .shop: return "bag.fill"
            case .social: return "person.2.fill"
            }
        }
    }
    
    static let allTopics: [HelpTopic] = [
        // Gameplay
        HelpTopic(
            category: .gameplay,
            title: "How to Play",
            content: """
            Botany Battle is a real-time multiplayer game where you compete to identify plants!
            
            **Game Flow:**
            1. Choose a difficulty level (Easy, Medium, Hard, or Expert)
            2. Get matched with another player of similar skill
            3. Play 5 rounds of plant identification
            4. Win rounds by answering correctly and quickly
            5. The player with the most round wins is victorious!
            
            **Tips:**
            • Study plant features like leaf shape, flower structure, and growth patterns
            • Practice with different difficulty levels to improve
            • Use the learning facts shown after each round
            """,
            keywords: ["play", "game", "rules", "rounds", "battle"]
        ),
        
        HelpTopic(
            category: .gameplay,
            title: "Scoring System",
            content: """
            Points are awarded based on correctness and speed:
            
            **Round Scoring:**
            • Correct answer while opponent is wrong: You win the round
            • Both correct: Fastest answer wins the round
            • Both wrong: No one wins the round
            
            **Game Scoring:**
            • Win a game: Earn Trophies (our in-game currency)
            • Trophy amount depends on opponent's skill level
            • Higher difficulty levels earn more Trophies
            
            **Ranking:**
            • Your ELO rating increases with wins
            • Get matched with players of similar skill
            • Climb the leaderboards!
            """,
            keywords: ["scoring", "points", "trophies", "ranking", "elo"]
        ),
        
        HelpTopic(
            category: .gameplay,
            title: "Difficulty Levels",
            content: """
            Choose from four difficulty levels:
            
            **Easy (30 seconds per round):**
            • Common garden plants and houseplants
            • Clear, high-quality images
            • Perfect for beginners
            
            **Medium (20 seconds per round):**
            • Mix of common and less common plants
            • Some seasonal variations
            • Good for casual gardeners
            
            **Hard (15 seconds per round):**
            • Includes rare and exotic species
            • Challenging angles and growth stages
            • For serious plant enthusiasts
            
            **Expert (10 seconds per round):**
            • Scientific nomenclature focus
            • Subtle species variations
            • For botany experts only!
            """,
            keywords: ["difficulty", "easy", "medium", "hard", "expert", "time"]
        ),
        
        // Shop & Currency
        HelpTopic(
            category: .shop,
            title: "Trophies & Shop",
            content: """
            Earn and spend Trophies to customize your experience:
            
            **Earning Trophies:**
            • Win games to earn Trophies
            • Higher difficulty = more Trophies
            • Beating higher-ranked players = bonus Trophies
            • Daily login bonuses
            
            **Shop Items:**
            • Avatar customizations and skins
            • Game backgrounds and themes
            • Collectible badges and titles
            • Special effects and animations
            
            **Note:** All items are cosmetic only - no gameplay advantages!
            """,
            keywords: ["trophies", "shop", "currency", "cosmetic", "avatar"]
        ),
        
        // Account
        HelpTopic(
            category: .account,
            title: "Creating an Account",
            content: """
            Get started with Botany Battle:
            
            **Account Benefits:**
            • Track your wins, losses, and ranking
            • Earn and spend Trophies
            • Challenge friends directly
            • Save your customizations
            • Access game history
            
            **Sign-in Options:**
            • Apple Game Center (recommended)
            • Guest mode (limited features)
            
            **Privacy:**
            • We only collect essential game data
            • No personal information sold
            • Full GDPR compliance
            • Data export/deletion available
            """,
            keywords: ["account", "sign in", "privacy", "game center"]
        ),
        
        HelpTopic(
            category: .account,
            title: "Profile & Statistics",
            content: """
            Track your botanical journey:
            
            **Profile Information:**
            • Username and avatar
            • Current ranking and ELO
            • Total games played
            • Win/loss ratio
            • Favorite difficulty level
            
            **Statistics:**
            • Games won/lost by difficulty
            • Average answer time
            • Most correct plant families
            • Longest winning streaks
            • Trophy earning history
            
            **Achievements:**
            • Unlock badges for milestones
            • Share your accomplishments
            • Special titles for experts
            """,
            keywords: ["profile", "statistics", "ranking", "achievements"]
        ),
        
        // Social
        HelpTopic(
            category: .social,
            title: "Playing with Friends",
            content: """
            Challenge your friends to plant battles:
            
            **Friend Challenges:**
            • Send direct game invitations
            • Choose custom difficulty settings
            • Private games don't affect ranking
            • Share results on social media
            
            **Finding Friends:**
            • Search by username
            • Import from Game Center
            • QR code sharing
            • Nearby device discovery
            
            **Tournaments:**
            • Join community tournaments
            • Create private group tournaments
            • Seasonal special events
            • Leaderboard competitions
            """,
            keywords: ["friends", "challenge", "tournament", "multiplayer"]
        ),
        
        // Technical
        HelpTopic(
            category: .technical,
            title: "Connection Issues",
            content: """
            Troubleshooting connectivity problems:
            
            **Common Solutions:**
            • Check your internet connection
            • Restart the app
            • Update to the latest version
            • Clear app cache (Settings > Storage)
            
            **Game Disconnections:**
            • Games pause when connection is lost
            • 30-second reconnection window
            • Automatic forfeit after timeout
            • No penalty for technical issues
            
            **Performance Issues:**
            • Close background apps
            • Restart your device
            • Free up storage space
            • Check iOS system requirements
            """,
            keywords: ["connection", "internet", "disconnect", "performance"]
        ),
        
        HelpTopic(
            category: .technical,
            title: "System Requirements",
            content: """
            Ensure optimal performance:
            
            **Minimum Requirements:**
            • iOS 15.0 or later
            • iPhone 8 or newer
            • 1GB available storage
            • Internet connection required
            
            **Recommended:**
            • iOS 16.0 or later
            • iPhone 12 or newer
            • 2GB available storage
            • Wi-Fi or 4G/5G connection
            
            **Performance Tips:**
            • Close unused apps
            • Update iOS regularly
            • Clear app cache monthly
            • Restart device if experiencing lag
            """,
            keywords: ["requirements", "ios", "iphone", "storage", "performance"]
        ),
        
        HelpTopic(
            category: .technical,
            title: "Data & Privacy",
            content: """
            Your privacy is important to us:
            
            **Data Collection:**
            • Game statistics and progress
            • App usage analytics
            • Crash reports for improvements
            • No personal information required
            
            **Data Usage:**
            • Improve matchmaking algorithms
            • Enhance game balance
            • Fix bugs and crashes
            • Never sold to third parties
            
            **Your Rights:**
            • Request data export
            • Delete your account anytime
            • Opt out of analytics
            • Contact support for questions
            """,
            keywords: ["privacy", "data", "gdpr", "analytics", "security"]
        )
    ]
}