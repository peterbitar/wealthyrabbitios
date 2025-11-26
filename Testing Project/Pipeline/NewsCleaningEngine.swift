import Foundation

// MARK: - News Cleaning & Normalization Engine
// Cleans raw articles and creates structured content
class NewsCleaningEngine {
    static let shared = NewsCleaningEngine()
    
    private init() {}
    
    // Clean a raw article into structured format
    // ZERO-WASTE: Detects low-information articles
    func cleanArticle(_ rawArticle: RawArticle) -> CleanedArticle {
        // 1. Strip boilerplate and extract main content
        let cleanTitle = cleanTitle(rawArticle.title)
        let cleanDescription = cleanDescription(rawArticle.description ?? "")
        let cleanBody = extractBody(from: rawArticle.rawHTML, fallback: rawArticle.description ?? "")
        
        // 2. Normalize date
        let normalizedDate = normalizeDate(rawArticle.publishedAt) ?? Date()
        
        // 3. Identify language (simplified - assume English for now)
        let language = detectLanguage(from: cleanTitle + " " + cleanDescription)
        
        // 4. Extract clean metadata
        let author = extractAuthor(from: rawArticle.rawHTML)
        let sourceCategory = categorizeSource(rawArticle.source)
        
        // 5. Extract clean tickers (improved extraction)
        let cleanTickers = extractCleanTickers(
            from: cleanTitle + " " + cleanDescription + " " + cleanBody,
            rawTickers: rawArticle.tickersExtractedRaw ?? []
        )
        
        // 6. Calculate source quality score
        let sourceQualityScore = calculateSourceQuality(
            source: rawArticle.source,
            layer: rawArticle.sourceLayer
        )
        
        // 7. ZERO-WASTE: Detect if article is low-information
        let isLowInformation = detectLowInformation(
            title: cleanTitle,
            description: cleanDescription,
            body: cleanBody
        )
        
        return CleanedArticle(
            rawArticleId: rawArticle.id,
            url: rawArticle.url,
            cleanTitle: cleanTitle,
            cleanDescription: cleanDescription,
            cleanBody: cleanBody,
            cleanTickers: cleanTickers,
            language: language,
            sourceQualityScore: sourceQualityScore,
            normalizedPublishedAt: normalizedDate,
            author: author,
            sourceCategory: sourceCategory,
            isHoldingsNews: rawArticle.isHoldingsNews,
            isLowInformation: isLowInformation
        )
    }
    
    // MARK: - Low Information Detection (Zero-Waste)
    private func detectLowInformation(title: String, description: String, body: String) -> Bool {
        let combinedText = (title + " " + description + " " + body).lowercased()
        
        // Event verbs that indicate something happened
        let eventVerbs = [
            "reports", "announces", "acquires", "sues", "launches", "beats", "misses",
            "raises", "lowers", "increases", "decreases", "surges", "plunges",
            "files", "settles", "approves", "rejects", "wins", "loses"
        ]
        
        // Macro/regulation keywords
        let macroKeywords = ["fed", "inflation", "gdp", "unemployment", "interest rate", "policy"]
        let regulationKeywords = ["regulation", "sec", "fda", "approval", "ban", "fine"]
        
        // Check for numbers (indicating concrete data)
        let hasNumbers = combinedText.range(of: #"\d+"#, options: .regularExpression) != nil
        
        // Check for event verbs
        let hasEventVerb = eventVerbs.contains(where: { combinedText.contains($0) })
        
        // Check for macro/regulation keywords
        let hasMacroKeyword = macroKeywords.contains(where: { combinedText.contains($0) })
        let hasRegulationKeyword = regulationKeywords.contains(where: { combinedText.contains($0) })
        
        // If no numbers, no event verbs, and no macro/regulation keywords → low information
        if !hasNumbers && !hasEventVerb && !hasMacroKeyword && !hasRegulationKeyword {
            return true
        }
        
        return false
    }
    
    // MARK: - Cleaning Methods
    
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        
        // Remove multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Remove tracking parameters from title if it looks like a URL
        if cleaned.contains("?") {
            cleaned = String(cleaned.split(separator: "?").first ?? "")
        }
        
        return cleaned
    }
    
