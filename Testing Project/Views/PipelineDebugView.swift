import SwiftUI
import Combine

// MARK: - Pipeline Debug Data Model
struct PipelineDebugData: Codable {
    let timestamp: Date
    let rawArticlesCount: Int
    let cleanedArticlesCount: Int
    let detectedEventsCount: Int
    let clustersCount: Int
    let finalThemesCount: Int
    
    let rawArticles: [RawArticleDebug]
    let cleanedArticles: [CleanedArticleDebug]
    let detectedEvents: [DetectedEventDebug]
    let clusters: [ClusterDebug]
    let themes: [ThemeDebug]
    let userScores: [UserScoreDebug]
    let filteredItems: [FilteredItemDebug] // New: Track what was filtered out
    let acceptedItems: [AcceptedItemDebug] // New: Track what made it through
    
    struct RawArticleDebug: Codable {
        let id: String
        let source: String
        let sourceLayer: Int
        let title: String
        let url: String
        let publishedAt: String
        let fetchTime: Date
    }
    
    struct CleanedArticleDebug: Codable {
        let id: String
        let rawArticleId: String
        let cleanTitle: String
        let cleanDescription: String
        let cleanBodyLength: Int
        let cleanTickers: [String]
        let sourceQualityScore: Double
        let normalizedPublishedAt: Date
        let isHoldingsNews: Bool? // New field
        let isLowInformation: Bool? // New field
    }
    
    struct DetectedEventDebug: Codable {
        let id: String
        let cleanedArticleId: String
        let eventType: String
        let baseScore: Double
        let dominantTicker: String?
        let confidence: Double
        let impactLabels: [String]? // New field for impact labels
    }
    
    struct ClusterDebug: Codable {
        let id: String
        let articleCount: Int
        let eventType: String
        let dominantTicker: String?
        let canonicalArticleTitle: String
        let similarityScores: [Double]
        let articleTitles: [String] // New: Show what articles are in this cluster
    }
    
    struct FilteredItemDebug: Codable {
        let stage: String // "holdings_search", "top_stories", "event_detection", "clustering", "scoring", "feed_builder"
        let itemType: String // "article", "cluster", "event"
        let title: String
        let ticker: String?
        let reason: String
    }
    
    struct AcceptedItemDebug: Codable {
        let stage: String
        let itemType: String
        let title: String
        let ticker: String?
        let score: Double?
        let reasons: [String] // Why it was accepted
    }
    
    struct ThemeDebug: Codable {
        let id: String
        let themeName: String
        let eventClusterCount: Int
        let hook: String
        let contextExplanation: String
        let whyItMatters: String
    }
    
    struct UserScoreDebug: Codable {
        let clusterId: String
        let clusterTitle: String // New: What is being scored
        let ticker: String? // New: Ticker for context
        let totalScore: Double
        let breakdown: ScoreBreakdownDebug
        let wasFiltered: Bool // New: Was this filtered out?
        let filterReason: String? // New: Why was it filtered (if applicable)
    }
    
    struct ScoreBreakdownDebug: Codable {
        let holdingsRelevance: Double
        let impactLabelScore: Double // New field
        let eventTypeWeight: Double
        let recencyScore: Double // New field
        let recencyDecay: Double
        let sourceQuality: Double
        let impactMagnitude: Double
        let userInterestTags: Double
    }
}

// MARK: - Pipeline Debug View
struct PipelineDebugView: View {
    @StateObject private var viewModel = PipelineDebugViewModel()
    @State private var selectedStage: PipelineStage = .raw
    
