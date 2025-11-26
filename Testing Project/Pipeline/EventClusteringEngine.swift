import Foundation

// MARK: - Event Clustering Engine
// Groups similar articles using embedding-based cosine similarity
class EventClusteringEngine {
    static let shared = EventClusteringEngine()
    
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
    
    // Cluster articles into events
    func clusterArticles(_ articles: [CleanedArticle], detectedEvents: [DetectedEvent]) async throws -> [EventCluster] {
        guard !articles.isEmpty else { return [] }
        
        // Create a map of article ID to detected event
        let eventMap = Dictionary(uniqueKeysWithValues: detectedEvents.map { ($0.cleanedArticleId, $0) })
        
        // Generate embeddings for all articles
        var embeddings: [UUID: [Double]] = [:]
        
        if let openAIService = openAIService {
            // Use OpenAI embeddings API
            for article in articles {
                let embedding = try await generateEmbedding(for: article, service: openAIService)
                embeddings[article.id] = embedding
            }
        } else {
            // Fallback to simple text-based similarity
            print("⚠️ No OpenAI service, using text-based similarity for clustering")
        }
        
        // Cluster articles based on similarity
        var clusters: [EventCluster] = []
        var processed: Set<UUID> = []
        
        // First, deduplicate by URL and title (exact duplicates)
        var seenURLs: Set<String> = []
        var seenTitles: Set<String> = []
        var uniqueArticles: [CleanedArticle] = []
        
        for article in articles {
            // Normalize URL for comparison (remove tracking parameters, lowercase)
            let normalizedURL = article.url.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "?")
                .first ?? article.url.lowercased()
            
            // Check if we've seen this exact URL before (most reliable)
            if seenURLs.contains(normalizedURL) {
                continue // Skip duplicate
            }
            
            // Normalize title for comparison (remove common words, punctuation)
            let normalizedTitle = article.cleanTitle.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                .components(separatedBy: .whitespaces)
                .filter { $0.count > 2 } // Remove short words
                .joined(separator: " ")
            
            // Check if we've seen this exact title before
            if seenTitles.contains(normalizedTitle) {
                continue // Skip duplicate
            }
            
            // Check if title is very similar to existing ones (>85% similarity)
            var isDuplicate = false
            for seenTitle in seenTitles {
                let similarity = calculateTitleSimilarity(normalizedTitle, seenTitle)
                if similarity > 0.85 {
                    isDuplicate = true
                    break
                }
            }
            
            if !isDuplicate {
                seenURLs.insert(normalizedURL)
                seenTitles.insert(normalizedTitle)
                uniqueArticles.append(article)
            }
        }
        
        print("🔄 Deduplication: \(articles.count) → \(uniqueArticles.count) unique articles")
        
        // STEP 1: Group articles by company/ticker first
        var articlesByTicker: [String: [CleanedArticle]] = [:]
        var articlesWithoutTicker: [CleanedArticle] = []
        
        for article in uniqueArticles {
            if let ticker = article.cleanTickers.first {
                let tickerUpper = ticker.uppercased()
                if articlesByTicker[tickerUpper] == nil {
                    articlesByTicker[tickerUpper] = []
                }
                articlesByTicker[tickerUpper]?.append(article)
            } else {
                articlesWithoutTicker.append(article)
            }
        }
        
        print("📊 Grouped by company: \(articlesByTicker.count) companies, \(articlesWithoutTicker.count) articles without ticker")
        
        // STEP 2: Cluster within each company group (now async for LLM-based semantic matching)
        for (_, tickerArticles) in articlesByTicker {
            let tickerClusters = await clusterArticlesWithinGroup(
                articles: tickerArticles,
                eventMap: eventMap,
                embeddings: embeddings,
                processed: &processed
            )
            clusters.append(contentsOf: tickerClusters)
        }
        
