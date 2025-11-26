# WealthyRabbit Backend Server

Real-time monitoring system for stock prices, news, and social buzz with calm, mindful notifications.

## 🏗️ Architecture

```
Express API Server (Node.js)
├── REST API endpoints for iOS app
├── PostgreSQL database for data persistence
├── Scheduled jobs (every 5 min) for monitoring
├── Alpha Vantage integration (stock prices)
├── NewsAPI integration (financial news)
├── Reddit API integration (social sentiment)
├── OpenAI integration (calm message formatting)
└── APNs service (push notifications)
```

## ✅ What's Implemented

### Core Infrastructure
- ✅ PostgreSQL database schema with 6 tables
- ✅ Express API server with CORS and error handling
- ✅ Complete data models and database operations
- ✅ Environment configuration with .env

### API Endpoints
- ✅ **Users**: Register, update push tokens, manage settings
- ✅ **Holdings**: Add, update, delete, list user holdings
- ✅ **Alerts**: View alert history and daily counts

### Services
- ✅ **Alpha Vantage**: Stock quote fetching with rate limiting
- ✅ **LLM Formatter**: OpenAI integration with strict guardrails
- ✅ **Deduplication**: Content hashing to prevent duplicate alerts
- ✅ **Sensitivity**: Threshold mappings (Zen/Curious/Alert)
- ✅ **Rate Limiter**: 5 pushes/day/user maximum

### Monitoring Jobs
- ✅ **Price Monitor**: Example implementation showing full pattern

### Still To Build
- ⏳ NewsAPI service
- ⏳ Reddit API service
- ⏳ News monitoring job
- ⏳ Social monitoring job
- ⏳ Job scheduler
- ⏳ APNs push notification service

## 🚀 Quick Start

### Automated Setup (Recommended)

```bash
cd backend
npm run setup  # Checks/installs PostgreSQL, creates DB, loads schema
npm run test-apis  # Test your API keys
npm run dev  # Start server
```

### Manual Setup

### 1. Prerequisites

```bash
# Install Node.js 18+
node --version  # Should be 18+

# Install PostgreSQL
brew install postgresql@15
brew services start postgresql@15

# Verify installation
psql --version
```

### 2. Setup Database

```bash
# Create database
createdb wealthyrabbit

# Run schema
psql wealthyrabbit < src/database/schema.sql

# Verify
psql wealthyrabbit -c "SELECT * FROM app_user;"
```

### 3. Install Dependencies

```bash
cd backend
npm install
```

### 4. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your API keys
nano .env
```

Required API keys:
- **DATABASE_URL**: `postgresql://username:password@localhost:5432/wealthyrabbit`
- **ALPHA_VANTAGE_API_KEY**: Get from https://www.alphavantage.co/support/#api-key
- **NEWS_API_KEY**: Get from https://newsapi.org/register
- **OPENAI_API_KEY**: Already have ✅

### 5. Start Server

```bash
# Development mode (auto-reload)
npm run dev

# Production mode
npm start
```

Server runs on `http://localhost:3000`

### 6. Test API

```bash
# Health check
curl http://localhost:3000/health

# Register a user
curl -X POST http://localhost:3000/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-123","name":"Peter"}'

# Add a holding
curl -X POST http://localhost:3000/api/holdings \
  -H "Content-Type: application/json" \
  -d '{"userId":"test-123","symbol":"AAPL","name":"Apple Inc.","allocation":25}'

# Get holdings
curl http://localhost:3000/api/holdings/test-123
```

## 📊 API Reference

### Users

#### Register User
```http
POST /api/users/register
Content-Type: application/json

{
  "userId": "uuid-from-ios",
  "name": "Peter",
  "pushToken": "optional-apns-token"
}
```

#### Update Push Token
```http
POST /api/users/push-token
Content-Type: application/json

{
  "userId": "uuid-from-ios",
  "pushToken": "apns-device-token"
}
```

#### Update Settings
```http
POST /api/users/settings
Content-Type: application/json

{
  "userId": "uuid-from-ios",
  "notificationFrequency": "balanced",  // quiet, balanced, active
  "notificationSensitivity": "curious",  // calm, curious, alert
  "weeklySubmary": true
}
```

