import Foundation

// MARK: - Feed Builder Engine
// 2-stage selection + LLM grouping into themes
class FeedBuilderEngine {
    static let shared = FeedBuilderEngine()
    
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
    
    // Build personalized feed for user
    // ZERO-WASTE: Strict limits based on Rabbit mode
    func buildFeed(
        clusters: [EventCluster],
        userScores: [UserEventScore],
        userHoldings: [Holding],
        rabbitMode: RabbitMode = .smart
    ) async throws -> [FeedTheme] {
        // ZERO-WASTE: Strict limits (no filler)
        let limit: Int
        switch rabbitMode {
        case .beginner:
            limit = 6
        case .smart:
            limit = 5
        case .focus:
            limit = 4
        }
        
        // Stage 1: Select top events based on user scores (strict limit)
        let topEvents = selectTopEvents(clusters: clusters, userScores: userScores, limit: limit, rabbitMode: rabbitMode)
        
        // Stage 2: Group into themes using LLM (max 3-4 themes, not 6)
        let maxThemes = min(4, max(3, topEvents.count / 2)) // 3-4 themes max
        let themes = try await groupIntoThemes(
            clusters: topEvents,
            userHoldings: userHoldings,
            maxThemes: maxThemes
        )
        
        return themes
    }
    
    // Stage 1: Select top events (ZERO-WASTE: strict limits, no filler)
    private func selectTopEvents(
        clusters: [EventCluster],
        userScores: [UserEventScore],
        limit: Int,
        rabbitMode: RabbitMode
    ) -> [EventCluster] {
        print("\n🎯 FILTERING: Selecting top \(limit) most important events from \(clusters.count) clusters (ZERO-WASTE mode)...")
        
        // Create score map and breakdown map
        let scoreMap = Dictionary(uniqueKeysWithValues: userScores.map { ($0.clusterId, $0.totalScore) })
        let breakdownMap = Dictionary(uniqueKeysWithValues: userScores.map { ($0.clusterId, $0.breakdown) })
        
        // Sort clusters by score (prioritize: holdings relevance > impact labels > event type > recency)
        let sorted = clusters.sorted { cluster1, cluster2 in
            let score1 = scoreMap[cluster1.id] ?? 0.0
            let score2 = scoreMap[cluster2.id] ?? 0.0
            
            // If scores are very close, use secondary sorting
            if abs(score1 - score2) < 0.01 {
                // Secondary sort by holdings relevance
                let breakdown1 = breakdownMap[cluster1.id]
                let breakdown2 = breakdownMap[cluster2.id]
                let holdings1 = breakdown1?.holdingsRelevance ?? 0.0
                let holdings2 = breakdown2?.holdingsRelevance ?? 0.0
                if abs(holdings1 - holdings2) > 0.01 {
                    return holdings1 > holdings2
                }
                // Tertiary sort by impact label score
                let impact1 = breakdown1?.impactLabelScore ?? 0.0
                let impact2 = breakdown2?.impactLabelScore ?? 0.0
                return impact1 > impact2
            }
            
            return score1 > score2
        }
        
        // ZERO-WASTE: Strict limit (no filler, even if fewer than limit)
        let finalSelected = Array(sorted.prefix(limit))
        
        // Log accept/reject decisions
        print("\n✅ ACCEPTED (\(finalSelected.count) events):")
        for (index, cluster) in finalSelected.enumerated() {
            let score = scoreMap[cluster.id] ?? 0.0
            let breakdown = breakdownMap[cluster.id]
            let ticker = cluster.dominantTicker ?? "Market-wide"
            let title = String(cluster.canonicalArticle.cleanTitle.prefix(50))
            
            var reasons: [String] = []
            if let breakdown = breakdown {
                if breakdown.holdingsRelevance > 0.5 {
                    reasons.append("High holdings relevance (\(String(format: "%.2f", breakdown.holdingsRelevance)))")
                }
                if breakdown.impactLabelScore > 0.3 {
                    reasons.append("Strong impact labels (\(String(format: "%.2f", breakdown.impactLabelScore)))")
                }
                if breakdown.eventTypeWeight > 0.7 {
                    reasons.append("Important event type (\(String(format: "%.2f", breakdown.eventTypeWeight)))")
                }
            }
            
            let reasonText = reasons.isEmpty ? "High total score" : reasons.joined(separator: ", ")
            print("   \(index + 1). [\(ticker)] Score: \(String(format: "%.3f", score)) - \(title)")
            print("      ✅ ACCEPTED because: \(reasonText)")
        }
        
        // Log rejected items
        let rejected = sorted.dropFirst(finalSelected.count)
        if !rejected.isEmpty {
            print("\n❌ REJECTED (\(rejected.count) events):")
            for (index, cluster) in rejected.enumerated().prefix(10) { // Show first 10 rejected
                let score = scoreMap[cluster.id] ?? 0.0
                let breakdown = breakdownMap[cluster.id]
                let ticker = cluster.dominantTicker ?? "Market-wide"
                let title = String(cluster.canonicalArticle.cleanTitle.prefix(50))
                
                var reasons: [String] = []
                if let breakdown = breakdown {
                    if breakdown.holdingsRelevance < 0.1 {
                        reasons.append("No holdings relevance (\(String(format: "%.2f", breakdown.holdingsRelevance)))")
                    }
                    if breakdown.impactLabelScore < 0.2 {
                        reasons.append("Low impact labels (\(String(format: "%.2f", breakdown.impactLabelScore)))")
                    }
                    if breakdown.eventTypeWeight < 0.5 {
                        reasons.append("Low-priority event type (\(String(format: "%.2f", breakdown.eventTypeWeight)))")
                    }
                    if score < 0.3 {
                        reasons.append("Low total score (\(String(format: "%.2f", score)))")
                    }
                } else {
                    reasons.append("No score breakdown available")
                }
                
                let reasonText = reasons.isEmpty ? "Lower priority than selected items" : reasons.joined(separator: ", ")
                print("   \(index + 1). [\(ticker)] Score: \(String(format: "%.3f", score)) - \(title)")
                print("      ❌ REJECTED because: \(reasonText)")
            }
            if rejected.count > 10 {
                print("   ... and \(rejected.count - 10) more rejected items")
            }
        }
        
        print("\n📊 FILTERING SUMMARY: \(finalSelected.count) events selected from \(clusters.count) total")
        
        return finalSelected
    }
    
