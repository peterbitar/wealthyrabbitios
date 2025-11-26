/**
 * Realistic Mock Notification Generator
 * Simulates a realistic trading day with news, Reddit posts, and market movements
 * Sends contextual notifications every 5-10 minutes
 */

const db = require('../database/connection');
const apnsService = require('../services/apns');
const crypto = require('crypto');

// Realistic mock market scenarios with news, social, and price data
const marketScenarios = {
    // Morning: Market Open (9:30 AM - 11:00 AM ET)
    morningOpen: [
        {
            rabbit: 'Holdings Rabbit',
            title: '☀️ Morning Portfolio Check',
            template: 'Good morning! Markets opened {direction} today. Your portfolio\'s at {change}% — {holdings} holdings are {sentiment}. {context}',
            contexts: [
                'Tech leading the way on strong overnight futures.',
                'Energy sector getting attention after oil price moves.',
                'Seeing rotation into growth stocks this morning.',
                'Market digesting yesterday\'s Fed comments.',
                'Pretty typical open — nothing dramatic yet.'
            ]
        },
        {
            rabbit: 'Trends Rabbit',
            title: '📱 Social Buzz Alert',
            template: 'Reddit\'s lighting up about {symbol} — mentions up {percent}% since yesterday. Main theme: "{theme}". {analysis}',
            themes: [
                { symbol: 'AAPL', theme: 'New product rumors circulating', analysis: 'Mostly excitement, some skepticism. Classic pre-announcement buzz.' },
                { symbol: 'NVDA', theme: 'AI chip demand speculation', analysis: 'Mix of FOMO and genuine interest. Institutional chatter too.' },
                { symbol: 'TSLA', theme: 'Production numbers discussion', analysis: 'Bulls and bears both vocal. Usual Tesla debate energy.' },
                { symbol: 'MSFT', theme: 'Cloud services growth', analysis: 'Quietly bullish sentiment. Enterprise focus resonating.' }
            ]
        },
        {
            rabbit: 'Insights Rabbit',
            title: '🌍 Macro Morning',
            template: '{news_source}: "{headline}" Your portfolio context: {context}',
            headlines: [
                { source: 'Bloomberg', headline: 'Treasury Yields Dip as Investors Seek Safety', context: 'This typically favors growth stocks. Your tech holdings benefit.' },
                { source: 'Reuters', headline: 'Dollar Weakens Against Major Currencies', context: 'Good for multinationals. Your large-caps export globally.' },
                { source: 'WSJ', headline: 'Consumer Confidence Beats Expectations', context: 'Positive for broad market. Supports your diversified approach.' },
                { source: 'CNBC', headline: 'Jobless Claims Come In Lower Than Forecast', context: 'Strong economy signal. Markets responding positively.' }
            ]
        }
    ],

    // Mid-Day: Trading Hours (11:00 AM - 2:00 PM ET)
    midDay: [
        {
            rabbit: 'Holdings Rabbit',
            title: '⏰ Midday Update',
            template: 'Lunchtime check: {symbol} moved {change}% to ${price}. {reason} {sentiment}',
            movements: [
                { symbol: 'AAPL', reason: 'Analyst upgrade from JP Morgan', sentiment: 'This is the third upgrade this month — market taking notice.' },
                { symbol: 'NVDA', reason: 'Following semiconductor index higher', sentiment: 'Sector-wide strength, not isolated news.' },
                { symbol: 'TSLA', reason: 'CEO comments on earnings call', sentiment: 'Market liked the tone. Cautious optimism building.' },
                { symbol: 'MSFT', reason: 'Cloud numbers leaked early (unconfirmed)', sentiment: 'Take with grain of salt until official, but market reacting.' }
            ]
        },
        {
            rabbit: 'Drama Rabbit',
            title: '📰 Story Developing',
            template: '{headline} Here\'s what\'s happening: {story} Market reaction: {reaction}',
            stories: [
                {
                    headline: 'Tech CEO Unexpected Departure',
                    story: 'Major tech company\'s CFO announced retirement effective end of quarter. Succession plan in place, but markets processing the news.',
                    reaction: 'Stock down 2% initially, now recovering to -0.8%. Fairly measured response.'
                },
                {
                    headline: 'Regulatory Review Announced',
                    story: 'DOJ opening antitrust review of major platform. Not unexpected — analysts called this months ago. Timeline: 12-18 months.',
                    reaction: 'Stock dipped 1.5%, but industry peers flat. Seems specific, not sector-wide concern.'
                },
                {
                    headline: 'Earnings Leak Controversy',
                    story: 'Company investigating how numbers appeared online before official release. SEC likely to get involved.',
                    reaction: 'Trading halted briefly. Resumed down 3%, but news isn\'t about fundamentals.'
                },
                {
                    headline: 'Partnership Rumors Heating Up',
                    story: 'Multiple sources reporting talks between two major players. Nothing confirmed, both companies declined comment.',
                    reaction: 'Both stocks up 4-5% on speculation. Classic rumor-driven move.'
                }
            ]
        },
        {
            rabbit: 'Trends Rabbit',
            title: '🔥 Trending Now',
            template: 'Your {symbol} is trending on {platform}. Top posts: "{post}" Vibe: {vibe}',
            trends: [
                { symbol: 'AAPL', platform: 'Reddit r/stocks', post: 'Is AAPL still a buy at these levels?', vibe: 'Curious but cautious. People taking profits, wondering if more upside.' },
                { symbol: 'NVDA', platform: 'Twitter/FinTwit', post: 'AI infrastructure spend isn\'t slowing down', vibe: 'Bullish conviction. Institutional voices joining retail enthusiasm.' },
                { symbol: 'TSLA', platform: 'Reddit r/wallstreetbets', post: 'Delivery numbers coming next week', vibe: 'High energy speculation. Mix of memes and actual analysis.' },
                { symbol: 'MSFT', platform: 'LinkedIn', post: 'Enterprise AI adoption accelerating', vibe: 'Professional, measured optimism. Corporate buyers chiming in.' }
            ]
        }
    ],

    // Afternoon: Late Trading (2:00 PM - 4:00 PM ET)
    afternoon: [
        {
            rabbit: 'Insights Rabbit',
            title: '📊 Afternoon Analysis',
            template: 'Market pattern: {pattern} What this means: {meaning} Your portfolio: {impact}',
            patterns: [
                { pattern: 'Tech leading, defensives lagging', meaning: 'Risk-on sentiment building', impact: 'Your growth tilt working in your favor today.' },
                { pattern: 'Small caps outperforming large', meaning: 'Confidence in economic resilience', impact: 'Broad market strength supports diversified holdings.' },
                { pattern: 'Everything moving together (high correlation)', meaning: 'Macro forces dominating stock-specific news', impact: 'Likely Fed/economy driven. Normal portfolio behavior.' },
                { pattern: 'Sector rotation from growth to value', meaning: 'Investors repositioning for changing rates', impact: 'Some choppiness expected, but you\'re diversified.' }
            ]
        },
        {
            rabbit: 'Holdings Rabbit',
            title: '🎯 Position Check',
            template: 'Your {symbol} just hit {milestone}. {context} Perspective: {perspective}',
            milestones: [
                { symbol: 'AAPL', milestone: '$185', context: 'Technical resistance level', perspective: 'If it holds above, next target is $190. Not urgent, just notable.' },
                { symbol: 'NVDA', milestone: '52-week high', context: 'Breaking out to new territory', perspective: 'Strong momentum, but don\'t let FOMO drive decisions.' },
                { symbol: 'TSLA', milestone: '200-day moving average', context: 'Key technical indicator', perspective: 'Bulls watching if it holds. Still early to tell.' },
                { symbol: 'MSFT', milestone: '$380', context: 'Psychological round number', perspective: 'Markets love round numbers. Support or resistance TBD.' }
            ]
        },
        {
            rabbit: 'Drama Rabbit',
            title: '⚠️ Late Breaking',
            template: '{headline} Quick take: {take} Your exposure: {exposure}',
            lateBreaking: [
                { headline: 'FDA Approval Delayed for Major Drug', take: 'Biotech taking hit but expected to reapply. Not end of story.', exposure: 'Not in your portfolio, but watch healthcare sector ripples.' },
                { headline: 'Cyber Security Breach Reported', take: 'Major retailer confirming data incident. Scope still being assessed.', exposure: 'You don\'t hold retail, but good reminder on cyber risk generally.' },
                { headline: 'Merger Deal Falls Through', take: 'Regulatory concerns killed the deal. Both stocks adjusting.', exposure: 'No direct impact, but shows current regulatory environment.' },
                { headline: 'Earnings Guidance Revised Upward', take: 'Company beating estimates and raising outlook. Market loves it.', exposure: 'Not your holding but same sector — positive signal for industry.' }
            ]
        }
    ],

    // Market Close (4:00 PM - 5:00 PM ET)
    marketClose: [
        {
            rabbit: 'Holdings Rabbit',
            title: '🔔 Closing Bell',
            template: 'Markets closed {direction} today. Your portfolio: {change}%. {winners} up, {losers} down. {summary}',
            summaries: [
                'Solid day overall. Normal volatility, nothing concerning.',
                'Bit of choppiness today, but your diversification did its job.',
                'Strong performance across your holdings. Market momentum building.',
                'Mixed day for the market, but you stayed near flat. Stability working.',
                'Small dip today, well within normal ranges. Nothing to adjust.'
            ]
        },
        {
            rabbit: 'Insights Rabbit',
            title: '🌙 Day In Review',
            template: 'Today\'s theme: {theme} Key stat: {stat} Tomorrow\'s watch: {watch}',
            themes: [
                { theme: 'Risk-on rotation continues', stat: 'Growth stocks up 0.8%, value flat', watch: 'Treasury auction results — could shift sentiment' },
                { theme: 'Choppy consolidation day', stat: 'S&P 500 range just 0.4% all day', watch: 'Jobs report Friday — market positioning ahead' },
                { theme: 'Tech strength persists', stat: 'Nasdaq outperformed by 1.2%', watch: 'Earnings calls tonight might move individual names' },
                { theme: 'Defensive positioning', stat: 'Volatility index up 8%', watch: 'Fed speaker tomorrow — markets want clarity' }
            ]
        },
        {
            rabbit: 'Trends Rabbit',
            title: '📈 Social Wrap-Up',
            template: 'Today\'s most discussed: {symbol}. Sentiment: {sentiment} Notable: {notable}',
            wraps: [
                { symbol: 'NVDA', sentiment: '78% bullish', notable: 'AI infrastructure theme dominated conversation. Retail + institutions aligned.' },
                { symbol: 'AAPL', sentiment: '65% bullish', notable: 'Product cycle speculation. Mixed views on China exposure.' },
                { symbol: 'TSLA', sentiment: '55% bullish', notable: 'Usual debate intensity. Delivery numbers anticipation building.' },
                { symbol: 'MSFT', sentiment: '72% bullish', notable: 'Cloud growth consensus strong. Enterprise AI seen as differentiator.' }
            ]
        }
    ],

    // After Hours / Evening (5:00 PM - 8:00 PM ET)
    afterHours: [
        {
            rabbit: 'Drama Rabbit',
            title: '🌃 After Hours',
            template: '{symbol} moving after-hours: {direction} {percent}%. Reason: {reason} Context: {context}',
            afterHoursNews: [
                { symbol: 'AAPL', reason: 'Earnings beat expectations', context: 'Revenue +8%, stronger iPhone sales. Market likes what it sees.' },
                { symbol: 'NVDA', reason: 'Conference presentation well-received', context: 'CEO outlined AI roadmap. Investors feeling confident in timeline.' },
                { symbol: 'MSFT', reason: 'Cloud growth numbers leaked', context: 'Better than expected Azure performance. Stock up 2% after-hours.' },
                { symbol: 'TSLA', reason: 'Production facility announcement', context: 'New gigafactory location revealed. Market digesting details.' }
            ]
        },
        {
            rabbit: 'Insights Rabbit',
            title: '🔮 Tomorrow\'s Setup',
            template: 'Overnight: {overnight} Tomorrow\'s focus: {focus} Your holdings: {positioning}',
            setups: [
                { overnight: 'Asian markets mixed, Europe slight green', focus: 'Economic data at 8:30 AM ET', positioning: 'Well-positioned for data regardless of direction.' },
                { overnight: 'Futures up 0.3% on China news', focus: 'Multiple earnings before open', positioning: 'Your sector exposure looks balanced heading in.' },
                { overnight: 'Global risk-off after headlines', focus: 'Fed speaker at 10 AM could calm nerves', positioning: 'Diversification helping weather uncertainty.' },
                { overnight: 'Commodity prices surging', focus: 'Inflation implications for tech valuations', positioning: 'Your growth/value mix should handle this well.' }
            ]
        }
    ]
};

