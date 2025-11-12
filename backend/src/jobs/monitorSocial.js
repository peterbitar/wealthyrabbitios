const { holdings, users, socialMentions, alertLogs } = require('../database/models');
const redditService = require('../services/reddit');
const llmService = require('../services/llm');
const deduplicationService = require('../services/deduplication');
const rateLimiter = require('../utils/rateLimiter');
const { shouldAlertOnSocial } = require('../utils/sensitivity');
const apnsService = require('../services/apns');

async function monitorSocial() {
    console.log('💬 Starting social monitoring job...');

    try {
        // Step 1: Get all unique symbols being tracked
        const symbols = await holdings.getAllUniqueSymbols();

        if (symbols.length === 0) {
            console.log('No holdings to monitor');
            return;
        }

        console.log(`Monitoring social buzz for ${symbols.length} symbols: ${symbols.join(', ')}`);

        // Step 2: Search Reddit for each symbol
        for (const symbol of symbols) {
            const { count, topPosts } = await redditService.searchMentions(symbol);

            console.log(`${symbol}: ${count} Reddit mentions in last hour`);

            if (count === 0) continue;

            // Get 7-day baseline for this symbol
            const baseline = await socialMentions.getBaseline(symbol, 'all', 7);
            const spikeMultiple = baseline > 0 ? (count / baseline) : count;

            console.log(`${symbol}: ${spikeMultiple.toFixed(1)}× baseline (baseline: ${baseline.toFixed(1)})`);

            // Store current mention count
            const now = new Date();
            const periodStart = new Date(now.getTime() - 60 * 60 * 1000); // 1 hour ago

            await socialMentions.create(symbol, {
                mentionCount: count,
                subreddit: 'all',
                periodStart: periodStart,
                periodEnd: now,
                baseline7day: baseline
            });

            // Check if this is a significant spike
            const isSpike = spikeMultiple >= 1.5; // Minimum 1.5× to be considered

            if (!isSpike) {
                console.log(`${symbol}: No significant spike (${spikeMultiple.toFixed(1)}×)`);
                continue;
            }

            // Step 3: Find users who hold this symbol
            const allUsers = await users.getAllWithPushTokens();

            for (const user of allUsers) {
                // Check if user holds this symbol
                const userHoldings = await holdings.getByUser(user.user_id);
                const holdsSymbol = userHoldings.some(h => h.symbol === symbol);

                if (!holdsSymbol) continue;

                // Check if spike exceeds user's threshold
                const shouldAlert = shouldAlertOnSocial(
                    spikeMultiple,
                    user.notification_sensitivity
                );

                if (!shouldAlert) {
                    console.log(`${symbol} spike ${spikeMultiple.toFixed(1)}× below threshold for ${user.name}`);
                    continue;
                }

                // Check deduplication (one social alert per symbol per hour)
                const contentHash = deduplicationService.generateSocialHash(symbol);
                const isDuplicate = await deduplicationService.isDuplicate(contentHash);

                if (isDuplicate) {
                    console.log(`Skipping duplicate social alert for ${symbol}`);
                    continue;
                }

                // Check rate limiting
                const canSend = await rateLimiter.checkAndReserve(user.user_id);

                if (!canSend) {
                    console.log(`Rate limit reached for ${user.name}, skipping alert`);
                    continue;
                }

                // Generate calm message using LLM
                const alertData = await llmService.formatSocialAlert(symbol, {
                    spikeMultiple: parseFloat(spikeMultiple.toFixed(1)),
                    mentionCount: count,
                    topPosts: topPosts.map(p => ({
                        title: p.title,
                        url: p.url
                    }))
                });

                // Log the alert
                await alertLogs.create(user.user_id, 'social', symbol, contentHash, {
                    title: alertData.title,
                    message: alertData.message,
                    url: alertData.sourceUrl,
                    metadata: {
                        spikeMultiple: spikeMultiple,
                        mentionCount: count,
                        baseline: baseline,
                        topPosts: topPosts.slice(0, 3)
                    }
                });

                // Send push notification
                await apnsService.sendNotification(user.push_token, {
                    title: alertData.title,
                    body: alertData.message.substring(0, 100) + '...',
                    data: {
                        type: 'social',
                        symbol: symbol,
                        url: alertData.sourceUrl,
                        spikeMultiple: spikeMultiple
                    }
                });

                console.log(`✅ Social alert sent to ${user.name}: ${alertData.title}`);
            }

            // Small delay between symbols
            await redditService.delay(2000);
        }

        console.log('✅ Social monitoring job complete');
    } catch (error) {
        console.error('❌ Error in social monitoring job:', error);
    }
}

// Allow running standalone for testing
if (require.main === module) {
    monitorSocial()
        .then(() => process.exit(0))
        .catch(err => {
            console.error(err);
            process.exit(1);
        });
}

module.exports = monitorSocial;
