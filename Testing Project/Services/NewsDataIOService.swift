import Foundation

// MARK: - NewsData.io Models
struct NewsDataIOResponse: Codable {
    let status: String
    let totalResults: Int
    let results: [NewsDataIOArticle]
    let nextPage: String?
}

struct NewsDataIOArticle: Codable {
    let article_id: String
    let title: String
    let link: String
    let keywords: [String]?
    let creator: [String]?
    let video_url: String?
    let description: String?
    let content: String?
    let pubDate: String
    let image_url: String?
    let source_id: String?
    let source_priority: Int?
    let source_url: String?
    let source_icon: String?
    let language: String
    let country: [String]?
    let category: [String]?
    let sentiment: String?
    let sentiment_stats: String?
    let ai_tag: String?
    let ai_region: String?
    let ai_org: String?
    let ai_person: String?
    let ai_quote: String?
    let ai_abstract: String?
}

// MARK: - NewsData.io Service
// Alternative news API with better free tier limits
class NewsDataIOService {
    static let shared = NewsDataIOService()
    
    private let apiKey: String
    private let baseURL = "https://newsdata.io/api/1"
    
    private init() {
        // Get API key from Config (add it there)
        self.apiKey = Config.newsDataIOAPIKey
    }
    
    // Fetch financial news from NewsData.io
    func fetchFinancialNews(limit: Int = 20) async throws -> [NewsArticle] {
        guard !apiKey.isEmpty else {
            print("⚠️ NewsData.io API key is empty - skipping this source")
            throw NewsDataIOError.missingAPIKey
        }
        
        var components = URLComponents(string: "\(baseURL)/news")!
        components.queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "category", value: "business"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "size", value: "\(limit)")
        ]
        
        guard let url = components.url else {
            throw NewsDataIOError.invalidURL
        }
        
        print("📰 Fetching from NewsData.io...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NewsDataIOError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ NewsData.io Error: Status \(httpResponse.statusCode)")
            throw NewsDataIOError.apiError(httpResponse.statusCode, errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let newsResponse = try decoder.decode(NewsDataIOResponse.self, from: data)
            print("✅ Fetched \(newsResponse.results.count) articles from NewsData.io")
            
            // Convert to NewsArticle format
            return newsResponse.results.map { article in
                self.convertToNewsArticle(article)
            }
        } catch {
            print("❌ Failed to decode NewsData.io response: \(error)")
            throw NewsDataIOError.decodingError(error.localizedDescription)
        }
    }
    
    // Convert NewsData.io article to NewsArticle format
    private func convertToNewsArticle(_ article: NewsDataIOArticle) -> NewsArticle {
        return NewsArticle(
            source: NewsSource(
                id: article.source_id,
                name: article.source_url?.components(separatedBy: "/").first(where: { !$0.isEmpty }) ?? "Unknown"
            ),
            author: article.creator?.first,
            title: article.title,
            description: article.description,
            url: article.link,
            urlToImage: article.image_url,
            publishedAt: article.pubDate,
            content: article.content
        )
    }
}

enum NewsDataIOError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(Int, String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "NewsData.io API key is missing"
        case .invalidURL:
            return "Invalid NewsData.io URL"
        case .invalidResponse:
            return "Invalid response from NewsData.io"
        case .apiError(let code, let message):
            return "NewsData.io error \(code): \(message)"
        case .decodingError(let message):
            return "Failed to decode NewsData.io data: \(message)"
        }
    }
}


