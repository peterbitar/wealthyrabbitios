import Foundation

// MARK: - Event Model
// Represents a market event or news item that can be referenced in Rabbit Brief
struct Event: Identifiable {
    let id: UUID
    let ticker: String?  // nil for macro events, otherwise stock ticker like "TSLA"
    let title: String
    let summary: String
    let impact: EventImpact
    let magnitude: EventMagnitude
    let createdAt: Date
    
    // Knowledge check fields
    let hasKnowledgeCheck: Bool
    let knowledgeQuestion: String?
    let knowledgeOptions: [KnowledgeOption]?
    let knowledgeExplanation: String?
    
    // Optional embedded lesson/context (only shown in Deep Dive)
    let lesson: EventLesson?
    
    // Sources & Signals summary (always present in Deep Dive)
    let sourcesSummary: SourcesSummary
    
    // Credibility snapshot (always present in Deep Dive)
    let credibilitySnapshot: CredibilitySnapshot
    
    init(
        id: UUID = UUID(),
        ticker: String?,
        title: String,
        summary: String,
        impact: EventImpact,
        magnitude: EventMagnitude,
        createdAt: Date = Date(),
        hasKnowledgeCheck: Bool = false,
        knowledgeQuestion: String? = nil,
        knowledgeOptions: [KnowledgeOption]? = nil,
        knowledgeExplanation: String? = nil,
        lesson: EventLesson? = nil,
        sourcesSummary: SourcesSummary,
        credibilitySnapshot: CredibilitySnapshot
    ) {
        self.id = id
        self.ticker = ticker
        self.title = title
        self.summary = summary
        self.impact = impact
        self.magnitude = magnitude
        self.createdAt = createdAt
        self.hasKnowledgeCheck = hasKnowledgeCheck
        self.knowledgeQuestion = knowledgeQuestion
        self.knowledgeOptions = knowledgeOptions
        self.knowledgeExplanation = knowledgeExplanation
        self.lesson = lesson
        self.sourcesSummary = sourcesSummary
        self.credibilitySnapshot = credibilitySnapshot
    }
}

// MARK: - Knowledge Option
struct KnowledgeOption: Identifiable {
    let id: String
    let label: String
    let isCorrect: Bool
}

// MARK: - Event Lesson
// Embedded lesson/context that appears in Deep Dive
struct EventLesson {
    let title: String  // e.g. "Why deliveries matter for growth stocks"
    let conceptSlug: String  // e.g. "earnings_deliveries", used internally
    let summary: String  // 2–3 sentence overview
    let bullets: [String]  // 3–5 simple key points
    let difficulty: LessonDifficulty
}

// MARK: - Sources Summary
// Human-readable summary of where the event was discussed
struct SourcesSummary {
    let redditMentions: String  // e.g. "Mentioned ~12 times on Reddit discussions today."
    let analystConsensus: String  // e.g. "Analysts see this as neutral short-term but positive long-term."
    let mediaCoverageSummary: String  // e.g. "Covered by major financial outlets like Bloomberg, Reuters, and CNBC."
    let rabbitConfidence: String  // e.g. "Rabbit confidence: Medium — event is meaningful, but not a major trend yet."
}

// MARK: - Credibility Snapshot
// High-level indicators of where information appeared across the market
struct CredibilitySnapshot {
    let mentionCountReddit: Int  // e.g. 27 mentions today
    let analystConsensusSummary: String  // e.g. "Most analysts believe this is neutral short-term, positive long-term."
    let newsOutletCount: Int  // e.g. 3 major outlets
    let forumMentionsCount: Int  // e.g. mentions on StockTwits, Twitter/X, etc.
}

// MARK: - Daily Podcast
// Daily podcast information for Rabbit Feed
struct DailyPodcast {
    let url: String?  // URL to audio file, null if not generated yet
    let generatedAt: Date?  // When podcast was generated, null if not generated
}

enum LessonDifficulty: String {
    case basic = "basic"
    case intermediate = "intermediate"
}

enum EventImpact: String {
    case positive = "positive"
    case negative = "negative"
    case mixed = "mixed"
}

