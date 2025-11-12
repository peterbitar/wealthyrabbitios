const { holdings, users, newsItems, alertLogs } = require('../database/models');
const newsApiService = require('../services/newsApi');
const llmService = require('../services/llm');
const deduplicationService = require('../services/deduplication');
const rateLimiter = require('../utils/rateLimiter');
const { shouldAlertOnNews } = require('../utils/sensitivity');
const apnsService = require('../services/apns');

async function monitorNews() {
    console.log('📰 Starting news monitoring job...');

    try {
        // Step 1: Get all unique symbols being tracked
        const symbols = await holdings.getAllUniqueSymbols();

        if (symbols.length === 0) {
            console.log('No holdings to monitor');
            return;
        }

        console.log(`Monitoring news for ${symbols.length} symbols: ${symbols.join(', ')}`);

        // Step 2: Fetch news for all symbols (last 24 hours)
        const allNews = await newsApiService.fetchNewsForSymbols(symbols, 24);

        console.log(`Found ${allNews.length} news articles`);

        // Step 3: Process each news article
        for (const article of allNews) {
            // Check deduplication (by URL)
            const contentHash = deduplicationService.generateNewsHash(article.url);
            const isDuplicate = await deduplicationService.isDuplicate(contentHash);

            if (isDuplicate) {
                console.log(`Skipping duplicate news: ${article.title.substring(0, 50)}...`);
                continue;
            }

            // Store in news_items cache
            await newsItems.create(article.symbol, {
                title: article.title,
                url: article.url,
                source: article.source,
                sourceTier: article.sourceTier,
                publishedAt: article.publishedAt,
                contentHash: contentHash
            });

            console.log(`${article.symbol}: ${article.source} (${article.sourceTier}) - ${article.title.substring(0, 40)}...`);

            // Step 4: Find users who hold this symbol
            const allUsers = await users.getAllWithPushTokens();

            for (const user of allUsers) {
                // Check if user holds this symbol
                const userHoldings = await holdings.getByUser(user.user_id);
                const holdsSymbol = userHoldings.some(h => h.symbol === article.symbol);

                if (!holdsSymbol) continue;

                // Check if news source matches user's sensitivity
                const shouldAlert = shouldAlertOnNews(
                    article.url,
                    user.notification_sensitivity
                );

                if (!shouldAlert) {
                    console.log(`${article.source} (${article.sourceTier}) below sensitivity threshold for ${user.name}`);
                    continue;
                }

                // Check rate limiting
                const canSend = await rateLimiter.checkAndReserve(user.user_id);

                if (!canSend) {
                    console.log(`Rate limit reached for ${user.name}, skipping alert`);
                    continue;
                }

                // Generate calm message using LLM
                const alertData = await llmService.formatNewsAlert(article.symbol, {
                    title: article.title,
                    source: article.source,
                    url: article.url,
                    description: article.description
                });

                // Log the alert
                await alertLogs.create(user.user_id, 'news', article.symbol, contentHash, {
                    title: alertData.title,
                    message: alertData.message,
                    url: alertData.sourceUrl,
                    metadata: {
                        source: article.source,
                        sourceTier: article.sourceTier,
                        publishedAt: article.publishedAt
                    }
                });

                // Send push notification
                await apnsService.sendNotification(user.push_token, {
                    title: alertData.title,
                    body: alertData.message.substring(0, 100) + '...',
                    data: {
                        type: 'news',
                        symbol: article.symbol,
                        url: alertData.sourceUrl
                    }
                });

                console.log(`✅ News alert sent to ${user.name}: ${alertData.title}`);
            }
        }

        console.log('✅ News monitoring job complete');
    } catch (error) {
        console.error('❌ Error in news monitoring job:', error);
    }
}

// Allow running standalone for testing
if (require.main === module) {
    monitorNews()
        .then(() => process.exit(0))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
}

module.exports = monitorNews;
