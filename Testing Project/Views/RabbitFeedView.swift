import SwiftUI
import AVFoundation
import Combine

// MARK: - Rabbit Feed View
// New standalone page showing Event Cards related to user's holdings
struct RabbitFeedView: View {
    @ObservedObject var viewModel: RabbitViewModel
    @State private var readEventIds: Set<UUID> = []
    @State private var archivedEventIds: Set<UUID> = []
    @State private var dailyPodcast: DailyPodcast? = nil
    @State private var isGeneratingPodcast = false
    @StateObject private var podcastPlayer = AudioPlayerManager()
    
    // Get relevant events for the user's holdings
    private var relevantEvents: [Event] {
        viewModel.findRelevantEvents()
    }
    
    // Check if podcast exists for today
    private var hasPodcastForToday: Bool {
        guard let podcast = dailyPodcast,
              let generatedAt = podcast.generatedAt else {
            return false
        }
        return Calendar.current.isDateInToday(generatedAt)
    }
    
    // Filter out archived events and get unread count
    private var activeEvents: [Event] {
        relevantEvents.filter { !archivedEventIds.contains($0.id) }
    }
    
    private var unreadCount: Int {
        activeEvents.filter { !readEventIds.contains($0.id) }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Rabbit pattern background
                RabbitPatternBackground()
                    .ignoresSafeArea()
                
                WealthyRabbitTheme.chatBackground.opacity(0.7)
                    .ignoresSafeArea()
                
                if activeEvents.isEmpty {
                    // Empty state (also scrollable for pull-to-refresh)
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.isLoadingNews {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading news...")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                        } else {
                            Text("🐇")
                                .font(.system(size: 48))
                            Text("No news yet")
                                .font(WealthyRabbitTheme.headingFont)
                                .foregroundColor(.primary)
                            
                            if let error = viewModel.newsError {
                                Text(error)
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(WealthyRabbitTheme.warningColor)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 8)
                                Text("Pull down to refresh")
                                    .font(WealthyRabbitTheme.captionFont)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            } else {
                                Text("We're fetching the latest financial news for you. Pull down to refresh or check back in a moment.")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100) // Add some top padding for better centering
                    }
                    .refreshable {
                        // Pull to refresh - clear cache and fetch fresh news
                        NewsCache.shared.clearCache()
                        await viewModel.fetchNewsEvents(forceRefresh: true)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Daily Podcast Card (at the top)
                            DailyPodcastCard(
                                podcast: dailyPodcast,
                                hasPodcastForToday: hasPodcastForToday,
                                isGenerating: isGeneratingPodcast,
                                audioPlayer: podcastPlayer,
                                onGenerate: {
                                    generateDailyPodcast()
                                },
                                onPlay: {
                                    // Generate AI podcast using OpenAI + ElevenLabs
                                    Task {
                                        await generateAndPlayAIPodcast(events: Array(activeEvents.prefix(3)))
                                    }
                                }
                            )
                            
                            // Catchup Card (if many unread events)
                            if unreadCount >= 3 {
                                CatchupCard(unreadCount: unreadCount) {
                                    // Mark all as read
                                    readEventIds = Set(activeEvents.map { $0.id })
                                }
                            }
                            
                            // Event Cards
                            ForEach(activeEvents) { event in
                                EventCard(
                                    event: event,
                                    isRead: readEventIds.contains(event.id),
                                    onRead: {
                                        readEventIds.insert(event.id)
                                    },
                                    onArchive: {
                                        archivedEventIds.insert(event.id)
                                    },
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(.horizontal, WealthyRabbitTheme.normalSpacing)
                        .padding(.vertical, WealthyRabbitTheme.normalSpacing)
                    }
                    .refreshable {
                        // Pull to refresh - clear cache and fetch fresh news
                        NewsCache.shared.clearCache()
                        await viewModel.fetchNewsEvents(forceRefresh: true)
                    }
                }
            }
            .navigationTitle("Rabbit Feed")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Log when view appears (this ensures AudioPlayerManager is initialized)
            print("📱 RabbitFeedView appeared - AudioPlayerManager should be initialized")
            
            // Fetch news events when view appears (only if we don't have any yet)
            if viewModel.newsEvents.isEmpty && !viewModel.isLoadingNews {
                Task {
                    await viewModel.fetchNewsEvents()
                }
            }
            
            // Check if we need to generate podcast for today
            if !hasPodcastForToday && !isGeneratingPodcast {
                generateDailyPodcast()
            }
        }
    }
    
    // Generate daily podcast
    private func generateDailyPodcast() {
        isGeneratingPodcast = true
        
        // Simulate podcast generation (in real app, this would call an API)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            dailyPodcast = DailyPodcast(
                url: "https://example.com/podcast/\(Date().timeIntervalSince1970).mp3",
                generatedAt: Date()
            )
            isGeneratingPodcast = false
        }
    }
    
    // Generate and play AI podcast using OpenAI + ElevenLabs
    private func generateAndPlayAIPodcast(events: [Event]) async {
        guard !events.isEmpty else {
            let emptyScript = "Hey there! It's your Rabbit Brief for today. Not much happening in your portfolio right now, which honestly? Sometimes that's the best news. I'll keep watching and let you know if anything interesting comes up. Have a great day!"
            await MainActor.run {
                podcastPlayer.playEventExplanation(text: emptyScript)
            }
            return
        }
        
        // Generate AI podcast script using OpenAI
        let openAIService = OpenAIService(apiKey: Config.openAIAPIKey)
        
        let systemPrompt = """
        You are the Rabbit, speaking directly to the user in a friendly daily brief about their investments. When referring to yourself, say "the rabbit" or "Rabbit" - never "Wealthy Rabbit".
        You are warm, calm, wise, and conversational. Speak as if you're having a personal conversation with them.
        
        PODCAST STRUCTURE:
        1. START WITH A QUICK SUMMARY - Give a brief overview of everything happening today (2-3 sentences max). This is the "what's happening" overview.
        2. THEN GO INTO EACH EVENT IN DETAIL - For each event, explain it thoroughly without assuming prior knowledge.
        
        EXPLANATION RULES - NEVER ASSUME KNOWLEDGE:
        - Always explain what things are. For example, if you mention "cloud services," explain: "Cloud services are basically when companies rent out computing power and storage over the internet, instead of having their own servers."
        - Always explain WHY something happened. Don't just say "earnings beat expectations" - explain what led to that, what it means.
        - Always explain WHAT IT MEANS. Connect the dots - what does this event mean for the company, the sector, and the user's portfolio?
        - Answer questions that might arise naturally. Think: "What would someone ask if they heard this?" Then answer it.
        - Use analogies and simple explanations. Break down complex financial terms and concepts.
        - If you mention technical terms (like "revenue," "earnings," "guidance," "deliveries," "cloud services," "AI chips," etc.), briefly explain what they mean in simple terms.
        
        IMPORTANT RULES:
        - Speak directly as the Rabbit. Use "I" and "you" - you are talking TO them, not describing what's happening. When referring to yourself, say "the rabbit" or "Rabbit" - never "Wealthy Rabbit".
        - NO stage directions, NO music cues, NO sound effects, NO descriptive text like "[intro music fades in]" or "[pause]"
        - Only output the words you are saying, nothing else.
        - Keep it conversational and natural, like you're talking to a friend over coffee.
        - Use transitions naturally: "First up", "Next", "And finally"
        - Be calm and reassuring, never alarmist
        - Keep it to 2-4 minutes when spoken (longer is okay if you're explaining things thoroughly)
        """
        
        let eventsDescription = events.enumerated().map { index, event in
            let ticker = event.ticker ?? "Market"
            return "\(index + 1). \(ticker): \(event.title). \(event.summary)"
        }.joined(separator: "\n")
        
        let userPrompt = """
        As the Rabbit, create a daily brief for today's events. Speak directly to the user. When referring to yourself, say "the rabbit" or "Rabbit" - never "Wealthy Rabbit":
        
        \(eventsDescription)
        
        STRUCTURE:
        1. Start with a warm greeting and a QUICK SUMMARY of everything happening today (2-3 sentences giving the big picture)
        2. Then go into EACH EVENT IN DETAIL:
           - Explain what happened
           - Explain what key terms mean (don't assume they know what "cloud services," "earnings," "deliveries," etc. mean)
           - Explain WHY it happened (the context and reasons)
           - Explain WHAT IT MEANS (for the company, sector, and their portfolio)
           - Answer any questions that might naturally arise
        3. End with a friendly sign-off
        
        Remember: Never assume knowledge. Always explain things further. If you mention a concept, explain it. If you mention why something happened, explain the context. If you mention what it means, connect the dots clearly.
        Only output your spoken words. No stage directions, no music cues, no descriptions.
        """
        
        do {
            let messages = [Message(text: userPrompt, isFromCurrentUser: true)]
            var podcastScript = try await openAIService.sendMessage(conversationHistory: messages, systemPrompt: systemPrompt)
            
            // Clean up any stage directions
            podcastScript = cleanStageDirections(from: podcastScript)
            
            await MainActor.run {
                podcastPlayer.playEventExplanation(text: podcastScript)
            }
        } catch {
            print("❌ Error generating AI podcast: \(error.localizedDescription)")
            // Fallback to local script generation
            let fallbackScript = generatePodcastScript(from: events)
            await MainActor.run {
                podcastPlayer.playEventExplanation(text: fallbackScript)
            }
        }
    }
    
    // Fallback: Generate a fun, engaging podcast-style script from events (local generation)
    private func generatePodcastScript(from events: [Event]) -> String {
        guard !events.isEmpty else {
            return "Hey there! It's your Rabbit Brief for today. Not much happening in your portfolio right now, which honestly? Sometimes that's the best news. I'll keep watching and let you know if anything interesting comes up. Have a great day!"
        }
        
        var script = "Hey there! Welcome to your Daily Rabbit Brief. I'm here to break down what's happening with your investments today. "
        
        if events.count == 1 {
            let event = events[0]
            script += "So, here's the one thing I'm watching: "
            
            if let ticker = event.ticker {
                script += "\(ticker). "
            }
            
            script += "\(event.title). "
            script += "Here's what that means: \(event.summary) "
            
            // Add a fun closing
            if event.impact == .positive {
                script += "Pretty solid news, right? Nothing to stress about here. "
            } else if event.impact == .negative {
                script += "Now, don't panic. This is just one piece of the puzzle. Markets move, and that's totally normal. "
            } else {
                script += "It's one of those neutral moves that happens all the time. Nothing to lose sleep over. "
            }
        } else {
            script += "I've got \(events.count) things on my radar today. "
            
            for (index, event) in events.enumerated() {
                if index == 0 {
                    script += "First up: "
                } else if index == events.count - 1 {
                    script += "And finally: "
                } else {
                    script += "Next: "
                }
                
                if let ticker = event.ticker {
                    script += "\(ticker). "
                }
                
                script += "\(event.title). "
                
                // Add a brief, conversational summary
                let summary = event.summary
                // Make it more conversational - take first sentence or two
                let sentences = summary.components(separatedBy: ". ")
                if sentences.count > 0 {
                    script += sentences[0]
                    if sentences.count > 1 && sentences[0].count < 100 {
                        script += ". " + sentences[1]
                    }
                    script += ". "
                }
            }
            
            // Add overall sentiment
            let positiveCount = events.filter { $0.impact == .positive }.count
            let negativeCount = events.filter { $0.impact == .negative }.count
            
            if positiveCount > negativeCount {
                script += "Overall, it's looking pretty good today. "
            } else if negativeCount > positiveCount {
                script += "There's some mixed signals here, but remember - one day doesn't make a trend. "
            } else {
                script += "All in all, it's a pretty balanced day. "
            }
        }
        
        script += "That's your brief for today. I'll keep an eye on things and let you know if anything major comes up. Take care!"
        
        return script
    }
    
    // Remove stage directions and descriptive text from AI-generated content
    private func cleanStageDirections(from text: String) -> String {
        var cleaned = text
        
        // Remove common stage direction patterns
        let patterns = [
            "\\[.*?\\]",  // [anything in brackets]
            "\\(.*?pause.*?\\)",  // (pause)
            "\\(.*?music.*?\\)",  // (music)
            "intro music.*?fades",
            "music fades",
            "fades in",
            "fades out"
        ]
        
        for pattern in patterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

// MARK: - Daily Podcast Card
// Shows at the top of Rabbit Feed with daily podcast
struct DailyPodcastCard: View {
    let podcast: DailyPodcast?
    let hasPodcastForToday: Bool
    let isGenerating: Bool
    @ObservedObject var audioPlayer: AudioPlayerManager
    let onGenerate: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎧")
                    .font(.system(size: 24))
                Text("Your Daily Rabbit Brief — Podcast")
                    .font(WealthyRabbitTheme.headingFont)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating your daily brief...")
                        .font(WealthyRabbitTheme.bodyFont)
                        .foregroundColor(.secondary)
                }
            } else if hasPodcastForToday {
                Text("A personalized 2–4 minute summary of today's most important events related to your holdings.")
                    .font(WealthyRabbitTheme.bodyFont)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.stop()
                    } else {
                        onPlay()
                    }
                }) {
                    HStack {
                        if audioPlayer.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                        }
                        Text(audioPlayer.isGenerating ? "Generating..." : (audioPlayer.isPlaying ? "Pause" : "Listen now"))
                            .font(WealthyRabbitTheme.bodyFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WealthyRabbitTheme.primaryColor)
                    .cornerRadius(12)
                }
            } else {
                Text("Get a personalized 2–4 minute audio summary of today's most important events related to your holdings.")
                    .font(WealthyRabbitTheme.bodyFont)
                    .foregroundColor(.secondary)
                
                Button(action: onGenerate) {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                        Text("Generate today's podcast")
                            .font(WealthyRabbitTheme.bodyFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(WealthyRabbitTheme.primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WealthyRabbitTheme.primaryColor.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding(WealthyRabbitTheme.normalSpacing)
        .background(WealthyRabbitTheme.neutralLight.opacity(0.9))
        .cornerRadius(16)
    }
}

// MARK: - Catchup Card
// Shows when there are many unread events
struct CatchupCard: View {
    let unreadCount: Int
    let onCatchup: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📚")
                    .font(.system(size: 24))
                Text("Catch up")
                    .font(WealthyRabbitTheme.headingFont)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text("You have \(unreadCount) unread event\(unreadCount == 1 ? "" : "s"). Tap to mark all as read.")
                .font(WealthyRabbitTheme.bodyFont)
                .foregroundColor(.secondary)
            
            Button(action: onCatchup) {
                Text("Mark all as read")
                    .font(WealthyRabbitTheme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(WealthyRabbitTheme.primaryColor)
                    .cornerRadius(12)
            }
        }
        .padding(WealthyRabbitTheme.normalSpacing)
        .background(WealthyRabbitTheme.neutralLight.opacity(0.9))
        .cornerRadius(16)
    }
}

// MARK: - Event Card
// Displays a single event with headline, summary, knowledge check, and actions
struct EventCard: View {
    let event: Event
    let isRead: Bool
    let onRead: () -> Void
    let onArchive: () -> Void
    @ObservedObject var viewModel: RabbitViewModel
    @State private var showDeepDive = false
    
    // Determine card type from event
    private var cardType: String {
        let title = event.title.lowercased()
        if title.contains("earnings") || title.contains("revenue") || title.contains("profit") {
            return "Earnings"
        } else if title.contains("market") || title.contains("price") || title.contains("stock") {
            return "Market Move"
        } else if title.contains("inflation") || title.contains("gdp") || title.contains("cpi") || title.contains("fed") || event.ticker == nil {
            return "Macro Event"
        } else if title.contains("volume") || title.contains("trading") {
            return "Volume Spike"
        } else if title.contains("analyst") || title.contains("upgrade") || title.contains("downgrade") {
            return "Analyst Takes"
        } else if title.contains("social") || title.contains("sentiment") || title.contains("reddit") || title.contains("twitter") {
            return "Social Sentiment"
        } else {
            return "Market Move"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section with Logo, Title, and Card Type Badge
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Logo and Badges
                HStack(alignment: .top, spacing: 12) {
                    // Company Logo (24-32px, circular or rounded-square)
                    if let ticker = event.ticker {
                        CompanyLogoView(ticker: ticker)
                            .frame(width: 32, height: 32)
                    } else {
                        // Macro event icon
                        Image(systemName: macroIconForEvent(event))
                            .font(.system(size: 16))
                            .foregroundColor(WealthyRabbitTheme.primaryColor)
                            .frame(width: 32, height: 32)
                            .background(WealthyRabbitTheme.primaryColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Top-right: Card Type Badge + Impact Indicator
                    HStack(spacing: 8) {
                        // Card Type Badge
                        Text(cardType)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WealthyRabbitTheme.primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(WealthyRabbitTheme.secondaryColor.opacity(0.3))
                            .cornerRadius(6)
                        
                        // Impact indicator
                        ImpactIndicator(impact: event.impact, magnitude: event.magnitude)
                    }
                }
                
                // Title Section (full width, more space)
                Text(event.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(WealthyRabbitTheme.primaryColor)
                    .opacity(isRead ? 0.8 : 1.0)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(18)  // Increased padding
            
            // Divider (1px, Neutral Mid)
            Divider()
                .background(WealthyRabbitTheme.neutralMid)
                .padding(.horizontal, 18)
            
            // Summary Section (with 4-6px extra spacing)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.summary)
                    .font(WealthyRabbitTheme.bodyFont)
                    .foregroundColor(WealthyRabbitTheme.neutralDark)  // Darker, not washed out
                    .opacity(isRead ? 0.7 : 1.0)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .padding(.top, 6)  // Extra spacing after divider
            
            // Knowledge Check Section (if present)
            if event.hasKnowledgeCheck {
                // Divider
                Divider()
                    .background(WealthyRabbitTheme.neutralMid)
                    .padding(.horizontal, 18)
                
                // Knowledge Check will be rendered here
                // (Note: Knowledge Check is typically shown in Deep Dive, but if shown in card, add it here)
            }
            
            // Divider before footer
            Divider()
                .background(WealthyRabbitTheme.neutralMid)
                .padding(.horizontal, 18)
            
            // Action Footer (Improved with icons + labels)
            HStack(spacing: 0) {
                // Deep Dive Action
                Button(action: {
                    showDeepDive = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                        Text("Deep Dive")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(WealthyRabbitTheme.primaryColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)  // Minimum 44px touch target
                }
                
                // Divider between actions
                Divider()
                    .frame(height: 30)
                    .background(WealthyRabbitTheme.neutralMid)
                
                // Save Action
                Button(action: {
                    onRead()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: isRead ? "checkmark.circle.fill" : "bookmark.fill")
                            .font(.system(size: 20))
                        Text("Save")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(isRead ? WealthyRabbitTheme.primaryColor : WealthyRabbitTheme.neutralDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                
                // Divider between actions
                Divider()
                    .frame(height: 30)
                    .background(WealthyRabbitTheme.neutralMid)
                
                // Dismiss Action
                Button(action: onArchive) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                        Text("Dismiss")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(WealthyRabbitTheme.neutralDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
            }
            .padding(.vertical, 8)
        }
        .background(WealthyRabbitTheme.neutralLight)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 2)  // Soft shadow
        .onTapGesture {
            if !isRead {
                onRead()
            }
        }
        .sheet(isPresented: $showDeepDive) {
            DeepDiveView(event: event, viewModel: viewModel)
        }
    }
    
    // Helper to determine macro icon
    private func macroIconForEvent(_ event: Event) -> String {
        let title = event.title.lowercased()
        if title.contains("inflation") || title.contains("cpi") {
            return "dollarsign.circle.fill"
        } else if title.contains("gdp") {
            return "chart.bar.fill"
        } else if title.contains("fed") || title.contains("rate") {
            return "percent"
        } else {
            return "globe"
        }
    }
}

// MARK: - Company Logo View
// Displays company logo based on ticker symbol (24-32px, circular or rounded-square)
struct CompanyLogoView: View {
    let ticker: String
    
    var body: some View {
        ZStack {
            // Background (circular or rounded-square)
            Circle()
                .fill(WealthyRabbitTheme.primaryColor.opacity(0.1))
            
            // Logo or ticker initial
            Text(logoForTicker(ticker))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(WealthyRabbitTheme.primaryColor)
        }
    }
    
    private func logoForTicker(_ ticker: String) -> String {
        let upperTicker = ticker.uppercased()
        
        // Map common tickers to SF Symbols or initials
        switch upperTicker {
        case "TSLA": return "⚡"
        case "AAPL": return "🍎"
        case "MSFT": return "💻"
        case "GOOGL", "GOOG": return "🔍"
        case "AMZN": return "📦"
        case "META", "FB": return "👤"
        case "NVDA": return "🎮"
        case "NFLX": return "🎬"
        case "DIS": return "🏰"
        case "JPM": return "🏦"
        case "BAC": return "🏛️"
        case "WMT": return "🛒"
        case "JNJ": return "💊"
        case "V": return "💳"
        case "MA": return "💳"
        case "PG": return "🧴"
        case "UNH": return "🏥"
        case "HD": return "🔨"
        case "PYPL": return "💸"
        case "INTC": return "🔧"
        case "CMCSA": return "📺"
        case "PFE": return "💉"
        case "CSCO": return "🌐"
        case "PEP": return "🥤"
        case "COST": return "📊"
        case "TMO": return "🔬"
        case "AVGO": return "📡"
        case "ABBV": return "💊"
        case "WFC": return "🏦"
        default:
            // Return first letter of ticker as fallback
            return String(upperTicker.prefix(1))
        }
    }
}

// MARK: - Impact Indicator
// Shows the impact and magnitude of an event (using Success/Warning colors)
struct ImpactIndicator: View {
    let impact: EventImpact
    let magnitude: EventMagnitude
    
    var body: some View {
        HStack(spacing: 4) {
            // Impact icon (using modern spark/lightning style)
            Image(systemName: impactIcon)
                .font(.system(size: 12))
                .foregroundColor(impactColor)
            
            // Magnitude badge
            Text(magnitude.rawValue.capitalized)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(impactColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(impactColor.opacity(0.2))
                .cornerRadius(4)
        }
    }
    
    private var impactIcon: String {
        switch impact {
        case .positive: return "sparkles"  // Modern spark icon instead of arrow
        case .negative: return "exclamationmark.triangle.fill"  // Warning triangle
        case .mixed: return "arrow.left.right.circle.fill"
        }
    }
    
    private var impactColor: Color {
        switch impact {
        case .positive: return WealthyRabbitTheme.successColor  // Success green
        case .negative: return WealthyRabbitTheme.warningColor  // Warning red
        case .mixed: return WealthyRabbitTheme.primaryColor  // Primary navy
        }
    }
}


// MARK: - Audio Player Manager
// Handles text-to-speech and audio playback using ElevenLabs and OpenAI
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isGenerating = false
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    
    // Services for AI text generation and voice synthesis
    private let openAIService: OpenAIService?
    private let elevenLabsService: ElevenLabsService?
    
    override init() {
        // Initialize services if API keys are available
        if !Config.openAIAPIKey.isEmpty {
            self.openAIService = OpenAIService(apiKey: Config.openAIAPIKey)
        } else {
            self.openAIService = nil
        }
        
        // Check ElevenLabs API key
        let apiKey = Config.elevenLabsAPIKey
        print("🔍 ElevenLabs API key check: isEmpty=\(apiKey.isEmpty), length=\(apiKey.count)")
        print("🔍 ElevenLabs API key first 10 chars: \(apiKey.prefix(10))...")
        
        if !apiKey.isEmpty {
            print("✅ Initializing ElevenLabs service with API key (length: \(apiKey.count))")
            self.elevenLabsService = ElevenLabsService(apiKey: apiKey)
            print("✅ ElevenLabs service initialized successfully")
            print("✅ ElevenLabs voice ID: UGTtbzgh3HObxRjWaSpr")
        } else {
            print("⚠️ ElevenLabs API key is empty, using system TTS")
            self.elevenLabsService = nil
        }
        
        super.init()
        speechSynthesizer.delegate = self
        configureAudioSession()
    }
    
    // Configure audio session for playback
    private func configureAudioSession() {
        // Don't configure here - configure when needed to avoid conflicts
    }
    
    // Generate and play AI-generated explanation with ElevenLabs voice
    func playEventExplanation(event: Event) {
        stop()
        isGenerating = true
        
        Task {
            do {
                // Step 1: Generate AI text using OpenAI
                let aiText = try await generateAIExplanation(for: event)
                
                // Step 2: Convert to speech using ElevenLabs (or fallback to system TTS)
                await MainActor.run {
                    if self.elevenLabsService != nil {
                        print("🎙️ Using ElevenLabs for voice synthesis")
                        // Use ElevenLabs for realistic AI voice
                        Task {
                            await self.playWithElevenLabs(text: aiText)
                        }
                    } else {
                        print("⚠️ ElevenLabs service not available, using system TTS")
                        // Fallback to system text-to-speech
                        self.playWithSystemTTS(text: aiText)
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Error generating AI explanation: \(error.localizedDescription)")
                    // Fallback to reading the original text
                    self.playWithSystemTTS(text: "\(event.title). \(event.summary)")
                }
            }
        }
    }
    
    // Generate comprehensive AI story with context, sources, and signals
    func generateComprehensiveStory(for event: Event) async throws -> String {
        guard let openAI = openAIService else {
            // Fallback to original text if no OpenAI
            return "\(event.title). \(event.summary)"
        }
        
        let systemPrompt = """
        You are the Rabbit, speaking directly to the user as a friendly, calm, and wise financial companion with personality and emotion. When referring to yourself, say "the rabbit" or "Rabbit" - never "Wealthy Rabbit".
        Tell a comprehensive story about this event following this EXACT structure:
        
        1. ALWAYS START WITH A HOOK - Begin with an engaging, attention-grabbing opening line that draws the user in. Make it interesting, surprising, or thought-provoking.
        2. Naturally state what happened (the event) - DO NOT say "the title is" or mention "title" - just state it naturally
        3. Explain what happened in simple, easy-to-understand terms
        4. Explain what this means specifically for the user and their portfolio
        5. Mention where this was discussed (Reddit, analysts, media) and what people are saying about it
        6. Share a quick, interesting fun fact about a similar past event or something related
        
        CRITICAL: Write exactly as a human would speak in a smooth, natural conversational tone optimized for ElevenLabs voice synthesis.
        
        WRITING RULES FOR NATURAL SPEECH:
        1. Add subtle emotional cues (warm, curious, calm, excited, thoughtful) throughout your speech
        2. Use SHORT, VARIED sentence lengths — mix short punchy sentences with longer ones. Avoid robotic rhythm.
        3. Add natural pauses using commas, ellipses … and dashes — but don't overdo it. Use them to create breathing room.
        4. Include occasional filler words like "you know," "honestly," "actually," "so here's the thing," "I mean," but only when it fits naturally and doesn't sound forced
        5. Break up long explanations into small, digestible units — one idea per sentence or two
        6. Use rhetorical questions, light humor, and gentle emphasis (like: *really*, *especially*, *the important part is…*)
        7. Avoid overly formal or academic phrasing. Keep it real, warm, and approachable
        8. When explaining complex concepts, add analogies or small storytelling elements to keep it lively
        9. DO NOT use parenthetical emotional cues like (smiles), (pause), (thinking) - these will be read as text. Express emotion naturally through your word choice, tone, and sentence structure.
        10. Vary your pace — some sentences should be quick, others should slow down for emphasis
        
        IMPORTANT: 
        - ALWAYS start with a hook - an engaging opening line that captures attention
        - Write for speech, not reading — imagine you're actually talking to someone
        - Add emotion naturally — show excitement for positive news, concern for negative news, curiosity for interesting developments
        - Never say "title", "headline", "the title is", "here's the title" - just state the event naturally
        - Keep it concise but complete (6-8 sentences total)
        - Only output the words you are saying, nothing else. No "[intro music]", no "[fades in]", no excessive stage directions.
        """
        
        let sourcesInfo = """
        Sources & Signals:
        - \(event.sourcesSummary.redditMentions)
        - \(event.sourcesSummary.analystConsensus)
        - \(event.sourcesSummary.mediaCoverageSummary)
        - \(event.sourcesSummary.rabbitConfidence)
        """
        
        let userPrompt = """
        Event Title: \(event.title)
        Summary: \(event.summary)
        Impact: \(event.impact.rawValue)
        Magnitude: \(event.magnitude.rawValue)
        \(event.ticker != nil ? "Ticker: \(event.ticker!)" : "This is a macro event")
        
        \(sourcesInfo)
        
        As the Rabbit, tell me about this event following this EXACT structure. When referring to yourself, say "the rabbit" or "Rabbit" - never "Wealthy Rabbit":
        1. ALWAYS START WITH A HOOK - Begin with an engaging, attention-grabbing opening line that draws me in. Make it interesting, surprising, or thought-provoking.
        2. Naturally state what happened (the event) - DO NOT say "the title is" or mention "title" - just state it naturally
        3. Explain what happened in simple terms
        4. What this means for the user specifically
        5. Where this was discussed and what people are saying about it
        6. Share a quick fun fact about a similar past event
        
        Write exactly as you would speak in a natural, conversational tone. 
        Use SHORT, VARIED sentence lengths. Add natural pauses with commas, ellipses …, and dashes.
        Include occasional filler words like "you know," "honestly," "actually," "so here's the thing" when they fit naturally.
        Break up explanations into small, digestible units. Use rhetorical questions and light humor.
        Add subtle emotional cues (warm, curious, calm, excited, thoughtful) through your word choice and tone. DO NOT use parenthetical cues like (smiles) or (pause) - express emotion naturally through your words.
        Show emotion naturally - excitement for positive news, concern for negative news, curiosity for interesting developments.
        Use analogies or storytelling to explain complex concepts. Keep it real, warm, and approachable - not formal or academic.
        ALWAYS start with a hook. Never say "title" or "headline" - just state the event naturally.
        Only output your spoken words - no excessive stage directions, no music cues.
        """
        
        let messages = [
            Message(text: userPrompt, isFromCurrentUser: true)
        ]
        
        let generatedText = try await openAI.sendMessage(conversationHistory: messages, systemPrompt: systemPrompt)
        
        // Clean up any stage directions that might have slipped through
        return cleanStageDirections(from: generatedText)
    }
    
    // Generate AI text for event explanation (legacy, kept for compatibility)
    private func generateAIExplanation(for event: Event) async throws -> String {
        return try await generateComprehensiveStory(for: event)
    }
    
    // Play comprehensive event story with ElevenLabs
    func playComprehensiveEventStory(event: Event) async {
        stop()
        isGenerating = true
        
        do {
            // Generate comprehensive story
            let story = try await generateComprehensiveStory(for: event)
            
            // Play with ElevenLabs if available, otherwise system TTS
            if elevenLabsService != nil {
                await playWithElevenLabs(text: story)
            } else {
                await MainActor.run {
                    playWithSystemTTS(text: story)
                }
            }
        } catch {
            await MainActor.run {
                isGenerating = false
                print("❌ Error generating story: \(error.localizedDescription)")
                // Fallback to basic explanation
                playEventExplanation(event: event)
            }
        }
    }
    
    // Remove unwanted stage directions and emotional cues (ElevenLabs reads them as text, not instructions)
    private func cleanStageDirections(from text: String) -> String {
        var cleaned = text
        
        // Remove all parenthetical emotional cues - ElevenLabs reads these as text, not instructions
        // Remove patterns like (smiles), (pause), (thinking), (laughs softly), (gentle tone), etc.
        let emotionalCuePatterns = [
            "\\(smiles?\\)",
            "\\(pause\\)",
            "\\(thinking\\)",
            "\\(laughs? softly\\)",
            "\\(gentle tone\\)",
            "\\(chuckles?\\)",
            "\\(sighs?\\)",
            "\\(excited\\)",
            "\\(concerned\\)",
            "\\(curious\\)",
            "\\(warmly\\)",
            "\\(thoughtfully\\)"
        ]
        
        for pattern in emotionalCuePatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Remove unwanted stage direction patterns
        let unwantedPatterns = [
            "\\[.*?\\]",  // [anything in brackets]
            "\\(.*?music.*?\\)",  // (music)
            "intro music.*?fades",
            "music fades",
            "fades in",
            "fades out"
        ]
        
        for pattern in unwantedPatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Remove phrases that mention "title" or "headline" in a meta way
        let metaPhrases = [
            "the title is",
            "here's the title",
            "the headline is",
            "here's the headline",
            "the title:",
            "the headline:",
            "title:",
            "headline:"
        ]
        
        for phrase in metaPhrases {
            cleaned = cleaned.replacingOccurrences(
                of: phrase,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Clean up extra whitespace (but preserve intentional pauses)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    // Play text using ElevenLabs AI voice
    private func playWithElevenLabs(text: String) async {
        guard let elevenLabs = elevenLabsService else {
            print("⚠️ ElevenLabs service is nil, falling back to system TTS")
            await MainActor.run {
                playWithSystemTTS(text: text)
            }
            return
        }
        
        // Validate text is not empty
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            print("⚠️ Empty text provided, cannot generate speech")
            await MainActor.run {
                isGenerating = false
                isPlaying = false
            }
            return
        }
        
        print("🎙️ Generating speech with ElevenLabs for text: \(trimmedText.prefix(50))...")
        
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            
            // Generate speech with ElevenLabs
            print("📡 Calling ElevenLabs API...")
            let audioData = try await elevenLabs.generateSpeech(text: trimmedText)
            print("✅ Received audio data from ElevenLabs: \(audioData.count) bytes")
            
            // Validate audio data
            guard !audioData.isEmpty, audioData.count > 100 else {
                print("❌ Received invalid audio data from ElevenLabs (size: \(audioData.count))")
                throw NSError(domain: "AudioError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid audio data received"])
            }
            
            // Play the audio
            await MainActor.run {
                do {
                    self.audioPlayer = try AVAudioPlayer(data: audioData)
                    self.audioPlayer?.delegate = self
                    
                    guard self.audioPlayer?.prepareToPlay() == true else {
                        throw NSError(domain: "AudioError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare audio player"])
                    }
                    
                    self.isGenerating = false
                    self.isPlaying = true
                    let success = self.audioPlayer?.play() ?? false
                    if !success {
                        print("❌ Failed to start audio playback")
                        self.isPlaying = false
                    } else {
                        print("✅ Playing ElevenLabs audio successfully")
                    }
                } catch {
                    print("❌ Error creating audio player: \(error.localizedDescription)")
                    self.isGenerating = false
                    self.isPlaying = false
                    // Fallback to system TTS
                    self.playWithSystemTTS(text: trimmedText)
                }
            }
        } catch {
            await MainActor.run {
                print("❌ Error with ElevenLabs API: \(error.localizedDescription)")
                print("   Error type: \(type(of: error))")
                if let elevenLabsError = error as? ElevenLabsError {
                    print("   ElevenLabs error details: \(elevenLabsError.localizedDescription)")
                } else if let urlError = error as? URLError {
                    print("   URL Error: \(urlError.localizedDescription)")
                    print("   Code: \(urlError.code.rawValue)")
                    print("   This might be a network issue or API endpoint problem")
                } else {
                    print("   Full error: \(error)")
                }
                self.isGenerating = false
                // Fallback to system TTS
                print("🔄 Falling back to system TTS")
                self.playWithSystemTTS(text: text)
            }
        }
    }
    
    // Fallback: Play text using system text-to-speech
    private func playWithSystemTTS(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Cannot play empty text")
            isGenerating = false
            return
        }
        
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error.localizedDescription)")
        }
        
        // Use AVSpeechSynthesizer
        let utterance = AVSpeechUtterance(string: text)
        
        // Try to get an enhanced voice
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        if let enhancedVoice = availableVoices.first(where: { voice in
            guard voice.language.hasPrefix("en") else { return false }
            if #available(iOS 13.0, *) {
                return voice.name.contains("Enhanced") || voice.quality == .enhanced
            }
            return voice.name.contains("Enhanced")
        }) {
            utterance.voice = enhancedVoice
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        utterance.rate = 0.48
        utterance.pitchMultiplier = 0.95
        utterance.volume = 1.0
        
        speechSynthesizer.speak(utterance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isGenerating = false
        }
    }
    
    // Play text explanation - uses ElevenLabs if available, otherwise system TTS
    func playEventExplanation(text: String) {
        stop()
        isGenerating = true
        
        // If we have ElevenLabs, use it; otherwise use system TTS
        if elevenLabsService != nil {
            print("🎙️ Using ElevenLabs for provided text")
            Task {
                await playWithElevenLabs(text: text)
            }
        } else {
            print("⚠️ ElevenLabs not available, using system TTS")
            playWithSystemTTS(text: text)
        }
    }
    
    // Play audio from URL (for podcast)
    // Note: This is for future use when we have actual audio file URLs
    func playAudio(from url: URL) {
        stop()
        isGenerating = true
        
        Task {
            do {
                // First, verify the URL is accessible
                var request = URLRequest(url: url)
                request.timeoutInterval = 10.0
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw NSError(domain: "AudioError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                }
                
                // Verify we have data
                guard !data.isEmpty else {
                    throw NSError(domain: "AudioError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No audio data received"])
                }
                
                // Configure audio session
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                
                // Create audio player
                guard let player = try? AVAudioPlayer(data: data) else {
                    throw NSError(domain: "AudioError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unsupported audio format"])
                }
                
                audioPlayer = player
                audioPlayer?.delegate = self
                
                guard audioPlayer?.prepareToPlay() == true else {
                    throw NSError(domain: "AudioError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare audio player"])
                }
                
                await MainActor.run {
                    isGenerating = false
                    isPlaying = true
                    let success = audioPlayer?.play() ?? false
                    if !success {
                        print("❌ Failed to start audio playback")
                        self.isPlaying = false
                    }
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    isPlaying = false
                    print("❌ Error playing audio: \(error.localizedDescription)")
                    // For now, fall back to text-to-speech if URL playback fails
                    // This will be handled by the caller
                }
            }
        }
    }
    
    func stop() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        isPlaying = false
        
        // Optionally deactivate audio session when stopping
        // (We keep it active for better responsiveness)
    }
}

extension AudioPlayerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            // Ensure playing state is set when speech actually starts
            self.isPlaying = true
            self.isGenerating = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isGenerating = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Optional: Can be used to track progress
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
            print("❌ Audio playback error: \(error?.localizedDescription ?? "Unknown")")
        }
    }
}

