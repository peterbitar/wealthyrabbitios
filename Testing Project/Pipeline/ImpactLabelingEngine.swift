import Foundation

// MARK: - Impact Label
// Categories for labeling news articles by their impact characteristics
enum ImpactLabel: String, Codable, CaseIterable {
    case mostImpactful = "most_impactful"
    case surprising = "surprising"
    case drama = "drama"
    case priceAffectingAbnormal = "price_affecting_abnormal"
    case bigMoves = "big_moves"
    case allTimeHigh = "all_time_high"
    case allTimeLow = "all_time_low"
    case stockPopularity = "stock_popularity"
    
    var displayName: String {
        switch self {
        case .mostImpactful: return "Most Impactful"
        case .surprising: return "Surprising"
        case .drama: return "Drama"
        case .priceAffectingAbnormal: return "Price Affecting"
        case .bigMoves: return "Big Moves"
        case .allTimeHigh: return "All-Time High"
        case .allTimeLow: return "All-Time Low"
        case .stockPopularity: return "Stock Popularity"
        }
    }
    
    var scoreWeight: Double {
        switch self {
        case .mostImpactful: return 0.3
        case .surprising: return 0.25
        case .drama: return 0.2
        case .priceAffectingAbnormal: return 0.35 // Highest for holdings relevance
        case .bigMoves: return 0.3
        case .allTimeHigh: return 0.4 // Very high
        case .allTimeLow: return 0.4 // Very high
        case .stockPopularity: return 0.15
        }
    }
}

// MARK: - Impact Labeling Engine
// Analyzes articles and assigns impact labels
class ImpactLabelingEngine {
    static let shared = ImpactLabelingEngine()
    
    private let openAIService: OpenAIService?
    
    init(openAIService: OpenAIService? = nil) {
        if let service = openAIService {
            self.openAIService = service
        } else if !Config.openAIAPIKey.isEmpty {
            self.openAIService = OpenAIService(apiKey: Config.openAIAPIKey)
        } else {
            self.openAIService = nil
        }
    }
    
    // Label an article with impact categories
    func labelArticle(_ article: CleanedArticle) async throws -> [ImpactLabel] {
        // First, try rule-based detection (fast, no API cost)
        let ruleBasedLabels = detectLabelsByRules(article)
        
        // If we have OpenAI, use LLM for more nuanced detection
        if let openAIService = openAIService {
            do {
                let llmLabels = try await detectLabelsWithLLM(article, service: openAIService)
                // Combine rule-based and LLM labels, prioritizing LLM
                return Array(Set(ruleBasedLabels + llmLabels))
            } catch {
                print("⚠️ LLM labeling failed, using rule-based: \(error.localizedDescription)")
                return ruleBasedLabels
            }
        }
        
        return ruleBasedLabels
    }
    