        // STEP 3: Cluster articles without tickers
        if !articlesWithoutTicker.isEmpty {
            let noTickerClusters = await clusterArticlesWithinGroup(
                articles: articlesWithoutTicker,
                eventMap: eventMap,
                embeddings: embeddings,
                processed: &processed
            )
            clusters.append(contentsOf: noTickerClusters)
        }
        
        print("✅ Initial clustering: \(articles.count) articles into \(clusters.count) event clusters (grouped by company)")
        
        // STEP 4: Cross-ticker clustering - merge clusters from different tickers if they're about the same event
        // This catches cases like "Alphabet/Meta AI chip deal" where articles mention different tickers
        var mergedClusters: [EventCluster] = []
        var processedClusterIds: Set<UUID> = []
        
        for cluster in clusters {
            if processedClusterIds.contains(cluster.id) {
                continue
            }
            
            var mergedArticles = cluster.articles
            var mergedSimilarityScores = cluster.similarityScores
            var mergedEventType = cluster.eventType
            processedClusterIds.insert(cluster.id)
            
            // Check if this cluster should be merged with any other cluster from a different ticker
            // First, collect candidates with quick checks (no API calls)
            var candidatesForLLM: [(EventCluster, CleanedArticle, DetectedEvent?)] = []
            
            for otherCluster in clusters {
                if processedClusterIds.contains(otherCluster.id) {
                    continue
                }
                
                // Skip if same ticker (already clustered in STEP 2)
                if cluster.dominantTicker == otherCluster.dominantTicker && cluster.dominantTicker != nil {
                    continue
                }
                
                let canonical1 = cluster.canonicalArticle
                let canonical2 = otherCluster.canonicalArticle
                
                // Quick check 1: High title similarity (>50%) = likely same event
                let titleSimilarity = textSimilarity(canonical1, canonical2)
                if titleSimilarity > 0.50 {
                    // High similarity - merge without LLM call
                    print("   🔗 MERGED (title similarity \(String(format: "%.2f", titleSimilarity))): '\(canonical1.cleanTitle.prefix(50))...' + '\(canonical2.cleanTitle.prefix(50))...'")
                    mergedArticles.append(contentsOf: otherCluster.articles)
                    mergedSimilarityScores.append(contentsOf: otherCluster.similarityScores)
                    processedClusterIds.insert(otherCluster.id)
                    
                    if otherCluster.eventType.baseScore > mergedEventType.baseScore {
                        mergedEventType = otherCluster.eventType
                    }
                    continue
                }
                
                // Quick check 2: Overlapping tickers (articles mention both companies)
                let tickers1 = Set(canonical1.cleanTickers.map { $0.uppercased() })
                let tickers2 = Set(canonical2.cleanTickers.map { $0.uppercased() })
                let hasOverlappingTickers = !tickers1.isDisjoint(with: tickers2)
                
                // Quick check 3: Date proximity (extended window for cross-ticker)
                let timeDiff = abs(canonical1.normalizedPublishedAt.timeIntervalSince(canonical2.normalizedPublishedAt))
                let closeDates = timeDiff < 72 * 3600 // 72 hours for cross-ticker events
                
                let event2 = eventMap[canonical2.id]
                
                // More aggressive cross-ticker matching:
                // 1. If overlapping tickers, always check (even if dates are a bit off)
                // 2. If moderate title similarity (>35%) AND close dates, check
                // Don't require same event type - articles about same event can have different classifications
                let shouldCheck = hasOverlappingTickers || (titleSimilarity > 0.35 && closeDates)
                
                if shouldCheck {
                    print("   🔍 CROSS-TICKER CANDIDATE (similarity: \(String(format: "%.2f", titleSimilarity)), overlapping: \(hasOverlappingTickers), dates: \(String(format: "%.1f", timeDiff/3600))h): '\(canonical1.cleanTitle.prefix(40))...' vs '\(canonical2.cleanTitle.prefix(40))...'")
                    candidatesForLLM.append((otherCluster, canonical2, event2))
                }
            }
            
            // Second pass: LLM check for ambiguous cases (with rate limiting)
            for (otherCluster, canonical2, event2) in candidatesForLLM {
                if processedClusterIds.contains(otherCluster.id) {
                    continue
                }
                
                let canonical1 = cluster.canonicalArticle
                let event1 = eventMap[canonical1.id]
                
                // Add small delay between LLM calls to avoid rate limits
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                
                let isSameEvent = await areArticlesAboutSameEvent(
                    article1: canonical1,
                    article2: canonical2,
                    event1: event1,
                    event2: event2
                )
                
                if isSameEvent {
                    // Merge clusters - they're about the same event
                    mergedArticles.append(contentsOf: otherCluster.articles)
                    mergedSimilarityScores.append(contentsOf: otherCluster.similarityScores)
                    processedClusterIds.insert(otherCluster.id)
                    
                    // Use the higher-value event type
                    if otherCluster.eventType.baseScore > mergedEventType.baseScore {
                        mergedEventType = otherCluster.eventType
                    }
                }
            }
            
            // Select new canonical article from merged articles
            let newCanonical = selectCanonicalArticle(from: mergedArticles)
            
            // Determine dominant ticker (prefer the one with more articles, or holdings-related)
            var tickerCounts: [String: Int] = [:]
            for article in mergedArticles {
                for ticker in article.cleanTickers {
                    tickerCounts[ticker, default: 0] += 1
                }
            }
            
            // Prefer holdings-related tickers if available
            let holdingsTickers = Set(mergedArticles.filter { $0.isHoldingsNews }.flatMap { $0.cleanTickers })
            let dominantTicker: String?
            if let holdingsTicker = holdingsTickers.first {
                dominantTicker = holdingsTicker
            } else {
                dominantTicker = tickerCounts.max(by: { $0.value < $1.value })?.key ?? cluster.dominantTicker
            }
            
            let mergedCluster = EventCluster(
                articles: mergedArticles,
                similarityScores: mergedSimilarityScores,
                eventType: mergedEventType,
                dominantTicker: dominantTicker,
                canonicalArticle: newCanonical
            )
            
            mergedClusters.append(mergedCluster)
        }
        