    // Stage 2: Group into themes using LLM
    // IMPORTANT: Each cluster should only appear in ONE theme to avoid duplicates
    private func groupIntoThemes(
        clusters: [EventCluster],
        userHoldings: [Holding],
        maxThemes: Int = 6
    ) async throws -> [FeedTheme] {
        guard let openAIService = openAIService else {
            // Fallback: one theme per cluster
            return clusters.map { cluster in
                FeedTheme(
                    id: UUID(),
                    themeName: cluster.dominantTicker ?? "Market Update",
                    eventClusters: [cluster],
                    hook: cluster.canonicalArticle.cleanTitle,
                    contextExplanation: cluster.canonicalArticle.cleanDescription,
                    whyItMatters: "This event may be relevant to your portfolio."
                )
            }
        }
        
        // Prepare context for LLM
        let clustersContext = clusters.enumerated().map { index, cluster in
            """
            Event \(index + 1):
            - Ticker: \(cluster.dominantTicker ?? "Market-wide")
            - Type: \(cluster.eventType.displayName)
            - Title: \(cluster.canonicalArticle.cleanTitle)
            - Summary: \(cluster.canonicalArticle.cleanDescription)
            """
        }.joined(separator: "\n\n")
        
        let holdingsContext = userHoldings.isEmpty
            ? "User has no specific holdings."
            : "User holds: \(userHoldings.map { $0.symbol }.joined(separator: ", "))"
        
        let systemPrompt = """
        You are the Rabbit, a friendly financial companion. Your job is to explain news in simple terms using ONLY FACTS, and ALWAYS connect it to what the user actually owns.
        
        ZERO-WASTE PRINCIPLE: If this doesn't affect the user or teach them something meaningful, don't even show it. Every piece of information must answer: "What happened?" and "Why does this matter for you?"
        
        CRITICAL RULES:
        1. ONLY USE FACTS - No speculation, no predictions, no "might" or "could". Only report what actually happened.
        2. Keep it SIMPLE - explain like you're talking to a friend, not a finance expert
        3. ALWAYS define terms - If you mention "earnings", explain: "Earnings are the profit a company makes in a quarter." If you mention "guidance", explain what it means.
        4. Explain history when relevant - If something is "unusual" or "record-breaking", explain what the normal is or what the previous record was.
        5. ALWAYS connect to their holdings - if they own the stock mentioned, say "You own [TICKER], so..." or "Since you hold [TICKER]..."
        6. ALWAYS explain WHY you're telling them this - start with "I'm sharing this because..." or "This matters to you because..."
        7. Use plain language - explain any financial terms simply
        8. Be brief and direct - 2-3 sentences max per section
        
        SPECIAL EXPLANATION REQUIREMENTS:
        - If the news mentions PREDICTIONS or FORECASTS: Explain WHY those predictions are being made. What facts or data led to that prediction? What are analysts or the company basing their forecast on?
        - If there's a BIG SWING (large price movement): Explain WHAT CAUSED the swing. Was it earnings? News? Market conditions? What specific event or data point triggered the move?
        - If there are UPS AND DOWNS (volatility): Explain WHY there are ups and downs. What conflicting factors are at play? What's pushing it up vs what's pushing it down? What's causing the uncertainty or mixed signals?
        
        GROUPING INSTRUCTIONS:
        - Group related events into \(maxThemes) themes maximum (not more).
        - Each theme should have a clear name (e.g., "Apple Earnings & Outlook", "Tesla Deliveries & Market Reaction").
        - Each theme should contain 1-5 related clusters.
        - Do NOT reuse clusters across themes (each cluster appears in only one theme).
        
        For each theme:
        - Hook: 1 short sentence (max 15 words) - conversational, like "You heard about [TICKER]? Here's why it matters to you."
        - Explanation: 2-3 simple sentences explaining what happened in plain terms. Define any terms. Explain history if relevant. ONLY FACTS.
        - Why it matters: MUST start with "I'm telling you this because..." or "This matters to you because..." and connect to their holdings if they own the stock
        
        Format as JSON array:
        [
          {
            "themeName": "Simple theme name",
            "eventIndices": [0, 1, 2],
            "hook": "Short conversational hook mentioning ticker if user owns it",
            "contextExplanation": "Simple explanation in 2-3 sentences",
            "whyItMatters": "Start with 'I'm telling you this because...' or 'This matters to you because...' and reference their holdings"
          }
        ]
        """
        
        let userPrompt = """
        Here are the top events happening:
        
        \(clustersContext)
        
        User's holdings: \(holdingsContext)
        
        Create themes that group related events. For EACH theme:
        1. Hook: 1 sentence (max 15 words) - mention the ticker if user owns it, like "You heard about [TICKER]? Here's what's happening."
        2. Explanation: 2-3 simple sentences explaining what happened in plain language. Define any financial terms you use. If something is unusual or record-breaking, explain what's normal or what the previous record was. ONLY USE FACTS - no speculation.
        
        IMPORTANT: If the news mentions:
        - PREDICTIONS/FORECASTS: Explain WHY those predictions exist. What facts, data, or trends led analysts/company to make that forecast? What are they basing it on?
        - BIG SWINGS (large price movements): Explain WHAT CAUSED the swing. What specific event, earnings report, news, or data point triggered the big move?
        - UPS AND DOWNS (volatility): Explain WHY there are ups and downs. What conflicting factors are causing the volatility? What's pushing it up vs what's pushing it down? What's creating the uncertainty?
        
        3. Why it matters: MUST start with "I'm telling you this because..." or "This matters to you because..." and connect to their holdings. If they own the stock, say "You own [TICKER], so this directly affects your portfolio." If it's sector-related, explain how it might impact their holdings.
        
        Remember: Only facts. Define terms. Explain history when relevant. EXPLAIN WHY for predictions, big swings, and ups/downs. Always connect to their holdings. Always explain why you're sharing this. Keep it simple and relatable.
        """
        
        let userMessage = Message(text: userPrompt, isFromCurrentUser: true)
        
        do {
            let response = try await openAIService.sendMessage(
                conversationHistory: [userMessage],
                systemPrompt: systemPrompt
            )
            
            // Parse JSON response
            return try parseThemesFromResponse(response, clusters: clusters)
        } catch {
            print("⚠️ LLM theme grouping failed: \(error.localizedDescription)")
            // Fallback: one theme per cluster
            return clusters.map { cluster in
                FeedTheme(
                    id: UUID(),
                    themeName: cluster.dominantTicker ?? "Market Update",
                    eventClusters: [cluster],
                    hook: cluster.canonicalArticle.cleanTitle,
                    contextExplanation: cluster.canonicalArticle.cleanDescription,
                    whyItMatters: "This event may be relevant to your portfolio."
                )
            }
        }
    }
    