    private func cleanDescription(_ description: String) -> String {
        var cleaned = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        
        // Remove HTML tags if present
        cleaned = removeHTMLTags(from: cleaned)
        
        // Remove boilerplate phrases
        let boilerplate = [
            "Click here to read more",
            "Read the full story",
            "Continue reading",
            "See full article",
            "More details",
            "View original article"
        ]
        
        for phrase in boilerplate {
            cleaned = cleaned.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
        }
        
        // Remove multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractBody(from html: String?, fallback: String) -> String {
        guard let html = html, !html.isEmpty else {
            return fallback
        }
        
        // Simple HTML tag removal (for now - could use proper HTML parser)
        var body = removeHTMLTags(from: html)
        
        // Remove common boilerplate
        let boilerplatePatterns = [
            "Cookie Policy",
            "Privacy Policy",
            "Terms of Service",
            "Subscribe to our newsletter",
            "Follow us on",
            "Share this article",
            "Related articles",
            "Advertisement",
            "Ad",
            "Sponsored"
        ]
        
        for pattern in boilerplatePatterns {
            body = body.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        
        // Remove multiple newlines and spaces
        body = body.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        while body.contains("  ") {
            body = body.replacingOccurrences(of: "  ", with: " ")
        }
        
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removeHTMLTags(from text: String) -> String {
        // Simple HTML tag removal using regex
        let pattern = "<[^>]+>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let cleaned = regex?.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "") ?? text
        
        // Decode HTML entities (basic ones)
        return cleaned
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
    
    private func normalizeDate(_ dateString: String) -> Date? {
        // Try ISO8601 first (most common format)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try DateFormatter with various formats
        let dateFormatters = [
            createDateFormatter("EEE, dd MMM yyyy HH:mm:ss zzz"),
            createDateFormatter("EEE, dd MMM yyyy HH:mm:ss Z"),
            createDateFormatter("yyyy-MM-dd'T'HH:mm:ssZ"),
            createDateFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ"),
            createDateFormatter("yyyy-MM-dd HH:mm:ss")
        ]
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func createDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    private func detectLanguage(from text: String) -> String {
        // Simplified - assume English for now
        // Could use NSLinguisticTagger or ML language detection
        return "en"
    }
    
    private func extractAuthor(from html: String?) -> String? {
        // Simple author extraction from common patterns
        guard let html = html else { return nil }
        
        let patterns = [
            "author\":\"([^\"]+)\"",
            "by ([A-Z][a-z]+ [A-Z][a-z]+)",
            "Author: ([A-Z][a-z]+ [A-Z][a-z]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.count)),
               match.numberOfRanges > 1 {
                let authorRange = match.range(at: 1)
                if authorRange.location != NSNotFound {
                    return (html as NSString).substring(with: authorRange)
                }
            }
        }
        
        return nil
    }
    
    private func categorizeSource(_ source: String) -> String {
        let lowerSource = source.lowercased()
        
        if lowerSource.contains("reuters") || lowerSource.contains("bloomberg") || lowerSource.contains("ap") {
            return "wire"
        } else if lowerSource.contains("finance") || lowerSource.contains("market") {
            return "financial"
        } else if lowerSource.contains("news") {
            return "news"
        } else {
            return "other"
        }
    }
    
    private func extractCleanTickers(from text: String, rawTickers: [String]) -> [String] {
        // Improved ticker extraction
        // First, use raw tickers as starting point
        var tickers = Set<String>(rawTickers)
        
        // Add ticker extraction from text (improved regex)
        let tickerPattern = "\\b([A-Z]{1,5})\\b"
        if let regex = try? NSRegularExpression(pattern: tickerPattern, options: []) {
            let nsString = text as NSString
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in results {
                if match.range.length > 0 {
                    let ticker = nsString.substring(with: match.range)
                    // Filter common words
                    if isValidTicker(ticker) {
                        tickers.insert(ticker)
                    }
                }
            }
        }
        
        // Context matching (e.g., "iPhone maker" -> "AAPL")
        // This would be expanded with ML in production
        let contextMatches = extractTickersFromContext(text)
        tickers.formUnion(contextMatches)
        
        return Array(tickers)
    }
    
    private func isValidTicker(_ ticker: String) -> Bool {
        // Filter out common words
        let commonWords: Set<String> = [
            "THE", "AND", "FOR", "ARE", "BUT", "NOT", "YOU", "ALL", "CAN", "HER", "WAS", "ONE", "OUR", "OUT", "DAY",
            "GET", "HAS", "HIM", "HIS", "HOW", "ITS", "MAY", "NEW", "NOW", "OLD", "SEE", "TWO", "WHO", "WAY", "USE"
        ]
        
        return !commonWords.contains(ticker) && ticker.count >= 1 && ticker.count <= 5
    }
    
    private func extractTickersFromContext(_ text: String) -> Set<String> {
        // Context-based ticker extraction
        // e.g., "iPhone maker" -> "AAPL", "Tesla" -> "TSLA"
        var tickers = Set<String>()
        
        let contextMap: [String: String] = [
            "iphone": "AAPL",
            "apple": "AAPL",
            "tesla": "TSLA",
            "microsoft": "MSFT",
            "google": "GOOGL",
            "amazon": "AMZN",
            "meta": "META",
            "facebook": "META",
            "nvidia": "NVDA",
            "netflix": "NFLX"
        ]
        
        let lowerText = text.lowercased()
        for (keyword, ticker) in contextMap {
            if lowerText.contains(keyword) {
                tickers.insert(ticker)
            }
        }
        
        return tickers
    }
    
    private func calculateSourceQuality(source: String, layer: Int) -> Double {
        // Base quality on layer
        var quality: Double
        
        switch layer {
        case 1: // Wire feeds
            quality = 1.0
        case 2: // Financial aggregators
            quality = 0.85
        case 3: // Supplemental
            quality = 0.60
        default:
            quality = 0.50
        }
        
        // Adjust based on specific source
        let lowerSource = source.lowercased()
        if lowerSource.contains("reuters") {
            quality = 1.0
        } else if lowerSource.contains("bloomberg") {
            quality = 1.0
        } else if lowerSource.contains("cnbc") {
            quality = 0.90
        } else if lowerSource.contains("yahoo") {
            quality = 0.85
        } else if lowerSource.contains("marketwatch") {
            quality = 0.80
        }
        
        return quality
    }
}

