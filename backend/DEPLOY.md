# WealthyRabbit Backend - Railway Deployment Guide

## Quick Deploy (15 minutes)

### Step 1: Push to GitHub (5 min)

```bash
cd "/Users/peter/projects/Testing Project"

# Add all backend files
git add backend/

# Commit
git commit -m "Add WealthyRabbit backend for deployment"

# Push to GitHub
git push origin main
```

### Step 2: Deploy on Railway (10 min)

1. **Go to Railway**: https://railway.app
2. **Sign up/Login** with GitHub
3. **New Project** → **Deploy from GitHub repo**
4. **Select** your `Testing Project` repository
5. **Root Directory**: Set to `backend`
6. **Add PostgreSQL**:
   - Click "+ New"
   - Select "Database" → "PostgreSQL"
   - Wait for provisioning (~30 seconds)

### Step 3: Configure Environment Variables

In Railway project settings → Variables, add:

```
ALPHA_VANTAGE_API_KEY=your_alpha_vantage_key
NEWS_API_KEY=your_newsapi_key
OPENAI_API_KEY=your_openai_key
PORT=3000
NODE_ENV=production
MAX_DAILY_PUSHES_PER_USER=5
MONITOR_SCHEDULE=*/60 * * * *
APNS_PRODUCTION=false
```

**Get your API keys from your local `.env` file**

**Database URL**: Railway will auto-inject `DATABASE_URL`

### Step 4: Run Database Schema

In Railway → PostgreSQL service → Data tab:

Run this SQL:
```sql
-- Copy contents from backend/src/database/schema.sql
```

Or use Railway CLI:
```bash
railway run psql $DATABASE_URL < src/database/schema.sql
```

### Step 5: Deploy & Test

1. **Deploy**: Railway auto-deploys on git push
2. **Get URL**: Settings → Domains → Generate Domain
3. **Test**: `curl https://your-app.railway.app/health`

### Step 6: Update iOS App

In `Testing Project/Config.swift`:

```swift
static let backendBaseURL = "https://your-app.railway.app"
```

## Monitoring Jobs

Railway doesn't run workers by default. To enable monitoring:

**Option A: Separate Worker Service**
1. Create new service in Railway
2. Set Start Command: `node src/jobs/scheduler.js`
3. Link same PostgreSQL database

**Option B: Combined (simpler)**
Update `src/server.js` to start scheduler:
```javascript
// At the end of server.js
require('./jobs/scheduler');
```

## Cost

- **Free Tier**: $5/month credit
- **Typical Usage**: ~$5-10/month
- **Includes**: PostgreSQL + Web service

## Troubleshooting

**Build fails**: Check Railway logs
**Database connection**: Verify `DATABASE_URL` is set
**Port issues**: Railway uses `PORT` env variable

## Production Checklist

- [ ] Backend deployed on Railway
- [ ] PostgreSQL provisioned
- [ ] Environment variables configured
- [ ] Database schema loaded
- [ ] Health endpoint working
- [ ] iOS app updated with production URL
- [ ] Monitoring jobs running

---

**You're live!** 🚀
