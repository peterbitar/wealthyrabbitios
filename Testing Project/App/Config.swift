import Foundation

struct Config {
    // IMPORTANT: Add your OpenAI API key here
    // Get your API key from: https://platform.openai.com/api-keys
    // NOTE: For production, use environment variables or secure storage
    static let openAIAPIKey = "" // Add your OpenAI API key here

    // Alpha Vantage API - Get your free key at: https://www.alphavantage.co/support/#api-key
    // Free tier: 25 requests/day, 5 requests/minute
    static let alphaVantageAPIKey = "23QKP0MVG9QZAFHQ"
    
    // ElevenLabs API - Get your API key at: https://elevenlabs.io/
    // Add your API key here for realistic AI voices
    static let elevenLabsAPIKey = "1ed8cabc5adb340e6454786ad6e82698d3885eadd395bb1248565342f3034c81"
    
    // NewsAPI.org - Get your free API key at: https://newsapi.org/
    // Free tier: 1,000 requests/day
    // Add your API key here for real-time financial news
    static let newsAPIKey = "9cce2c48ae78422082e85786fdce5c61"
    
    // NewsData.io - Get your free API key at: https://newsdata.io/
    // Free tier: 200 API credits/day = 2,000 articles/day
    // Add your API key here for additional news source
    static let newsDataIOAPIKey = "" // TODO: Add your NewsData.io API key (optional)

    // MARK: - Backend API Configuration

    // Backend server URL
    // For production: Change to your deployed backend URL
    // static let backendBaseURL = "https://wealthyrabbitios-production.up.railway.app"
    static let backendBaseURL = "http://192.168.0.127:3000"  // Local testing

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
