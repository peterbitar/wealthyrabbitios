import Foundation

class DataPersistenceManager {
    static let shared = DataPersistenceManager()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let userName = "userName"
        static let holdings = "holdings"
        static let notificationFrequency = "notificationFrequency"
        static let notificationSensitivity = "notificationSensitivity"
        static let weeklyPortfolioSummary = "weeklyPortfolioSummary"
        static let rabbitMode = "rabbitMode"
        static let conversations = "conversations"
        static let stockQuotes = "stockQuotes"
        static let stockQuotesTimestamp = "stockQuotesTimestamp"
        static let socialBuzzData = "socialBuzzData"
        static let socialBuzzTimestamp = "socialBuzzTimestamp"
    }
    
    private init() {}
    
    // MARK: - User Settings
    
    func saveUserSettings(_ settings: UserSettings) {
        userDefaults.set(settings.userName, forKey: Keys.userName)
        userDefaults.set(settings.notificationFrequency.rawValue, forKey: Keys.notificationFrequency)
        userDefaults.set(settings.notificationSensitivity.rawValue, forKey: Keys.notificationSensitivity)
        userDefaults.set(settings.weeklyPortfolioSummary, forKey: Keys.weeklyPortfolioSummary)
        userDefaults.set(settings.rabbitMode.rawValue, forKey: Keys.rabbitMode)
        
        // Save holdings as JSON
        if let encoded = try? JSONEncoder().encode(settings.holdings) {
            userDefaults.set(encoded, forKey: Keys.holdings)
        }
        
        print("✅ Saved user settings")
    }
    
    func loadUserSettings() -> UserSettings {
        let userName = userDefaults.string(forKey: Keys.userName) ?? "Peter"
        
        // Load holdings
        var holdings: [Holding] = []
        if let data = userDefaults.data(forKey: Keys.holdings),
           let decoded = try? JSONDecoder().decode([Holding].self, from: data) {
            holdings = decoded
        }
        
        // Load notification settings
        let frequencyRaw = userDefaults.string(forKey: Keys.notificationFrequency) ?? NotificationFrequency.balanced.rawValue
        let sensitivityRaw = userDefaults.string(forKey: Keys.notificationSensitivity) ?? NotificationSensitivity.curious.rawValue
        let frequency = NotificationFrequency(rawValue: frequencyRaw) ?? .balanced
        let sensitivity = NotificationSensitivity(rawValue: sensitivityRaw) ?? .curious
        // Use object(forKey:) to check if value exists, otherwise default to true
        let weeklyPortfolioSummary = userDefaults.object(forKey: Keys.weeklyPortfolioSummary) as? Bool ?? true
        
        // Load rabbit mode
        let rabbitModeRaw = userDefaults.string(forKey: Keys.rabbitMode) ?? RabbitMode.smart.rawValue
        let rabbitMode = RabbitMode(rawValue: rabbitModeRaw) ?? .smart
        
        print("✅ Loaded user settings - \(holdings.count) holdings, mode: \(rabbitMode.rawValue)")
        
        return UserSettings(
            userName: userName,
            holdings: holdings,
            notificationFrequency: frequency,
            notificationSensitivity: sensitivity,
            weeklyPortfolioSummary: weeklyPortfolioSummary,
            rabbitMode: rabbitMode
        )
    }
    
    // MARK: - Conversations
    
    func saveConversations(_ conversations: [Conversation]) {
        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: Keys.conversations)
            print("✅ Saved \(conversations.count) conversations")
        }
    }
    
    func loadConversations() -> [Conversation]? {
        guard let data = userDefaults.data(forKey: Keys.conversations),
              let decoded = try? JSONDecoder().decode([Conversation].self, from: data) else {
            return nil
        }
        print("✅ Loaded \(decoded.count) conversations")
        return decoded
    }
    
    // MARK: - Stock Quotes Cache
    
    func saveStockQuotes(_ quotes: [String: StockQuote]) {
        if let encoded = try? JSONEncoder().encode(quotes) {
            userDefaults.set(encoded, forKey: Keys.stockQuotes)
            userDefaults.set(Date(), forKey: Keys.stockQuotesTimestamp)
            print("✅ Cached \(quotes.count) stock quotes")
        }
    }
    
    func loadStockQuotes() -> [String: StockQuote]? {
        // Check if cache is still fresh (less than 5 minutes old)
        if let timestamp = userDefaults.object(forKey: Keys.stockQuotesTimestamp) as? Date {
            let age = Date().timeIntervalSince(timestamp)
            if age > 300 { // 5 minutes
                print("⚠️ Stock quote cache expired (age: \(Int(age))s)")
                return nil
            }
        }
        
        guard let data = userDefaults.data(forKey: Keys.stockQuotes),
              let decoded = try? JSONDecoder().decode([String: StockQuote].self, from: data) else {
            return nil
        }
        
        print("✅ Loaded \(decoded.count) cached stock quotes")
        return decoded
    }
    
    // MARK: - Social Buzz Cache

    func saveSocialBuzz(_ buzzData: [String: SocialBuzzData]) {
        if let encoded = try? JSONEncoder().encode(buzzData) {
            userDefaults.set(encoded, forKey: Keys.socialBuzzData)
            userDefaults.set(Date(), forKey: Keys.socialBuzzTimestamp)
            print("✅ Cached social buzz for \(buzzData.count) symbols")
        }
    }

    func loadSocialBuzz() -> [String: SocialBuzzData]? {
        // Check if cache is still fresh (less than 30 minutes old)
        if let timestamp = userDefaults.object(forKey: Keys.socialBuzzTimestamp) as? Date {
            let age = Date().timeIntervalSince(timestamp)
            if age > 1800 { // 30 minutes
                print("⚠️ Social buzz cache expired (age: \(Int(age/60)) min)")
                return nil
            }
        }

        guard let data = userDefaults.data(forKey: Keys.socialBuzzData),
              let decoded = try? JSONDecoder().decode([String: SocialBuzzData].self, from: data) else {
            return nil
        }

        print("✅ Loaded cached social buzz for \(decoded.count) symbols")
        return decoded
    }

    // Clear all data (for testing/reset)
    func clearAllData() {
        let keys = [Keys.userName, Keys.holdings, Keys.notificationFrequency,
                    Keys.notificationSensitivity, Keys.weeklyPortfolioSummary, Keys.rabbitMode,
                    Keys.conversations, Keys.stockQuotes, Keys.stockQuotesTimestamp,
                    Keys.socialBuzzData, Keys.socialBuzzTimestamp]
        keys.forEach { userDefaults.removeObject(forKey: $0) }
        print("🗑️ Cleared all persisted data")
    }
}
