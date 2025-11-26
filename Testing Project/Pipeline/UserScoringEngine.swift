import Foundation

// MARK: - User-Specific Scoring Engine
// Calculates personalized scores for each event cluster per user
class UserScoringEngine {
    static let shared = UserScoringEngine()
    
    private init() {}
    
    // Calculate user-specific score for an event cluster
    // ZERO-WASTE: Hard filters before scoring
    func calculateScore(
        for cluster: EventCluster,
        userHoldings: [Holding],
        userInterests: [String] = [], // e.g., ["AI", "EVs", "semiconductors"]
        detectedEvents: [DetectedEvent] = [], // Need for impact label scoring
        rabbitMode: RabbitMode = .smart // For mode-specific filtering
    ) -> UserEventScore? {
        let ticker = cluster.dominantTicker ?? "Market-wide"
        let title = cluster.canonicalArticle.cleanTitle
        let holdingTickers = Set(userHoldings.map { $0.symbol.uppercased() })
        
        // ZERO-WASTE: Hard filters before scoring
        let isHoldings = cluster.dominantTicker.map { holdingTickers.contains($0.uppercased()) } ?? false
        
        // Get impact labels
        let eventMap = Dictionary(uniqueKeysWithValues: detectedEvents.map { ($0.cleanedArticleId, $0) })
        var allLabels: [ImpactLabel] = []
        for article in cluster.articles {
            if let event = eventMap[article.id] {
                allLabels.append(contentsOf: event.impactLabels)
            }
        }
        let hasStrongImpact = allLabels.contains(where: {
            [.allTimeHigh, .allTimeLow, .bigMoves, .mostImpactful, .priceAffectingAbnormal].contains($0)
        })
        
        // IMPORTANT: Only filter out non-holdings in Focus mode
        // Beginner and Smart modes should see important market news
        if rabbitMode == .focus {
            // Focus mode: Only holdings-related news
            if !isHoldings {
                print("   🚫 SKIPPED SCORING (Focus mode: not holdings): \(ticker) - \(String(title.prefix(60)))...")
                return nil
            }
        } else {
            // Beginner and Smart modes: Keep important market news
            // Only drop if it's truly low-value: fluff, weak analyst notes, or social sentiment without impact
            // Let scoring handle the rest - we want to see what's happening in the market
            let isLowValueEvent = cluster.eventType == .fluff || 
                                  (cluster.eventType == .analystNote && !hasStrongImpact) ||
                                  (cluster.eventType == .socialSentiment && !hasStrongImpact) ||
                                  (cluster.eventType == .rumor && !hasStrongImpact)
            
            if !isHoldings && isLowValueEvent {
                print("   🚫 SKIPPED SCORING (low-value event type): \(ticker) - \(String(title.prefix(60)))...")
                return nil
            }
            // Otherwise, score it - let the scoring and feed builder decide if it's worth showing
        }
        
        // Hard filter: Drop if low-information (applies to all modes)
        if cluster.articles.contains(where: { $0.isLowInformation }) {
            // In Focus mode, only drop if not holdings. In other modes, drop all low-information
            if rabbitMode == .focus && isHoldings {
                // Keep holdings even if low-information in Focus mode
            } else {
                print("   🚫 SKIPPED SCORING (low information): \(ticker) - \(String(title.prefix(60)))...")
                return nil
            }
        }
        
        // Hard filter: Drop if fluff (applies to all modes, but Focus mode keeps holdings fluff)
        if cluster.eventType == .fluff {
            if rabbitMode == .focus && isHoldings {
                // Keep holdings fluff in Focus mode
            } else if !isHoldings {
                print("   🚫 SKIPPED SCORING (fluff, not holdings): \(ticker) - \(String(title.prefix(60)))...")
                return nil
            }
        }
        
        print("\n📊 SCORING: \(ticker) - \(String(title.prefix(60)))...")
        
        let breakdown = calculateBreakdown(
            cluster: cluster,
            userHoldings: userHoldings,
            userInterests: userInterests,
            detectedEvents: detectedEvents
        )
        
        // ZERO-WASTE: Updated weights (holdings 0.55, impact 0.20, event type 0.15, recency 0.10)
        let holdingsContribution = breakdown.holdingsRelevance * 0.55
        let impactContribution = breakdown.impactLabelScore * 0.20
        let eventTypeContribution = breakdown.eventTypeWeight * 0.15
        let recencyContribution = breakdown.recencyScore * 0.10
        
        let totalScore = holdingsContribution + impactContribution + eventTypeContribution + recencyContribution
        
        // Detailed scoring explanation
        print("   📈 SCORING BREAKDOWN:")
        print("      • Holdings Relevance: \(String(format: "%.3f", breakdown.holdingsRelevance)) × 0.55 = \(String(format: "%.3f", holdingsContribution))")
        print("      • Impact Labels: \(String(format: "%.3f", breakdown.impactLabelScore)) × 0.20 = \(String(format: "%.3f", impactContribution))")
        print("      • Event Type: \(String(format: "%.3f", breakdown.eventTypeWeight)) × 0.15 = \(String(format: "%.3f", eventTypeContribution))")
        print("      • Recency: \(String(format: "%.3f", breakdown.recencyScore)) × 0.10 = \(String(format: "%.3f", recencyContribution))")
        print("      • TOTAL SCORE: \(String(format: "%.3f", totalScore))")
        
        // Explain holdings relevance
        if breakdown.holdingsRelevance > 0 {
            let holdingTickers = Set(userHoldings.map { $0.symbol.uppercased() })
            if let dominantTicker = cluster.dominantTicker, holdingTickers.contains(dominantTicker.uppercased()) {
                print("      ✅ HOLDINGS MATCH: User owns \(dominantTicker) - HIGH PRIORITY")
            } else if breakdown.holdingsRelevance >= 0.3 {
                print("      ✅ SECTOR RELEVANCE: Related to user's holdings sector")
            } else {
                print("      ⚠️  LOW HOLDINGS RELEVANCE: Not directly related to user's holdings")
            }
        } else {
            print("      ❌ NO HOLDINGS RELEVANCE: Not related to user's holdings")
        }
        
        // Explain impact labels (reuse variables already declared above)
        if !allLabels.isEmpty {
            let uniqueLabels = Array(Set(allLabels))
            let labelNames = uniqueLabels.map { $0.displayName }.joined(separator: ", ")
            print("      ✅ IMPACT LABELS: \(labelNames) - Score: \(String(format: "%.3f", breakdown.impactLabelScore))")
        } else {
            print("      ⚠️  NO IMPACT LABELS: No special impact categories detected")
        }
        
        // Explain event type
        print("      📋 EVENT TYPE: \(cluster.eventType.displayName) - Base Score: \(String(format: "%.3f", breakdown.eventTypeWeight))")
        
        // ZERO-WASTE: Minimum score cutoff (lowered to be less aggressive)
        // Only apply minimum score in Focus mode, let scoring naturally filter in other modes
        let minScore: Double = rabbitMode == .focus ? 0.5 : 0.0 // No minimum for Beginner/Smart, let feed builder handle it
        if minScore > 0 && totalScore < minScore {
            print("      ❌ BELOW MINIMUM SCORE (\(String(format: "%.2f", minScore))): \(String(format: "%.3f", totalScore)) - DROPPED")
            return nil
        }
        
        return UserEventScore(
            clusterId: cluster.id,
            userId: "current_user", // In production, use actual user ID
            totalScore: totalScore,
            breakdown: breakdown
        )
    }
    
