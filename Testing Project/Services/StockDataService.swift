import Foundation

// Stock price data model
struct StockQuote: Codable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let timestamp: Date
}

// Market sentiment
enum MarketSentiment: String {
    case bullish = "Bullish"
    case bearish = "Bearish"
    case neutral = "Neutral"
    case steady = "Steady"
}

// Social buzz level
enum SocialBuzz: String, Codable {
    case hot = "Hot"
    case rising = "Rising"
    case quiet = "Quiet"
    case calm = "Calm"
}

class StockDataService {
    static let shared = StockDataService()
    private let apiKey = Config.alphaVantageAPIKey

    private init() {}
    
    // Fetch stock quote from Alpha Vantage
    func fetchQuote(symbol: String) async throws -> StockQuote {
        // Alpha Vantage API endpoint
        let urlString = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Parse Alpha Vantage response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let globalQuote = json?["Global Quote"] as? [String: String] else {
            throw NSError(domain: "Invalid response", code: -1)
        }
        
        guard let priceStr = globalQuote["05. price"],
              let changeStr = globalQuote["09. change"],
              let changePercentStr = globalQuote["10. change percent"],
              let price = Double(priceStr),
              let change = Double(changeStr),
              let changePercent = Double(changePercentStr.replacingOccurrences(of: "%", with: "")) else {
            throw NSError(domain: "Failed to parse price data", code: -1)
        }
        
        return StockQuote(
            symbol: symbol,
            price: price,
            change: change,
            changePercent: changePercent,
            timestamp: Date()
        )
    }
    
    // Calculate market sentiment based on price movement
    func calculateSentiment(changePercent: Double) -> MarketSentiment {
        switch changePercent {
        case 2...:
            return .bullish
        case ..<(-2):
            return .bearish
        case -0.5..<0.5:
            return .steady
        default:
            return .neutral
        }
    }
    
    // Simulate social buzz (replace with real Reddit/Twitter API later)
    func fetchSocialBuzz(symbol: String) async -> SocialBuzz {
        // For now, return random values
        // TODO: Integrate Reddit/Twitter API
        let buzzes: [SocialBuzz] = [.hot, .rising, .quiet, .calm]
        return buzzes.randomElement() ?? .quiet
    }
    
    // Fetch multiple quotes efficiently
    func fetchQuotes(symbols: [String]) async throws -> [String: StockQuote] {
        var quotes: [String: StockQuote] = [:]
        
        // Fetch quotes sequentially to avoid rate limiting
        for symbol in symbols {
            do {
                let quote = try await fetchQuote(symbol: symbol)
                quotes[symbol] = quote
                
                // Small delay to respect API rate limits (5 requests/minute for free tier)
                if symbol != symbols.last {
                    try await Task.sleep(nanoseconds: 13_000_000_000) // 13 seconds between requests
                }
            } catch {
                print("❌ Failed to fetch quote for \(symbol): \(error)")
                // Continue with other symbols
            }
        }
        
        return quotes
    }
}
