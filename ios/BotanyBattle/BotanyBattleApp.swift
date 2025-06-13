import SwiftUI
import ComposableArchitecture

@main
struct BotanyBattleApp: App {
    let store = Store(
        initialState: AppFeature.State(),
        reducer: { AppFeature() }
    )
    
    init() {
        AppConfiguration.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}