// MARK: - Deep Dive View
// Modal showing detailed event information and optional lesson
struct DeepDiveView: View {
    let event: Event
    @ObservedObject var viewModel: RabbitViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var selectedKnowledgeOption: String? = nil
    @State private var knowledgeState: KnowledgeState = .idle
    
    enum KnowledgeState {
        case idle
        case answeredCorrect
        case answeredWrong
        case skipped
    }
    
    // Determine if knowledge check should be shown based on Rabbit Mode
    private var shouldShowKnowledgeCheck: Bool {
        let mode = viewModel.userSettings.rabbitMode
        switch mode {
        case .beginner:
            // Beginner: Show all knowledge checks
            return event.hasKnowledgeCheck
        case .smart:
            // Smart: Show knowledge checks normally
            return event.hasKnowledgeCheck
        case .focus:
            // Focus: Reduce knowledge checks (only show if event has one, but less emphasis)
            return false  // Hide knowledge checks in focus mode
        }
    }
    
    // Determine if extra context sections should be shown
    private var shouldShowExtraContext: Bool {
        let mode = viewModel.userSettings.rabbitMode
        switch mode {
        case .beginner:
            // Beginner: Show all extra context
            return true
        case .smart:
            // Smart: Show context only when needed (if lesson exists)
            return event.lesson != nil
        case .focus:
            // Focus: Minimal context
            return false
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Rabbit pattern background
                RabbitPatternBackground()
                    .ignoresSafeArea()
                
                WealthyRabbitTheme.burrowGradient.opacity(0.7)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // ============================================
                        // EVENT SECTION (always present)
                        // ============================================
                        VStack(alignment: .leading, spacing: 16) {
                            // Event title with white background
                            Text(event.title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(WealthyRabbitTheme.primaryColor)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.95))
                                .cornerRadius(12)
                            
                            // Listen button directly under title
                            Button(action: {
                                if audioPlayer.isPlaying {
                                    audioPlayer.stop()
                                } else {
                                    // Generate comprehensive AI story with context, sources, and signals
                                    Task {
                                        await audioPlayer.playComprehensiveEventStory(event: event)
                                    }
                                }
                            }) {
                                HStack {
                                    if audioPlayer.isGenerating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 20))
                                    }
                                    Text(audioPlayer.isGenerating ? "Generating..." : (audioPlayer.isPlaying ? "Pause" : "Listen to story"))
                                        .font(WealthyRabbitTheme.bodyFont)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(WealthyRabbitTheme.primaryColor)
                                .cornerRadius(12)
                            }
                            .padding(.top, 8)
                            
