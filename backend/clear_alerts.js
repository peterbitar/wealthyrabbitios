const db = require('./src/database/connection');

async function clearTodayAlerts() {
    try {
        const today = new Date().toISOString().split('T')[0];
        
        console.log(`🧹 Clearing alerts for today (${today})...`);
        
        const result = await db.query(
            'DELETE FROM alert_log WHERE DATE(sent_at) = $1',
            [today]
        );
        
        console.log(`✅ Cleared ${result.rowCount} alerts from today`);
        
        // Show remaining count
        const remaining = await db.query(
            'SELECT COUNT(*) as count FROM alert_log WHERE DATE(sent_at) = $1',
            [today]
        );
        
        console.log(`📊 Alerts remaining today: ${remaining.rows[0].count}`);
        
        process.exit(0);
    } catch (error) {
        console.error('❌ Error clearing alerts:', error);
        process.exit(1);
    }
}

clearTodayAlerts();
