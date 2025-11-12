const { holdings, users, pricePoints, alertLogs } = require('../database/models');
const alphaVantageService = require('../services/alphaVantage');
const llmService = require('../services/llm');
const deduplicationService = require('../services/deduplication');
const rateLimiter = require('../utils/rateLimiter');
const { shouldAlertOnPrice } = require('../utils/sensitivity');
const apnsService = require('../services/apns');

async function monitorPrices() {
    console.log('🔍 Starting price monitoring job...');

    try {
        // Step 1: Get all unique symbols being tracked
        const symbols = await holdings.getAllUniqueSymbols();

        if (symbols.length === 0) {
            console.log('No holdings to monitor');
            return;
        }

        console.log(`Monitoring ${symbols.length} symbols: ${symbols.join(', ')}`);

        // Step 2: Fetch current quotes for all symbols
        // Note: With Alpha Vantage free tier (25 req/day), be very conservative
        const quotes = await alphaVantageService.getQuotes(symbols);

        // Step 3: Process each quote
        for (const quote of quotes) {
            if (!quote) continue;

            // Store price point
            await pricePoints.create(
                quote.symbol,
                quote.price,
                quote.changePercent,
                quote.volume
            );

            // Get historical points for 15-min calculation
            const recentPoints = await pricePoints.getRecent(quote.symbol, 15);

            // Calculate 15-minute change
            const changeData = alphaVantageService.calculate15MinChange(quote.price, recentPoints);

            if (!changeData) {
                console.log(`${quote.symbol}: Not enough historical data yet`);
                continue;
            }

            console.log(`${quote.symbol}: ${changeData.changePercent > 0 ? '↑' : '↓'} ${Math.abs(changeData.changePercent)}% in ${changeData.minutesAgo} min`);

            // Step 4: Find users who hold this symbol
            const allUsers = await users.getAllWithPushTokens();

            for (const user of allUsers) {
                // Check if user holds this symbol
                const userHoldings = await holdings.getByUser(user.user_id);
                const holdsSymbol = userHoldings.some(h => h.symbol === quote.symbol);

                if (!holdsSymbol) continue;

                // Check if change exceeds user's threshold
                const shouldAlert = shouldAlertOnPrice(
                    changeData.changePercent,
                    user.notification_sensitivity
                );

                if (!shouldAlert) {
                    console.log(`${quote.symbol} change ${Math.abs(changeData.changePercent)}% below threshold for ${user.name}`);
                    continue;
                }

                // Check deduplication (one price alert per symbol per hour)
                const contentHash = deduplicationService.generatePriceHash(quote.symbol);
                const isDuplicate = await deduplicationService.isDuplicate(contentHash);

                if (isDuplicate) {
                    console.log(`Skipping duplicate price alert for ${quote.symbol}`);
                    continue;
                }

                // Check rate limiting
                const canSend = await rateLimiter.checkAndReserve(user.user_id);

                if (!canSend) {
                    console.log(`Rate limit reached for ${user.name}, skipping alert`);
                    // TODO: Queue for digest
                    continue;
                }

                // Generate calm message using LLM
                const alertData = await llmService.formatPriceAlert(quote.symbol, {
                    changePercent: changeData.changePercent,
                    currentPrice: quote.price,
                    direction: changeData.changePercent > 0 ? 'up' : 'down'
                });

                // Log the alert
                await alertLogs.create(user.user_id, 'price', quote.symbol, contentHash, {
                    title: alertData.title,
                    message: alertData.message,
                    url: alertData.sourceUrl,
                    metadata: {
                        changePercent: changeData.changePercent,
                        currentPrice: quote.price,
                        oldPrice: changeData.oldPrice
                    }
                });

                // Send push notification
                await apnsService.sendNotification(user.push_token, {
                    title: alertData.title,
                    body: alertData.message.substring(0, 100) + '...',
                    data: {
                        type: 'price',
                        symbol: quote.symbol,
                        url: alertData.sourceUrl,
                        changePercent: changeData.changePercent
                    }
                });

                console.log(`✅ Alert sent to ${user.name}: ${alertData.title}`);
            }
        }

        console.log('✅ Price monitoring job complete');
    } catch (error) {
        console.error('❌ Error in price monitoring job:', error);
    }
}

// Allow running standalone for testing
if (require.main === module) {
    monitorPrices()
        .then(() => process.exit(0))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
}

module.exports = monitorPrices;