    private func calculateBreakdown(
        cluster: EventCluster,
        userHoldings: [Holding],
        userInterests: [String],
        detectedEvents: [DetectedEvent] // Need to pass this to access impact labels
    ) -> UserEventScore.ScoreBreakdown {
        let holdingTickers = Set(userHoldings.map { $0.symbol.uppercased() })
        let canonical = cluster.canonicalArticle
        
        // 1. Holdings Relevance (0.5 weight) - INCREASED PRIORITY
        let holdingsRelevance = calculateHoldingsRelevance(
            cluster: cluster,
            holdingTickers: holdingTickers
        )
        
        // 2. Impact Label Score (0.3 weight) - NEW
        let impactLabelScore = calculateImpactLabelScore(
            cluster: cluster,
            detectedEvents: detectedEvents
        )
        
        // 3. Event Type Weight (0.15 weight, decreased)
        let eventTypeWeight = cluster.eventType.baseScore
        
        // 4. Recency Score (0.10 weight, new)
        let recencyScore = calculateRecencyScore(cluster: cluster)
        
        // 5-7. Keep for compatibility but set to 0 (weights are 0)
        let recencyDecay = calculateRecencyDecay(cluster: cluster)
        let sourceQuality = canonical.sourceQualityScore
        let impactMagnitude = calculateImpactMagnitude(cluster: cluster)
        let userInterestTags = calculateUserInterestTags(
            cluster: cluster,
            userInterests: userInterests
        )
        
        return UserEventScore.ScoreBreakdown(
            holdingsRelevance: holdingsRelevance,
            impactLabelScore: impactLabelScore,
            eventTypeWeight: eventTypeWeight,
            recencyScore: recencyScore,
            recencyDecay: recencyDecay,
            sourceQuality: sourceQuality,
            impactMagnitude: impactMagnitude,
            userInterestTags: userInterestTags
        )
    }
    