                            // Divider
                            Divider()
                                .background(WealthyRabbitTheme.neutralMid)
                                .padding(.vertical, 8)
                            
                            // Event explanation (1-2 paragraphs) with white background
                            Text(event.summary)
                                .font(WealthyRabbitTheme.bodyFont)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.95))
                                .cornerRadius(12)
                            
                            // Additional context paragraph with white background
                            if let ticker = event.ticker {
                                Text("This news directly affects \(ticker) and could influence short-term price movements. However, it's important to consider this in the context of your overall portfolio and investment timeline.")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.95))
                                    .cornerRadius(12)
                            }
                            
                            // Divider
                            Divider()
                                .background(WealthyRabbitTheme.neutralMid)
                                .padding(.vertical, 8)
                            
                            // Impact block
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Impact")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text("Type:")
                                        .foregroundColor(.secondary)
                                    Text(event.impact.rawValue.capitalized)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("Magnitude:")
                                        .foregroundColor(.secondary)
                                    Text(event.magnitude.rawValue.capitalized)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                            
                            // Divider
                            Divider()
                                .background(WealthyRabbitTheme.neutralMid)
                                .padding(.vertical, 8)
                            
                            // "What this means for you" paragraph
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What this means for you")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("This event may create short-term volatility in your portfolio. Remember that daily news often creates noise, and it's the long-term trends that matter most for your investments.")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                        }
                        
                        // ============================================
                        // LESSON / CONTEXT SECTION (only if lesson exists and shouldShowExtraContext)
                        // ============================================
                        if shouldShowExtraContext, let lesson = event.lesson {
                            VStack(alignment: .leading, spacing: 16) {
                                // Lesson header
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(WealthyRabbitTheme.primaryColor)
                                    Text("Learn the concept")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.95))
                                .cornerRadius(12)
                                
                                // Lesson title
                                Text(lesson.title)
                                    .font(WealthyRabbitTheme.headingFont)
                                    .foregroundColor(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.95))
                                    .cornerRadius(12)
                                
                                // Lesson summary
                                Text(lesson.summary)
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.95))
                                    .cornerRadius(12)
                                
                                // Lesson bullets
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(lesson.bullets, id: \.self) { bullet in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("•")
                                                .foregroundColor(WealthyRabbitTheme.primaryColor)
                                            Text(bullet)
                                                .font(WealthyRabbitTheme.bodyFont)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                // Difficulty badge
                                HStack {
                                    Text("Difficulty:")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(lesson.difficulty.rawValue.capitalized)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(WealthyRabbitTheme.primaryColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(WealthyRabbitTheme.primaryColor.opacity(0.1))
                                        .cornerRadius(6)
                                }
                                
                                // Knowledge Check (if exists) - inside lesson section
                                // Only show if shouldShowKnowledgeCheck is true
                                if shouldShowKnowledgeCheck, event.hasKnowledgeCheck, let question = event.knowledgeQuestion, let options = event.knowledgeOptions {
                                    KnowledgeCheckView(
                                        question: question,
                                        options: options,
                                        explanation: event.knowledgeExplanation ?? "",
                                        selectedOption: $selectedKnowledgeOption,
                                        state: $knowledgeState
                                    )
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                        }
                        
                        // Divider before sources section
                        if shouldShowExtraContext {
                            Divider()
                                .background(WealthyRabbitTheme.neutralMid)
                                .padding(.vertical, 8)
                        }
                        
                        // ============================================
                        // SOURCES & SIGNALS SECTION (only in beginner/smart mode)
                        // ============================================
                        if shouldShowExtraContext {
                            VStack(alignment: .leading, spacing: 16) {
                                // Section header
                                Text("Sources & Signals")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.95))
                                    .cornerRadius(12)
                                
                                // Sources summary items
                                VStack(alignment: .leading, spacing: 12) {
                                    // Reddit mentions
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(WealthyRabbitTheme.primaryColor)
                                        Text(event.sourcesSummary.redditMentions)
                                            .font(WealthyRabbitTheme.bodyFont)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Analyst consensus
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(WealthyRabbitTheme.primaryColor)
                                        Text(event.sourcesSummary.analystConsensus)
                                            .font(WealthyRabbitTheme.bodyFont)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Media coverage
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(WealthyRabbitTheme.primaryColor)
                                        Text(event.sourcesSummary.mediaCoverageSummary)
                                            .font(WealthyRabbitTheme.bodyFont)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Rabbit confidence
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(WealthyRabbitTheme.primaryColor)
                                        Text(event.sourcesSummary.rabbitConfidence)
                                            .font(WealthyRabbitTheme.bodyFont)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                        }
                        
                        // Divider before credibility section
                        if shouldShowExtraContext {
                            Divider()
                                .background(WealthyRabbitTheme.neutralMid)
                                .padding(.vertical, 8)
                        }
                        
                        // ============================================
                        // CREDIBILITY SNAPSHOT SECTION (only in beginner/smart mode)
                        // ============================================
                        if shouldShowExtraContext {
                            VStack(alignment: .leading, spacing: 16) {
                            // Section header
                            HStack {
                                Text("📊")
                                    .font(.system(size: 20))
                                Text("Credibility Snapshot")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.95))
                            .cornerRadius(12)
                            
                            // Credibility indicators
                            VStack(alignment: .leading, spacing: 10) {
                                // Reddit mentions count
                                Text("Mentioned \(event.credibilitySnapshot.mentionCountReddit) times on Reddit today")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                                
                                // Analyst consensus
                                Text("Analyst consensus: \(event.credibilitySnapshot.analystConsensusSummary)")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                                
                                // News outlets
                                Text("Covered by \(event.credibilitySnapshot.newsOutletCount) major outlets")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                                
                                // Forum mentions
                                Text("Discussed \(event.credibilitySnapshot.forumMentionsCount) times across market forums")
                                    .font(WealthyRabbitTheme.bodyFont)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(12)
                        }
                    }
                    .padding(WealthyRabbitTheme.normalSpacing)
                }
            }
            .navigationTitle("Deep Dive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Knowledge Check View
// Interactive knowledge check with multiple choice options
struct KnowledgeCheckView: View {
    let question: String
    let options: [KnowledgeOption]
    let explanation: String
    @Binding var selectedOption: String?
    @Binding var state: DeepDiveView.KnowledgeState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Knowledge check")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(question)
                .font(WealthyRabbitTheme.bodyFont)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options) { option in
                    Button(action: {
                        if state == .idle {
                            selectedOption = option.id
                            state = option.isCorrect ? .answeredCorrect : .answeredWrong
                        }
                    }) {
                        HStack {
                            Text(option.label)
                                .font(WealthyRabbitTheme.bodyFont)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedOption == option.id {
                                Image(systemName: option.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(option.isCorrect ? WealthyRabbitTheme.successColor : WealthyRabbitTheme.warningColor)
                            }
                        }
                        .padding()
                        .background(
                            selectedOption == option.id
                                ? (option.isCorrect ? WealthyRabbitTheme.successColor.opacity(0.1) : WealthyRabbitTheme.warningColor.opacity(0.1))
                                : WealthyRabbitTheme.neutralLight.opacity(0.6)
                        )
                        .cornerRadius(8)
                    }
                    .disabled(state != .idle)
                }
            }
            
            if state != .idle && !explanation.isEmpty {
                Text(explanation)
                    .font(WealthyRabbitTheme.bodyFont)
                    .foregroundColor(state == .answeredCorrect ? WealthyRabbitTheme.successColor : WealthyRabbitTheme.secondaryColor)
                    .padding()
                    .background(
                        (state == .answeredCorrect ? WealthyRabbitTheme.successColor : WealthyRabbitTheme.secondaryColor).opacity(0.1)
                    )
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(WealthyRabbitTheme.secondaryColor.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Rabbit Pattern Background
// Uses custom background image if available, otherwise creates a subtle repeating pattern
struct RabbitPatternBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base light background
                WealthyRabbitTheme.neutralLight
                
                // Try to load custom background image first
                if let image = UIImage(named: "RabbitPatternBackground") {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.3) // Adjust opacity as needed
                } else {
                    // Fallback: Pattern overlay (subtle) using Canvas
                    Canvas { context, size in
                        let spacing: CGFloat = 80
                        let iconSize: CGFloat = 24
                        
                        // Draw pattern across the canvas
                        for x in stride(from: 0, through: size.width + spacing, by: spacing) {
                            for y in stride(from: 0, through: size.height + spacing, by: spacing) {
                                // Alternate between rabbit and icon
                                let isRabbit = Int(x / spacing + y / spacing) % 2 == 0
                                
                                if isRabbit {
                                    // Draw simple rabbit emoji representation
                                    let rabbitText = "🐇"
                                    let text = Text(rabbitText)
                                        .font(.system(size: iconSize))
                                        .foregroundColor(WealthyRabbitTheme.primaryColor.opacity(0.08))
                                    
                                    let resolved = context.resolve(text)
                                    context.draw(resolved, at: CGPoint(x: x, y: y))
                                } else {
                                    // Draw financial icon
                                    let iconText = ["📈", "💰", "📊", "⭐"].randomElement() ?? "📈"
                                    let text = Text(iconText)
                                        .font(.system(size: iconSize))
                                        .foregroundColor(WealthyRabbitTheme.primaryColor.opacity(0.08))
                                    
                                    let resolved = context.resolve(text)
                                    context.draw(resolved, at: CGPoint(x: x, y: y))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    RabbitFeedView(viewModel: RabbitViewModel(apiKey: Config.openAIAPIKey))
}

