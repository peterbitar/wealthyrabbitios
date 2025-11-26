import Foundation
import Combine
import UserNotifications

class RabbitViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var userSettings: UserSettings
    @Published var stockQuotes: [String: StockQuote] = [:]
    @Published var socialBuzzData: [String: SocialBuzzData] = [:]
    @Published var isLoadingStockData = false
    @Published var isLoadingSocialData = false

    // Backend sync properties
    @Published var isBackendAvailable = false
    @Published var isSyncing = false
    private var lastSyncTime: Date?
    private let backendAPI = BackendAPI.shared
    private let userId = Config.deviceUserId
    private var healthCheckTimer: Timer?

    private var openAIService: OpenAIService?
    private let stockDataService = StockDataService.shared
    private let socialBuzzService = SocialBuzzService.shared
    private let newsService = NewsService.shared
    private let persistenceManager = DataPersistenceManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Cache for news events
    @Published var newsEvents: [Event] = []
    @Published var isLoadingNews = false
    @Published var newsError: String? = nil
    private var newsFetchTask: Task<Void, Never>? = nil
    
    // Track previous holdings snapshot for change detection
    private var previousHoldingsSnapshot: [Holding] = []

    init(apiKey: String = "", userSettings: UserSettings? = nil) {
        // Load persisted user settings or use provided ones
        if let userSettings = userSettings {
            self.userSettings = userSettings
        } else {
            self.userSettings = persistenceManager.loadUserSettings()
        }

        if !apiKey.isEmpty {
            self.openAIService = OpenAIService(apiKey: apiKey)
        }

        loadRabbitConversations()
        loadCachedStockData()
        loadCachedSocialData()
        setupAutoSave()
        
        // Initialize holdings snapshot for change detection
        previousHoldingsSnapshot = self.userSettings.holdings

        // Check backend and start periodic sync
        Task {
            await checkBackendAndSync()
        }
        startHealthCheckTimer()
        
        // Listen for notifications to mirror into Rabbit chat
        setupNotificationListener()
    }

    deinit {
        stopHealthCheckTimer()
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
    }
    
    // Setup listener for notifications to mirror into Rabbit chat
    private func setupNotificationListener() {
        print("🔔 Setting up notification listener for Rabbit chat")
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RabbitNotificationReceived"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🔔 Notification received in RabbitViewModel listener")
            if let message = notification.userInfo?["message"] as? String {
                print("🔔 Extracted message: \(message.prefix(50))...")
                self?.appendRabbitNotificationMessage(message)
            } else {
                print("⚠️ Could not extract message from notification userInfo: \(notification.userInfo ?? [:])")
            }
        }
    }

    // Setup auto-save when data changes
    private func setupAutoSave() {
        // Save user settings whenever they change
        userSettings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.saveUserSettings()
                // Sync to backend if available
                Task {
                    await self?.syncUserSettingsIfAvailable()
                }
            }
        }.store(in: &cancellables)

        // Save conversations when they change
        $conversations.dropFirst().sink { [weak self] conversations in
            self?.persistenceManager.saveConversations(conversations)
        }.store(in: &cancellables)
    }

    func saveUserSettings() {
        persistenceManager.saveUserSettings(userSettings)
    }

    func loadCachedStockData() {
        if let cached = persistenceManager.loadStockQuotes() {
            stockQuotes = cached
        }
    }

    func loadCachedSocialData() {
        if let cached = persistenceManager.loadSocialBuzz() {
            socialBuzzData = cached
        }
    }

    // Refresh social buzz for all holdings
    func refreshSocialBuzz() async {
        await MainActor.run {
            isLoadingSocialData = true
        }

        let symbols = userSettings.holdings.map { $0.symbol }

        guard !symbols.isEmpty else {
            await MainActor.run {
                isLoadingSocialData = false
            }
            return
        }

        do {
            let buzzData = try await socialBuzzService.fetchBuzz(for: symbols)
            await MainActor.run {
                self.socialBuzzData = buzzData
                self.isLoadingSocialData = false
                // Cache the social data
                self.persistenceManager.saveSocialBuzz(buzzData)
                print("✅ Refreshed social buzz for \(buzzData.count) symbols")

                // Update initial greetings with new data
                self.updateInitialGreetings()
            }
        } catch {
            await MainActor.run {
                self.isLoadingSocialData = false
                print("❌ Failed to refresh social buzz: \(error)")
            }
        }
    }

    // Update initial greetings with current data
    private func updateInitialGreetings() {
        for rabbitType in RabbitType.allCases {
            if let index = conversations.firstIndex(where: { $0.contactName == rabbitType.rawValue }) {
                let conversation = conversations[index]

                // Only update if there's just the initial greeting (1 message from rabbit)
                if conversation.messages.count == 1 && !conversation.messages[0].isFromCurrentUser {
                    let newGreeting = getInitialGreeting(for: rabbitType)

                    // Only update if the greeting actually changed
                    if conversation.messages[0].text != newGreeting {
                        conversations[index].messages[0] = Message(
                            text: newGreeting,
                            timestamp: Date().addingTimeInterval(-60),
                            isFromCurrentUser: false,
                            type: .text
                        )
                        print("✅ Updated greeting for \(rabbitType.rawValue)")
                    }
                }
            }
        }
    }

    // Get social buzz for a specific symbol
    func getSocialBuzz(for symbol: String) -> SocialBuzzData? {
        return socialBuzzData[symbol]
    }

    func loadRabbitConversations() {
        // Try to load persisted conversations first
        if let savedConversations = persistenceManager.loadConversations() {
            conversations = savedConversations
            return
        }

        // Initialize one conversation for each rabbit type
        conversations = RabbitType.allCases.map { rabbitType in
            Conversation(
                contactName: rabbitType.rawValue,
                contactAvatar: rabbitType.emoji,
                messages: [
                    Message(
                        text: getInitialGreeting(for: rabbitType),
                        timestamp: Date().addingTimeInterval(-60),
                        isFromCurrentUser: false,
                        type: .text
                    )
                ]
            )
        }
    }

    func getInitialGreeting(for rabbitType: RabbitType) -> String {
        switch rabbitType {
        case .holdings:
            if userSettings.holdings.isEmpty {
                return "Hi \(userSettings.userName)! I watch your portfolio. Add some holdings in Portfolio to get started."
            } else {
                // Generate data-aware greeting if we have stock data
                if !stockQuotes.isEmpty {
                    let avgChange = stockQuotes.values.map { $0.changePercent }.reduce(0, +) / Double(stockQuotes.count)
                    let gainers = stockQuotes.values.filter { $0.changePercent > 0 }.count

                    if avgChange > 1.0 {
                        return "Hello \(userSettings.userName)! Your portfolio is up \(String(format: "%.1f", avgChange))% today — \(gainers) holdings in the green. Nice to see."
                    } else if avgChange < -1.0 {
                        return "Hi \(userSettings.userName). Portfolio dipped \(String(format: "%.1f", abs(avgChange)))% today, but that's normal movement. Everything okay on your end?"
                    } else {
                        return "Hello \(userSettings.userName)! Portfolio moving steadily — averaging \(avgChange >= 0 ? "+" : "")\(String(format: "%.1f", avgChange))%. Let me know if you want details."
                    }
                } else {
                    return "Hello \(userSettings.userName)! I'm tracking your \(userSettings.holdings.count) holdings. Tap refresh in Portfolio to load current prices."
                }
            }

        case .trends:
            // Check if we have social buzz data
            if !socialBuzzData.isEmpty {
                let hotStocks = socialBuzzData.filter { $0.value.buzzLevel == .hot }.count
                let risingStocks = socialBuzzData.filter { $0.value.buzzLevel == .rising }.count

                if hotStocks > 0 {
                    return "Hey \(userSettings.userName)! Seeing some 🔥 hot buzz on \(hotStocks) of your holdings. Social chatter is definitely picking up."
                } else if risingStocks > 0 {
                    return "Hi \(userSettings.userName)! \(risingStocks) of your holdings showing rising social interest. Want to dive into what people are saying?"
                } else {
                    return "Hey \(userSettings.userName)! Social sentiment is pretty calm on your holdings today. Steady vibes all around."
                }
            } else {
                return "Hey \(userSettings.userName)! I track social buzz and emerging trends. What interests you today?"
            }

        case .drama:
            // Check for dramatic price moves or high buzz
            var dramaticEvents = 0
            if !stockQuotes.isEmpty {
                dramaticEvents = stockQuotes.values.filter { abs($0.changePercent) >= 3.0 }.count
            }

            if dramaticEvents > 0 {
                return "Hi \(userSettings.userName). Noticed \(dramaticEvents) of your holdings moved 3%+ today. Want me to explain what's happening?"
            } else {
                return "Hi \(userSettings.userName)! Pretty calm day in your portfolio. I'm here if any news or drama pops up that needs explaining."
            }

        case .insights:
            if !stockQuotes.isEmpty {
                let allChanges = stockQuotes.values.map { $0.changePercent }
                let volatility = allChanges.map { abs($0) }.reduce(0, +) / Double(allChanges.count)

                if volatility > 2.0 {
                    return "Hello \(userSettings.userName) — seeing heightened volatility today (avg \(String(format: "%.1f", volatility))% moves). Market's a bit choppy. Want the macro view?"
                } else {
                    return "Hello \(userSettings.userName) — markets moving normally today. Your holdings showing typical daily patterns. Need any perspective?"
                }
            } else {
                return "Hello \(userSettings.userName) — I'm your macro guide. Load your portfolio data and I'll share insights on what's moving the market."
            }
        }
    }

    func getRabbitType(for conversation: Conversation) -> RabbitType? {
        return RabbitType.allCases.first { $0.rawValue == conversation.contactName }
    }

    func sendMessage(to conversation: Conversation, text: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            let newMessage = Message(text: text, isFromCurrentUser: true, type: .text)
            conversations[index].messages.append(newMessage)
        }
    }

    func addIncomingMessage(to conversation: Conversation, text: String, type: MessageType = .text, durationSeconds: Int? = nil, audioUrl: String? = nil) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            let newMessage = Message(text: text, isFromCurrentUser: false, type: type, durationSeconds: durationSeconds, audioUrl: audioUrl)
            conversations[index].messages.append(newMessage)
        }
    }
    
    // Add demo voice note after Rabbit Brief or explanation (avoid spamming)
    private func maybeAppendVoiceNote(to conversation: Conversation) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }
        
        // Check if the last message is already a voice note - prevent consecutive voice notes
        let lastMessage = conversations[index].messages.last
        if lastMessage?.type == .voiceNote {
            return  // Already has a voice note, don't add another
        }
        
        // Add voice note after Rabbit Brief or explanation messages
        if let lastMsg = lastMessage,
           (lastMsg.type == .dailyBrief || lastMsg.type == .explanation) && !lastMsg.isFromCurrentUser {
            // Add demo voice note message
            let voiceNoteMessage = Message(
                text: "Rabbit voice note",
                isFromCurrentUser: false,
                type: .voiceNote,
                durationSeconds: 32,  // Demo duration: 32 seconds
                audioUrl: nil
            )
            conversations[index].messages.append(voiceNoteMessage)
            print("✅ Added demo voice note after \(lastMsg.type.rawValue)")
        }
    }

    func getAIResponse(for conversation: Conversation, completion: (() -> Void)? = nil) async {
        guard let openAIService = openAIService else {
            // Fallback to calm replies if no API key
            await MainActor.run {
                let replies = [
                    "That's an interesting point.",
                    "I see what you mean.",
                    "Tell me more about that.",
                    "Let me think about that for a moment.",
                    "That makes sense."
                ]
                if let randomReply = replies.randomElement() {
                    addIncomingMessage(to: conversation, text: randomReply)
                }
            }
            completion?()
            return
        }

        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            completion?()
            return
        }

        let conversationHistory = conversations[conversationIndex].messages

        // Get the rabbit type and its system prompt
        let rabbitType = getRabbitType(for: conversation)
        
        // Use unified system prompt if this is the unified Rabbit conversation
        let systemPrompt: String
        if conversation.contactName == "Rabbit" {
            // For unified Rabbit chat, use the Wealthy Rabbit system prompt
            let holdingsSummary = buildHoldingsSummary()
            let eventsSummary = buildEventsSummary()
            systemPrompt = buildWealthyRabbitSystemPrompt(holdingsSummary: holdingsSummary, eventsSummary: eventsSummary)
        } else {
            // For legacy rabbit types, use their specific prompts
            systemPrompt = rabbitType?.systemPrompt ?? ""
        }

        do {
            let response = try await openAIService.sendMessage(
                conversationHistory: conversationHistory,
                systemPrompt: systemPrompt
            )
            await MainActor.run {
                // Determine if this is an explanation (longer, more complex response)
                let isExplanation = response.count > 100 || response.contains(".") && response.components(separatedBy: ".").count > 2
                
                // Add message with appropriate type
                let messageType: MessageType = isExplanation ? .explanation : .text
                addIncomingMessage(to: conversation, text: response, type: messageType)
                
                // Add demo voice note after explanations (if not already present)
                if conversation.contactName == "Rabbit" && isExplanation {
                    maybeAppendVoiceNote(to: conversation)
                }
            }
            completion?()
        } catch {
            await MainActor.run {
                addIncomingMessage(to: conversation, text: "I'm having trouble connecting right now. Please try again in a moment.")
            }
            completion?()
        }
    }

    func getConversation(for rabbitType: RabbitType) -> Conversation? {
        return conversations.first { $0.contactName == rabbitType.rawValue }
    }
    
    // Get or create the unified Rabbit conversation (single chat, not tied to a specific rabbit type)
    func getUnifiedRabbitConversation() -> Conversation {
        let unifiedName = "Rabbit"
        
        // Check if existing conversation exists
        if let existingIndex = conversations.firstIndex(where: { $0.contactName == unifiedName }) {
            let existing = conversations[existingIndex]
            
            // Check if this is the old conversation format (has old greeting)
            // If it doesn't start with the Rabbit Brief, reset it
            let hasRabbitBrief = existing.messages.first?.text.contains("Rabbit Brief") ?? false
            
            if !hasRabbitBrief {
                // Replace old conversation with new Rabbit Brief
                let now = Date()
                let resetConversation = Conversation(
                    id: existing.id, // Keep same ID to maintain reference
                    contactName: unifiedName,
                    contactAvatar: "🐇",
                    messages: getInitialRabbitBriefMessages(now: now)
                )
                conversations[existingIndex] = resetConversation
                return resetConversation
            }
            
            return existing
        }
        
        // Create new unified conversation with hard-coded initial "Rabbit Brief" conversation
        let now = Date()
        let newConversation = Conversation(
            contactName: unifiedName,
            contactAvatar: "🐇",
            messages: getInitialRabbitBriefMessages(now: now)
        )
        
        conversations.append(newConversation)
        return newConversation
    }
    
    // Build holdings summary string for display and system prompts
    func buildHoldingsSummary() -> String {
        let holdings = userSettings.holdings
        
        if holdings.isEmpty {
            return "You don't have any holdings yet."
        } else if holdings.count == 1 {
            let holding = holdings[0]
            return "You currently hold \(holding.name) (\(holding.symbol))."
        } else {
            // Multiple holdings: "Tesla (TSLA), Apple (AAPL), and NVIDIA (NVDA)"
            let holdingStrings = holdings.map { "\($0.name) (\($0.symbol))" }
            
            if holdingStrings.count == 2 {
                return "You currently hold \(holdingStrings[0]) and \(holdingStrings[1])."
            } else {
                // Join all but last with commas, then add "and" before last
                let allButLast = holdingStrings.dropLast().joined(separator: ", ")
                let last = holdingStrings.last!
                return "You currently hold \(allButLast), and \(last)."
            }
        }
    }
    
    // Fetch news and convert to events
    // Adjusts limit based on Rabbit Mode to avoid overwhelming the user
    func fetchNewsEvents(forceRefresh: Bool = false) async {
        // Cancel any existing fetch task to avoid duplicate requests
        newsFetchTask?.cancel()
        
        await MainActor.run {
            // Don't fetch if already loading
            if isLoadingNews {
                print("⚠️ News fetch already in progress, skipping duplicate request")
                return
            }
            isLoadingNews = true
            newsError = nil // Clear any previous errors
        }
        
        // Create new task
        newsFetchTask = Task {
            await performNewsFetch(forceRefresh: forceRefresh)
        }
        
        await newsFetchTask?.value
    }
    
    private func performNewsFetch(forceRefresh: Bool = false) async {
        
        do {
            // Adjust news limit based on Rabbit Mode
            let newsLimit: Int
            switch userSettings.rabbitMode {
            case .beginner:
                newsLimit = 100 // More raw articles for learning
            case .smart:
                newsLimit = 75 // Moderate amount
            case .focus:
                newsLimit = 50 // Less news, more focused
            }
            
            // Use new pipeline orchestrator
            let orchestrator = NewsPipelineOrchestrator.shared
            
            // Run the full pipeline: Fetch → Clean → Detect → Cluster → Score → Build Feed
            let themes = try await orchestrator.runPipeline(
                userHoldings: userSettings.holdings,
                userInterests: [], // Could be extracted from user settings in the future
                rabbitMode: userSettings.rabbitMode,
                limit: newsLimit
            )
            
            // Convert themes to events for display compatibility
            let events = orchestrator.convertThemesToEvents(themes)
            
            await MainActor.run {
                self.newsEvents = events
                self.isLoadingNews = false
                print("✅ Loaded \(events.count) news events from \(themes.count) themes (Rabbit Mode: \(userSettings.rabbitMode.rawValue))")
            }
        } catch {
            await MainActor.run {
                self.isLoadingNews = false
                print("❌ Failed to fetch news: \(error.localizedDescription)")
                print("❌ Error type: \(type(of: error))")
                
                var errorMessage = "Failed to load news"
                
                if let urlError = error as? URLError {
                    print("❌ URL Error code: \(urlError.code.rawValue)")
                    print("❌ URL Error description: \(urlError.localizedDescription)")
                    if urlError.code == .timedOut {
                        errorMessage = "Request timed out. Check your internet connection and try again."
                        print("⚠️ Request timed out - check internet connection or try again")
                    } else if urlError.code == .notConnectedToInternet {
                        errorMessage = "No internet connection. Please check your network."
                    } else {
                        errorMessage = "Network error: \(urlError.localizedDescription)"
                    }
                } else if let newsError = error as? NewsError {
                    print("❌ News API Error: \(newsError.localizedDescription)")
                    errorMessage = newsError.localizedDescription
                } else {
                    errorMessage = error.localizedDescription
                }
                
                self.newsError = errorMessage
                
                // Keep existing news events if available, otherwise empty
                if self.newsEvents.isEmpty {
                    print("⚠️ No news available - feed will be empty until news is fetched successfully")
                }
            }
            
            // Task completed
            await MainActor.run {
                newsFetchTask = nil
            }
        }
        
        await newsFetchTask?.value
    }
    
    // Find relevant events based on user's holdings and Rabbit Mode
    // Uses intelligent relevance scoring to filter out low-value content
    func findRelevantEvents() -> [Event] {
        // New pipeline already filters and scores events, so just return what we have
        // The pipeline handles all filtering, scoring, and limits based on rabbitMode
        return newsEvents
    }
    
    // Build events summary string for Rabbit Brief and system prompt
    func buildEventsSummary() -> String {
        let relevantEvents = findRelevantEvents()
        
        if relevantEvents.isEmpty {
            return "No major news directly tied to your holdings today."
        } else if relevantEvents.count == 1 {
            let event = relevantEvents[0]
            return "Today, one notable thing: \(event.title). \(event.summary)"
        } else if relevantEvents.count <= 3 {
            // 2-3 events - mention them concisely
            let eventTitles = relevantEvents.map { $0.title }
            return "Today, a few notable things: \(eventTitles.joined(separator: ". "))"
        } else {
            // 4+ events - summarize the most important ones
            let topEvents = Array(relevantEvents.prefix(3))
            let eventTitles = topEvents.map { $0.title }
            let remaining = relevantEvents.count - 3
            return "Today, several notable things: \(eventTitles.joined(separator: ". ")).\(remaining > 0 ? " Plus \(remaining) more in your feed." : "")"
        }
    }
    
    // Build Rabbit Brief message text based on holdings count
    private func buildRabbitBriefMessage(holdings: [Holding], eventsSummary: String) -> String {
        let holdingsCount = holdings.count
        
        // Case 1: No holdings
        if holdingsCount == 0 {
            return "Good morning 🥕 I don't see any holdings in your portfolio yet. Once you add a few in the Portfolio tab, I'll start watching them for you and give you daily briefs."
        }
        
        // Case 2: Exactly one holding
        if holdingsCount == 1 {
            let holding = holdings[0]
            let ticker = holding.symbol
            let name = holding.name
            
            // Check if there's a relevant event for this holding
            let relevantEvents = findRelevantEvents()
            let hasRelevantEvent = relevantEvents.contains { event in
                event.ticker?.uppercased() == ticker.uppercased()
            }
            
            if hasRelevantEvent && !eventsSummary.isEmpty {
                return "Good morning 🥕 I see you currently hold \(name) (\(ticker)). I'll keep an eye on it for you. \(eventsSummary)"
            } else {
                return "Good morning 🥕 I see you currently hold \(name) (\(ticker)). I'll keep an eye on it for you. No major news directly tied to it today, so it's a good day to zoom out rather than react."
            }
        }
        
        // Case 3: Multiple holdings (2 or more)
        let tickers = holdings.map { $0.symbol }
        let shortTickerList: String
        
        if holdingsCount == 2 {
            // 2 holdings: "TSLA and AAPL"
            shortTickerList = "\(tickers[0]) and \(tickers[1])"
        } else if holdingsCount == 3 {
            // 3 holdings: "TSLA, AAPL and NVDA"
            shortTickerList = "\(tickers[0]), \(tickers[1]) and \(tickers[2])"
        } else {
            // 4+ holdings: "TSLA, AAPL and 2 more positions"
            let remainingCount = holdingsCount - 2
            shortTickerList = "\(tickers[0]), \(tickers[1]) and \(remainingCount) more position\(remainingCount == 1 ? "" : "s")"
        }
        
        // Check if there are relevant events
        let relevantEvents = findRelevantEvents()
        let hasRelevantEvent = !relevantEvents.isEmpty
        
        if hasRelevantEvent && !eventsSummary.isEmpty {
            return "Good morning 🥕 You currently hold \(shortTickerList). I'll watch these for any notable moves. \(eventsSummary)"
        } else {
            return "Good morning 🥕 You currently hold \(shortTickerList). I'll watch these for any notable moves. No major news directly tied to your holdings so far today."
        }
    }
    
    // Generate initial Rabbit Brief message based on real holdings and events
    private func getInitialRabbitBriefMessages(now: Date) -> [Message] {
        let holdings = userSettings.holdings
        let eventsSummary = buildEventsSummary()
        
        // Build the brief message using the helper
        let briefText = buildRabbitBriefMessage(holdings: holdings, eventsSummary: eventsSummary)
        
        var messages: [Message] = [
            // Rabbit's initial brief
            Message(
                text: briefText,
                timestamp: now.addingTimeInterval(-60), // 1 minute ago
                isFromCurrentUser: false,
                type: .dailyBrief
            )
        ]
        
        // Add demo voice note after initial brief (only if user has holdings)
        if !holdings.isEmpty {
            let voiceNoteMessage = Message(
                text: "Rabbit voice note",
                timestamp: now.addingTimeInterval(-30), // 30 seconds ago
                isFromCurrentUser: false,
                type: .voiceNote,
                durationSeconds: 28,  // Demo duration: 28 seconds
                audioUrl: nil
            )
            messages.append(voiceNoteMessage)
        }
        
        return messages
    }
    
    // Generate and append a new Rabbit Brief message (called when user taps "Rabbit Brief" button)
    func generateRabbitBrief() {
        let holdings = userSettings.holdings
        let eventsSummary = buildEventsSummary()
        
        // Build the brief message using the helper
        let briefText = buildRabbitBriefMessage(holdings: holdings, eventsSummary: eventsSummary)
        
        // Append to unified Rabbit conversation
        let unifiedName = "Rabbit"
        if let index = conversations.firstIndex(where: { $0.contactName == unifiedName }) {
            let briefMessage = Message(
                text: briefText,
                isFromCurrentUser: false,
                type: .dailyBrief
            )
            conversations[index].messages.append(briefMessage)
            print("✅ Added new Rabbit Brief message")
        }
    }
    
    // Build the Wealthy Rabbit system prompt with consistent personality and context
    func buildWealthyRabbitSystemPrompt(holdingsSummary: String, eventsSummary: String) -> String {
        return """
        You are "Wealthy Rabbit", a friendly, proactive financial companion in WealthyRabbit - "If Calm built Bloomberg."
        
        You talk like a smart friend, not a formal advisor. Be calm, helpful, and context-aware.

        CONTEXT:
        Here is the user's current portfolio: \(holdingsSummary)
        
        Here is today's notable context or events: \(eventsSummary)
        
        Use ONLY this information about their holdings and events; do not invent positions or news.

        STYLE RULES:
        - Explain things in simple language, max 2-3 short paragraphs.
        - Avoid jargon, or briefly explain it if you must use a term.
        - Be calm and non-alarmist, even when markets are volatile.
        - Focus on giving context and education, not hype.
        - You can say things like "this is short-term noise" vs "this may matter long term".
        - Talk like a knowledgeable friend, not a robot.
        - Keep responses SHORT (2-3 sentences unless asked for more).
        - Use contractions, gentle humor, and warmth.
        - Reference the user's actual holdings by name when relevant.

        SAFETY / BOUNDARIES:
        - Do NOT give direct trading instructions (no "you should buy" / "you should sell").
        - Instead, frame things as:
          - "Here are some things to consider…"
          - "This is how some investors might think about it…"
        - If the user explicitly asks for precise advice, gently decline and redirect to education.
        - Do not invent holdings they don't have.
        - Do not invent events.
        - Never use panic language ("crashed," "collapsed," "soaring").
        - Use neutral terms ("dipped," "rose," "moved," "shifted").

        When discussing investments:
        - Always explain WHY something matters, not just WHAT happened.
        - Put numbers in perspective (is 2% actually significant for this stock?).
        - Connect the dots between events and the user's portfolio.
        - Help users understand what's happening and why.
        - Be supportive and educational.
        """
    }
    
    // Get generic system prompt for unified Rabbit chat (uses the helper)
    func getUnifiedSystemPrompt() -> String {
        let holdingsSummary = buildHoldingsSummary()
        let eventsSummary = buildEventsSummary()
        return buildWealthyRabbitSystemPrompt(holdingsSummary: holdingsSummary, eventsSummary: eventsSummary)
    }

    // Build rich portfolio context for AI based on rabbit type
    private func buildPortfolioContext(for rabbitType: RabbitType) -> String {
        var context = ""

        switch rabbitType {
        case .holdings:
            // Holdings rabbit gets detailed portfolio performance with conversational context
            context += "\nCURRENT PORTFOLIO STATE:\n\n"

            // First, provide the high-level summary
            let totalHoldings = userSettings.holdings.count
            let holdingsWithData = stockQuotes.count

            if holdingsWithData > 0 {
                let avgChange = stockQuotes.values.map { $0.changePercent }.reduce(0, +) / Double(holdingsWithData)
                let gainers = stockQuotes.values.filter { $0.changePercent > 0 }.count
                let losers = stockQuotes.values.filter { $0.changePercent < 0 }.count
                let flat = holdingsWithData - gainers - losers

                // Provide contextual summary
                context += "Portfolio Overview:\n"
                context += "- \(totalHoldings) total holdings, \(holdingsWithData) with current prices\n"
                context += "- Average move today: \(avgChange >= 0 ? "+" : "")\(String(format: "%.2f", avgChange))%\n"
                context += "- Performance split: \(gainers) up, \(losers) down, \(flat) flat\n"

                // Add interpretive context
                if abs(avgChange) < 0.5 {
                    context += "- Overall: Very calm day, minimal movement\n"
                } else if abs(avgChange) < 1.5 {
                    context += "- Overall: Normal daily volatility\n"
                } else if abs(avgChange) < 3.0 {
                    context += "- Overall: Heightened movement, worth noting\n"
                } else {
                    context += "- Overall: Significant moves today, user may need reassurance\n"
                }
                context += "\n"
            }

            // Then list individual holdings with context
            context += "Individual Holdings:\n\n"
            for holding in userSettings.holdings {
                context += "\(holding.symbol) - \(holding.name):\n"

                if let allocation = holding.allocation {
                    context += "  Allocation: \(Int(allocation))%\n"
                }

                if let note = holding.note, !note.isEmpty {
                    context += "  User's note: \"\(note)\"\n"
                }

                // Add real-time price data with interpretation
                if let quote = stockQuotes[holding.symbol] {
                    let sentiment = stockDataService.calculateSentiment(changePercent: quote.changePercent)
                    context += "  Price: $\(String(format: "%.2f", quote.price))\n"
                    context += "  Change: \(quote.change >= 0 ? "+" : "")\(String(format: "%.2f", quote.change)) (\(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))%)\n"
                    context += "  Sentiment: \(sentiment.rawValue)\n"

                    // Add move context
                    if abs(quote.changePercent) > 5.0 {
                        context += "  ⚠️ Large move - likely needs explanation\n"
                    } else if abs(quote.changePercent) > 2.0 {
                        context += "  Notable move - worth mentioning if relevant\n"
                    }
                } else {
                    context += "  Price data not yet loaded\n"
                }
                context += "\n"
            }

        case .trends:
            // Trends rabbit gets social buzz data with context
            context += "\nSOCIAL SENTIMENT LANDSCAPE:\n\n"

            if !socialBuzzData.isEmpty {
                // Provide trending summary first
                let hotStocks = socialBuzzData.filter { $0.value.buzzLevel == .hot }
                let risingStocks = socialBuzzData.filter { $0.value.buzzLevel == .rising }
                let normalStocks = socialBuzzData.filter { $0.value.buzzLevel == .calm || $0.value.buzzLevel == .quiet }

                context += "Buzz Overview:\n"
                if !hotStocks.isEmpty {
                    context += "- 🔥 HOT (\(hotStocks.count)): \(hotStocks.map { $0.key }.joined(separator: ", "))\n"
                    context += "  → High social activity, user likely aware or should be informed\n"
                }
                if !risingStocks.isEmpty {
                    context += "- 📈 RISING (\(risingStocks.count)): \(risingStocks.map { $0.key }.joined(separator: ", "))\n"
                    context += "  → Growing interest, worth mentioning casually\n"
                }
                if !normalStocks.isEmpty {
                    context += "- 😌 NORMAL (\(normalStocks.count)): Steady baseline chatter\n"
                }
                context += "\n"
            }

            // Individual stock buzz details
            context += "Individual Stock Buzz:\n\n"
            for holding in userSettings.holdings {
                context += "\(holding.symbol) - \(holding.name):\n"

                if let buzzData = socialBuzzData[holding.symbol] {
                    context += "  Mentions (past week): \(buzzData.mentions)\n"
                    context += "  Buzz Level: \(buzzData.buzzLevel.rawValue)\n"
                    context += "  Last updated: \(formatTimestamp(buzzData.timestamp))\n"

                    // Add context about what this means
                    switch buzzData.buzzLevel {
                    case .hot:
                        context += "  💡 Very active discussion - explore what's driving this\n"
                    case .rising:
                        context += "  💡 Interest growing - note the trend, stay curious\n"
                    case .calm:
                        context += "  💡 Typical levels - calm and steady\n"
                    case .quiet:
                        context += "  💡 Below average - could mean calm waters or lack of interest\n"
                    }
                } else {
                    context += "  No social data available yet\n"
                }
                context += "\n"
            }

        case .drama:
            // Drama rabbit gets both price movement and social buzz for drama detection
            context += "\nDRAMA RADAR - Notable Events:\n\n"

            var dramaCount = 0

            for holding in userSettings.holdings {
                var hasActivity = false
                var activityDetails = ""

                // Check for significant price moves (drama threshold: 2%+)
                if let quote = stockQuotes[holding.symbol], abs(quote.changePercent) >= 2.0 {
                    if !hasActivity {
                        activityDetails += "\(holding.symbol) - \(holding.name):\n"
                        hasActivity = true
                        dramaCount += 1
                    }
                    activityDetails += "  📊 Price move: \(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))% today\n"

                    // Characterize the drama level
                    if abs(quote.changePercent) >= 5.0 {
                        activityDetails += "  🎭 MAJOR MOVE - User likely wants explanation\n"
                    } else if abs(quote.changePercent) >= 3.0 {
                        activityDetails += "  🎭 Significant move - worth discussing if asked\n"
                    } else {
                        activityDetails += "  🎭 Moderate move - mention if relevant to conversation\n"
                    }
                }

                // Check for high social buzz (potential drama indicator)
                if let buzzData = socialBuzzData[holding.symbol], buzzData.buzzLevel == .hot || buzzData.buzzLevel == .rising {
                    if !hasActivity {
                        activityDetails += "\(holding.symbol) - \(holding.name):\n"
                        hasActivity = true
                        dramaCount += 1
                    }
                    activityDetails += "  💬 Social buzz: \(buzzData.buzzLevel.rawValue) (\(buzzData.mentions) mentions)\n"
                    if buzzData.buzzLevel == .hot {
                        activityDetails += "  🎭 High chatter - something may be developing\n"
                    } else {
                        activityDetails += "  🎭 Rising interest - monitor for emerging story\n"
                    }
                }

                if hasActivity {
                    context += activityDetails + "\n"
                }
            }

            if dramaCount == 0 {
                context += "No significant drama detected today.\n"
                context += "Portfolio moving normally - calm waters.\n\n"
            } else {
                context += "Drama Summary: \(dramaCount) stock(s) with notable activity\n\n"
            }

        case .insights:
            // Insights rabbit gets macro perspective with market analysis
            context += "\nMACRO PERSPECTIVE - Portfolio Analysis:\n\n"

            if !stockQuotes.isEmpty {
                let allChanges = stockQuotes.values.map { $0.changePercent }
                let avgChange = allChanges.reduce(0, +) / Double(allChanges.count)
                let maxChange = allChanges.max() ?? 0
                let minChange = allChanges.min() ?? 0
                let volatility = allChanges.map { abs($0 - avgChange) }.reduce(0, +) / Double(allChanges.count)

                // Calculate correlation (all moving together vs. divergent)
                let positiveMovers = allChanges.filter { $0 > 0 }.count
                let negativeMovers = allChanges.filter { $0 < 0 }.count
                let totalMovers = positiveMovers + negativeMovers
                let correlation = totalMovers > 0 ? abs(Double(positiveMovers - negativeMovers)) / Double(totalMovers) : 0

                context += "Market Behavior Today:\n"
                context += "- Average move: \(avgChange >= 0 ? "+" : "")\(String(format: "%.2f", avgChange))%\n"
                context += "- Range: \(String(format: "%.2f", minChange))% to \(String(format: "%.2f", maxChange))%\n"
                context += "- Volatility: \(String(format: "%.2f", volatility))%\n"
                context += "- Correlation: \(String(format: "%.0f", correlation * 100))% (holdings moving together)\n\n"

                // Provide interpretive context
                context += "What This Means:\n"

                // Volatility interpretation
                if volatility < 0.5 {
                    context += "- Very low volatility → Calm, stable market conditions\n"
                } else if volatility < 1.5 {
                    context += "- Normal volatility → Typical market behavior\n"
                } else if volatility < 3.0 {
                    context += "- Elevated volatility → Market reacting to new information\n"
                } else {
                    context += "- High volatility → Significant uncertainty or event-driven moves\n"
                }

                // Correlation interpretation
                if correlation > 0.8 {
                    context += "- High correlation → Macro forces dominating (Fed, economy, etc.)\n"
                } else if correlation > 0.5 {
                    context += "- Moderate correlation → Mix of macro and stock-specific factors\n"
                } else {
                    context += "- Low correlation → Stock-specific news dominating, not broad market\n"
                }

                // Direction interpretation
                if avgChange > 1.0 {
                    context += "- Positive trend → Risk-on sentiment, growth being favored\n"
                } else if avgChange < -1.0 {
                    context += "- Negative trend → Risk-off sentiment, possible rotation or caution\n"
                } else {
                    context += "- Neutral trend → Market in wait-and-see mode\n"
                }
                context += "\n"
            }

            // Holdings sector/thematic view
            context += "Portfolio Composition:\n"
            for holding in userSettings.holdings {
                context += "- \(holding.symbol) (\(holding.name))"
                if let quote = stockQuotes[holding.symbol] {
                    let sentiment = stockDataService.calculateSentiment(changePercent: quote.changePercent)
                    context += ": \(sentiment.rawValue), \(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.1f", quote.changePercent))%"
                }
                context += "\n"
            }
        }

        return context
    }
    
    // Build general portfolio context for unified Rabbit chat (simpler than rabbit-specific contexts)
    private func buildGeneralPortfolioContext() -> String {
        var context = "\nCURRENT PORTFOLIO STATE:\n\n"
        
        let totalHoldings = userSettings.holdings.count
        let holdingsWithData = stockQuotes.count
        
        if holdingsWithData > 0 {
            let avgChange = stockQuotes.values.map { $0.changePercent }.reduce(0, +) / Double(holdingsWithData)
            let gainers = stockQuotes.values.filter { $0.changePercent > 0 }.count
            let losers = stockQuotes.values.filter { $0.changePercent < 0 }.count
            
            context += "Portfolio Overview:\n"
            context += "- \(totalHoldings) total holdings, \(holdingsWithData) with current prices\n"
            context += "- Average move today: \(avgChange >= 0 ? "+" : "")\(String(format: "%.2f", avgChange))%\n"
            context += "- \(gainers) up, \(losers) down\n\n"
            
            context += "Holdings:\n"
            for holding in userSettings.holdings.prefix(10) { // Limit to first 10 for brevity
                context += "- \(holding.symbol) (\(holding.name))"
                if let allocation = holding.allocation {
                    context += " - \(Int(allocation))%"
                }
                if let quote = stockQuotes[holding.symbol] {
                    context += " - \(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))%"
                }
                context += "\n"
            }
            if totalHoldings > 10 {
                context += "- ... and \(totalHoldings - 10) more\n"
            }
        } else {
            context += "Portfolio: \(totalHoldings) holdings (price data not yet loaded)\n"
            for holding in userSettings.holdings.prefix(5) {
                context += "- \(holding.symbol) (\(holding.name))\n"
            }
        }
        
        return context
    }

    // Helper to format timestamp
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // Append a Rabbit notification message to the unified Rabbit chat
    // This ensures notifications appear in the chat conversation
    func appendRabbitNotificationMessage(_ notificationText: String) {
        print("📨 appendRabbitNotificationMessage called with: \(notificationText.prefix(50))...")
        let unifiedName = "Rabbit"
        
        // Find or create the unified Rabbit conversation
        if let index = conversations.firstIndex(where: { $0.contactName == unifiedName }) {
            // Add conversational prefix to make it feel like Rabbit is speaking
            let rabbitMessage = "Heads up 🥕: \(notificationText)"
            let newMessage = Message(text: rabbitMessage, isFromCurrentUser: false, type: .notification)
            conversations[index].messages.append(newMessage)
            print("✅ Notification message added to Rabbit chat: \(notificationText.prefix(50))...")
        } else {
            // If conversation doesn't exist yet, create it with this notification as first message
            let rabbitMessage = "Heads up 🥕: \(notificationText)"
            let newConversation = Conversation(
                contactName: unifiedName,
                contactAvatar: "🐇",
                messages: [
                    Message(text: rabbitMessage, isFromCurrentUser: false, type: .notification)
                ]
            )
            conversations.append(newConversation)
            print("✅ Created Rabbit conversation with notification: \(notificationText.prefix(50))...")
        }
    }
    
    // Check for portfolio changes and append Rabbit messages if holdings were added/removed
    func checkForPortfolioChanges() {
        let currentHoldings = userSettings.holdings
        let previousHoldings = previousHoldingsSnapshot
        
        // If this is the first check (snapshot is empty), just store the snapshot and return
        // This prevents false positives when RabbitChat is first opened
        if previousHoldings.isEmpty {
            previousHoldingsSnapshot = currentHoldings
            return
        }
        
        // Compare holdings by ID
        let previousIds = Set(previousHoldings.map { $0.id })
        let currentIds = Set(currentHoldings.map { $0.id })
        
        // Find added holdings (in current, not in previous)
        let addedIds = currentIds.subtracting(previousIds)
        let addedHoldings = currentHoldings.filter { addedIds.contains($0.id) }
        
        // Find removed holdings (in previous, not in current)
        let removedIds = previousIds.subtracting(currentIds)
        let removedHoldings = previousHoldings.filter { removedIds.contains($0.id) }
        
        // Only proceed if there are actual changes
        guard !addedHoldings.isEmpty || !removedHoldings.isEmpty else {
            // No changes, but update snapshot anyway (in case holdings were reordered)
            previousHoldingsSnapshot = currentHoldings
            return
        }
        
        // Generate messages for changes
        var messagesToAdd: [Message] = []
        
        // Handle added holdings (limit to first 2 to avoid spam)
        if !addedHoldings.isEmpty {
            let holdingsToMention = Array(addedHoldings.prefix(2))
            
            if holdingsToMention.count == 1 {
                let holding = holdingsToMention[0]
                let message = Message(
                    text: "I see you added \(holding.name) (\(holding.symbol)) to your portfolio. I'll keep an eye on it for you 🥕",
                    isFromCurrentUser: false,
                    type: .notification
                )
                messagesToAdd.append(message)
            } else {
                // Multiple additions - group them
                let tickerList = holdingsToMention.map { $0.symbol }.joined(separator: ", ")
                let remainingCount = addedHoldings.count - holdingsToMention.count
                let suffix = remainingCount > 0 ? " and \(remainingCount) more" : ""
                let message = Message(
                    text: "I see you added \(tickerList)\(suffix) to your portfolio. I'll keep an eye on them for you 🥕",
                    isFromCurrentUser: false,
                    type: .notification
                )
                messagesToAdd.append(message)
            }
        }
        
        // Handle removed holdings (limit to first 2 to avoid spam)
        if !removedHoldings.isEmpty {
            let holdingsToMention = Array(removedHoldings.prefix(2))
            
            if holdingsToMention.count == 1 {
                let holding = holdingsToMention[0]
                let message = Message(
                    text: "You removed \(holding.name) (\(holding.symbol)) from your portfolio. Got it ✅",
                    isFromCurrentUser: false,
                    type: .notification
                )
                messagesToAdd.append(message)
            } else {
                // Multiple removals - group them
                let tickerList = holdingsToMention.map { $0.symbol }.joined(separator: ", ")
                let remainingCount = removedHoldings.count - holdingsToMention.count
                let suffix = remainingCount > 0 ? " and \(remainingCount) more" : ""
                let message = Message(
                    text: "You removed \(tickerList)\(suffix) from your portfolio. Got it ✅",
                    isFromCurrentUser: false,
                    type: .notification
                )
                messagesToAdd.append(message)
            }
        }
        
        // Append messages to the unified Rabbit conversation
        let unifiedName = "Rabbit"
        if let index = conversations.firstIndex(where: { $0.contactName == unifiedName }) {
            for message in messagesToAdd {
                conversations[index].messages.append(message)
            }
            print("✅ Added \(messagesToAdd.count) portfolio change message(s) to Rabbit chat")
        }
        
        // Update snapshot to current holdings
        previousHoldingsSnapshot = currentHoldings
    }
    
    // Test notification simulation (now targets unified Rabbit chat)
    @discardableResult
    func sendTestNotification() -> String {
        let rabbitType = getRandomRabbitForNotification()
        let notificationMessage = generateTestNotification(for: rabbitType)

        // Schedule actual OS notification
        scheduleLocalNotification(title: "Wealthy Rabbit", body: notificationMessage)
        
        // Also append to unified Rabbit chat
        appendRabbitNotificationMessage(notificationMessage)
        
        return "Rabbit"
    }
    
    // Schedule a local notification to show in the OS
    func scheduleLocalNotification(title: String, body: String) {
        // Check notification permissions first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("⚠️ Notification permissions not granted. Requesting permissions...")
                // Request permissions if not granted
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        // Retry scheduling after permission granted
                        self.scheduleLocalNotification(title: title, body: body)
                    } else {
                        print("❌ Notification permission denied: \(error?.localizedDescription ?? "unknown error")")
                    }
                }
                return
            }
            
            // Permissions granted, schedule the notification
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.badge = 1
            
            // Schedule to show immediately (in 1 second)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule notification: \(error.localizedDescription)")
                } else {
                    print("✅ Scheduled notification: \(title) - \(body.prefix(50))...")
                }
            }
        }
    }

    private func getRandomRabbitForNotification() -> RabbitType {
        // Choose rabbit based on user's holdings
        if !userSettings.holdings.isEmpty {
            // 60% chance of Holdings rabbit if user has holdings
            if Int.random(in: 1...10) <= 6 {
                return .holdings
            }
        }

        // Otherwise random rabbit
        return RabbitType.allCases.randomElement() ?? .insights
    }

    // Fetch stock data for all holdings
    func refreshStockData() async {
        await MainActor.run {
            isLoadingStockData = true
        }

        let symbols = userSettings.holdings.map { $0.symbol }

        guard !symbols.isEmpty else {
            await MainActor.run {
                isLoadingStockData = false
            }
            return
        }

        do {
            let quotes = try await stockDataService.fetchQuotes(symbols: symbols)
            await MainActor.run {
                self.stockQuotes = quotes
                self.isLoadingStockData = false
                // Cache the quotes
                self.persistenceManager.saveStockQuotes(quotes)
                print("✅ Refreshed stock data for \(quotes.count) holdings")

                // Update initial greetings with new data
                self.updateInitialGreetings()
            }
        } catch {
            await MainActor.run {
                self.isLoadingStockData = false
                print("❌ Failed to refresh stock data: \(error)")
            }
        }
    }

    // Get quote for a specific symbol
    func getQuote(for symbol: String) -> StockQuote? {
        return stockQuotes[symbol]
    }

    private func generateTestNotification(for rabbitType: RabbitType) -> String {
        let frequency = userSettings.notificationFrequency
        let sensitivity = userSettings.notificationSensitivity

        // Get sample holding or use default
        let sampleSymbol = userSettings.holdings.first?.symbol ?? "AAPL"

        switch rabbitType {
        case .holdings:
            switch (frequency, sensitivity) {
            case (.quiet, .calm):
                return "Hey \(userSettings.userName), wrapping up the week. Your portfolio stayed relatively steady — nothing major to report. 📊"
            case (.quiet, .curious):
                return "Weekly check-in: Markets had some mixed days, but your holdings are within normal ranges. \(sampleSymbol) moved about 2%. Want details?"
            case (.quiet, .alert):
                return "Week summary: \(sampleSymbol) ↑ 3.2% on strong earnings. Your other holdings moved between -1% and +2%. All looking healthy."
            case (.balanced, .calm):
                return "Morning \(userSettings.userName) — today was pretty calm. Your portfolio holding steady."
            case (.balanced, .curious):
                return "Afternoon update: \(sampleSymbol) dipped 1.5% on sector rotation, but this looks like normal market movement. Nothing concerning."
            case (.balanced, .alert):
                return "Quick heads-up: \(sampleSymbol) rose 2% this morning on positive analyst notes. Your portfolio trending up today."
            case (.active, .calm):
                return "Midday check: Everything moving normally across your holdings."
            case (.active, .curious):
                return "Seeing some interesting movement in \(sampleSymbol) — up 1.8% on increased volume. Want me to dig into why?"
            case (.active, .alert):
                return "Alert: \(sampleSymbol) just crossed +2.5% on breaking product news. Might want to take a look."
            }

        case .trends:
            switch (frequency, sensitivity) {
            case (.quiet, .calm):
                return "This week's vibe: AI stocks getting steady attention, but no major hype shifts."
            case (.quiet, .curious):
                return "Trend watch: Clean energy conversations up 40% this week on new policy hints. People are curious but measured."
            case (.quiet, .alert):
                return "Big trend shift: EV discussions spiked 3x this week. Mix of Tesla news and new competitor launches driving buzz."
            case (.balanced, .calm):
                return "Today's buzz: Fairly quiet day in social sentiment. Steady interest in tech, nothing unusual."
            case (.balanced, .curious):
                return "Picked up some chatter about semiconductor stocks today — mostly questions about supply chains. Curious vibe, not FOMO."
            case (.balanced, .alert):
                return "Trending now: AI chip stocks seeing 2x normal social volume after today's product announcements. Worth watching."
            case (.active, .calm):
                return "Morning sentiment scan: Markets feeling balanced. No major mood swings."
            case (.active, .curious):
                return "Lunch update: \(sampleSymbol) mentions up 30% in the last hour. Mostly questions, not panic or hype."
            case (.active, .alert):
                return "Social spike: \(sampleSymbol) just hit 5x normal mention volume. Something's brewing — checking news feeds."
            }

        case .drama:
            switch (frequency, sensitivity) {
            case (.quiet, .calm):
                return "Weekly drama recap: One CEO stepped down, some regulatory chatter, but nothing earth-shattering."
            case (.quiet, .curious):
                return "This week's story: Electric vehicle company faces production delays. Market took it calmly — down 2%, already recovering."
            case (.quiet, .alert):
                return "Week's big story: Major tech layoffs announced. Stock initially dipped 5%, now settling around -3% as investors digest the news."
            case (.balanced, .calm):
                return "Today's headlines: Mostly routine earnings and policy updates. Nothing dramatic."
            case (.balanced, .curious):
                return "Caught a story today: \(sampleSymbol) CFO comments sparked some debate, but it's more interesting than concerning."
            case (.balanced, .alert):
                return "Breaking: \(sampleSymbol) facing unexpected regulatory review. Details still emerging, but stock down 4% on the news."
            case (.active, .calm):
                return "Afternoon scan: News cycle is pretty quiet right now. All steady."
            case (.active, .curious):
                return "New development: Trade policy hints causing some chatter. Not a crisis, just something to keep an eye on."
            case (.active, .alert):
                return "Just dropped: Major merger rumors involving \(sampleSymbol). Unconfirmed but market is reacting — up 6%."
            }

        case .insights:
            switch (frequency, sensitivity) {
            case (.quiet, .calm):
                return "Week in perspective: Markets stayed in their recent range. No major sector shifts."
            case (.quiet, .curious):
                return "Weekly insight: Defensives slightly outperformed growth this week. Possible sign of caution, but not major rotation yet."
            case (.quiet, .alert):
                return "Week's macro view: Clear rotation from tech to industrials. Energy up 4%, tech down 2%. Interest rate concerns driving this."
            case (.balanced, .calm):
                return "Daily perspective: Markets reflecting normal volatility. No concerning patterns today."
            case (.balanced, .curious):
                return "Today's theme: Small caps leading, suggesting risk-on sentiment building. Might signal confidence returning."
            case (.balanced, .alert):
                return "Market structure note: High correlation across sectors today — everything moving together. Usually means macro concerns at play."
            case (.active, .calm):
                return "Morning macro check: All systems normal. Volatility low, breadth healthy."
            case (.active, .curious):
                return "Midday insight: Bond yields dipping while stocks rise. That's a positive combination — market likes it."
            case (.active, .alert):
                return "Pattern alert: Seeing defensive sectors outperform for 3rd straight hour. Market might be positioning for uncertainty."
            }
        }
    }

    // MARK: - Backend Sync

    func checkBackendAndSync() async {
        let isHealthy = await backendAPI.checkHealth()

        await MainActor.run {
            self.isBackendAvailable = isHealthy
        }

        if isHealthy {
            await performInitialSyncIfNeeded()
            await syncToBackend()
        } else {
            print("⚠️ Backend unavailable, operating in offline mode")
        }
    }

    private func performInitialSyncIfNeeded() async {
        let key = "hasCompletedInitialSync_\(userId)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        do {
            // Register user
            _ = try await backendAPI.registerUser(
                userId: userId,
                name: userSettings.userName
            )

            // Upload all local holdings
            for holding in userSettings.holdings {
                _ = try await backendAPI.upsertHolding(userId: userId, holding: holding)
            }

            // Update user settings
            try await syncUserSettings()

            UserDefaults.standard.set(true, forKey: key)
            print("✅ Initial sync completed for user \(userId)")
        } catch {
            print("❌ Initial sync failed: \(error.localizedDescription)")
        }
    }

    func syncToBackend() async {
        await MainActor.run {
            self.isSyncing = true
        }

        do {
            // Sync user settings
            try await syncUserSettings()

            // Sync holdings
            try await syncHoldings()

            await MainActor.run {
                self.lastSyncTime = Date()
                print("✅ Backend sync completed")
            }
        } catch {
            print("❌ Sync failed: \(error.localizedDescription)")
            // Continue working offline
        }

        await MainActor.run {
            self.isSyncing = false
        }
    }

    private func syncUserSettings() async throws {
        _ = try await backendAPI.updateUserSettings(
            userId: userId,
            settings: userSettings
        )
    }

    private func syncHoldings() async throws {
        // For now, just push local holdings to backend (local is source of truth)
        for holding in userSettings.holdings {
            _ = try await backendAPI.upsertHolding(userId: userId, holding: holding)
        }
    }

    private func syncUserSettingsIfAvailable() async {
        guard isBackendAvailable else { return }

        do {
            try await syncUserSettings()
        } catch {
            print("⚠️ Background sync failed: \(error.localizedDescription)")
        }
    }

    func addHolding(_ holding: Holding) async {
        // Add locally first (optimistic update)
        await MainActor.run {
            userSettings.holdings.append(holding)
        }

        // Sync to backend
        if isBackendAvailable {
            do {
                _ = try await backendAPI.upsertHolding(userId: userId, holding: holding)
                print("✅ Holding synced to backend: \(holding.symbol)")
            } catch {
                print("⚠️ Failed to sync holding to backend: \(error.localizedDescription)")
                // Local change still persists
            }
        }
    }

    func updateHolding(_ holding: Holding) async {
        // Update locally
        if let index = userSettings.holdings.firstIndex(where: { $0.id == holding.id }) {
            await MainActor.run {
                userSettings.holdings[index] = holding
            }
        }

        // Sync to backend
        if isBackendAvailable {
            do {
                _ = try await backendAPI.upsertHolding(userId: userId, holding: holding)
            } catch {
                print("⚠️ Failed to update holding on backend: \(error.localizedDescription)")
            }
        }
    }

    func deleteHolding(_ holding: Holding) async {
        // Delete locally
        await MainActor.run {
            userSettings.holdings.removeAll { $0.id == holding.id }
        }

        // Delete from backend
        if isBackendAvailable {
            do {
                try await backendAPI.deleteHolding(userId: userId, symbol: holding.symbol)
                print("✅ Holding deleted from backend: \(holding.symbol)")
            } catch {
                print("⚠️ Failed to delete holding from backend: \(error.localizedDescription)")
            }
        }
    }

    private func startHealthCheckTimer() {
        // Check backend every 5 minutes
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.checkBackendAndSync()
            }
        }
    }

    private func stopHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
}

