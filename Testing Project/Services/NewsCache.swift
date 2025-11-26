import Foundation

// MARK: - News Cache
// Caches news articles to reduce API calls
class NewsCache {
    static let shared = NewsCache()
    
    private let cacheKey = "cached_news_articles"
    private let cacheTimestampKey = "cached_news_timestamp"
    private let defaultCacheDuration: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    // Get cached news if still valid
    func getCachedNews(duration: TimeInterval? = nil) -> [NewsArticle]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return nil
        }
        
        let cacheDuration = duration ?? defaultCacheDuration
        let age = Date().timeIntervalSince(timestamp)
        
        // Check if cache is still valid
        guard age < cacheDuration else {
            print("📦 Cache expired (age: \(Int(age))s, max: \(Int(cacheDuration))s)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let articles = try decoder.decode([NewsArticle].self, from: data)
            print("✅ Using cached news (\(articles.count) articles, age: \(Int(age))s)")
            return articles
        } catch {
            print("⚠️ Failed to decode cached news: \(error)")
            return nil
        }
    }
    
    // Save news to cache
    func saveNews(_ articles: [NewsArticle]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(articles)
            
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
            
            print("💾 Cached \(articles.count) news articles")
        } catch {
            print("⚠️ Failed to cache news: \(error)")
        }
    }
    
    // Clear cache
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        print("🗑️ Cleared news cache")
    }
    
    // Check if cache exists and is valid
    func isCacheValid(duration: TimeInterval? = nil) -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date else {
            return false
        }
        
        let cacheDuration = duration ?? defaultCacheDuration
        let age = Date().timeIntervalSince(timestamp)
        return age < cacheDuration
    }
}