// Helper to get realistic mock data based on time of day
function getMockMarketData() {
    const now = new Date();
    const hour = now.getHours();

    // Generate realistic but varied data
    const baseChange = (Math.random() - 0.5) * 2; // -1% to +1%
    const holdings = Math.floor(Math.random() * 4) + 2; // 2-5 holdings
    const winners = Math.floor(Math.random() * holdings);
    const losers = holdings - winners;

    return {
        direction: baseChange > 0 ? 'higher' : 'lower',
        change: (baseChange + (Math.random() - 0.5) * 0.5).toFixed(2),
        holdings: holdings,
        winners: winners,
        losers: losers,
        sentiment: baseChange > 0.5 ? 'green' : baseChange < -0.5 ? 'red' : 'mixed',
        price: (180 + Math.random() * 20).toFixed(2),
        percent: (50 + Math.random() * 100).toFixed(0)
    };
}

// Get time period based on current hour (ET)
function getCurrentPeriod() {
    const now = new Date();
    // Convert to ET (simplified - just offset by hour)
    const hour = now.getHours();

    // Market hours are 9:30 AM - 4:00 PM ET
    // For demo purposes, cycle through periods every 2 hours
    const periodIndex = Math.floor((hour % 12) / 2);
    const periods = ['morningOpen', 'midDay', 'afternoon', 'marketClose', 'afterHours', 'morningOpen'];

    return periods[periodIndex] || 'midDay';
}