enum EventMagnitude: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

// MARK: - Dummy Events Data
// Hard-coded market events for Rabbit Brief (demo data)
struct DummyEventsData {
    static let events: [Event] = [
        Event(
            ticker: "TSLA",
            title: "Tesla's delivery miss: What it really means for your portfolio",
            summary: "Tesla's Q4 deliveries came in below analyst estimates, which adds short-term pressure but doesn't change the long-term story.",
            impact: .negative,
            magnitude: .medium,
            createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
            hasKnowledgeCheck: true,
            knowledgeQuestion: "Why do delivery numbers matter more than earnings for growth stocks like Tesla?",
            knowledgeOptions: [
                KnowledgeOption(id: "1", label: "They show future revenue potential", isCorrect: true),
                KnowledgeOption(id: "2", label: "They're easier to calculate", isCorrect: false),
                KnowledgeOption(id: "3", label: "They don't matter at all", isCorrect: false)
            ],
            knowledgeExplanation: "Delivery numbers indicate future revenue potential and market demand, which investors value more than past earnings for growth companies.",
            lesson: EventLesson(
                title: "Why deliveries and guidance matter more than last quarter's EPS",
                conceptSlug: "earnings_deliveries",
                summary: "For growth stocks, forward-looking metrics like delivery numbers and guidance often matter more than backward-looking earnings. Investors care about future potential, not just past performance.",
                bullets: [
                    "Delivery numbers show real demand and future revenue potential",
                    "Guidance reveals management's confidence in the business",
                    "Growth investors prioritize momentum over historical earnings",
                    "Short-term misses can create buying opportunities if the long-term story is intact"
                ],
                difficulty: .intermediate
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Mentioned ~45 times on Reddit finance forums today, with mixed sentiment in r/stocks and r/investing.",
                analystConsensus: "Analysts view this as slightly negative short-term but manageable noise that doesn't change the long-term growth story.",
                mediaCoverageSummary: "Covered by major financial outlets including Bloomberg, Reuters, and CNBC, with focus on delivery miss implications.",
                rabbitConfidence: "Rabbit confidence: Medium — event is meaningful and widely discussed, but consensus suggests it's short-term noise rather than a trend shift."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 45,
                analystConsensusSummary: "Most analysts believe this is neutral short-term, positive long-term.",
                newsOutletCount: 3,
                forumMentionsCount: 67
            )
        ),
        Event(
            ticker: "AAPL",
            title: "Apple's new AI could drive your next upgrade cycle",
            summary: "Apple unveiled new AI capabilities in its latest software update, which could drive stronger device upgrade cycles.",
            impact: .positive,
            magnitude: .medium,
            createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
            lesson: EventLesson(
                title: "How AI features drive device upgrade cycles",
                conceptSlug: "ai_upgrade_cycles",
                summary: "When tech companies add compelling AI features, they create reasons for users to upgrade their devices. This drives revenue through both hardware sales and ecosystem engagement.",
                bullets: [
                    "New AI features often require newer hardware to run smoothly",
                    "Compelling features create FOMO (fear of missing out) among users",
                    "Upgrade cycles generate recurring revenue for tech companies",
                    "Strong upgrade cycles signal healthy product demand"
                ],
                difficulty: .basic
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Generating moderate conversation on retail forums, with ~18 mentions focusing on upgrade cycle implications.",
                analystConsensus: "Analysts see this as positive for near-term revenue, with potential to accelerate upgrade cycles in the next 12 months.",
                mediaCoverageSummary: "Picked up by 3+ major newsrooms today, including tech-focused coverage in mainstream financial media.",
                rabbitConfidence: "Rabbit confidence: High — strong agreement across sources that this is a meaningful product development with clear business implications."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 18,
                analystConsensusSummary: "Analysts view this as positive for near-term revenue with upgrade cycle potential.",
                newsOutletCount: 3,
                forumMentionsCount: 34
            )
        ),
        Event(
            ticker: nil,  // Macro event
            title: "The Fed just hinted at rate cuts—here's what that means for you",
            summary: "The Federal Reserve indicated it may consider rate cuts in the coming months if inflation continues to moderate, which could support growth stocks.",
            impact: .positive,
            magnitude: .high,
            createdAt: Date().addingTimeInterval(-10800), // 3 hours ago
            hasKnowledgeCheck: true,
            knowledgeQuestion: "How do rate cuts typically affect growth stocks vs value stocks?",
            knowledgeOptions: [
                KnowledgeOption(id: "1", label: "Growth stocks benefit more because lower rates make future earnings more valuable", isCorrect: true),
                KnowledgeOption(id: "2", label: "Value stocks benefit more because they're cheaper", isCorrect: false),
                KnowledgeOption(id: "3", label: "Both are affected equally", isCorrect: false)
            ],
            knowledgeExplanation: "Growth stocks benefit more from rate cuts because their value is based on future earnings, which become more valuable when discounted at lower rates.",
            lesson: EventLesson(
                title: "How rate cuts usually affect growth vs value stocks",
                conceptSlug: "rate_cuts_growth_value",
                summary: "When the Fed cuts interest rates, growth stocks typically benefit more than value stocks. This is because growth companies' valuations depend heavily on future earnings, which become more valuable when discounted at lower rates.",
                bullets: [
                    "Lower rates reduce the discount rate for future earnings",
                    "Growth stocks have more of their value in future earnings",
                    "Value stocks are already priced based on current earnings",
                    "Rate cuts also make borrowing cheaper, helping growth companies expand"
                ],
                difficulty: .intermediate
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Mentioned ~120+ times across Reddit finance forums today, with heavy discussion in r/stocks and r/investing about portfolio implications.",
                analystConsensus: "Analysts see this as broadly positive for growth-oriented portfolios, with most viewing rate cuts as supportive of risk assets.",
                mediaCoverageSummary: "Covered extensively by major financial outlets like Bloomberg, Reuters, CNBC, and The Wall Street Journal, with focus on market implications.",
                rabbitConfidence: "Rabbit confidence: High — this event has broad consensus across sources and represents a significant macro shift with clear market implications."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 120,
                analystConsensusSummary: "Most analysts see this as broadly positive for growth-oriented portfolios.",
                newsOutletCount: 5,
                forumMentionsCount: 234
            )
        ),
        Event(
            ticker: "NVDA",
            title: "Nvidia's earnings beat expectations—here's why it matters for tech stocks",
            summary: "Nvidia reported stronger-than-expected earnings, driven by AI chip demand. This signals continued strength in the AI infrastructure sector and could lift other tech stocks.",
            impact: .positive,
            magnitude: .high,
            createdAt: Date().addingTimeInterval(-14400), // 4 hours ago
            hasKnowledgeCheck: true,
            knowledgeQuestion: "Why do Nvidia earnings often impact the broader tech sector?",
            knowledgeOptions: [
                KnowledgeOption(id: "1", label: "Nvidia chips power many AI applications, so strong demand signals sector health", isCorrect: true),
                KnowledgeOption(id: "2", label: "Nvidia is the largest tech company", isCorrect: false),
                KnowledgeOption(id: "3", label: "It doesn't impact other tech stocks", isCorrect: false)
            ],
            knowledgeExplanation: "Nvidia's chips are foundational to AI infrastructure, so strong earnings indicate healthy demand across the AI ecosystem, which benefits related tech companies.",
            lesson: EventLesson(
                title: "How infrastructure companies signal sector health",
                conceptSlug: "infrastructure_indicators",
                summary: "Companies that provide foundational technology (like chips, cloud infrastructure, or software platforms) often serve as leading indicators for their sectors. Strong performance suggests broader sector strength.",
                bullets: [
                    "Infrastructure companies serve many other companies in their sector",
                    "Strong infrastructure demand indicates healthy sector growth",
                    "Earnings from infrastructure companies can predict sector trends",
                    "Investors watch infrastructure companies as sector barometers"
                ],
                difficulty: .intermediate
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Mentioned ~200+ times across Reddit finance forums, with heavy discussion about AI sector implications and portfolio positioning.",
                analystConsensus: "Analysts view this as very positive for the AI sector and tech stocks broadly, with many upgrading price targets.",
                mediaCoverageSummary: "Covered extensively by major financial outlets including Bloomberg, Reuters, CNBC, and The Wall Street Journal, with focus on AI sector implications.",
                rabbitConfidence: "Rabbit confidence: High — strong consensus across sources that this is a significant positive signal for the tech sector."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 200,
                analystConsensusSummary: "Analysts see this as very positive for AI sector and tech stocks broadly.",
                newsOutletCount: 5,
                forumMentionsCount: 350
            )
        ),
        Event(
            ticker: "MSFT",
            title: "Microsoft's cloud growth slows—what this means for your tech holdings",
            summary: "Microsoft reported slower cloud revenue growth than expected, which could signal broader enterprise spending caution. This might affect other cloud and enterprise software stocks.",
            impact: .negative,
            magnitude: .medium,
            createdAt: Date().addingTimeInterval(-18000), // 5 hours ago
            lesson: EventLesson(
                title: "How enterprise spending trends affect tech stocks",
                conceptSlug: "enterprise_spending_indicators",
                summary: "When large enterprise tech companies show slowing growth, it often indicates broader corporate spending caution. This can affect related companies in the enterprise software and cloud sectors.",
                bullets: [
                    "Enterprise spending is cyclical and tied to economic conditions",
                    "Large tech companies serve as indicators of corporate IT budgets",
                    "Slowing enterprise growth can signal sector-wide caution",
                    "Investors watch enterprise tech earnings for spending trends"
                ],
                difficulty: .intermediate
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Mentioned ~85 times on Reddit finance forums, with discussion about enterprise spending trends and cloud sector implications.",
                analystConsensus: "Analysts see this as slightly negative but manageable, with most viewing it as temporary enterprise spending caution rather than a trend shift.",
                mediaCoverageSummary: "Covered by major financial outlets including Bloomberg and Reuters, with focus on enterprise spending implications.",
                rabbitConfidence: "Rabbit confidence: Medium — event is meaningful but consensus suggests it's temporary caution rather than a major trend shift."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 85,
                analystConsensusSummary: "Analysts view this as slightly negative but manageable, likely temporary enterprise spending caution.",
                newsOutletCount: 3,
                forumMentionsCount: 145
            )
        ),
        Event(
            ticker: "AMZN",
            title: "Amazon's Prime Day results show strong consumer spending",
            summary: "Amazon's Prime Day sales exceeded expectations, indicating resilient consumer spending despite economic concerns. This could be positive for retail and e-commerce stocks.",
            impact: .positive,
            magnitude: .medium,
            createdAt: Date().addingTimeInterval(-21600), // 6 hours ago
            lesson: EventLesson(
                title: "How major shopping events signal consumer health",
                conceptSlug: "consumer_spending_indicators",
                summary: "Major shopping events like Prime Day, Black Friday, and holiday sales serve as indicators of consumer spending health. Strong results suggest consumer confidence and discretionary spending power.",
                bullets: [
                    "Major shopping events reflect consumer confidence",
                    "Strong sales indicate healthy discretionary spending",
                    "E-commerce events can signal broader retail trends",
                    "Investors watch shopping events for consumer health signals"
                ],
                difficulty: .basic
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Mentioned ~65 times on Reddit finance forums, with discussion about consumer spending trends and retail sector implications.",
                analystConsensus: "Analysts view this as positive for consumer spending and retail stocks, suggesting resilient consumer confidence.",
                mediaCoverageSummary: "Covered by major financial outlets including Bloomberg, Reuters, and CNBC, with focus on consumer spending implications.",
                rabbitConfidence: "Rabbit confidence: High — strong agreement that this signals healthy consumer spending and positive retail trends."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 65,
                analystConsensusSummary: "Analysts see this as positive for consumer spending and retail stocks.",
                newsOutletCount: 3,
                forumMentionsCount: 98
            )
        ),
        Event(
            ticker: nil,  // Macro event
            title: "Inflation data comes in lower than expected—here's what that means for your portfolio",
            summary: "The latest CPI data showed inflation cooling faster than economists predicted, which could support the Fed's case for rate cuts and benefit growth stocks.",
            impact: .positive,
            magnitude: .high,
            createdAt: Date().addingTimeInterval(-25200), // 7 hours ago
            hasKnowledgeCheck: true,
            knowledgeQuestion: "How does lower inflation typically affect stock prices?",
            knowledgeOptions: [
                KnowledgeOption(id: "1", label: "Lower inflation supports rate cuts, which benefit growth stocks", isCorrect: true),
                KnowledgeOption(id: "2", label: "Lower inflation always hurts stocks", isCorrect: false),
                KnowledgeOption(id: "3", label: "Inflation doesn't affect stocks", isCorrect: false)
            ],
            knowledgeExplanation: "Lower inflation allows the Fed to cut interest rates, which makes future earnings more valuable and typically benefits growth stocks more than value stocks.",
            lesson: EventLesson(
                title: "How inflation data affects Fed policy and stocks",
                conceptSlug: "inflation_fed_policy",
                summary: "Inflation data directly influences Federal Reserve interest rate decisions. Lower inflation allows for rate cuts, which typically benefit growth stocks by making future earnings more valuable.",
                bullets: [
                    "Lower inflation allows the Fed to cut interest rates",
                    "Rate cuts make future earnings more valuable",
                    "Growth stocks benefit more from rate cuts than value stocks",
                    "Inflation data is a key indicator for Fed policy direction"
                ],
                difficulty: .intermediate
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Mentioned ~150+ times across Reddit finance forums, with heavy discussion about Fed policy implications and portfolio positioning.",
                analystConsensus: "Analysts see this as very positive for growth stocks and risk assets, with most expecting the Fed to signal rate cuts ahead.",
                mediaCoverageSummary: "Covered extensively by major financial outlets including Bloomberg, Reuters, CNBC, and The Wall Street Journal, with focus on Fed policy implications.",
                rabbitConfidence: "Rabbit confidence: High — strong consensus that this supports rate cuts and benefits growth-oriented portfolios."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 150,
                analystConsensusSummary: "Analysts see this as very positive for growth stocks, expecting Fed to signal rate cuts.",
                newsOutletCount: 5,
                forumMentionsCount: 280
            )
        ),
        Event(
            ticker: "GOOGL",
            title: "Google's AI search update drives user engagement higher",
            summary: "Google's latest AI-powered search features are showing strong user engagement metrics, which could drive advertising revenue growth and support the stock price.",
            impact: .positive,
            magnitude: .medium,
            createdAt: Date().addingTimeInterval(-28800), // 8 hours ago
            lesson: EventLesson(
                title: "How product engagement metrics drive advertising revenue",
                conceptSlug: "engagement_advertising_revenue",
                summary: "For companies that rely on advertising revenue, user engagement metrics (time spent, searches, clicks) directly correlate with advertising revenue. Higher engagement means more ad impressions and higher revenue potential.",
                bullets: [
                    "User engagement drives advertising impressions",
                    "More engagement means more opportunities to show ads",
                    "AI features can increase user engagement significantly",
                    "Engagement metrics are leading indicators of ad revenue"
                ],
                difficulty: .basic
            ),
            sourcesSummary: SourcesSummary(
                redditMentions: "Mentioned ~45 times on Reddit finance forums, with discussion about AI features and advertising revenue implications.",
                analystConsensus: "Analysts view this as positive for Google's advertising revenue, with many seeing AI features as a competitive advantage.",
                mediaCoverageSummary: "Covered by major financial outlets including Bloomberg and Reuters, with focus on AI features and revenue implications.",
                rabbitConfidence: "Rabbit confidence: Medium — positive signal but still early to assess long-term revenue impact."
            ),
            credibilitySnapshot: CredibilitySnapshot(
                mentionCountReddit: 45,
                analystConsensusSummary: "Analysts see this as positive for advertising revenue, viewing AI features as competitive advantage.",
                newsOutletCount: 3,
                forumMentionsCount: 78
            )
        )
    ]
}

