import Foundation
import Dependencies

protocol UserDefaultsServiceProtocol {
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    func integer(forKey key: String) -> Int
    func set(_ value: Int, forKey key: String)
    func removeObject(forKey key: String)
}

final class UserDefaultsService: UserDefaultsServiceProtocol {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func bool(forKey key: String) -> Bool {
        return userDefaults.bool(forKey: key)
    }
    
    func set(_ value: Bool, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func string(forKey key: String) -> String? {
        return userDefaults.string(forKey: key)
    }
    
    func set(_ value: String?, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func integer(forKey key: String) -> Int {
        return userDefaults.integer(forKey: key)
    }
    
    func set(_ value: Int, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}

extension DependencyValues {
    var userDefaults: UserDefaultsServiceProtocol {
        get { self[UserDefaultsServiceKey.self] }
        set { self[UserDefaultsServiceKey.self] = newValue }
    }
}

private enum UserDefaultsServiceKey: DependencyKey {
    static let liveValue: UserDefaultsServiceProtocol = UserDefaultsService()
    static let testValue: UserDefaultsServiceProtocol = UserDefaultsService(userDefaults: UserDefaults(suiteName: "test")!)
}