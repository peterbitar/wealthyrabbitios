import Foundation

// MARK: - Event Detection Engine
// Classifies articles into event types using LLM and detects impact labels
class EventDetectionEngine {
    static let shared = EventDetectionEngine()
    
    private let openAIService: OpenAIService?
    private let impactLabelingEngine: ImpactLabelingEngine
    
    init(openAIService: OpenAIService? = nil) {
        if let service = openAIService {
            self.openAIService = service
            self.impactLabelingEngine = ImpactLabelingEngine(openAIService: service)
        } else if !Config.openAIAPIKey.isEmpty {
            let service = OpenAIService(apiKey: Config.openAIAPIKey)
            self.openAIService = service
            self.impactLabelingEngine = ImpactLabelingEngine(openAIService: service)
        } else {
            self.openAIService = nil
            self.impactLabelingEngine = ImpactLabelingEngine(openAIService: nil)
        }
    }
    
    // Detect event type from cleaned article
    func detectEvent(from article: CleanedArticle) async throws -> DetectedEvent {
        guard let openAIService = openAIService else {
            // Fallback to rule-based detection if no OpenAI service
            return ruleBasedDetection(from: article)
        }
        
        // Use LLM for event detection
        let systemPrompt = """
        You are a financial news classifier. Analyze the article and classify it into ONE of these event types:
        
        - earnings: Company earnings reports, quarterly results
        - guidance: Forward-looking guidance, forecasts, outlook
        - product_launch: New product announcements, launches
        - merger_acquisition: M&A deals, acquisitions, mergers
        - regulation: Regulatory changes, government policy affecting companies
        - litigation: Lawsuits, legal disputes, settlements
        - analyst_note: Analyst upgrades, downgrades, price targets
        - macro: Economic indicators, Fed policy, inflation, GDP
        - social_sentiment: Social media buzz, Reddit mentions, viral discussions
        - rumor: Unconfirmed reports, speculation
        - fluff: Generic news, clickbait, low-value content
        
        Respond with ONLY the event type (one word, lowercase, underscore-separated).
        """
        
        let userPrompt = """
        Title: \(article.cleanTitle)
        Description: \(article.cleanDescription)
        Body (first 300 chars): \(String(article.cleanBody.prefix(300)))
        
        Classify this article into one event type.
        """
        
        let userMessage = Message(
            text: userPrompt,
            isFromCurrentUser: true
        )
        
        do {
            let response = try await openAIService.sendMessage(
                conversationHistory: [userMessage],
                systemPrompt: systemPrompt
            )
            
            // Parse response to get event type
            let eventTypeString = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let eventType = EventType(rawValue: eventTypeString) ?? .fluff
            
            // Determine dominant ticker
            let dominantTicker = article.cleanTickers.first
            
            // Calculate confidence (simplified - could be improved)
            let confidence = calculateConfidence(article: article, eventType: eventType)
            
            // Detect impact labels
            let impactLabels = try await impactLabelingEngine.labelArticle(article)
            
            return DetectedEvent(
                cleanedArticleId: article.id,
                eventType: eventType,
                baseScore: eventType.baseScore,
                dominantTicker: dominantTicker,
                confidence: confidence,
                impactLabels: impactLabels
            )
        } catch {
            print("⚠️ LLM event detection failed, using rule-based: \(error.localizedDescription)")
            return ruleBasedDetection(from: article)
        }
    }
    
    // Rule-based fallback detection
    private func ruleBasedDetection(from article: CleanedArticle) -> DetectedEvent {
        let title = article.cleanTitle.lowercased()
        let description = article.cleanDescription.lowercased()
        let body = article.cleanBody.lowercased()
        let combined = title + " " + description + " " + body
        
        var eventType: EventType = .fluff
        var confidence: Double = 0.5
        
        // Earnings
        if combined.contains("earnings") || combined.contains("quarterly results") || combined.contains("q1") || combined.contains("q2") || combined.contains("q3") || combined.contains("q4") {
            eventType = .earnings
            confidence = 0.9
        }
        // Guidance
        else if combined.contains("guidance") || combined.contains("forecast") || combined.contains("outlook") || combined.contains("expects") {
            eventType = .guidance
            confidence = 0.85
        }
        // Product Launch
        else if combined.contains("launches") || combined.contains("announces") || combined.contains("unveils") || combined.contains("introduces") {
            eventType = .productLaunch
            confidence = 0.8
        }
        // M&A
        else if combined.contains("merger") || combined.contains("acquisition") || combined.contains("acquires") || combined.contains("buys") || combined.contains("deal") {
            eventType = .mergerAcquisition
            confidence = 0.85
        }
        // Regulation
        else if combined.contains("regulation") || combined.contains("regulatory") || combined.contains("sec") || combined.contains("fda") || combined.contains("government") {
            eventType = .regulation
            confidence = 0.8
        }
        // Litigation
        else if combined.contains("lawsuit") || combined.contains("sues") || combined.contains("legal") || combined.contains("settlement") {
            eventType = .litigation
            confidence = 0.8
        }
        // Analyst Note
        else if combined.contains("analyst") || combined.contains("upgrade") || combined.contains("downgrade") || combined.contains("price target") {
            eventType = .analystNote
            confidence = 0.75
        }
        // Macro
        else if combined.contains("fed") || combined.contains("inflation") || combined.contains("gdp") || combined.contains("unemployment") || combined.contains("interest rate") {
            eventType = .macro
            confidence = 0.8
        }
        // Social Sentiment
        else if combined.contains("reddit") || combined.contains("social media") || combined.contains("viral") || combined.contains("trending") {
            eventType = .socialSentiment
            confidence = 0.7
        }
        // Rumor
        else if combined.contains("rumor") || combined.contains("reportedly") || combined.contains("sources say") || combined.contains("unconfirmed") {
            eventType = .rumor
            confidence = 0.6
        }
        
        // Get impact labels (rule-based only, no LLM)
        let impactLabels = impactLabelingEngine.detectLabelsByRules(article)
        
        return DetectedEvent(
            cleanedArticleId: article.id,
            eventType: eventType,
            baseScore: eventType.baseScore,
            dominantTicker: article.cleanTickers.first,
            confidence: confidence,
            impactLabels: impactLabels
        )
    }
    
    private func calculateConfidence(article: CleanedArticle, eventType: EventType) -> Double {
        // Base confidence on article quality
        var confidence = 0.7
        
        // Boost confidence if article has good content
        if article.cleanBody.count > 200 {
            confidence += 0.1
        }
        
        if article.cleanTickers.count > 0 {
            confidence += 0.1
        }
        
        if article.sourceQualityScore > 0.8 {
            confidence += 0.1
        }
        
        return min(1.0, confidence)
    }
}


