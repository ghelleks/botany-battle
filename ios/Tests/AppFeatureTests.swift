import XCTest
import ComposableArchitecture
@testable import BotanyBattle

@MainActor
final class AppFeatureTests: XCTestCase {
    
    func testTabNavigation() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
        
        await store.send(.tabChanged(.profile)) {
            $0.currentTab = .profile
        }
        
        await store.send(.tabChanged(.shop)) {
            $0.currentTab = .shop
        }
        
        await store.send(.tabChanged(.game)) {
            $0.currentTab = .game
        }
    }
    
    func testOnAppear() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
        
        await store.send(.onAppear)
    }
}