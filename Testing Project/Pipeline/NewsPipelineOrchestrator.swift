import Foundation

    // MARK: - News Pipeline Orchestrator
    // Main coordinator that runs the entire pipeline from raw articles to personalized feed
    class NewsPipelineOrchestrator {
        static let shared = NewsPipelineOrchestrator()
        
        private let multiLayerFetcher = MultiLayerNewsFetcher.shared
        private let cleaningEngine = NewsCleaningEngine.shared
        private let eventDetection = EventDetectionEngine.shared
        private let clusteringEngine = EventClusteringEngine.shared
        private let scoringEngine = UserScoringEngine.shared
        private let feedBuilder = FeedBuilderEngine.shared
        
        private var openAIService: OpenAIService?
    
    init() {
        if !Config.openAIAPIKey.isEmpty {
            self.openAIService = OpenAIService(apiKey: Config.openAIAPIKey)
            // Initialize engines with OpenAI service
            let _ = EventDetectionEngine(openAIService: openAIService)
            let _ = EventClusteringEngine(openAIService: openAIService)
            let _ = FeedBuilderEngine(openAIService: openAIService)
        }
    }
    
    // Main pipeline: Fetch → Clean → Detect → Cluster → Score → Build Feed
    func runPipeline(
        userHoldings: [Holding],
        userInterests: [String] = [],
        rabbitMode: RabbitMode = .smart,
        limit: Int = 100
    ) async throws -> [FeedTheme] {
        print("🚀 Starting news pipeline...")
        
        // Debug tracking (local to this function)
        var filteredItems: [PipelineDebugData.FilteredItemDebug] = []
        
        // Step 1: Holdings-First Search (Search for holdings news first, then top stories)
        print("📥 Step 1: Holdings-first search...")
        print("   - Searching for holdings news first...")
        print("   - Then fetching top stories...")
        let rawArticles = try await multiLayerFetcher.fetchAllLayers(holdings: userHoldings, limit: limit)
        print("✅ Fetched \(rawArticles.count) raw articles (holdings-first priority)")
        
        // Step 2: Raw Storage (Warehouse)
        // In production, you'd store rawArticles in a database here
        // For now, we'll process them directly
        
        // Step 3: Cleaning & Normalization
        print("🧼 Step 3: Cleaning and normalizing articles...")
        let cleanedArticles = rawArticles.map { cleaningEngine.cleanArticle($0) }
        print("✅ Cleaned \(cleanedArticles.count) articles")
        
        // Step 4: Event Detection (process in batches for better performance)
        print("🔍 Step 4: Detecting event types...")
        var detectedEvents: [DetectedEvent] = []
        var articleToEventMap: [UUID: DetectedEvent] = [:]
        
        // Process in batches of 10 to avoid overwhelming the API
        let batchSize = 10
        for i in stride(from: 0, to: cleanedArticles.count, by: batchSize) {
            let batch = Array(cleanedArticles[i..<min(i + batchSize, cleanedArticles.count)])
            await withTaskGroup(of: DetectedEvent?.self) { group in
                for article in batch {
                    group.addTask {
                        do {
                            let event = try await self.eventDetection.detectEvent(from: article)
                            
                            // ZERO-WASTE: Early drop only truly low-value content
                            // In Focus mode: drop non-holdings fluff. In other modes: drop all fluff
                            if event.eventType == .fluff {
                                if rabbitMode == .focus && article.isHoldingsNews {
                                    // Keep holdings fluff in Focus mode
                                } else {
                                    // Drop fluff in all modes (it's truly low-value)
                                    let reason = "Fluff event type (low-value content)"
                                    print("   🚫 DROPPED (fluff): \(article.cleanTitle.prefix(60))...")
                                    filteredItems.append(PipelineDebugData.FilteredItemDebug(
                                        stage: "event_detection",
                                        itemType: "article",
                                        title: article.cleanTitle,
                                        ticker: article.cleanTickers.first,
                                        reason: reason
                                    ))
                                    return nil
                                }
                            }
                            
                            // For analyst notes, only drop if they're truly weak (no impact, not holdings)
                            // In Focus mode: keep holdings analyst notes. In other modes: drop weak ones
                            if event.eventType == .analystNote {
                                let strongLabels: [ImpactLabel] = [.mostImpactful, .bigMoves, .allTimeHigh, .allTimeLow]
                                let hasStrongLabel = strongLabels.contains(where: { event.impactLabels.contains($0) })
                                
                                if rabbitMode == .focus && article.isHoldingsNews {
                                    // Keep holdings analyst notes in Focus mode
                                } else if !article.isHoldingsNews && !hasStrongLabel {
                                    // Drop weak analyst notes (no impact, not holdings)
                                    let reason = "Analyst note, not holdings-related, weak impact labels"
                                    print("   🚫 DROPPED (analyst note, weak impact): \(article.cleanTitle.prefix(60))...")
                                    filteredItems.append(PipelineDebugData.FilteredItemDebug(
                                        stage: "event_detection",
                                        itemType: "article",
                                        title: article.cleanTitle,
                                        ticker: article.cleanTickers.first,
                                        reason: reason
                                    ))
                                    return nil
                                }
                                // Otherwise, keep it - let scoring decide
                            }
                            
                            return event
                        } catch {
                            print("⚠️ Event detection failed for article: \(error.localizedDescription)")
                            // Return fallback event (but still check for early drop)
                            let fallbackEvent = DetectedEvent(
                                cleanedArticleId: article.id,
                                eventType: .fluff,
                                baseScore: 0.1,
                                dominantTicker: article.cleanTickers.first,
                                confidence: 0.5,
                                impactLabels: []
                            )
                            
                            // Drop fluff if not holdings
                            if !article.isHoldingsNews {
                                return nil
                            }
                            
                            return fallbackEvent
                        }
                    }
                }
                
                for await event in group {
                    if let event = event {
                        detectedEvents.append(event)
                        articleToEventMap[event.cleanedArticleId] = event
                    }
                }
            }
        }
        print("✅ Detected \(detectedEvents.count) events (dropped fluff/analyst notes)")
        
        // Filter cleaned articles to only those with detected events
        let validArticleIds = Set(detectedEvents.map { $0.cleanedArticleId })
        let validCleanedArticles = cleanedArticles.filter { validArticleIds.contains($0.id) }
        
        // Step 5: Clustering
        print("🧩 Step 5: Clustering similar articles...")
        let allClusters = try await clusteringEngine.clusterArticles(validCleanedArticles, detectedEvents: detectedEvents)
        
        // ZERO-WASTE: Drop low-value clusters before scoring
        let holdingTickers = Set(userHoldings.map { $0.symbol.uppercased() })
        let clusters = allClusters.filter { cluster in
            let isHoldings = cluster.dominantTicker.map { holdingTickers.contains($0.uppercased()) } ?? false
            
            // Only filter single-article clusters if they're truly low-value
            // In Focus mode, filter non-holdings. In other modes, be more lenient
            if cluster.articles.count == 1 {
                let event = articleToEventMap[cluster.articles[0].id]
                let hasStrongImpact = event?.impactLabels.contains(where: { 
                    [.mostImpactful, .bigMoves, .allTimeHigh, .allTimeLow, .priceAffectingAbnormal].contains($0)
                }) ?? false
                let isLowValueEvent = cluster.eventType == .fluff || 
                                      cluster.eventType == .rumor ||
                                      (cluster.eventType == .analystNote && !hasStrongImpact) ||
                                      (cluster.eventType == .socialSentiment && !hasStrongImpact)
                
                // In Focus mode, only keep holdings
                if rabbitMode == .focus {
                    if !isHoldings {
                        let reason = "Focus mode: Single article cluster, not holdings"
                        print("   🚫 DROPPED CLUSTER (Focus mode: not holdings): \(cluster.canonicalArticle.cleanTitle.prefix(60))...")
                        filteredItems.append(PipelineDebugData.FilteredItemDebug(
                            stage: "clustering",
                            itemType: "cluster",
                            title: cluster.canonicalArticle.cleanTitle,
                            ticker: cluster.dominantTicker,
                            reason: reason
                        ))
                        return false
                    }
                } else {
                    // Beginner/Smart: Only drop if it's a low-value event type (fluff, rumor, weak analyst note)
                    // Let scoring handle the rest - we want to see market news
                    if !isHoldings && isLowValueEvent {
                        let reason = "Single article cluster, low-value event type"
                        print("   🚫 DROPPED CLUSTER (low-value event): \(cluster.canonicalArticle.cleanTitle.prefix(60))...")
                        filteredItems.append(PipelineDebugData.FilteredItemDebug(
                            stage: "clustering",
                            itemType: "cluster",
                            title: cluster.canonicalArticle.cleanTitle,
                            ticker: cluster.dominantTicker,
                            reason: reason
                        ))
                        return false
                    }
                    // Otherwise, keep it - let scoring decide
                }
            }
            
            // Drop if low-information (applies to all modes, but Focus keeps holdings)
            if cluster.articles.contains(where: { $0.isLowInformation }) {
                if rabbitMode == .focus && isHoldings {
                    // Keep holdings even if low-information in Focus mode
                } else if !isHoldings {
                    let reason = "Low-information content"
                    print("   🚫 DROPPED CLUSTER (low information): \(cluster.canonicalArticle.cleanTitle.prefix(60))...")
                    filteredItems.append(PipelineDebugData.FilteredItemDebug(
                        stage: "clustering",
                        itemType: "cluster",
                        title: cluster.canonicalArticle.cleanTitle,
                        ticker: cluster.dominantTicker,
                        reason: reason
                    ))
                    return false
                }
            }
            
            return true
        }
        print("✅ Created \(clusters.count) event clusters (dropped \(allClusters.count - clusters.count) low-value clusters)")
        
        // Step 6: User-Specific Scoring (with impact labels and hard filters)
        print("⭐ Step 6: Calculating user-specific scores with impact labels and hard filters...")
        var allScoredClusters: [(score: UserEventScore?, cluster: EventCluster)] = []
        let userScores = clusters.compactMap { cluster -> UserEventScore? in
            let score = scoringEngine.calculateScore(
                for: cluster,
                userHoldings: userHoldings,
                userInterests: userInterests,
                detectedEvents: detectedEvents,
                rabbitMode: rabbitMode
            )
            allScoredClusters.append((score: score, cluster: cluster))
            return score
        }
        print("✅ Calculated scores for \(userScores.count) clusters (dropped below minimum score)")
        
        // Filter clusters to only those with valid scores
        let validClusterIds = Set(userScores.map { $0.clusterId })
        let validClusters = clusters.filter { validClusterIds.contains($0.id) }
        
        // Step 7: Feed Building (strict limits based on Rabbit mode)
        print("🎚️ Step 7: Building personalized feed (strict limits: \(rabbitMode == .beginner ? 6 : rabbitMode == .smart ? 5 : 4) events)...")
        let themes = try await feedBuilder.buildFeed(
            clusters: validClusters,
            userScores: userScores,
            userHoldings: userHoldings,
            rabbitMode: rabbitMode
        )
        print("✅ Built feed with \(themes.count) themes (filtered to most important)")
        
        // Save debug data
        saveDebugData(
            rawArticles: rawArticles,
            cleanedArticles: cleanedArticles,
            detectedEvents: detectedEvents,
            clusters: clusters,
            allScoredClusters: allScoredClusters,
            validClusters: validClusters,
            userScores: userScores,
            themes: themes,
            filteredItems: filteredItems,
            rabbitMode: rabbitMode
        )
        
        print("🎉 Pipeline complete!")
        return themes
    }
    
    // Convert FeedTheme to Event for display compatibility
    // IMPORTANT: One Event per theme (not per cluster) to avoid duplicates
    func convertThemesToEvents(_ themes: [FeedTheme]) -> [Event] {
        return themes.map { theme in
            // Use the first cluster as representative (they're all related in the theme)
            guard let firstCluster = theme.eventClusters.first else {
                // Fallback if no clusters (shouldn't happen)
                let canonical = CleanedArticle(
                    rawArticleId: UUID(),
                    url: "",
                    cleanTitle: theme.themeName,
                    cleanDescription: theme.contextExplanation,
                    cleanBody: theme.whyItMatters,
                    cleanTickers: [],
                    sourceQualityScore: 0.5,
                    normalizedPublishedAt: Date()
                )
                return createEventFromCluster(
                    cluster: EventCluster(
                        articles: [],
                        similarityScores: [],
                        eventType: .macro,
                        dominantTicker: nil,
                        canonicalArticle: canonical
                    ),
                    theme: theme
                )
            }
            
            return createEventFromCluster(cluster: firstCluster, theme: theme)
        }
    }
    
    private func createEventFromCluster(cluster: EventCluster, theme: FeedTheme) -> Event {
        // Determine impact and magnitude from event type
                let impact: EventImpact
                let magnitude: EventMagnitude
                
                switch cluster.eventType {
                case .earnings, .guidance, .mergerAcquisition:
                    impact = .positive // Default, could be improved with sentiment analysis
                    magnitude = .high
                case .regulation, .litigation:
                    impact = .mixed
                    magnitude = .medium
                case .productLaunch:
                    impact = .positive
                    magnitude = .medium
                case .macro:
                    impact = .mixed
                    magnitude = .medium
                case .analystNote:
                    impact = .mixed
                    magnitude = .low
                case .socialSentiment, .rumor:
                    impact = .mixed
                    magnitude = .low
                case .fluff:
                    impact = .mixed
                    magnitude = .low
                }
                
                // Create sources summary
                let sourcesSummary = SourcesSummary(
                    redditMentions: "Mentioned across multiple financial discussions.",
                    analystConsensus: "Covered by \(cluster.articles.count) source\(cluster.articles.count > 1 ? "s" : "").",
                    mediaCoverageSummary: "Reported by \(cluster.articles.count) news outlet\(cluster.articles.count > 1 ? "s" : ""), indicating significant market interest.",
                    rabbitConfidence: "Rabbit confidence: \(magnitude == .high ? "High" : magnitude == .medium ? "Medium" : "Moderate") — analyzed from multiple sources for accuracy."
                )
                
                // Create credibility snapshot
                let credibilitySnapshot = CredibilitySnapshot(
                    mentionCountReddit: cluster.articles.count * 5,
                    analystConsensusSummary: "Multiple sources reporting, indicating broad market awareness.",
                    newsOutletCount: cluster.articles.count,
                    forumMentionsCount: cluster.articles.count * 10
                )
                
        return Event(
            ticker: cluster.dominantTicker,
            title: theme.hook, // Use theme hook as title
            summary: theme.contextExplanation + "\n\n" + theme.whyItMatters, // Combine context and why it matters
            impact: impact,
            magnitude: magnitude,
            createdAt: cluster.clusterCreatedAt,
            hasKnowledgeCheck: false,
            sourcesSummary: sourcesSummary,
            credibilitySnapshot: credibilitySnapshot
        )
    }
    
    // MARK: - Debug Data Capture
    private func saveDebugData(
        rawArticles: [RawArticle],
        cleanedArticles: [CleanedArticle],
        detectedEvents: [DetectedEvent],
        clusters: [EventCluster],
        allScoredClusters: [(score: UserEventScore?, cluster: EventCluster)],
        validClusters: [EventCluster],
        userScores: [UserEventScore],
        themes: [FeedTheme],
        filteredItems: [PipelineDebugData.FilteredItemDebug],
        rabbitMode: RabbitMode
    ) {
        let debugData = PipelineDebugData(
            timestamp: Date(),
            rawArticlesCount: rawArticles.count,
            cleanedArticlesCount: cleanedArticles.count,
            detectedEventsCount: detectedEvents.count,
            clustersCount: clusters.count,
            finalThemesCount: themes.count,
            rawArticles: rawArticles.map { article in
                PipelineDebugData.RawArticleDebug(
                    id: article.id.uuidString,
                    source: article.source,
                    sourceLayer: article.sourceLayer,
                    title: article.title,
                    url: article.url,
                    publishedAt: article.publishedAt,
                    fetchTime: article.fetchTime
                )
            },
            cleanedArticles: cleanedArticles.map { article in
                PipelineDebugData.CleanedArticleDebug(
                    id: article.id.uuidString,
                    rawArticleId: article.rawArticleId.uuidString,
                    cleanTitle: article.cleanTitle,
                    cleanDescription: article.cleanDescription,
                    cleanBodyLength: article.cleanBody.count,
                    cleanTickers: article.cleanTickers,
                    sourceQualityScore: article.sourceQualityScore,
                    normalizedPublishedAt: article.normalizedPublishedAt,
                    isHoldingsNews: article.isHoldingsNews,
                    isLowInformation: article.isLowInformation
                )
            },
            detectedEvents: detectedEvents.map { event in
                PipelineDebugData.DetectedEventDebug(
                    id: event.id.uuidString,
                    cleanedArticleId: event.cleanedArticleId.uuidString,
                    eventType: event.eventType.rawValue,
                    baseScore: event.baseScore,
                    dominantTicker: event.dominantTicker,
                    confidence: event.confidence,
                    impactLabels: event.impactLabels.map { $0.rawValue }
                )
            },
            clusters: clusters.map { cluster in
                PipelineDebugData.ClusterDebug(
                    id: cluster.id.uuidString,
                    articleCount: cluster.articles.count,
                    eventType: cluster.eventType.rawValue,
                    dominantTicker: cluster.dominantTicker,
                    canonicalArticleTitle: cluster.canonicalArticle.cleanTitle,
                    similarityScores: cluster.similarityScores,
                    articleTitles: cluster.articles.map { $0.cleanTitle }
                )
            },
            themes: themes.map { theme in
                PipelineDebugData.ThemeDebug(
                    id: theme.id.uuidString,
                    themeName: theme.themeName,
                    eventClusterCount: theme.eventClusters.count,
                    hook: theme.hook,
                    contextExplanation: theme.contextExplanation,
                    whyItMatters: theme.whyItMatters
                )
            },
            userScores: allScoredClusters.compactMap { scored in
                if let score = scored.score {
                    // Score exists - find cluster and check if it made it to feed
                    let cluster = clusters.first { $0.id == score.clusterId } ?? validClusters.first { $0.id == score.clusterId }!
                    let madeItToFeed = themes.contains { theme in
                        theme.eventClusters.contains { $0.id == score.clusterId }
                    }
                    return PipelineDebugData.UserScoreDebug(
                        clusterId: score.clusterId.uuidString,
                        clusterTitle: cluster.canonicalArticle.cleanTitle,
                        ticker: cluster.dominantTicker,
                        totalScore: score.totalScore,
                        breakdown: PipelineDebugData.ScoreBreakdownDebug(
                            holdingsRelevance: score.breakdown.holdingsRelevance,
                            impactLabelScore: score.breakdown.impactLabelScore,
                            eventTypeWeight: score.breakdown.eventTypeWeight,
                            recencyScore: score.breakdown.recencyScore,
                            recencyDecay: score.breakdown.recencyDecay,
                            sourceQuality: score.breakdown.sourceQuality,
                            impactMagnitude: score.breakdown.impactMagnitude,
                            userInterestTags: score.breakdown.userInterestTags
                        ),
                        wasFiltered: !madeItToFeed,
                        filterReason: madeItToFeed ? nil : "Not selected for feed (below top \(rabbitMode == .beginner ? 6 : rabbitMode == .smart ? 5 : 4))"
                    )
                } else {
                    // Score was nil - cluster was filtered during scoring
                    let cluster = scored.cluster
                    return PipelineDebugData.UserScoreDebug(
                        clusterId: cluster.id.uuidString,
                        clusterTitle: cluster.canonicalArticle.cleanTitle,
                        ticker: cluster.dominantTicker,
                        totalScore: 0.0,
                        breakdown: PipelineDebugData.ScoreBreakdownDebug(
                            holdingsRelevance: 0.0,
                            impactLabelScore: 0.0,
                            eventTypeWeight: 0.0,
                            recencyScore: 0.0,
                            recencyDecay: 0.0,
                            sourceQuality: 0.0,
                            impactMagnitude: 0.0,
                            userInterestTags: 0.0
                        ),
                        wasFiltered: true,
                        filterReason: "Filtered during scoring (hard filter or below minimum score)"
                    )
                }
            },
            filteredItems: filteredItems,
            acceptedItems: themes.flatMap { theme in
                theme.eventClusters.compactMap { cluster in
                    if let score = userScores.first(where: { $0.clusterId == cluster.id }) {
                        var reasons: [String] = []
                        if score.breakdown.holdingsRelevance > 0.5 {
                            reasons.append("High holdings relevance")
                        }
                        if score.breakdown.impactLabelScore > 0.3 {
                            reasons.append("Strong impact labels")
                        }
                        if score.breakdown.eventTypeWeight > 0.7 {
                            reasons.append("Important event type")
                        }
                        if reasons.isEmpty {
                            reasons.append("High total score")
                        }
                        return PipelineDebugData.AcceptedItemDebug(
                            stage: "feed_builder",
                            itemType: "cluster",
                            title: cluster.canonicalArticle.cleanTitle,
                            ticker: cluster.dominantTicker,
                            score: score.totalScore,
                            reasons: reasons
                        )
                    }
                    return nil
                }
            }
        )
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(debugData) {
            UserDefaults.standard.set(encoded, forKey: "pipelineDebugData")
            print("💾 Debug data saved")
        }
    }
}

