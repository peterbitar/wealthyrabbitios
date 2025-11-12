# WealthyRabbit Backend - Implementation Status

## ✅ What's Complete

### Database Layer
- ✅ PostgreSQL schema (`src/database/schema.sql`)
- ✅ Database connection (`src/database/connection.js`)
- ✅ Complete data models with CRUD operations (`src/database/models.js`)

### Express API Server
- ✅ Main server setup (`src/server.js`)
- ✅ User routes (`src/routes/users.js`)
  - POST /api/users/register
  - POST /api/users/push-token
  - POST /api/users/settings
  - GET /api/users/:userId
- ✅ Holdings routes (`src/routes/holdings.js`)
  - GET /api/holdings/:userId
  - POST /api/holdings
  - DELETE /api/holdings/:userId/:symbol
  - GET /api/holdings/symbols/all
- ✅ Alerts routes (`src/routes/alerts.js`)
  - GET /api/alerts/:userId
  - GET /api/alerts/:userId/count/today

### Services
- ✅ Alpha Vantage integration (`src/services/alphaVantage.js`)
  - Quote fetching with rate limiting
  - 15-minute change calculation
  - Free tier compatible (25 req/day)

### Configuration
- ✅ package.json with all dependencies
- ✅ .env.example template
- ✅ Directory structure

## 🚧 What's Remaining

### Services to Build (~ 60 min)

#### 1. NewsAPI Service (`src/services/newsApi.js`)
```javascript
// Fetch news articles for symbols
// Filter by source tier (tier1, tier2, tier3)
// Tier 1: Reuters, FT, Bloomberg, WSJ
// Tier 2: CNBC, MarketWatch, Seeking Alpha
// Tier 3: Most reputable domains
```

#### 2. Reddit Service (`src/services/reddit.js`)
```javascript
// Poll r/stocks and r/investing
// Count symbol mentions in posts/comments
// Calculate 7-day baseline
// Detect 2-3× spikes
```

#### 3. LLM Formatter (`src/services/llm.js`)
```javascript
// Call OpenAI with strict system prompt
// NEVER generate numbers (use payload data)
// Format to 2-3 calm sentences
// Add "Show sources" button data
// Fallback to templates if LLM fails
```

#### 4. Deduplication (`src/services/deduplication.js`)
```javascript
// Generate content hash (symbol + title + url + timestamp)
// Check against alert_log
// Prevent duplicate alerts
```

#### 5. APNs Push Service (`src/services/apns.js`)
```javascript
// Apple Push Notification Service integration
// Send notifications with payload
// Handle device token validation
// Format: { type, symbol, url?, pct? }
```

#### 6. Sensitivity Utils (`src/utils/sensitivity.js`)
```javascript
// Map sensitivity → thresholds
// Zen: 3.0% price, tier1 news, 3.0× social
// Curious: 2.0% price, tier1+2 news, 2.0× social
// Alert: 1.0% price, tier1+2+3 news, 1.5× social
```

#### 7. Rate Limiter (`src/utils/rateLimiter.js`)
```javascript
// Check today's push count per user
// Max 5/day/user
// Queue overflow as digest messages
```

### Scheduled Jobs (~ 40 min)

#### 1. Price Monitor (`src/jobs/monitorPrices.js`)
```javascript
// Every 5 min (or 30-60 min for free tier):
// 1. Get all unique symbols
// 2. Fetch current quotes
// 3. Store in price_points
// 4. Calculate 15-min changes
// 5. Check thresholds per user
// 6. Generate alerts if triggered
```

#### 2. News Monitor (`src/jobs/monitorNews.js`)
```javascript
// Every 5 min:
// 1. Get all unique symbols
// 2. Fetch news from NewsAPI
// 3. Filter by source tier per user sensitivity
// 4. Check for new articles (dedup)
// 5. Generate alerts
```

#### 3. Social Monitor (`src/jobs/monitorSocial.js`)
```javascript
// Every 5 min:
// 1. Get all unique symbols
// 2. Poll Reddit (r/stocks, r/investing)
// 3. Count mentions
// 4. Compare to 7-day baseline
// 5. Detect 2-3× spikes
// 6. Generate alerts
```

#### 4. Scheduler (`src/jobs/scheduler.js`)
```javascript
const cron = require('node-cron');

// Run all monitors every 5 minutes
cron.schedule('*/5 * * * *', async () => {
  await monitorPrices();
  await monitorNews();
  await monitorSocial();
});

// Cleanup old data daily
cron.schedule('0 0 * * *', async () => {
  await cleanupOldPricePoints();
});
```

## 📱 iOS Updates Needed (~ 30 min)

### 1. Add Push Notification Capability
```swift
// In Xcode:
// - Enable Push Notifications capability
// - Add Background Modes → Remote notifications
```

### 2. Request Permission & Get Token
```swift
// Add to Testing_ProjectApp.swift
import UserNotifications

@main
struct Testing_ProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        // Send to backend: POST /api/users/push-token
        BackendAPI.shared.registerPushToken(token)
    }
}
```