// Generate a realistic notification message
function generateRealisticNotification() {
    const period = getCurrentPeriod();
    const scenarios = marketScenarios[period];

    if (!scenarios || scenarios.length === 0) {
        // Fallback to midDay if period has no scenarios
        return generateFromScenario(marketScenarios.midDay);
    }

    return generateFromScenario(scenarios);
}

// Generate message from scenario data
function generateFromScenario(scenarios) {
    const scenario = scenarios[Math.floor(Math.random() * scenarios.length)];
    const mockData = getMockMarketData();

    let message = scenario.template;
    let title = scenario.title;
    let rabbit = scenario.rabbit;

    // Fill in template variables based on scenario type
    if (scenario.contexts) {
        // Morning open scenario
        const context = scenario.contexts[Math.floor(Math.random() * scenario.contexts.length)];
        message = message
            .replace('{direction}', mockData.direction)
            .replace('{change}', mockData.change)
            .replace('{holdings}', mockData.holdings)
            .replace('{sentiment}', mockData.sentiment)
            .replace('{context}', context);
    } else if (scenario.themes) {
        // Social buzz scenario
        const theme = scenario.themes[Math.floor(Math.random() * scenario.themes.length)];
        message = message
            .replace('{symbol}', theme.symbol)
            .replace('{percent}', mockData.percent)
            .replace('{theme}', theme.theme)
            .replace('{analysis}', theme.analysis);
    } else if (scenario.headlines) {
        // News headline scenario
        const headline = scenario.headlines[Math.floor(Math.random() * scenario.headlines.length)];
        message = message
            .replace('{news_source}', headline.source)
            .replace('{headline}', headline.headline)
            .replace('{context}', headline.context);
    } else if (scenario.movements) {
        // Price movement scenario
        const movement = scenario.movements[Math.floor(Math.random() * scenario.movements.length)];
        message = message
            .replace('{symbol}', movement.symbol)
            .replace('{change}', mockData.change)
            .replace('{price}', mockData.price)
            .replace('{reason}', movement.reason)
            .replace('{sentiment}', movement.sentiment);
    } else if (scenario.stories) {
        // Drama story scenario
        const story = scenario.stories[Math.floor(Math.random() * scenario.stories.length)];
        message = message
            .replace('{headline}', story.headline)
            .replace('{story}', story.story)
            .replace('{reaction}', story.reaction);
    } else if (scenario.trends) {
        // Trending topic scenario
        const trend = scenario.trends[Math.floor(Math.random() * scenario.trends.length)];
        message = message
            .replace('{symbol}', trend.symbol)
            .replace('{platform}', trend.platform)
            .replace('{post}', trend.post)
            .replace('{vibe}', trend.vibe);
    } else if (scenario.patterns) {
        // Market pattern scenario
        const pattern = scenario.patterns[Math.floor(Math.random() * scenario.patterns.length)];
        message = message
            .replace('{pattern}', pattern.pattern)
            .replace('{meaning}', pattern.meaning)
            .replace('{impact}', pattern.impact);
    } else if (scenario.milestones) {
        // Milestone scenario
        const milestone = scenario.milestones[Math.floor(Math.random() * scenario.milestones.length)];
        message = message
            .replace('{symbol}', milestone.symbol)
            .replace('{milestone}', milestone.milestone)
            .replace('{context}', milestone.context)
            .replace('{perspective}', milestone.perspective);
    } else if (scenario.lateBreaking) {
        // Late breaking news scenario
        const breaking = scenario.lateBreaking[Math.floor(Math.random() * scenario.lateBreaking.length)];
        message = message
            .replace('{headline}', breaking.headline)
            .replace('{take}', breaking.take)
            .replace('{exposure}', breaking.exposure);
    } else if (scenario.summaries) {
        // Closing bell scenario
        const summary = scenario.summaries[Math.floor(Math.random() * scenario.summaries.length)];
        message = message
            .replace('{direction}', mockData.direction)
            .replace('{change}', mockData.change)
            .replace('{winners}', mockData.winners)
            .replace('{losers}', mockData.losers)
            .replace('{summary}', summary);
    } else if (scenario.themes) {
        // Day in review scenario
        const theme = scenario.themes[Math.floor(Math.random() * scenario.themes.length)];
        message = message
            .replace('{theme}', theme.theme)
            .replace('{stat}', theme.stat)
            .replace('{watch}', theme.watch);
    } else if (scenario.wraps) {
        // Social wrap-up scenario
        const wrap = scenario.wraps[Math.floor(Math.random() * scenario.wraps.length)];
        message = message
            .replace('{symbol}', wrap.symbol)
            .replace('{sentiment}', wrap.sentiment)
            .replace('{notable}', wrap.notable);
    } else if (scenario.afterHoursNews) {
        // After hours news scenario
        const news = scenario.afterHoursNews[Math.floor(Math.random() * scenario.afterHoursNews.length)];
        const direction = Math.random() > 0.5 ? 'up' : 'down';
        message = message
            .replace('{symbol}', news.symbol)
            .replace('{direction}', direction)
            .replace('{percent}', mockData.change)
            .replace('{reason}', news.reason)
            .replace('{context}', news.context);
    } else if (scenario.setups) {
        // Tomorrow's setup scenario
        const setup = scenario.setups[Math.floor(Math.random() * scenario.setups.length)];
        message = message
            .replace('{overnight}', setup.overnight)
            .replace('{focus}', setup.focus)
            .replace('{positioning}', setup.positioning);
    }

    return {
        rabbit: rabbit,
        title: title,
        message: message,
        contentHash: crypto.createHash('md5').update(message).digest('hex')
    };
}