### Holdings

#### Get User Holdings
```http
GET /api/holdings/:userId
```

#### Add/Update Holding
```http
POST /api/holdings
Content-Type: application/json

{
  "userId": "uuid-from-ios",
  "symbol": "AAPL",
  "name": "Apple Inc.",
  "allocation": 25.0,
  "note": "Core tech holding"
}
```

#### Delete Holding
```http
DELETE /api/holdings/:userId/:symbol
```

### Alerts

#### Get Alert History
```http
GET /api/alerts/:userId?limit=50
```

#### Get Today's Count
```http
GET /api/alerts/:userId/count/today
```

## 🔨 Completing the Implementation

### Step 1: Build NewsAPI Service

Create `src/services/newsApi.js`:

```javascript
const axios = require('axios');
const { getSourceTier } = require('../utils/sensitivity');

class NewsAPIService {
    constructor() {
        this.apiKey = process.env.NEWS_API_KEY;
        this.endpoint = 'https://newsapi.org/v2/everything';
    }

    async fetchNews(symbol, hoursAgo = 24) {
        const from = new Date(Date.now() - hoursAgo * 60 * 60 * 1000).toISOString();

        const response = await axios.get(this.endpoint, {
            params: {
                q: symbol,
                from: from,
                language: 'en',
                sortBy: 'publishedAt',
                apiKey: this.apiKey
            }
        });

        return response.data.articles.map(article => ({
            title: article.title,
            url: article.url,
            source: article.source.name,
            sourceTier: getSourceTier(article.url),
            publishedAt: article.publishedAt,
            description: article.description
        }));
    }
}

module.exports = new NewsAPIService();
```

### Step 2: Build Reddit Service

Create `src/services/reddit.js`:

```javascript
const axios = require('axios');

class RedditService {
    async searchMentions(symbol, subreddit = 'stocks+investing') {
        const url = `https://www.reddit.com/r/${subreddit}/search.json`;

        const response = await axios.get(url, {
            params: {
                q: symbol,
                t: 'hour',  // Last hour
                sort: 'hot',
                limit: 100
            },
            headers: {
                'User-Agent': 'WealthyRabbit/1.0'
            }
        });

        const posts = response.data.data.children;
        let count = 0;
        const topPosts = [];

        posts.forEach(post => {
            const data = post.data;
            if (data.title.toUpperCase().includes(symbol)) {
                count++;
                topPosts.push({
                    title: data.title,
                    url: `https://reddit.com${data.permalink}`,
                    score: data.score
                });
            }
        });

        return {
            count,
            topPosts: topPosts.sort((a, b) => b.score - a.score).slice(0, 3)
        };
    }
}

module.exports = new RedditService();
```

### Step 3: Build APNs Service

Create `src/services/apns.js`:

```javascript
const apn = require('apn');
const path = require('path');

class APNsService {
    constructor() {
        this.provider = new apn.Provider({
            token: {
                key: path.join(__dirname, '../../certs', process.env.APNS_KEY_PATH),
                keyId: process.env.APNS_KEY_ID,
                teamId: process.env.APNS_TEAM_ID
            },
            production: process.env.APNS_PRODUCTION === 'true'
        });
    }

    async sendNotification(deviceToken, payload) {
        const notification = new apn.Notification();

        notification.alert = {
            title: payload.title,
            body: payload.body
        };

        notification.badge = 1;
        notification.sound = 'default';
        notification.topic = 'com.wealthyrabbit.app';  // Your bundle ID
        notification.payload = payload.data;

        const result = await this.provider.send(notification, deviceToken);

        if (result.failed.length > 0) {
            console.error('APNs failed:', result.failed);
        }

        return result;
    }
}

module.exports = new APNsService();
```

### Step 4: Build Remaining Monitoring Jobs

Copy pattern from `src/jobs/monitorPrices.js` to create:
- `src/jobs/monitorNews.js`
- `src/jobs/monitorSocial.js`

### Step 5: Build Scheduler

Create `src/jobs/scheduler.js`:

```javascript
const cron = require('node-cron');
const monitorPrices = require('./monitorPrices');
// const monitorNews = require('./monitorNews');
// const monitorSocial = require('./monitorSocial');

