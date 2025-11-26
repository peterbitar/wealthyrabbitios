import Foundation

// Reddit post data model
struct RedditPost: Codable {
    let title: String
    let selftext: String?
    let score: Int
    let numComments: Int
    let created: Double
    
    enum CodingKeys: String, CodingKey {
        case title
        case selftext
        case score
        case numComments = "num_comments"
        case created = "created_utc"
    }
}

// Reddit API response
struct RedditResponse: Codable {
    let data: RedditData
}

struct RedditData: Codable {
    let children: [RedditChild]
}

struct RedditChild: Codable {
    let data: RedditPost
}

// Social buzz data for a symbol
struct SocialBuzzData: Codable {
    let symbol: String
    let mentions: Int
    let sentiment: Double // -1 to 1 (negative to positive)
    let buzzLevel: SocialBuzz
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case symbol, mentions, sentiment, buzzLevel, timestamp
    }

    init(symbol: String, mentions: Int, sentiment: Double = 0.0) {
        self.symbol = symbol
        self.mentions = mentions
        self.sentiment = sentiment
        self.buzzLevel = SocialBuzzService.calculateBuzzLevel(mentions: mentions)
        self.timestamp = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(String.self, forKey: .symbol)
        mentions = try container.decode(Int.self, forKey: .mentions)
        sentiment = try container.decode(Double.self, forKey: .sentiment)
        buzzLevel = try container.decode(SocialBuzz.self, forKey: .buzzLevel)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(mentions, forKey: .mentions)
        try container.encode(sentiment, forKey: .sentiment)
        try container.encode(buzzLevel, forKey: .buzzLevel)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

class SocialBuzzService {
    static let shared = SocialBuzzService()
    
    // Reddit finance subreddits to monitor
    private let subreddits = ["wallstreetbets", "stocks", "investing", "stockmarket"]
    
    private init() {}
    
    // Fetch social buzz for a stock symbol
    func fetchBuzz(for symbol: String) async throws -> SocialBuzzData {
        var totalMentions = 0
        
        // Search across multiple subreddits
        for subreddit in subreddits.prefix(2) { // Limit to 2 subreddits to avoid rate limiting
            let mentions = try await searchSubreddit(subreddit, for: symbol)
            totalMentions += mentions
            
            // Small delay between requests
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        return SocialBuzzData(symbol: symbol, mentions: totalMentions)
    }
    
    // Search a subreddit for mentions of a symbol
    private func searchSubreddit(_ subreddit: String, for symbol: String) async throws -> Int {
        // Reddit JSON API - no auth required for read-only access
        guard let encodedSymbol = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "Failed to encode symbol", code: -1)
        }

        let urlString = "https://www.reddit.com/r/\(subreddit)/search.json?q=\(encodedSymbol)&restrict_sr=1&limit=100&sort=new&t=week"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: -1)
        }
        
        var request = URLRequest(url: url)
        request.setValue("iOS:WealthyRabbit:v1.0 (by /u/wealthyrabbit)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check for rate limiting and errors
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                print("⚠️ Reddit API rate limit hit for \(symbol)")
                return 0
            }

            if httpResponse.statusCode != 200 {
                print("⚠️ Reddit API returned status code \(httpResponse.statusCode) for \(symbol)")
                return 0
            }
        }

        // Try to decode the response
        let redditResponse: RedditResponse
        do {
            redditResponse = try JSONDecoder().decode(RedditResponse.self, from: data)
        } catch {
            print("❌ Failed to decode Reddit response for \(symbol): \(error)")
            return 0
        }
        
        // Count mentions in titles and content
        var mentions = 0
        let symbolPattern = "\\$?\(symbol)\\b"
        let regex = try? NSRegularExpression(pattern: symbolPattern, options: .caseInsensitive)
        
        for child in redditResponse.data.children {
            let post = child.data
            
            // Check title
            if regex?.firstMatch(in: post.title, range: NSRange(post.title.startIndex..., in: post.title)) != nil {
                mentions += 1
            }
            
            // Check selftext if exists
            if let selftext = post.selftext,
               regex?.firstMatch(in: selftext, range: NSRange(selftext.startIndex..., in: selftext)) != nil {
                mentions += 1
            }
        }
        
        return mentions
    }
    
    // Calculate buzz level based on mention count
    static func calculateBuzzLevel(mentions: Int) -> SocialBuzz {
        switch mentions {
        case 50...:
            return .hot
        case 20..<50:
            return .rising
        case 5..<20:
            return .calm
        default:
            return .quiet
        }
    }
    
    // Fetch buzz for multiple symbols efficiently
    func fetchBuzz(for symbols: [String]) async throws -> [String: SocialBuzzData] {
        var buzzData: [String: SocialBuzzData] = [:]
        
        // Fetch sequentially to respect rate limits
        for symbol in symbols {
            do {
                let data = try await fetchBuzz(for: symbol)
                buzzData[symbol] = data
                print("✅ Fetched social buzz for \(symbol): \(data.mentions) mentions (\(data.buzzLevel.rawValue))")
                
                // Delay between symbols (Reddit allows ~60 requests/minute)
                if symbol != symbols.last {
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
            } catch {
                print("❌ Failed to fetch buzz for \(symbol): \(error)")
                // Use default quiet buzz on error
                buzzData[symbol] = SocialBuzzData(symbol: symbol, mentions: 0)
            }
        }
        
        return buzzData
    }
}
