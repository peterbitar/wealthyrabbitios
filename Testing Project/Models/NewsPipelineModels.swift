import Foundation

// MARK: - Layer 1: Wire Feeds (High-value mandatory)
enum WireFeedSource: String, CaseIterable {
    case bloomberg = "Bloomberg"
    case reuters = "Reuters"
    case apNews = "AP News"
    case prNewswire = "PR Newswire"
    case financialTimes = "Financial Times"
    
    nonisolated var rssURL: String {
        switch self {
        case .bloomberg:
            return "https://feeds.bloomberg.com/markets/news.rss"
        case .reuters:
            // Reuters discontinued RSS feeds in 2020, using Google News RSS as alternative
            return "https://news.google.com/rss/search?q=site:reuters.com+business+finance&hl=en-US&gl=US&ceid=US:en"
        case .apNews:
            return "https://feeds.apnews.com/rss/business"
        case .prNewswire:
            return "https://www.prnewswire.com/rss/financial-services-latest-news/financial-services-latest-news-list.rss"
        case .financialTimes:
            return "https://www.ft.com/?format=rss"
        }
    }
    
    var qualityScore: Double {
        return 1.0 // All wire feeds are top tier
    }
}

// MARK: - Layer 2: Financial News Aggregators
enum FinancialAggregatorSource: String, CaseIterable {
    case yahooFinance = "Yahoo Finance"
    case marketWatch = "MarketWatch"
    case cnbc = "CNBC"
    case investing = "Investing.com"
    case theStreet = "TheStreet"
    
    nonisolated var rssURL: String {
        switch self {
        case .yahooFinance:
            return "https://feeds.finance.yahoo.com/rss/2.0/headline"
        case .marketWatch:
            return "https://www.marketwatch.com/rss/topstories"
        case .cnbc:
            return "https://www.cnbc.com/id/100003114/device/rss/rss.html"
        case .investing:
            return "https://www.investing.com/rss/news.rss"
        case .theStreet:
            return "https://www.thestreet.com/.rss/full-coverage"
        }
    }
    
    var qualityScore: Double {
        switch self {
        case .yahooFinance: return 0.85
        case .marketWatch: return 0.80
        case .cnbc: return 0.90
        case .investing: return 0.75
        case .theStreet: return 0.80
        }
    }
}

// MARK: - Layer 3: Supplemental (Fallback only)
enum SupplementalSource: String {
    case newsAPI = "NewsAPI"
    case newsDataIO = "NewsData.io"
    
    var qualityScore: Double {
        return 0.60 // Lower quality, fallback only
    }
}

// MARK: - Raw Article (Warehouse Layer)
// Stored AS-IS before any cleaning
struct RawArticle: Codable, Identifiable {
    let id: UUID
    let source: String
    let sourceLayer: Int // 1=Wire, 2=Financial, 3=Supplemental
    let title: String
    let rawHTML: String? // Full HTML if available
    let description: String?
    let publishedAt: String // Raw date string
    let url: String
    let tickersExtractedRaw: [String]? // Initial ticker extraction
    let fetchTime: Date
    let isHoldingsNews: Bool // True if from holdings search
    let sourceTag: String? // e.g., "HoldingsSearch"
    
    nonisolated init(
        id: UUID = UUID(),
        source: String,
        sourceLayer: Int,
        title: String,
        rawHTML: String? = nil,
        description: String?,
        publishedAt: String,
        url: String,
        tickersExtractedRaw: [String]? = nil,
        fetchTime: Date = Date(),
        isHoldingsNews: Bool = false,
        sourceTag: String? = nil
    ) {
        self.id = id
        self.source = source
        self.sourceLayer = sourceLayer
        self.title = title
        self.rawHTML = rawHTML
        self.description = description
        self.publishedAt = publishedAt
        self.url = url
        self.tickersExtractedRaw = tickersExtractedRaw
        self.fetchTime = fetchTime
        self.isHoldingsNews = isHoldingsNews
        self.sourceTag = sourceTag
    }
}

// MARK: - Cleaned Article
// After cleaning & normalization
struct CleanedArticle: Codable, Identifiable {
    let id: UUID
    let rawArticleId: UUID // Reference to original
    let url: String // Original URL for deduplication
    let cleanTitle: String
    let cleanDescription: String
    let cleanBody: String
    let cleanTickers: [String]
    let language: String
    let sourceQualityScore: Double
    let normalizedPublishedAt: Date
    let author: String?
    let sourceCategory: String?
    let isHoldingsNews: Bool // True if from holdings search
    let isLowInformation: Bool // True if article lacks clear event information
    
