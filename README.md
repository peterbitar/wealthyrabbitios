# WealthyRabbit 🐇

**"If Calm built Bloomberg"**

A mindful finance app that helps you stay informed about your investments without the stress. Chat with friendly AI "rabbits" who provide calm, emotionally intelligent financial insights.

## ✨ What Makes It Special

- **Four AI Rabbit Companions**: Each with unique personalities (Holdings, Trends, Drama, Insights)
- **Mindful Notifications**: Control frequency and sensitivity with "Calm Controls"
- **Portfolio Tracking**: Add your holdings and get personalized insights
- **Emotionally Intelligent**: No panic-inducing language, only calm explanations
- **Beautiful Design**: Soft pastels, airy spacing, gentle animations

## 🚀 Quick Start

### Prerequisites
- Xcode 26.1+
- OpenAI API key (get one at [platform.openai.com](https://platform.openai.com/api-keys))

### Setup
1. Open `Testing Project.xcodeproj` in Xcode
2. Your API key is already in `Config.swift` ✓
3. Select an iPhone simulator
4. Press **Cmd+R** to run

### First Steps
1. App opens to **The Burrow** (home screen) with 4 rabbits
2. Tap **Profile** → **Holdings & Accounts** to add your investments
3. Tap any rabbit to start a conversation
4. Adjust **Mindful Notifications** in Profile settings

## 🐇 Meet Your Rabbits

| Rabbit | Focus | Personality | Color |
|--------|-------|-------------|-------|
| 🐇 **Holdings** | Your portfolio | Calm, analytical | Mist Blue |
| 🐇 **Trends** | Market buzz | Curious, conversational | Apricot |
| 🐇 **Drama** | Market news | Warm, storyteller | Terracotta |
| 🐇 **Insights** | Macro view | Wise, teacher-like | Moss Green |

## 📱 App Structure

- **🏡 The Burrow**: Home screen with rabbit tiles
- **💬 Chats**: Talk to each rabbit individually
- **🌙 Reflect**: Journal space (coming soon)
- **👤 Profile**: Settings, holdings, calm controls

## 🎨 Design Philosophy

- Muted pastel colors (no bright red/green)
- SF Rounded typography
- Airy layouts with breathing room
- No alarming language ("dipped" not "crashed")
- Gentle animations

## 🧘 Calm Controls

### Frequency
- **Quiet**: Weekly updates
- **Balanced**: Daily summaries
- **Active**: Multiple updates/day

### Sensitivity
- **Calm**: Only big events
- **Curious**: Moderate changes
- **Alert**: All moves

### Quick Presets
- 🧘 **Zen**: Maximum calm
- 🤔 **Curious**: Balanced
- 👀 **On Edge**: Stay informed

## 💻 Technical Details

- **Language**: Swift 5.0
- **Framework**: SwiftUI + Combine
- **AI**: OpenAI GPT-4.1-mini (200k TPM rate limit)
- **Platform**: iOS 26.1+
- **Architecture**: MVVM with clean folder structure

### Project Structure

See `FOLDER_STRUCTURE.md` for detailed file organization:
- **App/** - Entry point and configuration
- **Views/** - SwiftUI views
- **ViewModels/** - Business logic
- **Models/** - Data structures
- **Services/** - API integrations
- **Pipeline/** - News processing system
- **Utils/** - Utilities and helpers

## 🔐 Privacy & Security

- All data stored locally
- No analytics or tracking
- API calls use HTTPS
- Your holdings stay on your device

⚠️ **Note**: For production, use secure storage for the API key instead of hardcoding in `Config.swift`

## 📚 Documentation

- **ARCHITECTURE.md** - News pipeline architecture and API setup
- **FOLDER_STRUCTURE.md** - File organization guide
- **backend/README.md** - Backend server documentation
- **backend/DEPLOY.md** - Deployment guide

## 🎯 Use Cases

- **Morning Check-in**: Quick market summary without overwhelm
- **Portfolio Updates**: Understand why your holdings changed
- **Learning**: Ask rabbits to explain financial concepts
- **Stress-free Investing**: Stay informed at your comfort level

## 🔮 Future Ideas

- Real market data integration
- Voice conversations with rabbits
- Full journaling in Reflect
- Push notifications
- Broker integration via Plaid
- Apple Watch app

---

**Built with calm for mindful investors** 🐇🕊️
