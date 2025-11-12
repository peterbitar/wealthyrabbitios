# WealthyRabbit Quick Start Guide

## 🎯 What You Just Built

A complete mindful finance app with 4 AI personalities, portfolio tracking, and customizable notifications - all with a calm, stress-free design.

## ▶️ Run It Now

```bash
1. Open Testing Project.xcodeproj in Xcode
2. Select iPhone 17 Pro simulator (or any iPhone)
3. Press Cmd+R
```

Your OpenAI API key is already configured! ✅

## 🗺️ Navigate the App

### Tab 1: Reflect 🌙
- Peaceful journal placeholder
- Shows inspirational quote
- Feature coming soon

### Tab 2: The Burrow 🏡 (Home)
- **Greeting**: "Good morning/afternoon/evening, Peter"
- **Market Status**: When markets open/close
- **4 Rabbit Tiles**: Tap any to chat
  - Holdings Rabbit (blue)
  - Trends Rabbit (apricot)
  - Drama Rabbit (terracotta)
  - Insights Rabbit (green)

### Tab 3: Profile 👤
- Change your name
- **Holdings & Accounts**: Add stocks
- **Mindful Notifications**: Control frequency/sensitivity
- Settings and preferences

## 💬 Chat with Rabbits

1. Tap any rabbit tile from The Burrow
2. Type a message (e.g., "What's happening with tech stocks?")
3. Tap send (arrow button)
4. Rabbit responds with calm, thoughtful insights
5. Chat maintains context throughout conversation

### Try These Prompts

**Holdings Rabbit:**
- "Explain my portfolio in simple terms"
- "Should I be worried about recent changes?"
- "What's the outlook for AAPL?"

**Trends Rabbit:**
- "What's trending in the market today?"
- "Are people excited about AI stocks?"
- "What sectors are getting attention?"

**Drama Rabbit:**
- "What's the latest controversy?"
- "Tell me about the Tesla news"
- "What happened with that crypto situation?"

**Insights Rabbit:**
- "Give me the 30-second market summary"
- "How's inflation affecting things?"
- "What sectors are strong right now?"

## 📊 Add Your Holdings

1. Tap **Profile** tab
2. Tap **Holdings & Accounts**
3. Tap **+** button
4. Enter:
   - Symbol (e.g., AAPL)
   - Company name (e.g., Apple)
   - Allocation % (optional, e.g., 25)
   - Note (optional, e.g., "core tech")
5. Tap **Add Holding**

Now Holdings Rabbit will reference your specific stocks!

## 🧘 Adjust Calm Controls

1. Go to **Profile** tab
2. Tap **Mindful Notifications**
3. Try the quick presets:
   - **🧘 Zen**: Minimal updates
   - **🤔 Curious**: Balanced
   - **👀 On Edge**: Stay informed
4. Or use sliders:
   - **Frequency**: Quiet → Balanced → Active
   - **Sensitivity**: Calm → Curious → Alert
5. Watch the **Preview** box update in real-time

## 🎨 Appreciate the Design

### Colors
- Soft pastels throughout
- No bright red/green (stress-inducing)
- Each rabbit has a unique accent color

### Animations
- Rabbits gently "hop" on home screen
- Smooth transitions between screens
- Calm message bubble animations

### Typography
- SF Rounded font (friendly, approachable)
- Clear hierarchy
- Easy to read

## 🧪 Test Different Scenarios

### Ask Complex Questions
"Explain the relationship between inflation and tech stocks in simple terms"

### Request More Detail
"Tell me more about that" (rabbits remember context!)

### Check Emotional Intelligence
"I'm feeling stressed about my portfolio"

### Test Different Moods
Switch between Zen/Curious/On Edge presets and notice how responses might differ

## 🐛 If Something Goes Wrong

### Build Errors
```bash
cd "/Users/peter/projects/Testing Project"
xcodebuild clean
# Then rebuild in Xcode
```

### API Not Working
- Check `Config.swift` has valid OpenAI key
- Check internet connection
- Rabbits will give friendly error messages

### UI Issues
- Try different simulators (iPhone 15, 16, 17)
- App designed for iPhone portrait mode

## 📝 Customize It

### Change Rabbit Names
Edit `RabbitType` enum in `RabbitModels.swift`

### Adjust Personalities
Modify `systemPrompt` property in `RabbitModels.swift`

### Change Colors
Edit theme in `Theme.swift`

### Modify Greetings
Update `getInitialGreeting()` in `RabbitViewModel.swift`

## 🔄 Reset Everything

The app doesn't persist data yet, so just restart it:
- Press Stop in Xcode
- Press Run again
- Fresh state!

## 📖 Learn More

- **README.md**: Quick overview and setup
- **WEALTHYRABBIT.md**: Complete documentation (60+ pages!)
- **Code Comments**: Throughout the project

## 🎓 Key Concepts

### MVVM Architecture
- **Models**: `RabbitModels.swift`, `Models.swift`
- **Views**: All `*View.swift` files
- **ViewModel**: `RabbitViewModel.swift`

### SwiftUI + Combine
- `@StateObject`: Owns the view model
- `@ObservedObject`: Observes changes
- `@Published`: Triggers UI updates
- `@State`: Local view state

### AI Integration
- System prompts define personality
- Conversation history maintains context
- User settings influence responses

## 🎉 Congratulations!

You now have a fully functional mindful finance app with:
- ✅ 4 unique AI personalities
- ✅ Portfolio tracking
- ✅ Customizable notifications
- ✅ Beautiful calm design
- ✅ Real OpenAI integration

## 🚀 Next Steps

1. **Add real holdings**: Put in your actual stocks
2. **Chat with all rabbits**: Explore different personalities
3. **Adjust settings**: Find your comfort level
4. **Read WEALTHYRABBIT.md**: Learn about future features
5. **Customize**: Make it your own!

## 💡 Pro Tips

- Holdings Rabbit is most useful with actual holdings added
- Each rabbit maintains separate conversation history
- Longer messages get more detailed responses
- App works best with natural, conversational questions
- Try asking rabbits to "explain like I'm 5"

---

**Enjoy your calm investing experience!** 🐇🕊️