### 3. Handle Notification Taps
```swift
// Deep link to appropriate rabbit chat
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Extract type, symbol from payload
        if let type = userInfo["type"] as? String {
            // Navigate to appropriate rabbit
            NotificationCenter.default.post(
                name: .openRabbitChat,
                object: nil,
                userInfo: userInfo
            )
        }

        completionHandler()
    }
}
```

### 4. Backend API Client
```swift
// BackendAPI.swift
class BackendAPI {
    static let shared = BackendAPI()
    private let baseURL = "http://localhost:3000/api"

    func registerPushToken(_ token: String) async {
        // POST /api/users/push-token
    }

    func syncHoldings(_ holdings: [Holding]) async {
        // POST /api/holdings (for each)
    }

    func syncSettings(_ settings: UserSettings) async {
        // POST /api/users/settings
    }
}
```

## 🚀 How to Complete This

### Step 1: Install Dependencies
```bash
cd backend
npm install
```

### Step 2: Setup PostgreSQL Database
```bash
# Install PostgreSQL (if not installed)
brew install postgresql
brew services start postgresql

# Create database
createdb wealthyrabbit

# Run schema
psql wealthyrabbit < src/database/schema.sql
```

### Step 3: Configure Environment
```bash
cp .env.example .env
# Edit .env with your API keys
```

### Step 4: Build Remaining Services
Complete the 7 services listed above in `src/services/` and `src/utils/`.

### Step 5: Build Scheduled Jobs
Complete the 4 job files in `src/jobs/`.

### Step 6: Test Backend
```bash
# Start server
npm run dev

# In another terminal, test endpoints
curl http://localhost:3000/health
curl -X POST http://localhost:3000/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-123","name":"Peter"}'
```

### Step 7: Run Jobs
```bash
# Start the scheduler
npm run jobs
```

### Step 8: Update iOS App
Add the 4 iOS components listed above.

### Step 9: Get API Keys

1. **Alpha Vantage**: https://www.alphavantage.co/support/#api-key (free)
2. **NewsAPI**: https://newsapi.org/register (free tier)
3. **Reddit**: https://www.reddit.com/prefs/apps (create app)
4. **APNs**: Apple Developer → Certificates → Create APNs Auth Key

## 📊 API Key Limits (Free Tiers)

- **Alpha Vantage**: 25 req/day, 5 req/min
  - With 5 holdings = 5 checks/day max
  - **Recommendation**: Check every 60 min instead of 5 min
- **NewsAPI**: 100 req/day
  - With 5 holdings = 20 checks/day OK
- **Reddit**: 60 req/min (generous)

## 🎯 Quick Win: Mock Data First

To test the system without API limits:

```javascript
// src/services/mockData.js
module.exports = {
    getMockQuote: (symbol) => ({
        symbol,
        price: 150.00 + Math.random() * 10,
        changePercent: (Math.random() - 0.5) * 4,
        volume: 1000000,
        timestamp: new Date()
    }),

    getMockNews: (symbol) => ([{
        title: `${symbol} announces new product`,
        url: 'https://example.com',
        source: 'Reuters',
        sourceTier: 'tier1',
        publishedAt: new Date()
    }]),

    getMockSocial: (symbol) => ({
        mentionCount: 42,
        baseline7day: 20,
        spike: 2.1
    })
};
```

Then build the full system with real APIs later.

## 💡 Production Checklist

- [ ] Deploy database (Railway, Supabase, etc.)
- [ ] Deploy backend (Railway, Render, Fly.io)
- [ ] Set environment variables
- [ ] Upload APNs certificate
- [ ] Test push notifications on real device
- [ ] Monitor API usage
- [ ] Set up error logging (Sentry)
- [ ] Add health check monitoring
- [ ] Configure CORS for production
- [ ] Add authentication (JWT tokens)

## 🐛 Common Issues

1. **APNs not working**: Need real device + Apple Developer account
2. **Alpha Vantage rate limits**: Use mock data or reduce frequency
3. **Database connection**: Check DATABASE_URL in .env
4. **CORS errors**: Add iOS app URL to cors whitelist

## 📚 Next Steps

1. **Today**: Build remaining 7 service files (~ 1 hour)
2. **Today**: Build 4 job files (~ 40 min)
3. **Today**: Update iOS app (~ 30 min)
4. **Tomorrow**: Test end-to-end
5. **Tomorrow**: Deploy to production
6. **Next week**: Add real APNs + test on device

## 🎓 Learning Resources

- **Alpha Vantage Docs**: https://www.alphavantage.co/documentation/
- **NewsAPI Docs**: https://newsapi.org/docs
- **Reddit API**: https://www.reddit.com/dev/api/
- **APNs Guide**: https://developer.apple.com/documentation/usernotifications
- **Node Cron**: https://www.npmjs.com/package/node-cron

---

**You've built the foundation! The hard part is done. Now it's just filling in the service implementations.**