// Send mock notification to all users
async function sendMockNotifications() {
    try {
        const period = getCurrentPeriod();
        console.log(`\n🎭 [MOCK] Generating realistic notifications for ${period}...`);

        // Get all users with push tokens
        const result = await db.query(
            'SELECT user_id, name, push_token, notification_frequency FROM app_user WHERE push_token IS NOT NULL'
        );

        const users = result.rows;

        if (users.length === 0) {
            console.log('⚠️  No users with push tokens found');
            return;
        }

        console.log(`📱 Found ${users.length} user(s) with push tokens`);

        // Send to each user
        for (const user of users) {
            // Check if user has hit daily limit
            const today = new Date().toISOString().split('T')[0];
            const alertCount = await db.query(
                `SELECT COUNT(*) as count FROM alert_log
                 WHERE user_id = $1 AND DATE(sent_at) = $2`,
                [user.user_id, today]
            );

            const dailyCount = parseInt(alertCount.rows[0].count);
            const maxDaily = parseInt(process.env.MAX_DAILY_PUSHES_PER_USER) || 20; // Increased for demo

            if (dailyCount >= maxDaily) {
                console.log(`⏭️  User ${user.name} has reached daily limit (${maxDaily})`);
                continue;
            }

            // Generate a realistic notification
            const mockMsg = generateRealisticNotification();

            // Check for recent duplicates (last 2 hours to allow more variety)
            const recentDupe = await db.query(
                `SELECT id FROM alert_log
                 WHERE user_id = $1 AND content_hash = $2
                 AND sent_at > NOW() - INTERVAL '2 hours'`,
                [user.user_id, mockMsg.contentHash]
            );

            if (recentDupe.rows.length > 0) {
                console.log(`🔁 Skipping duplicate message for ${user.name}`);
                // Try one more time with different message
                const mockMsg2 = generateRealisticNotification();
                const recentDupe2 = await db.query(
                    `SELECT id FROM alert_log
                     WHERE user_id = $1 AND content_hash = $2
                     AND sent_at > NOW() - INTERVAL '2 hours'`,
                    [user.user_id, mockMsg2.contentHash]
                );

                if (recentDupe2.rows.length > 0) {
                    console.log(`🔁 Still duplicate, skipping this cycle`);
                    continue;
                }

                // Use the second message
                Object.assign(mockMsg, mockMsg2);
            }

            // Send notification via APNs
            const payload = {
                title: mockMsg.title,
                body: mockMsg.message,
                data: {
                    alert_type: 'realistic_mock',
                    rabbit: mockMsg.rabbit,
                    period: period,
                    timestamp: new Date().toISOString()
                }
            };

            const sendResult = await apnsService.sendNotification(user.push_token, payload);

            // Log to database
            await db.query(
                `INSERT INTO alert_log
                 (user_id, alert_type, content_hash, title, message, metadata)
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                [
                    user.user_id,
                    'realistic_mock',
                    mockMsg.contentHash,
                    mockMsg.title,
                    mockMsg.message,
                    JSON.stringify({
                        rabbit: mockMsg.rabbit,
                        period: period,
                        simulated: sendResult.simulated
                    })
                ]
            );

            console.log(`✅ Sent ${period} notification to ${user.name}`);
            console.log(`   🐇 ${mockMsg.rabbit}`);
            console.log(`   📰 ${mockMsg.title}`);
            console.log(`   💬 ${mockMsg.message.substring(0, 80)}...`);
        }

        console.log(`🎭 Realistic mock notifications complete (${period})\n`);

    } catch (error) {
        console.error('❌ Error sending mock notifications:', error);
    }
}

// Only run if called directly
if (require.main === module) {
    sendMockNotifications()
        .then(() => {
            console.log('✅ Mock notification test complete');
            process.exit(0);
        })
        .catch(error => {
            console.error('❌ Mock notification test failed:', error);
            process.exit(1);
        });
}

module.exports = { sendMockNotifications };
