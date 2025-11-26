import Foundation

// MARK: - News API Models
struct NewsAPIResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [NewsArticle]
}

struct NewsArticle: Codable {
    let source: NewsSource
    let author: String?
    let title: String
    let description: String?
    let url: String
    let urlToImage: String?
    let publishedAt: String
    let content: String?
}

struct NewsSource: Codable {
    let id: String?
    let name: String
}

// MARK: - News Service
// Fetches financial and market news from NewsAPI.org
class NewsService {
    static let shared = NewsService()
    
    private let apiKey: String
    private let baseURL = "https://newsapi.org/v2"
    
    private init() {
        self.apiKey = Config.newsAPIKey
    }
    
    // Search for news by query (e.g., ticker symbol)
    func searchNews(query: String, limit: Int = 20) async throws -> [NewsArticle] {
        guard !apiKey.isEmpty else {
            print("⚠️ NewsAPI key is empty - add your API key to Config.swift")
            throw NewsError.missingAPIKey
        }
        
        // Use everything endpoint for search
        var components = URLComponents(string: "\(baseURL)/everything")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "sortBy", value: "publishedAt"),
            URLQueryItem(name: "pageSize", value: "\(limit)")
        ]
        
        guard let url = components.url else {
            throw NewsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = 30.0
        
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        let session = URLSession(configuration: configuration)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NewsError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NewsError.apiError(httpResponse.statusCode, errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let newsResponse = try decoder.decode(NewsAPIResponse.self, from: data)
            return newsResponse.articles
        } catch {
            print("⚠️ News search failed for query '\(query)': \(error.localizedDescription)")
            throw error
        }
    }
    
    // Fetch top financial news
    // Limit can be adjusted based on user's Rabbit Mode to avoid overwhelming
    func fetchFinancialNews(limit: Int = 15) async throws -> [NewsArticle] {
        guard !apiKey.isEmpty else {
            print("⚠️ NewsAPI key is empty - add your API key to Config.swift")
            throw NewsError.missingAPIKey
        }
        
        print("🔑 NewsAPI key present (length: \(apiKey.count))")
        
        // Build URL for financial news
        // Use top-headlines endpoint (more reliable on free tier)
        var components = URLComponents(string: "\(baseURL)/top-headlines")!
        components.queryItems = [
            URLQueryItem(name: "category", value: "business"),
            URLQueryItem(name: "country", value: "us"),
            URLQueryItem(name: "pageSize", value: "\(limit)")
            // Note: API key will be added as header (more secure)
        ]
        
        guard let url = components.url else {
            throw NewsError.invalidURL
        }
        
        print("📰 Fetching financial news from NewsAPI (top-headlines/business)...")
        print("📰 URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Use header for API key (recommended by NewsAPI)
        request.addValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.timeoutInterval = 30.0 // Increased timeout
        
        // Configure URLSession with proper SSL/TLS settings
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        let session = URLSession(configuration: configuration)
        
        print("📰 Starting network request (timeout: 30s)...")
        print("📰 Full URL: \(url.absoluteString.replacingOccurrences(of: apiKey, with: "***"))")
        let startTime = Date()
        
        do {
            let (data, response) = try await session.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            print("📰 Received response in \(String(format: "%.2f", duration))s, data size: \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NewsError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ NewsAPI Error: Status \(httpResponse.statusCode)")
                print("❌ Error response: \(errorMessage.prefix(500))")
                
                // Check for common errors
                if httpResponse.statusCode == 401 {
                    print("⚠️ API key may be invalid or expired - check your NewsAPI.org account")
                } else if httpResponse.statusCode == 429 {
                    print("⚠️ Rate limit exceeded - free tier allows 1,000 requests/day")
                } else if httpResponse.statusCode == 426 {
                    print("⚠️ This endpoint may require a paid plan")
                }
                
                throw NewsError.apiError(httpResponse.statusCode, errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let newsResponse = try decoder.decode(NewsAPIResponse.self, from: data)
                print("✅ Fetched \(newsResponse.articles.count) news articles")
                if newsResponse.articles.isEmpty {
                    print("⚠️ NewsAPI returned 0 articles - this is unusual")
                }
                return newsResponse.articles
            } catch {
                print("❌ Failed to decode news response: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("❌ Response data (first 500 chars): \(jsonString.prefix(500))")
                }
                throw NewsError.decodingError(error.localizedDescription)
            }
        } catch let error as URLError {
            print("❌ URLError occurred: \(error.localizedDescription)")
            print("❌ Error code: \(error.code.rawValue)")
            
            if error.code == .timedOut {
                print("❌ Request timed out after 30 seconds")
                print("⚠️ This might be a network issue or NewsAPI might be slow")
            } else if error.code == .secureConnectionFailed {
                print("❌ SSL/TLS connection failed")
                print("⚠️ This might be due to:")
                print("   - Network proxy or firewall blocking HTTPS")
                print("   - SSL certificate validation issue")
                print("   - Try checking your network settings")
            } else if error.code == .notConnectedToInternet {
                print("❌ No internet connection")
            } else if error.code == .cannotConnectToHost {
                print("❌ Cannot connect to NewsAPI host")
            }
            
            throw error
        } catch {
            // Re-throw any other errors
            print("❌ Unexpected error: \(error)")
            throw error
        }
    }
    
    // Fetch news for specific ticker/symbol
    func fetchNewsForTicker(_ ticker: String, limit: Int = 10) async throws -> [NewsArticle] {
        guard !apiKey.isEmpty else {
            throw NewsError.missingAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/everything")!
        components.queryItems = [
            URLQueryItem(name: "q", value: ticker),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "sortBy", value: "publishedAt"),
            URLQueryItem(name: "pageSize", value: "\(limit)"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw NewsError.invalidURL
        }
        
        print("📰 Fetching news for \(ticker)...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ NewsAPI Error for \(ticker): Status \(httpResponse.statusCode)")
            throw NewsError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let newsResponse = try decoder.decode(NewsAPIResponse.self, from: data)
            print("✅ Fetched \(newsResponse.articles.count) articles for \(ticker)")
            return newsResponse.articles
        } catch {
            print("❌ Failed to decode news response for \(ticker): \(error)")
            throw NewsError.decodingError(error.localizedDescription)
        }
    }
    
    // Fetch top headlines (alternative endpoint)
    func fetchTopHeadlines(category: String = "business", country: String = "us", limit: Int = 20) async throws -> [NewsArticle] {
        guard !apiKey.isEmpty else {
            throw NewsError.missingAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/top-headlines")!
        components.queryItems = [
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "pageSize", value: "\(limit)"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        
        guard let url = components.url else {
            throw NewsError.invalidURL
        }
        
        print("📰 Fetching top headlines...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ NewsAPI Error: Status \(httpResponse.statusCode) - \(errorMessage)")
            throw NewsError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let newsResponse = try decoder.decode(NewsAPIResponse.self, from: data)
            print("✅ Fetched \(newsResponse.articles.count) top headlines")
            return newsResponse.articles
        } catch {
            print("❌ Failed to decode news response: \(error)")
            throw NewsError.decodingError(error.localizedDescription)
        }
    }
}

enum NewsError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(Int, String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "NewsAPI key is missing"
        case .invalidURL:
            return "Invalid NewsAPI URL"
        case .invalidResponse:
            return "Invalid response from NewsAPI"
        case .apiError(let code, let message):
            return "NewsAPI error \(code): \(message)"
        case .decodingError(let message):
            return "Failed to decode news data: \(message)"
        }
    }
}

