import Foundation
import Combine

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
    private let persistenceManager = DataPersistenceManager.shared
    private var cancellables = Set<AnyCancellable>()

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

        // Check backend and start periodic sync
        Task {
            await checkBackendAndSync()
        }
        startHealthCheckTimer()
    }

    deinit {
        stopHealthCheckTimer()
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
                            isFromCurrentUser: false
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
                        isFromCurrentUser: false
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
            let newMessage = Message(text: text, isFromCurrentUser: true)
            conversations[index].messages.append(newMessage)
        }
    }

    func addIncomingMessage(to conversation: Conversation, text: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            let newMessage = Message(text: text, isFromCurrentUser: false)
            conversations[index].messages.append(newMessage)
        }
    }

    func getAIResponse(for conversation: Conversation) async {
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
            return
        }

        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }

        let conversationHistory = conversations[conversationIndex].messages

        // Get the rabbit type and its system prompt
        let rabbitType = getRabbitType(for: conversation)
        let systemPrompt = rabbitType?.systemPrompt

        // Add context about user settings to the system prompt
        var enhancedPrompt = systemPrompt ?? ""
        if let rabbitType = rabbitType {
            enhancedPrompt += """


            User context:
            - Name: \(userSettings.userName)
            - Notification preference: \(userSettings.notificationFrequency.rawValue) / \(userSettings.notificationSensitivity.rawValue)
            - Holdings count: \(userSettings.holdings.count)

            """

            // Add detailed portfolio data if available
            if !userSettings.holdings.isEmpty {
                enhancedPrompt += buildPortfolioContext(for: rabbitType)
            }

            enhancedPrompt += """

            Adjust your tone and detail level accordingly. Reference specific data when relevant.
            """
        }

        do {
            let response = try await openAIService.sendMessage(
                conversationHistory: conversationHistory,
                systemPrompt: enhancedPrompt
            )
            await MainActor.run {
                addIncomingMessage(to: conversation, text: response)
            }
        } catch {
            await MainActor.run {
                addIncomingMessage(to: conversation, text: "I'm having trouble connecting right now. Please try again in a moment.")
            }
        }
    }

    func getConversation(for rabbitType: RabbitType) -> Conversation? {
        return conversations.first { $0.contactName == rabbitType.rawValue }
    }

    // Build rich portfolio context for AI based on rabbit type
    private func buildPortfolioContext(for rabbitType: RabbitType) -> String {
        var context = ""

        switch rabbitType {
        case .holdings:
            // Holdings rabbit gets detailed portfolio performance
            context += "PORTFOLIO DETAILS:\n"
            for holding in userSettings.holdings {
                context += "- \(holding.symbol) (\(holding.name))"
                if let allocation = holding.allocation {
                    context += " - \(Int(allocation))% allocation"
                }
                if let note = holding.note, !note.isEmpty {
                    context += " - Note: \(note)"
                }

                // Add real-time price data
                if let quote = stockQuotes[holding.symbol] {
                    let sentiment = stockDataService.calculateSentiment(changePercent: quote.changePercent)
                    context += """

                      Current: $\(String(format: "%.2f", quote.price))
                      Change: \(quote.change >= 0 ? "+" : "")\(String(format: "%.2f", quote.change)) (\(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))%)
                      Sentiment: \(sentiment.rawValue)
                    """
                }
                context += "\n"
            }

            // Add portfolio summary
            let totalHoldings = userSettings.holdings.count
            let holdingsWithData = stockQuotes.count
            if holdingsWithData > 0 {
                let avgChange = stockQuotes.values.map { $0.changePercent }.reduce(0, +) / Double(holdingsWithData)
                let gainers = stockQuotes.values.filter { $0.changePercent > 0 }.count
                let losers = stockQuotes.values.filter { $0.changePercent < 0 }.count
                context += """

                PORTFOLIO SUMMARY:
                - Total holdings: \(totalHoldings)
                - Average change: \(avgChange >= 0 ? "+" : "")\(String(format: "%.2f", avgChange))%
                - Gainers: \(gainers) | Losers: \(losers) | Flat: \(holdingsWithData - gainers - losers)
                """
            }

        case .trends:
            // Trends rabbit gets social buzz data
            context += "SOCIAL BUZZ DATA:\n"
            for holding in userSettings.holdings {
                context += "- \(holding.symbol)"

                if let buzzData = socialBuzzData[holding.symbol] {
                    context += " (\(holding.name))\n"
                    context += "  Mentions: \(buzzData.mentions) in past week\n"
                    context += "  Buzz Level: \(buzzData.buzzLevel.rawValue)\n"
                    context += "  Timestamp: \(formatTimestamp(buzzData.timestamp))\n"
                } else {
                    context += " - No social data available yet\n"
                }
            }

            // Add trending summary
            if !socialBuzzData.isEmpty {
                let hotStocks = socialBuzzData.filter { $0.value.buzzLevel == .hot }.map { $0.key }
                let risingStocks = socialBuzzData.filter { $0.value.buzzLevel == .rising }.map { $0.key }
                if !hotStocks.isEmpty || !risingStocks.isEmpty {
                    context += "\n\nTRENDING:"
                    if !hotStocks.isEmpty {
                        context += "\n- Hot: \(hotStocks.joined(separator: ", "))"
                    }
                    if !risingStocks.isEmpty {
                        context += "\n- Rising: \(risingStocks.joined(separator: ", "))"
                    }
                }
            }

        case .drama:
            // Drama rabbit gets both price movement and social buzz for context
            context += "RECENT ACTIVITY:\n"
            for holding in userSettings.holdings {
                var hasActivity = false

                // Check for significant price moves
                if let quote = stockQuotes[holding.symbol], abs(quote.changePercent) >= 2.0 {
                    if !hasActivity {
                        context += "\(holding.symbol) (\(holding.name)):\n"
                        hasActivity = true
                    }
                    context += "  Price: \(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.2f", quote.changePercent))% today\n"
                }

                // Check for high social buzz
                if let buzzData = socialBuzzData[holding.symbol], buzzData.buzzLevel == .hot || buzzData.buzzLevel == .rising {
                    if !hasActivity {
                        context += "\(holding.symbol) (\(holding.name)):\n"
                        hasActivity = true
                    }
                    context += "  Social: \(buzzData.buzzLevel.rawValue) (\(buzzData.mentions) mentions)\n"
                }
            }

        case .insights:
            // Insights rabbit gets macro overview
            context += "MACRO OVERVIEW:\n"

            if !stockQuotes.isEmpty {
                let allChanges = stockQuotes.values.map { $0.changePercent }
                let avgChange = allChanges.reduce(0, +) / Double(allChanges.count)
                let maxChange = allChanges.max() ?? 0
                let minChange = allChanges.min() ?? 0
                let volatility = allChanges.map { abs($0 - avgChange) }.reduce(0, +) / Double(allChanges.count)

                context += """
                Portfolio Performance:
                - Average move: \(avgChange >= 0 ? "+" : "")\(String(format: "%.2f", avgChange))%
                - Range: \(String(format: "%.2f", minChange))% to \(String(format: "%.2f", maxChange))%
                - Volatility: \(String(format: "%.2f", volatility))%

                """
            }

            // Add holdings overview
            context += "Holdings:\n"
            for holding in userSettings.holdings {
                context += "- \(holding.symbol)"
                if let quote = stockQuotes[holding.symbol] {
                    let sentiment = stockDataService.calculateSentiment(changePercent: quote.changePercent)
                    context += " (\(sentiment.rawValue), \(quote.changePercent >= 0 ? "+" : "")\(String(format: "%.1f", quote.changePercent))%)"
                }
                context += "\n"
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

    // Test notification simulation
    @discardableResult
    func sendTestNotification() -> String {
        let rabbitType = getRandomRabbitForNotification()
        let notificationMessage = generateTestNotification(for: rabbitType)

        // Find the conversation index directly
        if let index = conversations.firstIndex(where: { $0.contactName == rabbitType.rawValue }) {
            let newMessage = Message(text: notificationMessage, isFromCurrentUser: false)
            conversations[index].messages.append(newMessage)
            print("✅ Test notification sent to \(rabbitType.rawValue): \(notificationMessage.prefix(50))...")
            return rabbitType.rawValue
        } else {
            print("❌ Could not find conversation for \(rabbitType.rawValue)")
            return "Unknown Rabbit"
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
