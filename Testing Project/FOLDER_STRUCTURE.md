# 📁 Project Folder Structure

This document explains the organization of the Wealthy Rabbit codebase.

## 📂 Folder Organization

### 🚀 **App/**
App entry point and main configuration
- `Testing_ProjectApp.swift` - Main app entry point
- `ContentView.swift` - Root view with tab navigation
- `Config.swift` - App configuration (API keys, etc.)

### 👁️ **Views/**
All SwiftUI views (user interface)
- `RabbitFeedView.swift` - Main news feed with event cards
- `UnifiedRabbitChatView.swift` - Chat interface with Rabbit AI
- `ReflectView.swift` - Portfolio/holdings view
- `SettingsView.swift` - User settings and preferences
- `HoldingsView.swift` - Holdings management
- `PipelineDebugView.swift` - Debug view for news pipeline

### 🧠 **ViewModels/**
View models (business logic for views)
- `RabbitViewModel.swift` - Main view model managing app state

### 📊 **Models/**
Data models and structures
- `Event.swift` - News event model
- `PortfolioHolding.swift` - User holdings model
- `Models.swift` - Message, Conversation (used by RabbitViewModel)
- `RabbitModels.swift` - Rabbit-specific models
- `NewsPipelineModels.swift` - News pipeline data models

### 🔧 **Services/**
External API services and data management
- `OpenAIService.swift` - OpenAI API integration
- `ElevenLabsService.swift` - Voice synthesis API
- `NewsService.swift` - NewsAPI.org integration
- `NewsDataIOService.swift` - NewsData.io integration
- `RSSFeedService.swift` - RSS feed parsing
- `StockDataService.swift` - Stock price data
- `SocialBuzzService.swift` - Social media sentiment
- `BackendAPI.swift` - Backend server API
- `PushNotificationManager.swift` - Push notifications
- `DataPersistenceManager.swift` - Local data storage
- `NewsCache.swift` - News caching

### 🔄 **Pipeline/**
News processing pipeline (the "Bloomberg signal engine")
- `NewsPipelineOrchestrator.swift` - Main pipeline coordinator
- `MultiLayerNewsFetcher.swift` - Multi-source news fetching
- `NewsCleaningEngine.swift` - Article cleaning & normalization
- `EventDetectionEngine.swift` - Event type detection
- `ImpactLabelingEngine.swift` - Impact label detection
- `EventClusteringEngine.swift` - Article clustering (deduplication)
- `UserScoringEngine.swift` - Personalized relevance scoring
- `FeedBuilderEngine.swift` - Feed generation & theme grouping
- `PipelineDebugServer.swift` - Debug web server

### 🛠️ **Utils/**
Utilities and helpers
- `Theme.swift` - App theme and styling

### 📦 **Resources/**
App resources and configuration
- `Testing Project.entitlements` - App capabilities
- `Assets.xcassets/` - Images and assets

## 🔄 Data Flow

```
App → Views → ViewModels → Services/Pipeline → External APIs
```

1. **User interacts** with Views
2. **ViewModels** handle business logic
3. **Services** fetch data from APIs
4. **Pipeline** processes news through multiple stages
5. **Models** structure the data
6. **Views** display the results

## 📝 Notes

- All folders use **PascalCase** for consistency
- Each file has a single, clear responsibility
- The Pipeline folder contains the sophisticated news processing system
- Services are independent and can be easily swapped or extended