    enum PipelineStage: String, CaseIterable {
        case raw = "Raw Articles"
        case cleaned = "Cleaned"
        case events = "Events"
        case clusters = "Clusters"
        case scores = "Scores"
        case themes = "Final Themes"
        case filtered = "Filtered Out"
        case accepted = "Made It to Feed"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stage selector
                Picker("Stage", selection: $selectedStage) {
                    ForEach(PipelineStage.allCases, id: \.self) { stage in
                        Text(stage.rawValue).tag(stage)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let debugData = viewModel.debugData {
                            // Summary stats
                            summarySection(debugData)
                            
                            Divider()
                            
                            // Stage-specific content
                            switch selectedStage {
                            case .raw:
                                rawArticlesSection(debugData.rawArticles)
                            case .cleaned:
                                cleanedArticlesSection(debugData.cleanedArticles)
                            case .events:
                                eventsSection(debugData.detectedEvents)
                            case .clusters:
                                clustersSection(debugData.clusters)
                            case .scores:
                                scoresSection(debugData.userScores)
                            case .themes:
                                themesSection(debugData.themes)
                            case .filtered:
                                filteredItemsSection(debugData.filteredItems)
                            case .accepted:
                                acceptedItemsSection(debugData.acceptedItems)
                            }
                        } else {
                            Text("No debug data available. Run the pipeline first.")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Pipeline Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.loadDebugData()
                    }
                }
            }
            .onAppear {
                viewModel.loadDebugData()
            }
        }
    }
    
    // MARK: - Summary Section
    private func summarySection(_ data: PipelineDebugData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pipeline Summary")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Raw Articles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(data.rawArticlesCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Cleaned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(data.cleanedArticlesCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Clusters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(data.clustersCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Themes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(data.finalThemesCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            
            Text("Last run: \(data.timestamp, style: .relative)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Raw Articles Section
    private func rawArticlesSection(_ articles: [PipelineDebugData.RawArticleDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Raw Articles (\(articles.count))")
                .font(.headline)
            
            ForEach(articles, id: \.id) { article in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(article.source)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(layerColor(article.sourceLayer))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(article.publishedAt)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(article.url)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Cleaned Articles Section
    private func cleanedArticlesSection(_ articles: [PipelineDebugData.CleanedArticleDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleaned Articles (\(articles.count))")
                .font(.headline)
            
            ForEach(articles, id: \.id) { article in
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.cleanTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(article.cleanDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        if !article.cleanTickers.isEmpty {
                            ForEach(article.cleanTickers, id: \.self) { ticker in
                                Text(ticker)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                        
                        if article.isHoldingsNews == true {
                            Text("Holdings")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        if article.isLowInformation == true {
                            Text("Low Info")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Quality: \(String(format: "%.2f", article.sourceQualityScore))")
                                .font(.caption)
                            Text("Body: \(article.cleanBodyLength) chars")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Events Section
    private func eventsSection(_ events: [PipelineDebugData.DetectedEventDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Events (\(events.count))")
                .font(.headline)
            
            ForEach(events, id: \.id) { event in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(event.eventType)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(eventTypeColor(event.eventType))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        if let ticker = event.dominantTicker {
                            Text(ticker)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack {
                        Text("Base Score: \(String(format: "%.2f", event.baseScore))")
                            .font(.caption)
                        Spacer()
                        Text("Confidence: \(String(format: "%.2f", event.confidence))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let impactLabels = event.impactLabels, !impactLabels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(impactLabels, id: \.self) { label in
                                    Text(label)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Clusters Section
    private func clustersSection(_ clusters: [PipelineDebugData.ClusterDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Clusters (\(clusters.count))")
                .font(.headline)
            
            ForEach(clusters, id: \.id) { cluster in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(cluster.eventType)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(eventTypeColor(cluster.eventType))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text("\(cluster.articleCount) articles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(cluster.canonicalArticleTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("📦 Cluster: \(cluster.articleCount) article\(cluster.articleCount == 1 ? "" : "s") grouped together")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    
                    if !cluster.articleTitles.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Articles in this cluster:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            ForEach(Array(cluster.articleTitles.enumerated()), id: \.offset) { index, title in
                                Text("  \(index + 1). \(title)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    if let ticker = cluster.dominantTicker {
                        Text("Ticker: \(ticker)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !cluster.similarityScores.isEmpty {
                        Text("Similarity: \(cluster.similarityScores.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Scores Section
    private func scoresSection(_ scores: [PipelineDebugData.UserScoreDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("User Scores (\(scores.count))")
                .font(.headline)
            
            ForEach(scores.sorted(by: { $0.totalScore > $1.totalScore }), id: \.clusterId) { score in
                VStack(alignment: .leading, spacing: 8) {
                    // Show what is being scored
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scoring:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(score.clusterTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let ticker = score.ticker {
                            Text("Ticker: \(ticker)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 4)
                    
                    HStack {
                        Text("Total Score")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(String(format: "%.3f", score.totalScore))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(score.totalScore))
                        if score.wasFiltered {
                            Text("FILTERED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    if let filterReason = score.filterReason {
                        Text("❌ Filtered: \(filterReason)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        scoreRow("Holdings Relevance", score.breakdown.holdingsRelevance, weight: 0.55)
                        scoreRow("Impact Label Score", score.breakdown.impactLabelScore, weight: 0.20)
                        scoreRow("Event Type Weight", score.breakdown.eventTypeWeight, weight: 0.15)
                        scoreRow("Recency Score", score.breakdown.recencyScore, weight: 0.10)
                        // Legacy fields (weight 0.0, shown for reference)
                        scoreRow("Source Quality", score.breakdown.sourceQuality, weight: 0.0, showCalculation: false)
                        scoreRow("Impact Magnitude", score.breakdown.impactMagnitude, weight: 0.0, showCalculation: false)
                        scoreRow("User Interest Tags", score.breakdown.userInterestTags, weight: 0.0, showCalculation: false)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private func scoreRow(_ label: String, _ value: Double, weight: Double, showCalculation: Bool = true) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            Spacer()
            Text(String(format: "%.3f", value))
                .font(.caption)
                .fontWeight(.medium)
            if showCalculation {
                Text("× \(String(format: "%.2f", weight))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("= \(String(format: "%.3f", value * weight))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            } else {
                Text("(weight: 0.0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Themes Section
    private func themesSection(_ themes: [PipelineDebugData.ThemeDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Final Themes (\(themes.count))")
                .font(.headline)
            
            ForEach(themes, id: \.id) { theme in
                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.themeName)
                        .font(.headline)
                    
                    Text(theme.hook)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text(theme.contextExplanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Why it matters: \(theme.whyItMatters)")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                    
                    Text("\(theme.eventClusterCount) event clusters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func layerColor(_ layer: Int) -> Color {
        switch layer {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        default: return .gray
        }
    }
    
    private func eventTypeColor(_ type: String) -> Color {
        switch type {
        case "earnings": return .green
        case "guidance": return .blue
        case "regulation": return .orange
        case "merger_acquisition": return .purple
        case "product_launch": return .pink
        case "macro": return .yellow
        default: return .gray
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score > 0.5 { return .green }
        if score > 0.3 { return .orange }
        return .red
    }
    
    // MARK: - Filtered Items Section
    private func filteredItemsSection(_ items: [PipelineDebugData.FilteredItemDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filtered Out Items (\(items.count))")
                .font(.headline)
            
            if items.isEmpty {
                Text("No items were filtered out.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Group by stage
                let grouped = Dictionary(grouping: items) { $0.stage }
                ForEach(Array(grouped.keys.sorted()), id: \.self) { stage in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stage.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        ForEach(grouped[stage] ?? [], id: \.title) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if let ticker = item.ticker {
                                        Text(ticker)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    Text(item.itemType.capitalized)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(item.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Text("❌ \(item.reason)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .padding(.top, 2)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
    }
    
    // MARK: - Accepted Items Section
    private func acceptedItemsSection(_ items: [PipelineDebugData.AcceptedItemDebug]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items That Made It to Feed (\(items.count))")
                .font(.headline)
            
            if items.isEmpty {
                Text("No items in feed yet.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(items, id: \.title) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if let ticker = item.ticker {
                                Text(ticker)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            if let score = item.score {
                                Text(String(format: "Score: %.3f", score))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(scoreColor(score))
                            }
                        }
                        
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("✅ Accepted because:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            ForEach(item.reasons, id: \.self) { reason in
                                Text("  • \(reason)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Pipeline Debug ViewModel
class PipelineDebugViewModel: ObservableObject {
    @Published var debugData: PipelineDebugData?
    
    func loadDebugData() {
        // Load from UserDefaults where pipeline stores debug data
        if let data = UserDefaults.standard.data(forKey: "pipelineDebugData"),
           let decoded = try? JSONDecoder().decode(PipelineDebugData.self, from: data) {
            DispatchQueue.main.async {
                self.debugData = decoded
            }
        }
    }
}

