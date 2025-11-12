/**
 * Mock Notification Generator
 * Sends realistic test notifications every 5 minutes for development/testing
 */

const db = require('../database/connection');
const apnsService = require('../services/apns');
const crypto = require('crypto');

// Mock message templates - realistic and relatable
const mockMessages = [
    // Calm Rabbit - Zen and reassuring
    {
        rabbit: 'Calm Rabbit',
        title: '🧘 Breathe Easy',
        messages: [
            'Markets are just doing their thing today. Your portfolio is steady. How about a cup of tea? ☕',
            'Small dips are like clouds passing by. Your long-term view looks clear. Stay centered.',
            'The market moved 0.8% today. Remember: zoom out, breathe in. You\'re doing great.',
            'Your holdings are weathering today\'s noise beautifully. Take a mindful moment.',
            'No rush, no panic. Your investments are planted like trees—growing slowly, surely.',
        ]
    },

    // Insights Rabbit - Analytical and informative
    {
        rabbit: 'Insights Rabbit',
        title: '📊 Market Pattern',
        messages: [
            'Interesting: Tech sector showing defensive behavior today. Your AAPL holding up well at +0.3%.',
            'Pattern alert: Seeing rotation into value stocks. Your balanced allocation looking smart.',
            'Data point: S&P 500 testing support at 4,450. Your portfolio diversity is cushioning this.',
            'Notable: Treasury yields dropping. This historically benefits your growth positions.',
            'Macro view: Fed language softening. Good environment for your current holdings mix.',
        ]
    },

    // Alert Rabbit - Urgent but calm
    {
        rabbit: 'Alert Rabbit',
        title: '⚡ Heads Up',
        messages: [
            'NVDA moved +2.3% in the last hour on earnings whispers. Keeping an eye on this for you.',
            'Your tech allocation up 1.2% today. Might be a good moment to review rebalancing—no rush though.',
            'Breaking: Fed member hints at rate pause. This could affect your positions positively.',
            'Quick note: Trading volume spiking on TSLA. Currently +1.8%. Everything\'s under control.',
            'Market volatility ticked up 15% this hour. Your diversification strategy holding steady.',
        ]
    },

    // Chill Rabbit - Casual and friendly
    {
        rabbit: 'Chill Rabbit',
        title: '😎 Just Checking In',
        messages: [
            'Hey! Markets are pretty chill today. Your portfolio barely moved. Keep doing you. 🌊',
            'Not much happening in finance world today. Perfect time to forget about the charts. ☀️',
            'Your investments? Solid. Your stress level? Hopefully low. Go enjoy your day!',
            'Markets doing their usual dance. Nothing to see here, friend. Maybe grab lunch? 🍃',
            'Real talk: your portfolio is fine. Like, actually fine. Go do something fun.',
        ]
    },

    // Weekly summary style
    {
        rabbit: 'Insights Rabbit',
        title: '📈 Your Week So Far',
        messages: [
            'Portfolio update: Up 1.2% this week. All holdings green. You\'re crushing it quietly.',
            'This week: 3 holdings up, 0 down. Total gain: $247. Sometimes boring is beautiful.',
            'Week in review: Market volatility 12% below average. Your calm strategy paying off.',
        ]
    },

    // Social buzz mentions
    {
        rabbit: 'Alert Rabbit',
        title: '💬 Social Radar',
        messages: [
            'Reddit chatter about AAPL up 40% today—mostly positive. Seems like renewed interest.',
            'Your NVDA position getting mentioned more on social. Community sentiment: bullish.',
            'Interesting social trend: TSLA discussion volume spiking. Watching for you.',
        ]
    },

    // News-based
    {
        rabbit: 'Insights Rabbit',
        title: '📰 In The News',
        messages: [
            'WSJ: "Tech stocks resilient amid uncertainty." Your allocation strategy validated.',
            'Bloomberg reports strong earnings season ahead. Your positions well-positioned.',
            'Reuters: Analysts upgrading tech sector. Your AAPL & NVDA looking prescient.',
        ]
    },

    // Mindful reminders
    {
        rabbit: 'Calm Rabbit',
        title: '🌿 Mindful Moment',
        messages: [
            'Reminder: You invested with intention. Trust your process. The numbers agree.',
            'Your portfolio doesn\'t need you to check it every hour. But I\'m here if you want to.',
            'Markets up, markets down. Your strategy stays sound. That\'s the power of planning.',
            'Good investing is mostly waiting. You\'re doing the hardest part: being patient.',
        ]
    }
];

// Get a random message that hasn't been sent recently
function getRandomMessage() {
    const category = mockMessages[Math.floor(Math.random() * mockMessages.length)];
    const message = category.messages[Math.floor(Math.random() * category.messages.length)];

    return {
        rabbit: category.rabbit,
        title: category.title,
        message: message,
        contentHash: crypto.createHash('md5').update(message).digest('hex')
    };
}

// Send mock notification to all users
async function sendMockNotifications() {
    try {
        console.log('\n🎭 [MOCK] Generating test notifications...');

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
            const maxDaily = parseInt(process.env.MAX_DAILY_PUSHES_PER_USER) || 5;

            if (dailyCount >= maxDaily) {
                console.log(`⏭️  User ${user.name} has reached daily limit (${maxDaily})`);
                continue;
            }

            // Get a random message
            const mockMsg = getRandomMessage();

            // Check for recent duplicates (last 24 hours)
            const recentDupe = await db.query(
                `SELECT id FROM alert_log
                 WHERE user_id = $1 AND content_hash = $2
                 AND sent_at > NOW() - INTERVAL '24 hours'`,
                [user.user_id, mockMsg.contentHash]
            );

            if (recentDupe.rows.length > 0) {
                console.log(`🔁 Skipping duplicate message for ${user.name}`);
                continue;
            }

            // Send notification via APNs
            const payload = {
                title: mockMsg.title,
                body: mockMsg.message,
                data: {
                    alert_type: 'mock',
                    rabbit: mockMsg.rabbit,
                    timestamp: new Date().toISOString()
                }
            };

            const result = await apnsService.sendNotification(user.push_token, payload);

            // Log to database
            await db.query(
                `INSERT INTO alert_log
                 (user_id, alert_type, content_hash, title, message, metadata)
                 VALUES ($1, $2, $3, $4, $5, $6)`,
                [
                    user.user_id,
                    'mock',
                    mockMsg.contentHash,
                    mockMsg.title,
                    mockMsg.message,
                    JSON.stringify({ rabbit: mockMsg.rabbit, simulated: result.simulated })
                ]
            );

            console.log(`✅ Sent mock notification to ${user.name}`);
            console.log(`   ${mockMsg.title}`);
            console.log(`   ${mockMsg.message.substring(0, 60)}...`);
        }

        console.log('🎭 Mock notifications complete\n');

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