        print("✅ Cross-ticker clustering: \(clusters.count) → \(mergedClusters.count) clusters")
        return mergedClusters
    }
    
    // Helper: Cluster articles within a group (same ticker or no ticker)
    // Now uses semantic meaning (same event) rather than just similar titles
    private func clusterArticlesWithinGroup(
        articles: [CleanedArticle],
        eventMap: [UUID: DetectedEvent],
        embeddings: [UUID: [Double]],
        processed: inout Set<UUID>
    ) async -> [EventCluster] {
        var clusters: [EventCluster] = []
        
        for article in articles {
            if processed.contains(article.id) {
                continue
            }
            
            // Find articles about the same event within this group
            var clusterArticles = [article]
            var similarityScores: [Double] = []
            processed.insert(article.id)
            
            let detectedEvent = eventMap[article.id]
            let eventType = detectedEvent?.eventType ?? .fluff
            let dominantTicker = detectedEvent?.dominantTicker ?? article.cleanTickers.first
            
            // Find articles about the same event (semantic meaning, not just words)
            // First pass: Quick checks (fast, no API calls)
            var candidatesForLLM: [(CleanedArticle, DetectedEvent?)] = []
            
            for otherArticle in articles {
                if processed.contains(otherArticle.id) {
                    continue
                }
                
                let otherEvent = eventMap[otherArticle.id]
                
                // Quick check 1: Same ticker + same event type + close dates
                if let ticker1 = detectedEvent?.dominantTicker,
                   let ticker2 = otherEvent?.dominantTicker,
                   ticker1 == ticker2,
                   detectedEvent?.eventType == otherEvent?.eventType,
                   detectedEvent?.eventType != .fluff,
                   detectedEvent?.eventType != .macro {
                    let timeDiff = abs(article.normalizedPublishedAt.timeIntervalSince(otherArticle.normalizedPublishedAt))
                    if timeDiff < 48 * 3600 {
                        // Same event - quick match!
                        clusterArticles.append(otherArticle)
                        similarityScores.append(0.95)
                        processed.insert(otherArticle.id)
                        continue
                    }
                }
                
                // Quick check 2: Very high title similarity (>70%) with same ticker
                let titleSimilarity = textSimilarity(article, otherArticle)
                if let ticker1 = detectedEvent?.dominantTicker,
                   let ticker2 = otherEvent?.dominantTicker,
                   ticker1 == ticker2,
                   titleSimilarity > 0.70 {
                    // Same event - high similarity match!
                    clusterArticles.append(otherArticle)
                    similarityScores.append(titleSimilarity)
                    processed.insert(otherArticle.id)
                    continue
                }
                
                // If quick checks didn't match but there's some similarity, check with LLM
                if titleSimilarity > 0.30 || 
                   (detectedEvent?.dominantTicker == otherEvent?.dominantTicker && detectedEvent?.dominantTicker != nil) {
                    candidatesForLLM.append((otherArticle, otherEvent))
                }
            }
            
            // Second pass: LLM semantic check for ambiguous cases (with rate limiting)
            for (otherArticle, otherEvent) in candidatesForLLM {
                if processed.contains(otherArticle.id) {
                    continue
                }
                
                // Add small delay between LLM calls to avoid rate limits
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                
                let isSameEvent = await areArticlesAboutSameEvent(
                    article1: article,
                    article2: otherArticle,
                    event1: detectedEvent,
                    event2: otherEvent
                )
                
                if isSameEvent {
                    clusterArticles.append(otherArticle)
                    similarityScores.append(0.9) // High similarity for same event
                    processed.insert(otherArticle.id)
                }
            }
            
            // Select canonical article (best one)
            let canonicalArticle = selectCanonicalArticle(from: clusterArticles)
            
            // Create cluster
            let cluster = EventCluster(
                articles: clusterArticles,
                similarityScores: similarityScores,
                eventType: eventType,
                dominantTicker: dominantTicker,
                canonicalArticle: canonicalArticle
            )
            
            clusters.append(cluster)
        }
        
        return clusters
    }
    
    // Check if two articles are about the same event (semantic meaning, not just similar words)
    // This is called only for ambiguous cases after quick checks
    private func areArticlesAboutSameEvent(
        article1: CleanedArticle,
        article2: CleanedArticle,
        event1: DetectedEvent?,
        event2: DetectedEvent?
    ) async -> Bool {
        // Use LLM to check semantic meaning if OpenAI is available
        if let openAIService = openAIService {
            let prompt = """
            Are these two articles about the SAME EVENT? Answer only "YES" or "NO".
            
            Article 1:
            Title: \(article1.cleanTitle)
            Description: \(String(article1.cleanDescription.prefix(200)))
            
            Article 2:
            Title: \(article2.cleanTitle)
            Description: \(String(article2.cleanDescription.prefix(200)))
            
            Answer (YES or NO):
            """
            
            do {
                let response = try await openAIService.sendMessage(
                    conversationHistory: [Message(text: prompt, isFromCurrentUser: true)],
                    systemPrompt: "You are a news analysis assistant. Determine if two articles are about the same event, even if they use different words. Consider: same company, same time period, same type of event (earnings, product launch, etc.). Answer only YES or NO."
                )
                let answer = response.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                return answer.contains("YES")
            } catch {
                // If LLM fails, fall back to title similarity
                print("⚠️ LLM event matching failed, using fallback: \(error.localizedDescription)")
                let titleSimilarity = textSimilarity(article1, article2)
                return titleSimilarity > 0.50
            }
        }
        
        // Fallback: Use title similarity if no LLM
        let titleSimilarity = textSimilarity(article1, article2)
        return titleSimilarity > 0.50
    }
    
    // Generate embedding using OpenAI
    private func generateEmbedding(for article: CleanedArticle, service: OpenAIService) async throws -> [Double] {
        // For now, use a simplified approach
        // In production, you'd call OpenAI's embedding API
        // This is a placeholder that uses text-based features
        
        let text = article.cleanTitle + " " + String(article.cleanBody.prefix(300))
        return textBasedEmbedding(text)
    }
    
    // Fallback: Simple text-based embedding (TF-IDF-like)
    private func textBasedEmbedding(_ text: String) -> [Double] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 2 }
        
        // Simple word frequency vector (simplified)
        var features: [Double] = Array(repeating: 0.0, count: 100)
        
        for (index, word) in words.enumerated() {
            if index < features.count {
                // Simple hash-based feature
                let hash = abs(word.hashValue)
                features[index % features.count] += Double(hash % 100) / 100.0
            }
        }
        
        // Normalize
        let magnitude = sqrt(features.map { $0 * $0 }.reduce(0, +))
        if magnitude > 0 {
            features = features.map { $0 / magnitude }
        }
        
        return features
    }
    
    // Calculate cosine similarity between two embeddings
    private func cosineSimilarity(_ vec1: [Double], _ vec2: [Double]) -> Double {
        guard vec1.count == vec2.count else { return 0.0 }
        
        let dotProduct = zip(vec1, vec2).map(*).reduce(0, +)
        let magnitude1 = sqrt(vec1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(vec2.map { $0 * $0 }.reduce(0, +))
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }
        
        return dotProduct / (magnitude1 * magnitude2)
    }
    
    // Fallback text similarity (Jaccard similarity)
    private func textSimilarity(_ article1: CleanedArticle, _ article2: CleanedArticle) -> Double {
        let text1 = (article1.cleanTitle + " " + article1.cleanDescription).lowercased()
        let text2 = (article2.cleanTitle + " " + article2.cleanDescription).lowercased()
        
        let words1 = Set(text1.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { $0.count > 2 })
        let words2 = Set(text2.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { $0.count > 2 })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0.0 }
        
        return Double(intersection.count) / Double(union.count)
    }
    
    // Calculate title similarity (for deduplication)
    private func calculateTitleSimilarity(_ title1: String, _ title2: String) -> Double {
        let words1 = Set(title1.components(separatedBy: .whitespaces).filter { $0.count > 2 })
        let words2 = Set(title2.components(separatedBy: .whitespaces).filter { $0.count > 2 })
        
        guard !words1.isEmpty && !words2.isEmpty else { return 0.0 }
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return Double(intersection.count) / Double(union.count)
    }
    
    // Select canonical article (best one in cluster)
    private func selectCanonicalArticle(from articles: [CleanedArticle]) -> CleanedArticle {
        guard !articles.isEmpty else {
            fatalError("Cannot select canonical article from empty cluster")
        }
        
        // Score each article
        let scored = articles.map { article -> (CleanedArticle, Double) in
            var score = 0.0
            
            // Source quality (0.4 weight)
            score += article.sourceQualityScore * 0.4
            
            // Content fullness (0.3 weight)
            let bodyLength = Double(article.cleanBody.count)
            let fullness = min(1.0, bodyLength / 1000.0) // Normalize to 1000 chars
            score += fullness * 0.3
            
            // Earliest publication (0.2 weight)
            // Earlier is better - normalize by time since now
            let timeSinceNow = Date().timeIntervalSince(article.normalizedPublishedAt)
            let recency = max(0.0, 1.0 - (timeSinceNow / (7 * 24 * 3600))) // 7 days max
            score += recency * 0.2
            
            // Clarity (0.1 weight) - simple heuristic based on title length and description
            let titleLength = Double(article.cleanTitle.count)
            let clarity = min(1.0, titleLength / 100.0) // Normalize to 100 chars
            score += clarity * 0.1
            
            return (article, score)
        }
        
        // Return article with highest score
        return scored.max(by: { $0.1 < $1.1 })?.0 ?? articles[0]
    }
}

