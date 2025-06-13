import Foundation
import Alamofire
import Dependencies

protocol NetworkServiceProtocol {
    func request<T: Codable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        parameters: [String: Any]?,
        headers: HTTPHeaders?
    ) async throws -> T
    
    func upload<T: Codable>(
        _ endpoint: APIEndpoint,
        data: Data,
        filename: String,
        mimeType: String
    ) async throws -> T
}

final class NetworkService: NetworkServiceProtocol {
    private let session: Session
    private let baseURL: String
    
    init(baseURL: String = APIConfig.baseURL) {
        self.baseURL = baseURL
        self.session = Session(configuration: URLSessionConfiguration.default)
    }
    
    func request<T: Codable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil
    ) async throws -> T {
        let url = baseURL + endpoint.path
        
        let response = await session.request(
            url,
            method: method,
            parameters: parameters,
            encoding: method == .get ? URLEncoding.default : JSONEncoding.default,
            headers: headers
        ).serializingDecodable(T.self).response
        
        switch response.result {
        case .success(let value):
            return value
        case .failure(let error):
            throw NetworkError.requestFailed(error)
        }
    }
    
    func upload<T: Codable>(
        _ endpoint: APIEndpoint,
        data: Data,
        filename: String,
        mimeType: String
    ) async throws -> T {
        let url = baseURL + endpoint.path
        
        let response = await session.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(
                    data,
                    withName: "file",
                    fileName: filename,
                    mimeType: mimeType
                )
            },
            to: url
        ).serializingDecodable(T.self).response
        
        switch response.result {
        case .success(let value):
            return value
        case .failure(let error):
            throw NetworkError.uploadFailed(error)
        }
    }
}

enum NetworkError: Error, LocalizedError {
    case requestFailed(AFError)
    case uploadFailed(AFError)
    case invalidResponse
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

enum APIEndpoint {
    case auth(AuthEndpoint)
    case game(GameEndpoint)
    case plant(PlantEndpoint)
    case user(UserEndpoint)
    case shop(ShopEndpoint)
    
    var path: String {
        switch self {
        case .auth(let endpoint): return "/auth" + endpoint.path
        case .game(let endpoint): return "/game" + endpoint.path
        case .plant(let endpoint): return "/plant" + endpoint.path
        case .user(let endpoint): return "/user" + endpoint.path
        case .shop(let endpoint): return "/shop" + endpoint.path
        }
    }
}

enum AuthEndpoint {
    case login
    case logout
    case refresh
    case profile
    
    var path: String {
        switch self {
        case .login: return "/login"
        case .logout: return "/logout"
        case .refresh: return "/refresh"
        case .profile: return "/profile"
        }
    }
}

enum GameEndpoint {
    case create
    case join(String)
    case leave(String)
    case status(String)
    case answer(String, String)
    case history
    
    var path: String {
        switch self {
        case .create: return "/create"
        case .join(let gameId): return "/\(gameId)/join"
        case .leave(let gameId): return "/\(gameId)/leave"
        case .status(let gameId): return "/\(gameId)/status"
        case .answer(let gameId, let roundId): return "/\(gameId)/rounds/\(roundId)/answer"
        case .history: return "/history"
        }
    }
}

enum PlantEndpoint {
    case search(String)
    case details(String)
    case random
    case difficulty(Game.Difficulty)
    
    var path: String {
        switch self {
        case .search(let query): return "/search?q=\(query)"
        case .details(let plantId): return "/\(plantId)"
        case .random: return "/random"
        case .difficulty(let difficulty): return "/difficulty/\(difficulty.rawValue)"
        }
    }
}

enum UserEndpoint {
    case profile
    case stats
    case update
    case leaderboard
    case avatar
    case password
    case delete
    case settings
    
    var path: String {
        switch self {
        case .profile: return "/profile"
        case .stats: return "/stats"
        case .update: return "/update"
        case .leaderboard: return "/leaderboard"
        case .avatar: return "/avatar"
        case .password: return "/password"
        case .delete: return "/delete"
        case .settings: return "/settings"
        }
    }
}

enum ShopEndpoint {
    case items
    case purchase(String)
    case inventory
    
    var path: String {
        switch self {
        case .items: return "/items"
        case .purchase(let itemId): return "/purchase/\(itemId)"
        case .inventory: return "/inventory"
        }
    }
}

struct APIConfig {
    static let baseURL = "https://api.botanybattle.com/v1"
    static let websocketURL = "wss://ws.botanybattle.com/v1"
}

extension DependencyValues {
    var networkService: NetworkServiceProtocol {
        get { self[NetworkServiceKey.self] }
        set { self[NetworkServiceKey.self] = newValue }
    }
}

private enum NetworkServiceKey: DependencyKey {
    static let liveValue: NetworkServiceProtocol = NetworkService()
}