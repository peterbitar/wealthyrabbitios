# WealthyRabbit - "If Calm Built Bloomberg"

## 🐇 Overview

WealthyRabbit is a mindful finance app that reimagines how people stay informed about their investments. Instead of panic-inducing charts and notifications, it offers clarity through conversations with friendly AI "rabbits" - each focused on a specific financial area.

## ✨ Core Features

### 🏡 The Burrow (Home Screen)
- Displays your four AI rabbit companions as interactive tiles
- Shows personalized greeting based on time of day
- Real-time market status (when markets open/close)
- Preview of latest message from each rabbit
- Soft pastel gradient background for a calm experience

### 🐇 Four AI Rabbit Personalities

#### Holdings Rabbit 🐇
- **Focus**: Watches your portfolio and explains changes
- **Personality**: Calm, analytical, grounded
- **Color**: Mist Blue / Slate
- Tracks your specific holdings and provides context-aware insights

#### Trends Rabbit 🐇
- **Focus**: Tracks social sentiment and market hype
- **Personality**: Curious, conversational
- **Color**: Apricot / Taupe
- Identifies emerging trends without inducing FOMO

#### Drama Rabbit 🐇
- **Focus**: Explains controversies and "market gossip"
- **Personality**: Warm, engaging, storyteller
- **Color**: Terracotta / Cream
- Provides context around market news without sensationalizing

#### Insights Rabbit 🐇
- **Focus**: Macro view and sector summaries
- **Personality**: Wise, reflective, teacher-like
- **Color**: Moss Green / Linen
- Offers the 30,000-foot view of market conditions

### 💬 Intelligent Conversations
- Each rabbit has a unique AI personality powered by OpenAI GPT-3.5
- Rabbits remember conversation context
- Responses are intentionally brief (2-3 sentences) unless you ask for more
- Emotionally intelligent tone - no alarming language
- Adjusts responses based on your notification preferences

### 📊 Portfolio Management
- Add and manage your holdings
- Track allocation percentages
- Add personal notes to holdings (e.g., "core tech", "dividend play")
- Rabbits reference your specific holdings in conversations

### 🧘 Mindful Notifications ("Calm Controls")

**Frequency Slider**:
- Quiet → Weekly updates only
- Balanced → Daily summaries
- Active → Multiple updates per day

**Sensitivity Slider**:
- Calm → Only big events
- Curious → Moderate changes
- Alert → All moves

**Quick Presets**:
- 🧘 Zen - Maximum calm, minimal notifications
- 🤔 Curious - Balanced information flow
- 👀 On Edge - Stay fully informed

**Live Preview**: See example notifications as you adjust settings

### 🌙 Reflect (Coming Soon)
- Peaceful space for journaling about your investment journey
- Currently shows inspirational quotes

## 🎨 Design Philosophy

### Visual Design
- **Color Palette**: Muted pastels with low contrast
- **Typography**: SF Rounded (calm, friendly)
- **Spacing**: Airy layouts with breathing room
- **Animations**: Soft, subtle movements (gentle rabbit hops)
- **No bright red/green**: Avoids stress-inducing colors

### Interaction Design
- Calm, non-urgent tone throughout
- No panic-inducing language ("dipped" not "crashed")
- Information presented in digestible chunks
- User always in control of notification frequency

## 🏗 Technical Architecture

### File Structure
```
Testing Project/
├── RabbitModels.swift         # Core data models and rabbit types
├── RabbitViewModel.swift      # Main view model managing state
├── OpenAIService.swift        # OpenAI API integration
├── Theme.swift                # Design system and colors
├── BurrowView.swift          # Home screen
├── RabbitChatView.swift      # Individual rabbit chats
├── SettingsView.swift        # Settings and calm controls
├── HoldingsView.swift        # Portfolio management
├── ReflectView.swift         # Journal placeholder
├── ContentView.swift         # Tab navigation root
└── Config.swift              # API key configuration
```

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state management
- **OpenAI GPT-3.5**: Powers rabbit personalities
- **iOS 26.1+**: Latest iOS features

### Data Flow
1. User chats with a rabbit → RabbitChatView
2. Message sent to RabbitViewModel
3. ViewModel calls OpenAIService with:
   - Rabbit's personality system prompt
   - User settings context (holdings, preferences)
   - Conversation history
4. AI response displayed in chat
5. State updates propagate via Combine

## 🚀 Getting Started