console.log('🐇 WealthyRabbit Job Scheduler starting...');

// Run monitoring every 5 minutes
// Note: With Alpha Vantage free tier, consider every 30-60 min instead
cron.schedule('*/30 * * * *', async () => {
    console.log('⏰ Running scheduled monitors...');

    try {
        await monitorPrices();
        // await monitorNews();
        // await monitorSocial();
    } catch (error) {
        console.error('Error in scheduled job:', error);
    }
});

// Cleanup old data daily at midnight
cron.schedule('0 0 * * *', async () => {
    console.log('🧹 Cleaning up old data...');
    // Add cleanup logic
});

console.log('✅ Scheduler running. Press Ctrl+C to stop.');
```

Run with: `npm run jobs`

## 📱 iOS Integration

See `IMPLEMENTATION_STATUS.md` for iOS setup instructions including:
- Push notification capability
- APNs device token registration
- Notification handling and deep linking
- Backend API client

## 🔐 API Keys & Limits

### Alpha Vantage (Free Tier)
- **Limit**: 25 requests/day, 5 requests/minute
- **Impact**: With 5 holdings = 5 checks/day
- **Solution**: Run job every 30-60 minutes, not every 5

### NewsAPI (Free Tier)
- **Limit**: 100 requests/day
- **Impact**: With 5 holdings = 20 checks/day (OK)

### Reddit API
- **Limit**: 60 requests/minute
- **Impact**: Very generous, no issues

### OpenAI
- **Cost**: ~$0.002 per alert (GPT-3.5-turbo)
- **Fallback**: Template messages if LLM fails

## 🚢 Deployment

### Option 1: Railway (Recommended)

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Add PostgreSQL
railway add postgresql

# Deploy
railway up
```

Railway provides:
- Free PostgreSQL database
- Automatic deployments from Git
- Environment variable management
- $5/month for both services

### Option 2: Render

1. Create account at render.com
2. New → Web Service → Connect repository
3. Add PostgreSQL database
4. Set environment variables
5. Deploy

### Option 3: Fly.io

```bash
# Install flyctl
brew install flyctl

# Login
flyctl auth login

# Launch app
flyctl launch

# Add PostgreSQL
flyctl postgres create

# Deploy
flyctl deploy
```

## 🧪 Testing

### Test Individual Services

```bash
# Test Alpha Vantage
node -e "const av = require('./src/services/alphaVantage'); av.getQuote('AAPL').then(console.log);"

# Test LLM formatter
node -e "const llm = require('./src/services/llm'); llm.formatPriceAlert('AAPL', {changePercent: 2.5, currentPrice: 150, direction: 'up'}).then(console.log);"

# Test deduplication
node -e "const dedup = require('./src/services/deduplication'); console.log(dedup.generatePriceHash('AAPL'));"
```

### Test Monitoring Job

```bash
# Run price monitor standalone
node src/jobs/monitorPrices.js
```

### Test API Endpoints

Use the curl commands in the Quick Start section above.

## 🐛 Troubleshooting

### Database Connection Error
```bash
# Check PostgreSQL is running
brew services list

# Check connection string
echo $DATABASE_URL

# Test connection
psql $DATABASE_URL -c "SELECT 1;"
```

### API Rate Limits
```bash
# Check how many API calls you've made
# Alpha Vantage returns this in headers

# Reduce frequency
# Edit .env: MONITOR_SCHEDULE=*/60 * * * *
```

### APNs Not Working
- Need real iOS device (simulator doesn't support push)
- Need Apple Developer account ($99/year)
- Need APNs certificate (.p8 file)

## 📚 Next Steps

1. ✅ Complete NewsAPI service
2. ✅ Complete Reddit service
3. ✅ Complete APNs service
4. ✅ Build remaining monitoring jobs
5. ✅ Test end-to-end locally
6. ✅ Deploy to Railway/Render
7. ✅ Update iOS app
8. ✅ Test on real device

---

**Current Status**: Foundation complete (~70%). Remaining ~30% follows established patterns.
