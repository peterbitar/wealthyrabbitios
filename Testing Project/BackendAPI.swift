//
//  BackendAPI.swift
//  WealthyRabbit
//
//  Backend API Service for syncing data with Node.js server
//

import Foundation

// MARK: - API Response Models

struct APIUserResponse: Codable {
    let success: Bool
    let user: APIUser
}

struct APIUser: Codable {
    let userId: String
    let name: String
    var pushToken: String?
    var notificationFrequency: String?
    var notificationSensitivity: String?
    var weeklySummary: Bool?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case pushToken = "push_token"
        case notificationFrequency = "notification_frequency"
        case notificationSensitivity = "notification_sensitivity"
        case weeklySummary = "weekly_summary"
    }
}

struct APIHoldingResponse: Codable {
    let success: Bool
    let holding: APIHolding?
    let holdings: [APIHolding]?
}

struct APIHolding: Codable {
    let userId: String
    let symbol: String
    let name: String
    var allocation: String?
    var note: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case symbol
        case name
        case allocation
        case note
    }
}

struct APIHealthResponse: Codable {
    let status: String
    let timestamp: String
}

struct APIErrorResponse: Codable {
    let error: String
    var message: String?
}

// MARK: - Backend API Service

class BackendAPI {
    static let shared = BackendAPI()

    private let baseURL: String
    private let session: URLSession

    // MARK: - API Endpoints

    private enum APIEndpoint {
        case health
        case userRegister
        case userSettings(userId: String)
        case userPushToken(userId: String)
        case userGet(userId: String)
        case holdingsGet(userId: String)
        case holdingsUpsert
        case holdingsDelete(userId: String, symbol: String)

        func path(baseURL: String) -> String {
            switch self {
            case .health:
                return "\(baseURL)/health"
            case .userRegister:
                return "\(baseURL)/api/users/register"
            case .userSettings(let userId):
                return "\(baseURL)/api/users/\(userId)/settings"
            case .userPushToken(let userId):
                return "\(baseURL)/api/users/\(userId)/push-token"
            case .userGet(let userId):
                return "\(baseURL)/api/users/\(userId)"
            case .holdingsGet(let userId):
                return "\(baseURL)/api/holdings/\(userId)"
            case .holdingsUpsert:
                return "\(baseURL)/api/holdings"
            case .holdingsDelete(let userId, let symbol):
                return "\(baseURL)/api/holdings/\(userId)/\(symbol)"
            }
        }
    }

    // MARK: - Errors

    enum BackendError: LocalizedError {
        case networkUnavailable
        case invalidURL
        case invalidResponse
        case serverError(String)
        case decodingError(Error)
        case timeout

        var errorDescription: String? {
            switch self {
            case .networkUnavailable:
                return "Backend server is not available"
            case .invalidURL:
                return "Invalid backend URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let message):
                return "Server error: \(message)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .timeout:
                return "Request timed out"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        self.baseURL = Config.backendBaseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false

        self.session = URLSession(configuration: config)
    }

    // MARK: - Health Check

    func checkHealth() async -> Bool {
        do {
            let url = URL(string: APIEndpoint.health.path(baseURL: baseURL))!
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            let healthResponse = try JSONDecoder().decode(APIHealthResponse.self, from: data)
            return healthResponse.status == "healthy"
        } catch {
            print("⚠️ Health check failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - User Endpoints

    func registerUser(userId: String, name: String) async throws -> APIUser {
        let endpoint = APIEndpoint.userRegister
        let body: [String: Any] = [
            "userId": userId,
            "name": name
        ]

        let response: APIUserResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body
        )

        return response.user
    }

    func updateUserSettings(userId: String, settings: UserSettings) async throws -> APIUser {
        let endpoint = APIEndpoint.userSettings(userId: userId)

        let body: [String: Any] = [
            "notificationFrequency": settings.notificationFrequency.rawValue,
            "notificationSensitivity": settings.notificationSensitivity.rawValue,
            "weeklySummary": settings.weeklyPortfolioSummary
        ]

        let response: APIUserResponse = try await makeRequest(
            endpoint: endpoint,
            method: "PUT",
            body: body
        )

        return response.user
    }

    func getUser(userId: String) async throws -> APIUser {
        let endpoint = APIEndpoint.userGet(userId: userId)

        let response: APIUserResponse = try await makeRequest(
            endpoint: endpoint,
            method: "GET",
            body: nil
        )

        return response.user
    }

    func updatePushToken(userId: String, pushToken: String) async throws {
        let endpoint = APIEndpoint.userPushToken(userId: userId)

        let body: [String: Any] = [
            "pushToken": pushToken
        ]

        let _: EmptyResponse = try await makeRequest(
            endpoint: endpoint,
            method: "PUT",
            body: body
        )
    }

    // MARK: - Holdings Endpoints

    func getHoldings(userId: String) async throws -> [APIHolding] {
        let endpoint = APIEndpoint.holdingsGet(userId: userId)

        let holdings: [APIHolding] = try await makeRequest(
            endpoint: endpoint,
            method: "GET",
            body: nil
        )

        return holdings
    }

    func upsertHolding(userId: String, holding: Holding) async throws -> APIHolding {
        let endpoint = APIEndpoint.holdingsUpsert

        let body: [String: Any] = [
            "userId": userId,
            "symbol": holding.symbol,
            "name": holding.name,
            "allocation": holding.allocation ?? 0,
            "note": holding.note ?? ""
        ]

        let response: APIHoldingResponse = try await makeRequest(
            endpoint: endpoint,
            method: "POST",
            body: body
        )

        guard let apiHolding = response.holding else {
            throw BackendError.invalidResponse
        }

        return apiHolding
    }

    func deleteHolding(userId: String, symbol: String) async throws {
        let endpoint = APIEndpoint.holdingsDelete(userId: userId, symbol: symbol)

        let _: EmptyResponse = try await makeRequest(
            endpoint: endpoint,
            method: "DELETE",
            body: nil
        )
    }

    // MARK: - Generic Request Handler

    private func makeRequest<T: Decodable>(
        endpoint: APIEndpoint,
        method: String,
        body: [String: Any]?
    ) async throws -> T {
        guard let url = URL(string: endpoint.path(baseURL: baseURL)) else {
            throw BackendError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.invalidResponse
            }

            // Check for HTTP errors
            if httpResponse.statusCode >= 400 {
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    throw BackendError.serverError(errorResponse.message ?? errorResponse.error)
                }
                throw BackendError.serverError("HTTP \(httpResponse.statusCode)")
            }

            // Decode response
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                print("❌ Decoding error: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "invalid")")
                throw BackendError.decodingError(error)
            }
        } catch let error as BackendError {
            throw error
        } catch {
            // Network errors
            if (error as NSError).code == NSURLErrorTimedOut {
                throw BackendError.timeout
            }
            throw BackendError.networkUnavailable
        }
    }
}

// MARK: - Empty Response for DELETE operations

private struct EmptyResponse: Codable {
    // Used for DELETE endpoints that return empty success responses
}
