const cron = require('node-cron');
const monitorPrices = require('./monitorPrices');
const monitorNews = require('./monitorNews');
const monitorSocial = require('./monitorSocial');
const { sendMockNotifications } = require('./mockNotifications');
const { pricePoints } = require('../database/models');
require('dotenv').config();

console.log('🐇 WealthyRabbit Job Scheduler starting...');
console.log(`📅 Schedule: ${process.env.MONITOR_SCHEDULE || '*/60 * * * *'}`);
console.log('');

// Get schedule from env or default to every 60 minutes (for Alpha Vantage free tier)
const schedule = process.env.MONITOR_SCHEDULE || '*/60 * * * *';

// Run all monitoring jobs
async function runAllMonitors() {
    const startTime = Date.now();
    console.log(`\n⏰ [${new Date().toLocaleTimeString()}] Running scheduled monitors...`);

    try {
        // Run price monitoring
        console.log('\n--- Price Monitoring ---');
        await monitorPrices();

        // Run news monitoring
        console.log('\n--- News Monitoring ---');
        await monitorNews();

        // Run social monitoring
        console.log('\n--- Social Monitoring ---');
        await monitorSocial();

        const duration = ((Date.now() - startTime) / 1000).toFixed(1);
        console.log(`\n✅ All monitors complete in ${duration}s`);
        console.log(`Next run: ${getNextRunTime(schedule)}`);

    } catch (error) {
        console.error('❌ Error in scheduled job:', error);
    }
}

// Schedule the monitoring jobs
cron.schedule(schedule, runAllMonitors);

// Cleanup old data daily at midnight
cron.schedule('0 0 * * *', async () => {
    console.log('\n🧹 Running daily cleanup...');

    try {
        // Delete price points older than 7 days
        await pricePoints.cleanup(7);
        console.log('✅ Cleanup complete');
    } catch (error) {
        console.error('❌ Error in cleanup job:', error);
    }
});

// Mock notifications every 5-10 minutes with realistic trading day simulation
if (process.env.NODE_ENV !== 'production' || process.env.ENABLE_MOCK_NOTIFICATIONS === 'true') {
    console.log('🎭 Realistic mock notifications enabled - sending every 5-10 minutes');

    // Function to schedule next mock notification with random delay
    function scheduleNextMockNotification() {
        // Random delay between 5-10 minutes (in milliseconds)
        const minDelay = 5 * 60 * 1000;  // 5 minutes
        const maxDelay = 10 * 60 * 1000; // 10 minutes
        const randomDelay = Math.floor(Math.random() * (maxDelay - minDelay + 1)) + minDelay;
        const minutesDelay = (randomDelay / 60000).toFixed(1);

        console.log(`⏰ Next realistic notification in ${minutesDelay} minutes`);

        setTimeout(async () => {
            console.log(`\n🎭 [${new Date().toLocaleTimeString()}] Sending realistic mock notifications...`);
            try {
                await sendMockNotifications();
            } catch (error) {
                console.error('❌ Error in mock notifications:', error);
            }

            // Schedule the next one
            scheduleNextMockNotification();
        }, randomDelay);
    }

    // Start the cycle
    scheduleNextMockNotification();

    // Also send one immediately on startup
    console.log('🚀 Sending initial realistic mock notification...');
    setTimeout(async () => {
        try {
            await sendMockNotifications();
        } catch (error) {
            console.error('❌ Error in initial mock notification:', error);
        }
    }, 5000); // 5 seconds after startup
}

// Run once immediately on startup
console.log('🚀 Running initial monitoring cycle...');
runAllMonitors();

// Helper function to show next run time
function getNextRunTime(cronExpression) {
    const parts = cronExpression.split(' ');
    const minutes = parts[0];

    if (minutes.startsWith('*/')) {
        const interval = parseInt(minutes.substring(2));
        const now = new Date();
        const nextRun = new Date(now);
        const currentMinute = now.getMinutes();
        const nextMinute = Math.ceil(currentMinute / interval) * interval;
        nextRun.setMinutes(nextMinute);
        nextRun.setSeconds(0);

        if (nextMinute >= 60) {
            nextRun.setHours(nextRun.getHours() + 1);
            nextRun.setMinutes(nextMinute - 60);
        }

        return nextRun.toLocaleTimeString();
    }

    return 'on schedule';
}

console.log('✅ Scheduler running. Press Ctrl+C to stop.');

// Handle graceful shutdown
process.on('SIGTERM', () => {
    console.log('\n👋 Shutting down scheduler...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('\n👋 Shutting down scheduler...');
    process.exit(0);
});
