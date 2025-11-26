# 🏗️ Architecture Documentation

## News Pipeline Architecture

The news pipeline implements a clean, multi-stage "Bloomberg signal engine" for processing financial news.

### 🧱 Multi-Layer Inputs (3 Layers)

**Layer 1 - Wire Feeds (High-value mandatory)**
- Bloomberg
- Reuters (via Google News RSS)
- AP News
- PR Newswire
- Financial Times

**Layer 2 - Financial News Aggregators**
- Yahoo Finance
- MarketWatch
- CNBC
- Investing.com
- TheStreet

**Layer 3 - Supplemental (Fallback only)**
- NewsAPI.org
- NewsData.io (optional)

### 🔄 Pipeline Stages

1. **Raw Storage** - Articles stored AS-IS
2. **Cleaning & Normalization** - Strip boilerplate, extract content
3. **Event Detection** - Classify event types (earnings, M&A, etc.)
4. **Impact Labeling** - Detect impact categories
5. **Clustering** - Group duplicate/similar articles by semantic meaning
6. **User Scoring** - Personalized relevance scoring
7. **Feed Building** - Generate themes and interpretations
8. **Rabbit Interpretation** - Apply Rabbit personality layer

### 📊 Data Flow

```
Multi-Layer Fetch → Raw Storage → Cleaning → Event Detection → 
Clustering → Scoring → Feed Building → Display
```

## API Setup

### ✅ Required
- **OpenAI API** - For event detection, clustering, and interpretation
- **NewsAPI.org** - Layer 3 fallback source

### ✅ No Setup Needed
- **RSS Feeds** - All Layer 1 & 2 sources (free, unlimited)

### ⚠️ Optional
- **NewsData.io** - Additional Layer 3 source

See `App/Config.swift` for API key configuration.

## Folder Structure

See `FOLDER_STRUCTURE.md` for detailed file organization.