    // Calculate impact label score based on labels in the cluster
    private func calculateImpactLabelScore(
        cluster: EventCluster,
        detectedEvents: [DetectedEvent]
    ) -> Double {
        // Get impact labels from all articles in cluster
        var allLabels: [ImpactLabel] = []
        let eventMap = Dictionary(uniqueKeysWithValues: detectedEvents.map { ($0.cleanedArticleId, $0) })
        
        for article in cluster.articles {
            if let event = eventMap[article.id] {
                allLabels.append(contentsOf: event.impactLabels)
            }
        }
        
        // Calculate weighted score based on label weights
        var totalScore = 0.0
        var maxPossibleScore = 0.0
        
        for label in ImpactLabel.allCases {
            let count = allLabels.filter { $0 == label }.count
            if count > 0 {
                totalScore += label.scoreWeight * Double(count)
            }
            maxPossibleScore += label.scoreWeight
        }
        
        // Normalize to 0.0-1.0 range
        if maxPossibleScore > 0 {
            return min(1.0, totalScore / maxPossibleScore)
        }
        
        return 0.0
    }
    
    // 1. Holdings Relevance
    private func calculateHoldingsRelevance(
        cluster: EventCluster,
        holdingTickers: Set<String>
    ) -> Double {
        guard let dominantTicker = cluster.dominantTicker else {
            // Check for sector/thematic relevance
            let relevance = calculateSectorRelevance(cluster: cluster, holdingTickers: holdingTickers)
            if relevance > 0 {
                print("      📍 Sector/Thematic Relevance: \(String(format: "%.2f", relevance)) (no direct ticker match)")
            }
            return relevance
        }
        
        let tickerUpper = dominantTicker.uppercased()
        let userOwns = holdingTickers.contains(tickerUpper)
        
        // Direct ticker match in title: +1.0
        let title = cluster.canonicalArticle.cleanTitle.uppercased()
        if title.contains(tickerUpper) {
            if userOwns {
                print("      ✅ DIRECT HOLDINGS MATCH: \(tickerUpper) in title - User owns this stock! (Score: 1.0)")
            } else {
                print("      ⚠️  Ticker \(tickerUpper) in title but user doesn't own it (Score: 0.0)")
                return 0.0
            }
            return 1.0
        }
        
        // Ticker in body: +0.6
        let body = cluster.canonicalArticle.cleanBody.uppercased()
        if body.contains(tickerUpper) {
            if userOwns {
                print("      ✅ HOLDINGS MATCH: \(tickerUpper) in body - User owns this stock! (Score: 0.6)")
            } else {
                print("      ⚠️  Ticker \(tickerUpper) in body but user doesn't own it (Score: 0.0)")
                return 0.0
            }
            return 0.6
        }
        
        // Sector relevance: +0.3
        let relevance = calculateSectorRelevance(cluster: cluster, holdingTickers: holdingTickers)
        if relevance > 0 {
            print("      📍 Sector Relevance: \(String(format: "%.2f", relevance)) (ticker \(tickerUpper) not directly mentioned)")
        } else {
            print("      ❌ NO HOLDINGS RELEVANCE: Ticker \(tickerUpper) not found and no sector match")
        }
        return relevance
    }
    