    // Rule-based label detection (fast, no API cost)
    // Made internal so EventDetectionEngine can use it for fallback
    func detectLabelsByRules(_ article: CleanedArticle) -> [ImpactLabel] {
        var labels: [ImpactLabel] = []
        let text = (article.cleanTitle + " " + article.cleanDescription + " " + article.cleanBody).lowercased()
        
        // Most Impactful
        let impactfulKeywords = ["breakthrough", "historic", "unprecedented", "game-changer", "transformative", "revolutionary", "milestone"]
        if impactfulKeywords.contains(where: { text.contains($0) }) {
            labels.append(.mostImpactful)
        }
        
        // Surprising
        let surprisingKeywords = ["unexpected", "surprise", "shock", "stunned", "caught off guard", "beat expectations", "missed expectations"]
        if surprisingKeywords.contains(where: { text.contains($0) }) {
            labels.append(.surprising)
        }
        
        // Drama
        let dramaKeywords = ["scandal", "controversy", "lawsuit", "investigation", "resignation", "fired", "crisis", "turmoil", "conflict"]
        if dramaKeywords.contains(where: { text.contains($0) }) {
            labels.append(.drama)
        }
        
        // Price Affecting Abnormal
        let priceAffectingKeywords = ["earnings", "guidance", "forecast", "upgrade", "downgrade", "price target", "analyst", "revenue", "profit"]
        let abnormalKeywords = ["unusual", "abnormal", "atypical", "exceptional", "outlier"]
        if priceAffectingKeywords.contains(where: { text.contains($0) }) && 
           abnormalKeywords.contains(where: { text.contains($0) }) {
            labels.append(.priceAffectingAbnormal)
        } else if priceAffectingKeywords.contains(where: { text.contains($0) }) {
            labels.append(.priceAffectingAbnormal)
        }
        
        // Big Moves
        let bigMoveKeywords = ["surge", "plunge", "rally", "crash", "soar", "tumble", "jump", "drop", "spike", "plummet"]
        if bigMoveKeywords.contains(where: { text.contains($0) }) {
            labels.append(.bigMoves)
        }
        // Check for large percentage moves
        if let regex = try? NSRegularExpression(pattern: "\\d+%", options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let matchText = String(text[range])
                    if let percent = Double(matchText.replacingOccurrences(of: "%", with: "")) {
                        if abs(percent) >= 5.0 { // 5% or more is a big move
                            labels.append(.bigMoves)
                            break
                        }
                    }
                }
            }
        }
        
        // All-Time High
        let athKeywords = ["all-time high", "all time high", "ath", "record high", "highest ever", "new high"]
        if athKeywords.contains(where: { text.contains($0) }) {
            labels.append(.allTimeHigh)
        }
        
        // All-Time Low
        let atlKeywords = ["all-time low", "all time low", "atl", "record low", "lowest ever", "new low"]
        if atlKeywords.contains(where: { text.contains($0) }) {
            labels.append(.allTimeLow)
        }
        
        // Stock Popularity
        let popularityKeywords = ["viral", "trending", "popular", "buzz", "hype", "social media", "reddit", "wallstreetbets", "retail investors"]
        if popularityKeywords.contains(where: { text.contains($0) }) {
            labels.append(.stockPopularity)
        }
        
        return Array(Set(labels)) // Remove duplicates
    }
    
    // LLM-based label detection (more nuanced)
    private func detectLabelsWithLLM(_ article: CleanedArticle, service: OpenAIService) async throws -> [ImpactLabel] {
        let systemPrompt = """
        You are a financial news analyzer. Analyze the article and identify which impact labels apply.
        
        Impact Labels:
        - most_impactful: Major breakthroughs, historic events, game-changing news
        - surprising: Unexpected results, surprises, beat/missed expectations
        - drama: Scandals, controversies, lawsuits, crises, conflicts
        - price_affecting_abnormal: Earnings, guidance, analyst notes, revenue/profit news that's unusual
        - big_moves: Large price movements (5%+), surges, plunges, rallies
        - all_time_high: Record highs, new all-time highs
        - all_time_low: Record lows, new all-time lows
        - stock_popularity: Viral, trending, social media buzz, retail investor interest
        
        Respond with ONLY a comma-separated list of applicable labels (e.g., "most_impactful,big_moves,all_time_high").
        If none apply, respond with "none".
        """
        
        let userPrompt = """
        Title: \(article.cleanTitle)
        Description: \(article.cleanDescription)
        Body (first 500 chars): \(String(article.cleanBody.prefix(500)))
        
        Identify which impact labels apply to this article.
        """
        
        let userMessage = Message(text: userPrompt, isFromCurrentUser: true)
        
        let response = try await service.sendMessage(
            conversationHistory: [userMessage],
            systemPrompt: systemPrompt
        )
        
        // Parse response
        let labels = parseLabelsFromResponse(response)
        return labels
    }
    
    private func parseLabelsFromResponse(_ response: String) -> [ImpactLabel] {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if cleaned == "none" || cleaned.isEmpty {
            return []
        }
        
        let labelStrings = cleaned.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var labels: [ImpactLabel] = []
        
        for labelString in labelStrings {
            if let label = ImpactLabel.allCases.first(where: { $0.rawValue == labelString }) {
                labels.append(label)
            }
        }
        
        return labels
    }
}

