import Foundation
import Network

// MARK: - Pipeline Debug Web Server
// Serves debug data via localhost HTTP server
class PipelineDebugServer {
    static let shared = PipelineDebugServer()
    
    private var listener: NWListener?
    private let port: UInt16 = 8080
    private var isRunning = false
    
    private init() {}
    
    // Start the debug server
    func start() {
        guard !isRunning else {
            print("🌐 Debug server already running on http://localhost:\(port)")
            return
        }
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global())
            isRunning = true
            print("🌐 Pipeline Debug Server started at http://localhost:\(port)")
            print("   Open this URL in your browser to view debug data")
        } catch {
            print("❌ Failed to start debug server: \(error.localizedDescription)")
        }
    }
    
    // Stop the debug server
    func stop() {
        listener?.cancel()
        isRunning = false
        print("🌐 Debug server stopped")
    }
    
    // Handle incoming HTTP connection
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, let request = String(data: data, encoding: .utf8), let strongSelf = self {
                let response = strongSelf.handleRequest(request)
                strongSelf.sendResponse(connection, response: response)
            }
            
            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }
    
    // Handle HTTP request
    private func handleRequest(_ request: String) -> String {
        // Simple HTTP request parsing
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first, !requestLine.isEmpty else {
            return errorResponse("Invalid request")
        }
        
        let requestComponents = requestLine.components(separatedBy: " ")
        guard requestComponents.count >= 2 else {
            return errorResponse("Invalid request line")
        }
        
        let method = requestComponents[0]
        let path = requestComponents[1]
        
        if method == "GET" && path == "/" {
            return generateHTML()
        } else if method == "GET" && path == "/api/data" {
            return generateJSON()
        } else {
            return errorResponse("Not found", status: 404)
        }
    }
    
    // Generate HTML page
    private func generateHTML() -> String {
        guard let debugData = loadDebugData() else {
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Pipeline Debug - No Data</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; background: #1a1a1a; color: #fff; }
                    .container { max-width: 1200px; margin: 0 auto; }
                    .error { background: #ff4444; padding: 20px; border-radius: 8px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>Pipeline Debug</h1>
                    <div class="error">
                        <p>No debug data available. Run the pipeline first to generate data.</p>
                    </div>
                </div>
            </body>
            </html>
            """
        }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Pipeline Debug</title>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                * { box-sizing: border-box; }
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; 
                    margin: 0; 
                    padding: 20px; 
                    background: #1a1a1a; 
                    color: #e0e0e0; 
                }
                .container { max-width: 1400px; margin: 0 auto; }
                h1 { color: #fff; margin-bottom: 10px; }
                .subtitle { color: #888; margin-bottom: 30px; }
                .tabs { 
                    display: flex; 
                    gap: 10px; 
                    margin-bottom: 20px; 
                    border-bottom: 2px solid #333; 
                    padding-bottom: 10px;
                }
                .tab { 
                    padding: 10px 20px; 
                    background: #2a2a2a; 
                    border: none; 
                    color: #e0e0e0; 
                    cursor: pointer; 
                    border-radius: 6px 6px 0 0;
                    font-size: 14px;
                }
                .tab.active { 
                    background: #007AFF; 
                    color: #fff; 
                }
                .tab-content { display: none; }
                .tab-content.active { display: block; }
                .stats { 
                    display: grid; 
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
                    gap: 15px; 
                    margin-bottom: 30px; 
                }
                .stat-card { 
                    background: #2a2a2a; 
                    padding: 20px; 
                    border-radius: 8px; 
                    border-left: 4px solid #007AFF;
                }
                .stat-label { 
                    font-size: 12px; 
                    color: #888; 
                    text-transform: uppercase; 
                    margin-bottom: 5px; 
                }
                .stat-value { 
                    font-size: 32px; 
                    font-weight: bold; 
                    color: #fff; 
                }
                .article-card, .event-card, .cluster-card, .theme-card, .score-card { 
                    background: #2a2a2a; 
                    padding: 15px; 
                    margin-bottom: 15px; 
                    border-radius: 8px; 
                    border-left: 4px solid #007AFF;
                }
                .article-title { 
                    font-weight: 600; 
                    color: #fff; 
                    margin-bottom: 8px; 
                    font-size: 15px;
                }
                .article-meta { 
                    display: flex; 
                    gap: 10px; 
                    flex-wrap: wrap; 
                    margin-top: 10px; 
                }
                .badge { 
                    padding: 4px 8px; 
                    border-radius: 4px; 
                    font-size: 12px; 
                    font-weight: 500; 
                }
                .badge-layer1 { background: #007AFF; color: #fff; }
                .badge-layer2 { background: #34C759; color: #fff; }
                .badge-layer3 { background: #FF9500; color: #fff; }
                .badge-event { background: #5856D6; color: #fff; }
                .badge-ticker { background: #5AC8FA; color: #000; }
                .article-url { 
                    color: #5AC8FA; 
                    text-decoration: none; 
                    font-size: 12px; 
                    word-break: break-all;
                }
                .article-url:hover { text-decoration: underline; }
                .score-breakdown { 
                    margin-top: 10px; 
                    padding-top: 10px; 
                    border-top: 1px solid #333; 
                }
                .score-row { 
                    display: flex; 
                    justify-content: space-between; 
                    padding: 5px 0; 
                    font-size: 13px; 
                }
                .score-total { 
                    font-size: 24px; 
                    font-weight: bold; 
                    color: #34C759; 
                    margin-bottom: 10px; 
                }
                .theme-hook { 
                    font-size: 16px; 
                    font-weight: 600; 
                    color: #5AC8FA; 
                    margin-bottom: 10px; 
                }
                .theme-explanation { 
                    color: #aaa; 
                    line-height: 1.6; 
                    margin-bottom: 8px; 
                }
                .timestamp { color: #888; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🐇 Pipeline Debug Dashboard</h1>
                <div class="subtitle">Last run: \(formatDate(debugData.timestamp))</div>
                
                <div class="stats">
                    <div class="stat-card">
                        <div class="stat-label">Raw Articles</div>
                        <div class="stat-value">\(debugData.rawArticlesCount)</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Cleaned</div>
                        <div class="stat-value">\(debugData.cleanedArticlesCount)</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Events</div>
                        <div class="stat-value">\(debugData.detectedEventsCount)</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Clusters</div>
                        <div class="stat-value">\(debugData.clustersCount)</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Final Themes</div>
                        <div class="stat-value">\(debugData.finalThemesCount)</div>
                    </div>
                </div>
                
                <div class="tabs">
                    <button class="tab active" onclick="showTab('raw')">Raw Articles</button>
                    <button class="tab" onclick="showTab('cleaned')">Cleaned</button>
                    <button class="tab" onclick="showTab('events')">Events</button>
                    <button class="tab" onclick="showTab('clusters')">Clusters</button>
                    <button class="tab" onclick="showTab('scores')">Scores</button>
                    <button class="tab" onclick="showTab('themes')">Final Themes</button>
                </div>
                
                <div id="raw" class="tab-content active">
                    \(generateRawArticlesHTML(debugData.rawArticles))
                </div>
                
                <div id="cleaned" class="tab-content">
                    \(generateCleanedArticlesHTML(debugData.cleanedArticles))
                </div>
                
                <div id="events" class="tab-content">
                    \(generateEventsHTML(debugData.detectedEvents))
                </div>
                
                <div id="clusters" class="tab-content">
                    \(generateClustersHTML(debugData.clusters))
                </div>
                
                <div id="scores" class="tab-content">
                    \(generateScoresHTML(debugData.userScores))
                </div>
                
                <div id="themes" class="tab-content">
                    \(generateThemesHTML(debugData.themes))
                </div>
            </div>
            
            <script>
                function showTab(tabName) {
                    // Hide all tabs
                    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
                    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
                    
                    // Show selected tab
                    document.getElementById(tabName).classList.add('active');
                    event.target.classList.add('active');
                }
            </script>
        </body>
        </html>
        """
        
        return httpResponse(html)
    }
    
    // Generate JSON API response
    private func generateJSON() -> String {
        guard let debugData = loadDebugData(),
              let jsonData = try? JSONEncoder().encode(debugData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return errorResponse("No data available")
        }
        return httpResponse(jsonString, contentType: "application/json")
    }
    
    // HTML generators
    private func generateRawArticlesHTML(_ articles: [PipelineDebugData.RawArticleDebug]) -> String {
        return articles.map { article in
            """
            <div class="article-card">
                <div class="article-title">\(escapeHTML(article.title))</div>
                <div class="article-meta">
                    <span class="badge badge-layer\(article.sourceLayer)">Layer \(article.sourceLayer): \(escapeHTML(article.source))</span>
                    <span class="timestamp">\(article.publishedAt)</span>
                </div>
                <a href="\(escapeHTML(article.url))" target="_blank" class="article-url">\(escapeHTML(article.url))</a>
            </div>
            """
        }.joined()
    }
    
    private func generateCleanedArticlesHTML(_ articles: [PipelineDebugData.CleanedArticleDebug]) -> String {
        return articles.map { article in
            let tickersHTML = article.cleanTickers.map { "<span class=\"badge badge-ticker\">\($0)</span>" }.joined(separator: " ")
            return """
            <div class="article-card">
                <div class="article-title">\(escapeHTML(article.cleanTitle))</div>
                <div style="color: #aaa; font-size: 13px; margin: 8px 0;">\(escapeHTML(article.cleanDescription))</div>
                <div class="article-meta">
                    \(tickersHTML)
                    <span style="color: #888; font-size: 12px;">Quality: \(String(format: "%.2f", article.sourceQualityScore)) | Body: \(article.cleanBodyLength) chars</span>
                </div>
            </div>
            """
        }.joined()
    }
    
    private func generateEventsHTML(_ events: [PipelineDebugData.DetectedEventDebug]) -> String {
        return events.map { event in
            let tickerHTML = event.dominantTicker.map { "<span class=\"badge badge-ticker\">\($0)</span>" } ?? ""
            return """
            <div class="event-card">
                <div class="article-meta">
                    <span class="badge badge-event">\(escapeHTML(event.eventType))</span>
                    \(tickerHTML)
                </div>
                <div style="margin-top: 10px;">
                    <span style="color: #888;">Base Score: \(String(format: "%.2f", event.baseScore))</span>
                    <span style="color: #888; margin-left: 15px;">Confidence: \(String(format: "%.2f", event.confidence))</span>
                </div>
            </div>
            """
        }.joined()
    }
    
    private func generateClustersHTML(_ clusters: [PipelineDebugData.ClusterDebug]) -> String {
        return clusters.map { cluster in
            let tickerHTML = cluster.dominantTicker.map { "<span class=\"badge badge-ticker\">\($0)</span>" } ?? ""
            let similarityHTML = cluster.similarityScores.isEmpty ? "" : 
                "<div style=\"color: #888; font-size: 12px; margin-top: 5px;\">Similarity: \(cluster.similarityScores.map { String(format: "%.2f", $0) }.joined(separator: ", "))</div>"
            return """
            <div class="cluster-card">
                <div class="article-title">\(escapeHTML(cluster.canonicalArticleTitle))</div>
                <div class="article-meta">
                    <span class="badge badge-event">\(escapeHTML(cluster.eventType))</span>
                    \(tickerHTML)
                    <span style="color: #888;">\(cluster.articleCount) articles</span>
                </div>
                \(similarityHTML)
            </div>
            """
        }.joined()
    }
    
    private func generateScoresHTML(_ scores: [PipelineDebugData.UserScoreDebug]) -> String {
        return scores.sorted(by: { $0.totalScore > $1.totalScore }).map { score in
            """
            <div class="score-card">
                <div class="score-total">Score: \(String(format: "%.3f", score.totalScore))</div>
                <div class="score-breakdown">
                    <div class="score-row">
                        <span>Holdings Relevance</span>
                        <span>\(String(format: "%.3f", score.breakdown.holdingsRelevance)) × 0.35 = \(String(format: "%.3f", score.breakdown.holdingsRelevance * 0.35))</span>
                    </div>
                    <div class="score-row">
                        <span>Event Type Weight</span>
                        <span>\(String(format: "%.3f", score.breakdown.eventTypeWeight)) × 0.25 = \(String(format: "%.3f", score.breakdown.eventTypeWeight * 0.25))</span>
                    </div>
                    <div class="score-row">
                        <span>Recency Decay</span>
                        <span>\(String(format: "%.3f", score.breakdown.recencyDecay)) × 0.15 = \(String(format: "%.3f", score.breakdown.recencyDecay * 0.15))</span>
                    </div>
                    <div class="score-row">
                        <span>Source Quality</span>
                        <span>\(String(format: "%.3f", score.breakdown.sourceQuality)) × 0.10 = \(String(format: "%.3f", score.breakdown.sourceQuality * 0.10))</span>
                    </div>
                    <div class="score-row">
                        <span>Impact Magnitude</span>
                        <span>\(String(format: "%.3f", score.breakdown.impactMagnitude)) × 0.10 = \(String(format: "%.3f", score.breakdown.impactMagnitude * 0.10))</span>
                    </div>
                    <div class="score-row">
                        <span>User Interest Tags</span>
                        <span>\(String(format: "%.3f", score.breakdown.userInterestTags)) × 0.05 = \(String(format: "%.3f", score.breakdown.userInterestTags * 0.05))</span>
                    </div>
                </div>
            </div>
            """
        }.joined()
    }
    
    private func generateThemesHTML(_ themes: [PipelineDebugData.ThemeDebug]) -> String {
        return themes.map { theme in
            """
            <div class="theme-card">
                <h3 style="margin-top: 0; color: #fff;">\(escapeHTML(theme.themeName))</h3>
                <div class="theme-hook">\(escapeHTML(theme.hook))</div>
                <div class="theme-explanation">\(escapeHTML(theme.contextExplanation))</div>
                <div style="color: #888; font-style: italic; margin-top: 10px;">Why it matters: \(escapeHTML(theme.whyItMatters))</div>
                <div style="color: #888; font-size: 12px; margin-top: 10px;">\(theme.eventClusterCount) event clusters</div>
            </div>
            """
        }.joined()
    }
    
    // Helper functions
    private func loadDebugData() -> PipelineDebugData? {
        guard let data = UserDefaults.standard.data(forKey: "pipelineDebugData"),
              let debugData = try? JSONDecoder().decode(PipelineDebugData.self, from: data) else {
            return nil
        }
        return debugData
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func httpResponse(_ body: String, contentType: String = "text/html", status: Int = 200) -> String {
        let statusText = status == 200 ? "OK" : status == 404 ? "Not Found" : "Error"
        return """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: \(contentType); charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        \r
        \(body)
        """
    }
    
    private func errorResponse(_ message: String, status: Int = 500) -> String {
        let body = """
        <!DOCTYPE html>
        <html>
        <head><title>Error</title></head>
        <body><h1>Error</h1><p>\(message)</p></body>
        </html>
        """
        return httpResponse(body, status: status)
    }
    
    private func sendResponse(_ connection: NWConnection, response: String) {
        guard let data = response.data(using: .utf8) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