    private func parseThemesFromResponse(_ response: String, clusters: [EventCluster]) throws -> [FeedTheme] {
        // Extract JSON from response (might have markdown code blocks)
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```") {
            let lines = jsonString.components(separatedBy: .newlines)
            jsonString = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        
        // Parse JSON
        guard let data = jsonString.data(using: .utf8) else {
            throw FeedBuilderError.invalidResponse
        }
        
        struct ThemeResponse: Codable {
            let themeName: String
            let eventIndices: [Int]
            let hook: String
            let contextExplanation: String
            let whyItMatters: String
        }
        
        let decoder = JSONDecoder()
        let themeResponses = try decoder.decode([ThemeResponse].self, from: data)
        
        // Convert to FeedTheme objects
        // Track which clusters have been used to prevent duplicates
        var usedClusterIndices: Set<Int> = []
        var themes: [FeedTheme] = []
        
        for themeResponse in themeResponses {
            // Filter out clusters that have already been used
            let availableIndices = themeResponse.eventIndices.filter { index in
                guard index >= 0 && index < clusters.count else { return false }
                return !usedClusterIndices.contains(index)
            }
            
            guard !availableIndices.isEmpty else { continue } // Skip if all clusters already used
            
            let themeClusters = availableIndices.compactMap { index -> EventCluster? in
                guard index >= 0 && index < clusters.count else { return nil }
                usedClusterIndices.insert(index) // Mark as used
                return clusters[index]
            }
            
            guard !themeClusters.isEmpty else { continue }
            
            themes.append(FeedTheme(
                id: UUID(),
                themeName: themeResponse.themeName,
                eventClusters: themeClusters,
                hook: themeResponse.hook,
                contextExplanation: themeResponse.contextExplanation,
                whyItMatters: themeResponse.whyItMatters
            ))
        }
        
        return themes
    }
}

enum FeedBuilderError: LocalizedError {
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Failed to parse theme response from LLM"
        }
    }
}

