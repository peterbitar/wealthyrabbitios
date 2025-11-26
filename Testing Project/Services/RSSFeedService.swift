import Foundation

// MARK: - RSS Feed Models
struct RSSFeedItem {
    let title: String
    let description: String?
    let link: String
    let pubDate: Date?
    let source: String
}

// MARK: - RSS Feed Service
// Parses RSS feeds from major financial news sources (free, unlimited)
class RSSFeedService {
    static let shared = RSSFeedService()
    
    // Major financial news RSS feeds
    // Note: Reuters discontinued RSS feeds in 2020, removed from list
    private let feedURLs: [(url: String, source: String)] = [
        ("https://feeds.bloomberg.com/markets/news.rss", "Bloomberg"),
        ("https://www.cnbc.com/id/100003114/device/rss/rss.html", "CNBC"),
        ("https://feeds.finance.yahoo.com/rss/2.0/headline", "Yahoo Finance"),
        ("https://www.marketwatch.com/rss/topstories", "MarketWatch"),
        ("https://www.investing.com/rss/news.rss", "Investing.com"),
        ("https://feeds.apnews.com/rss/business", "AP News"),
        ("https://seekingalpha.com/feed.xml", "Seeking Alpha"),
        ("https://www.fool.com/feeds/index.aspx", "Motley Fool")
    ]
    
    private init() {}
    
    // Fetch and parse all RSS feeds
    func fetchAllFeeds(limit: Int = 50) async throws -> [NewsArticle] {
        print("📡 Fetching RSS feeds from \(feedURLs.count) sources...")
        
        // Fetch all feeds in parallel
        var allItems: [RSSFeedItem] = []
        var successCount = 0
        var failureCount = 0
        
        await withTaskGroup(of: [RSSFeedItem].self) { group in
            for feedInfo in feedURLs {
                group.addTask {
                    do {
                        let items = try await self.fetchRSSFeed(url: feedInfo.url, source: feedInfo.source)
                        if !items.isEmpty {
                            print("✅ Successfully fetched \(items.count) items from \(feedInfo.source)")
                        }
                        return items
                    } catch {
                        // Check if it's a timeout error
                        if let urlError = error as? URLError {
                            if urlError.code == .timedOut {
                                print("⏱️ RSS feed timeout from \(feedInfo.source) - check internet connection")
                            } else {
                                print("⚠️ Failed to fetch RSS feed from \(feedInfo.source): \(urlError.localizedDescription)")
                            }
                        } else {
                            print("⚠️ Failed to fetch RSS feed from \(feedInfo.source): \(error.localizedDescription)")
                        }
                        return []
                    }
                }
            }
            
            for await items in group {
                if items.isEmpty {
                    failureCount += 1
                } else {
                    successCount += 1
                    allItems.append(contentsOf: items)
                }
            }
        }
        
        print("📡 RSS fetch summary: \(successCount) succeeded, \(failureCount) failed, \(allItems.count) total items")
        
        // Sort by date (newest first) and limit
        let sortedItems = allItems
            .sorted { ($0.pubDate ?? Date.distantPast) > ($1.pubDate ?? Date.distantPast) }
            .prefix(limit)
        
        print("✅ Fetched \(sortedItems.count) articles from RSS feeds")
        
        // Convert to NewsArticle format
        return sortedItems.map { item in
            self.convertToNewsArticle(item)
        }
    }
    
    // Fetch and parse a single RSS feed
    func fetchRSSFeed(url: String, source: String) async throws -> [RSSFeedItem] {
        guard let feedURL = URL(string: url) else {
            throw RSSError.invalidURL
        }
        
        var request = URLRequest(url: feedURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 20.0 // Increased from 15s to 20s
        request.setValue("Mozilla/5.0 (compatible; RSSReader/1.0)", forHTTPHeaderField: "User-Agent")
        
        // Configure URLSession with better timeout settings
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 20.0
        configuration.timeoutIntervalForResource = 40.0
        let session = URLSession(configuration: configuration)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RSSError.invalidResponse
        }
        
        // Parse XML/RSS
        return try parseRSSFeed(data: data, source: source)
    }
    
    // Parse RSS XML data
    private func parseRSSFeed(data: Data, source: String) throws -> [RSSFeedItem] {
        let parser = XMLParser(data: data)
        let rssParser = RSSParser(source: source)
        parser.delegate = rssParser
        
        guard parser.parse() else {
            throw RSSError.parseError
        }
        
        return rssParser.items
    }
    
    // Convert RSS item to NewsArticle format
    private func convertToNewsArticle(_ item: RSSFeedItem) -> NewsArticle {
        return NewsArticle(
            source: NewsSource(id: nil, name: item.source),
            author: nil,
            title: item.title,
            description: item.description,
            url: item.link,
            urlToImage: nil,
            publishedAt: item.pubDate?.ISO8601Format() ?? Date().ISO8601Format(),
            content: item.description
        )
    }
}

// MARK: - RSS XML Parser
class RSSParser: NSObject, XMLParserDelegate {
    var items: [RSSFeedItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentLink = ""
    private var currentPubDate: Date?
    private let source: String
    
    init(source: String) {
        self.source = source
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentPubDate = nil
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "description":
            currentDescription += trimmed
        case "link":
            currentLink += trimmed
        case "pubDate":
            currentPubDate = parseDate(trimmed)
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            let item = RSSFeedItem(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.isEmpty ? nil : currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: currentPubDate,
                source: source
            )
            items.append(item)
        }
        currentElement = ""
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",  // RFC 822
            "EEE, dd MMM yyyy HH:mm:ss Z",    // RFC 822 variant
            "yyyy-MM-dd'T'HH:mm:ssZ",         // ISO 8601
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"      // ISO 8601 with milliseconds
        ]
        
        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // Try ISO8601DateFormatter as fallback
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return isoFormatter.date(from: dateString) ?? isoFormatter.date(from: dateString.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
    }
}

enum RSSError: LocalizedError {
    case invalidURL
    case invalidResponse
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid RSS feed URL"
        case .invalidResponse:
            return "Invalid response from RSS feed"
        case .parseError:
            return "Failed to parse RSS feed"
        }
    }
}

// Expose a simple utility for extracting the source from an RSS feed URL.
// Example: "https://feeds.bloomberg.com/markets/news.rss" -> "Bloomberg"
extension RSSFeedService {
    func extractSource(from url: String) -> String {
        let knownSources = [
            "Bloomberg": "bloomberg",
            "CNBC": "cnbc",
            "Yahoo Finance": "yahoo",
            "MarketWatch": "marketwatch",
            "Investing.com": "investing",
            "AP News": "apnews",
            "Seeking Alpha": "seekingalpha",
            "Motley Fool": "fool"
        ]
        let lowercasedUrl = url.lowercased()
        for (source, substring) in knownSources {
            if lowercasedUrl.contains(substring) {
                return source
            }
        }
        // Fallback: use hostname capitalized
        if let host = URL(string: url)?.host {
            return host
                .replacingOccurrences(of: "www.", with: "")
                .split(separator: ".")
                .first
                .map { String($0).capitalized } ?? url
        }
        return url
    }
}
