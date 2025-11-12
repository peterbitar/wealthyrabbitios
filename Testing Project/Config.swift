import Foundation

struct Config {
    // IMPORTANT: Add your OpenAI API key here
    // Get your API key from: https://platform.openai.com/api-keys
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY_HERE"

    // Alpha Vantage API - Get your free key at: https://www.alphavantage.co/support/#api-key
    // Free tier: 25 requests/day, 5 requests/minute
    static let alphaVantageAPIKey = "YOUR_ALPHA_VANTAGE_KEY_HERE"

    // MARK: - Backend API Configuration

    // Backend server URL
    // For production: Change to your deployed backend URL
    static let backendBaseURL = "http://localhost:3000"

    // Network timeout
    static let backendTimeout: TimeInterval = 10.0

    // Device User ID (unique per device installation)
    static var deviceUserId: String {
        let key = "deviceUserId"
        if let saved = UserDefaults.standard.string(forKey: key) {
            return saved
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
