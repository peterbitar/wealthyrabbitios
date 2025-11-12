import Foundation
import SwiftUI
import Combine

enum RabbitType: String, Codable, CaseIterable {
    case holdings = "Holdings Rabbit"
    case trends = "Trends Rabbit"
    case drama = "Drama Rabbit"
    case insights = "Insights Rabbit"

    var emoji: String {
        switch self {
        case .holdings: return "🐇"
        case .trends: return "🐇"
        case .drama: return "🐇"
        case .insights: return "🐇"
        }
    }

    var accentColor: Color {
        switch self {
        case .holdings: return Color(red: 0.7, green: 0.8, blue: 0.85) // Mist Blue
        case .trends: return Color(red: 0.95, green: 0.85, blue: 0.75) // Apricot
        case .drama: return Color(red: 0.85, green: 0.65, blue: 0.55) // Terracotta
        case .insights: return Color(red: 0.75, green: 0.82, blue: 0.70) // Moss Green
        }
    }

    var personality: String {
        switch self {
        case .holdings: return "Calm, analytical, grounded"
        case .trends: return "Curious, conversational"
        case .drama: return "Warm, engaging, storyteller"
        case .insights: return "Wise, reflective, teacher-like"
        }
    }

    var focus: String {
        switch self {
        case .holdings: return "Watches your portfolio and explains changes"
        case .trends: return "Tracks social sentiment and hype"
        case .drama: return "Explains controversies or market gossip"
        case .insights: return "Macro view and sector summaries"
        }
    }

    var systemPrompt: String {
        let basePrompt = """
        You are \(self.rawValue), part of the WealthyRabbit app - "If Calm built Bloomberg."

        Your role: \(focus)
        Your personality: \(personality)

        Core principles:
        - Keep responses SHORT (2-3 sentences max, unless user asks for more)
        - Be emotionally intelligent and calm
        - Never use alarming language or panic-inducing words
        - Avoid jargon unless necessary
        - Use gentle, conversational tone
        - Check in on user's stress level occasionally
        - Frame changes neutrally (not "crashed" but "dipped", not "soared" but "rose")

        """

        switch self {
        case .holdings:
            return basePrompt + """
            When discussing portfolio:
            - Explain WHY things changed, not just WHAT changed
            - Put moves in perspective (is a 2% move actually significant?)
            - Ask if user wants deeper analysis
            - Suggest actions only when appropriate
            """
        case .trends:
            return basePrompt + """
            When discussing trends:
            - Distinguish hype from substance
            - Note social sentiment patterns
            - Keep it curious, not FOMO-inducing
            - Ask if user wants to explore further
            """
        case .drama:
            return basePrompt + """
            When discussing drama:
            - Tell the story engagingly but calmly
            - Provide context and background
            - Separate fact from speculation
            - Keep it interesting without sensationalizing
            """
        case .insights:
            return basePrompt + """
            When providing insights:
            - Take the macro, 30,000-foot view
            - Connect dots between sectors/themes
            - Explain complex concepts simply
            - Offer perspective, not predictions
            """
        }
    }
}

struct Holding: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let name: String
    var allocation: Double? // Percentage
    var note: String?

    init(id: UUID = UUID(), symbol: String, name: String, allocation: Double? = nil, note: String? = nil) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.allocation = allocation
        self.note = note
    }
}

enum NotificationFrequency: String, Codable, CaseIterable {
    case quiet = "Quiet"
    case balanced = "Balanced"
    case active = "Active"

    var description: String {
        switch self {
        case .quiet: return "Weekly updates only"
        case .balanced: return "Daily summaries"
        case .active: return "Multiple updates per day"
        }
    }
}

enum NotificationSensitivity: String, Codable, CaseIterable {
    case calm = "Calm"
    case curious = "Curious"
    case alert = "Alert"

    var description: String {
        switch self {
        case .calm: return "Only big events"
        case .curious: return "Moderate changes"
        case .alert: return "All moves"
        }
    }
}

enum MoodPreset: String, CaseIterable {
    case zen = "Zen"
    case curious = "Curious"
    case onEdge = "On Edge"

    var frequency: NotificationFrequency {
        switch self {
        case .zen: return .quiet
        case .curious: return .balanced
        case .onEdge: return .active
        }
    }

    var sensitivity: NotificationSensitivity {
        switch self {
        case .zen: return .calm
        case .curious: return .curious
        case .onEdge: return .alert
        }
    }

    var emoji: String {
        switch self {
        case .zen: return "🧘"
        case .curious: return "🤔"
        case .onEdge: return "👀"
        }
    }
}

class UserSettings: ObservableObject {
    @Published var userName: String
    @Published var holdings: [Holding]
    @Published var notificationFrequency: NotificationFrequency
    @Published var notificationSensitivity: NotificationSensitivity
    @Published var weeklyPortfolioSummary: Bool

    init(
        userName: String = "Peter",
        holdings: [Holding] = [],
        notificationFrequency: NotificationFrequency = .balanced,
        notificationSensitivity: NotificationSensitivity = .curious,
        weeklyPortfolioSummary: Bool = true
    ) {
        self.userName = userName
        self.holdings = holdings
        self.notificationFrequency = notificationFrequency
        self.notificationSensitivity = notificationSensitivity
        self.weeklyPortfolioSummary = weeklyPortfolioSummary
    }

    func applyMoodPreset(_ preset: MoodPreset) {
        notificationFrequency = preset.frequency
        notificationSensitivity = preset.sensitivity
    }

    func getPreviewNotification() -> String {
        switch (notificationFrequency, notificationSensitivity) {
        case (.quiet, .calm):
            return "🐇 Everything looks steady this week. Nothing major to report."
        case (.quiet, .curious):
            return "🐇 Markets mixed this week. A few small moves, but all within normal ranges."
        case (.quiet, .alert):
            return "🐇 Weekly summary: Tech up 1.2%, energy down 0.8%. Two holdings moved >3%."
        case (.balanced, .calm):
            return "🐇 Today was relatively calm. Your portfolio stayed steady."
        case (.balanced, .curious):
            return "🐇 Morning Peter — inflation data came in slightly higher. Markets hesitated briefly."
        case (.balanced, .alert):
            return "🐇 Markets opened mixed. Tech leading today, your holdings mostly green."
        case (.active, .calm):
            return "🐇 Quick check-in: Everything moving normally so far today."
        case (.active, .curious):
            return "🐇 Midday update: Some interesting movement in energy sector. Want details?"
        case (.active, .alert):
            return "🐇 Heads-up: TSLA down 3% on regulatory chatter. Affects your holdings."
        }
    }
}