    private func calculateSectorRelevance(
        cluster: EventCluster,
        holdingTickers: Set<String>
    ) -> Double {
        // Simplified sector matching
        // In production, you'd have a proper sector mapping
        let text = (cluster.canonicalArticle.cleanTitle + " " + cluster.canonicalArticle.cleanDescription).lowercased()
        
        // Tech sector keywords
        if text.contains("tech") || text.contains("software") || text.contains("cloud") || text.contains("ai") {
            // Check if user holds tech stocks (simplified check)
            let techTickers = ["AAPL", "MSFT", "GOOGL", "AMZN", "META", "NVDA", "NFLX"]
            let userTechHoldings = holdingTickers.intersection(Set(techTickers))
            if !userTechHoldings.isEmpty {
                print("      📍 Tech Sector Match: User holds tech stocks (\(userTechHoldings.joined(separator: ", "))) - Score: 0.3")
                return 0.3
            }
        }
        
        // EV sector
        if text.contains("electric vehicle") || text.contains("ev") || text.contains("tesla") {
            if holdingTickers.contains("TSLA") {
                print("      📍 EV Sector Match: User holds TSLA - Score: 0.3")
                return 0.3
            }
        }
        
        // Thematic relevance: +0.15
        print("      📍 General Thematic Relevance: Score: 0.15")
        return 0.15
    }
    
    // 2. Recency Score (0-1, normalized for 0.10 weight)
    private func calculateRecencyScore(cluster: EventCluster) -> Double {
        let hoursOld = Calendar.current.dateComponents(
            [.hour],
            from: cluster.clusterCreatedAt,
            to: Date()
        ).hour ?? 0
        
        switch hoursOld {
        case 0..<1:
            return 1.0
        case 1..<3:
            return 0.9
        case 3..<12:
            return 0.75
        case 12..<24:
            return 0.6
        case 24..<72: // 3 days
            return 0.4
        case 72..<168: // 7 days
            return 0.2
        default:
            return 0.1
        }
    }
    
    // 2. Recency Decay (kept for compatibility)
    private func calculateRecencyDecay(cluster: EventCluster) -> Double {
        return calculateRecencyScore(cluster: cluster)
    }
    
    // 3. Impact Magnitude
    private func calculateImpactMagnitude(cluster: EventCluster) -> Double {
        var magnitude = 0.5 // Base
        
        let article = cluster.canonicalArticle
        let text = (article.cleanTitle + " " + article.cleanDescription + " " + article.cleanBody).lowercased()
        
        // High impact keywords
        let highImpactKeywords = [
            "surge", "plunge", "soar", "crash", "breakthrough", "record", "historic",
            "major", "significant", "substantial", "massive", "huge"
        ]
        
        for keyword in highImpactKeywords {
            if text.contains(keyword) {
                magnitude += 0.1
            }
        }
        
        // Number mentions (earnings, percentages, etc.)
        let numberPattern = "\\d+%|\\$\\d+"
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            if matches.count > 0 {
                magnitude += min(0.2, Double(matches.count) * 0.05)
            }
        }
        
        // Body size (longer articles often have more impact)
        if article.cleanBody.count > 500 {
            magnitude += 0.1
        }
        
        return min(1.0, magnitude)
    }
    
    // 4. User Interest Tags
    private func calculateUserInterestTags(
        cluster: EventCluster,
        userInterests: [String]
    ) -> Double {
        guard !userInterests.isEmpty else { return 0.0 }
        
        let text = (cluster.canonicalArticle.cleanTitle + " " + cluster.canonicalArticle.cleanDescription).lowercased()
        
        var matches = 0
        for interest in userInterests {
            if text.contains(interest.lowercased()) {
                matches += 1
            }
        }
        
        // Normalize to 0.0-1.0
        return min(1.0, Double(matches) / Double(userInterests.count))
    }
}