    nonisolated init(
        id: UUID = UUID(),
        rawArticleId: UUID,
        url: String,
        cleanTitle: String,
        cleanDescription: String,
        cleanBody: String,
        cleanTickers: [String],
        language: String = "en",
        sourceQualityScore: Double,
        normalizedPublishedAt: Date,
        author: String? = nil,
        sourceCategory: String? = nil,
        isHoldingsNews: Bool = false,
        isLowInformation: Bool = false
    ) {
        self.id = id
        self.rawArticleId = rawArticleId
        self.url = url
        self.cleanTitle = cleanTitle
        self.cleanDescription = cleanDescription
        self.cleanBody = cleanBody
        self.cleanTickers = cleanTickers
        self.language = language
        self.sourceQualityScore = sourceQualityScore
        self.normalizedPublishedAt = normalizedPublishedAt
        self.author = author
        self.sourceCategory = sourceCategory
        self.isHoldingsNews = isHoldingsNews
        self.isLowInformation = isLowInformation
    }
}

// MARK: - Event Type
enum EventType: String, Codable {
    case earnings = "earnings"
    case guidance = "guidance"
    case productLaunch = "product_launch"
    case mergerAcquisition = "merger_acquisition"
    case regulation = "regulation"
    case litigation = "litigation"
    case analystNote = "analyst_note"
    case macro = "macro"
    case socialSentiment = "social_sentiment"
    case rumor = "rumor"
    case fluff = "fluff"
    
    var baseScore: Double {
        switch self {
        case .earnings: return 1.0
        case .guidance: return 0.95
        case .regulation: return 0.9
        case .mergerAcquisition: return 0.85
        case .productLaunch: return 0.8
        case .macro: return 0.7
        case .litigation: return 0.65
        case .analystNote: return 0.45
        case .socialSentiment: return 0.35
        case .rumor: return 0.25
        case .fluff: return 0.1
        }
    }
    
    var displayName: String {
        switch self {
        case .earnings: return "Earnings"
        case .guidance: return "Guidance"
        case .productLaunch: return "Product Launch"
        case .mergerAcquisition: return "M&A"
        case .regulation: return "Regulation"
        case .litigation: return "Litigation"
        case .analystNote: return "Analyst Note"
        case .macro: return "Macro"
        case .socialSentiment: return "Social Sentiment"
        case .rumor: return "Rumor"
        case .fluff: return "Fluff"
        }
    }
}

// MARK: - Detected Event
struct DetectedEvent: Codable, Identifiable {
    let id: UUID
    let cleanedArticleId: UUID
    let eventType: EventType
    let baseScore: Double
    let dominantTicker: String?
    let confidence: Double // 0.0 to 1.0
    let impactLabels: [ImpactLabel] // Impact categories
    
    nonisolated init(
        id: UUID = UUID(),
        cleanedArticleId: UUID,
        eventType: EventType,
        baseScore: Double,
        dominantTicker: String? = nil,
        confidence: Double = 0.8,
        impactLabels: [ImpactLabel] = []
    ) {
        self.id = id
        self.cleanedArticleId = cleanedArticleId
        self.eventType = eventType
        self.baseScore = baseScore
        self.dominantTicker = dominantTicker
        self.confidence = confidence
        self.impactLabels = impactLabels
    }
}

// MARK: - Event Cluster
// Group of articles covering the same event
struct EventCluster: Codable, Identifiable {
    let id: UUID
    let articles: [CleanedArticle] // All articles in cluster
    let similarityScores: [Double] // Similarity scores between articles
    let eventType: EventType
    let dominantTicker: String?
    let canonicalArticle: CleanedArticle // Best article selected
    let clusterCreatedAt: Date
    
    init(
        id: UUID = UUID(),
        articles: [CleanedArticle],
        similarityScores: [Double],
        eventType: EventType,
        dominantTicker: String?,
        canonicalArticle: CleanedArticle,
        clusterCreatedAt: Date = Date()
    ) {
        self.id = id
        self.articles = articles
        self.similarityScores = similarityScores
        self.eventType = eventType
        self.dominantTicker = dominantTicker
        self.canonicalArticle = canonicalArticle
        self.clusterCreatedAt = clusterCreatedAt
    }
}

// MARK: - User-Specific Event Score
struct UserEventScore: Codable {
    let clusterId: UUID
    let userId: String
    let totalScore: Double
    let breakdown: ScoreBreakdown
    
    struct ScoreBreakdown: Codable {
        let holdingsRelevance: Double // 0.55 weight (increased)
        let impactLabelScore: Double // 0.20 weight
        let eventTypeWeight: Double // 0.15 weight (decreased)
        let recencyScore: Double // 0.10 weight (new)
        let recencyDecay: Double // 0.0 weight (kept for compatibility)
        let sourceQuality: Double // 0.0 weight (kept for compatibility)
        let impactMagnitude: Double // 0.0 weight (kept for compatibility)
        let userInterestTags: Double // 0.0 weight (kept for compatibility)
    }
}

// MARK: - Feed Theme
// LLM-grouped themes from top events
struct FeedTheme: Codable, Identifiable {
    let id: UUID
    let themeName: String // e.g. "Tesla earnings", "AI chip demand"
    let eventClusters: [EventCluster]
    let hook: String // Short, conversational hook
    let contextExplanation: String // Detailed explanation
    let whyItMatters: String // "Why it matters to you"
}