### Prerequisites
- Xcode 26.1 or later
- OpenAI API key (from https://platform.openai.com/api-keys)
- iOS Simulator or device

### Setup
1. Open `Testing Project.xcodeproj` in Xcode
2. Your API key is already configured in `Config.swift`
3. Select a simulator (iPhone 17 Pro recommended)
4. Press Cmd+R to run

### First Use
1. App opens to The Burrow with 4 rabbits
2. Tap "Profile" to add your holdings
3. Tap any rabbit to start chatting
4. Adjust notification preferences in Profile → Mindful Notifications

## 🎯 User Experience Flow

### New User Journey
1. Opens app → sees The Burrow with welcoming rabbits
2. Each rabbit has a friendly introduction message
3. Taps Holdings Rabbit → prompted to add investments
4. Goes to Profile → Settings → adds first holding (e.g., AAPL)
5. Returns to chat → Holdings Rabbit now references their portfolio
6. Explores other rabbits to understand different perspectives
7. Adjusts Calm Controls to match their comfort level

### Daily Use
1. Opens app in morning → sees greeting and market status
2. Notices Insights Rabbit has an update
3. Reads brief market summary (30 seconds)
4. Asks follow-up question if interested
5. Checks Holdings Rabbit for portfolio status
6. Feels informed without feeling stressed

## 🔮 Future Enhancements

### Potential Features
- **Real Market Data**: Integrate live stock prices via API
- **Reflect Journal**: Full journaling feature with mood tracking
- **Voice Mode**: Talk to rabbits via voice
- **Push Notifications**: Actual system notifications
- **Broker Integration**: Connect via Plaid for automatic holdings
- **Rabbit Learning**: Rabbits learn your preferences over time
- **Group Chats**: Multiple rabbits discuss a topic together
- **Meditation Mode**: Guided breathing when markets are volatile
- **Historical Insights**: "One year ago today..." reflections

### Technical Improvements
- Persistent storage (Core Data / UserDefaults)
- iCloud sync for settings and holdings
- Background fetch for market data
- Widget support for home screen
- Apple Watch companion app

## 📐 Design System Reference

### Colors
| Name | RGB | Usage |
|------|-----|-------|
| Mist Blue | (0.7, 0.8, 0.85) | Holdings Rabbit |
| Apricot | (0.95, 0.85, 0.75) | Trends Rabbit |
| Terracotta | (0.85, 0.65, 0.55) | Drama Rabbit |
| Moss Green | (0.75, 0.82, 0.70) | Insights Rabbit |
| Cream | (0.98, 0.96, 0.93) | Backgrounds |
| Linen | (0.96, 0.94, 0.90) | Chat backgrounds |

### Typography
- **Title**: 28pt, Semibold, SF Rounded
- **Heading**: 20pt, Medium, SF Rounded
- **Body**: 15pt, Regular, SF Rounded
- **Caption**: 13pt, Regular, SF Rounded

### Spacing Scale
- Tight: 8pt
- Normal: 16pt
- Relaxed: 24pt
- Airy: 32pt

## 🔐 Privacy & Security

- All data stored locally on device
- OpenAI API calls use HTTPS
- API key stored in app (consider secure storage for production)
- No analytics or tracking
- User data never shared with third parties

## 📝 Notes for Development

### Important Considerations
1. **API Costs**: OpenAI charges per token - monitor usage
2. **Rate Limits**: Implement exponential backoff for API errors
3. **Offline Mode**: Consider cached responses when offline
4. **Accessibility**: Add VoiceOver support and dynamic type
5. **Localization**: Design system supports i18n

### Known Limitations
- Market status calculation is simplified (doesn't account for holidays)
- No actual stock price data (would need market data API)
- Rabbits don't truly learn (each conversation starts fresh)
- No data persistence (resets on app restart)

## 🎭 Rabbit Personality Guidelines

When extending or modifying rabbit behaviors, remember:

- **Keep responses short**: 2-3 sentences default
- **No alarm words**: Never use "crash", "plummet", "disaster"
- **Frame neutrally**: "dipped" not "fell", "rose" not "soared"
- **Check emotional state**: Ask "How are you feeling about this?"
- **Provide context**: Explain the "why" not just the "what"
- **Respect settings**: Adjust detail level to user preferences
- **Be consistent**: Each rabbit maintains their personality

## 🙏 Credits

Concept inspired by:
- Calm app (meditation & mindfulness)
- Bloomberg Terminal (financial data)
- Wealthsimple (approachable investing)
- Replika (AI companion conversations)

Built with care for Peter's portfolio. 🐇

---

*"The stock market is a device for transferring money from the impatient to the patient."* — Warren Buffett
