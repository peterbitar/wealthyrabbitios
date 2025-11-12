const db = require('./connection');

// User operations
const users = {
    async create(userId, name = 'User') {
        const result = await db.query(
            'INSERT INTO app_user (user_id, name) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP RETURNING *',
            [userId, name]
        );
        return result.rows[0];
    },

    async updatePushToken(userId, pushToken) {
        const result = await db.query(
            'UPDATE app_user SET push_token = $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2 RETURNING *',
            [pushToken, userId]
        );
        return result.rows[0];
    },

    async updateSettings(userId, settings) {
        const { notificationFrequency, notificationSensitivity, weeklySubmary } = settings;
        const result = await db.query(
            `UPDATE app_user
             SET notification_frequency = $1,
                 notification_sensitivity = $2,
                 weekly_summary = $3,
                 updated_at = CURRENT_TIMESTAMP
             WHERE user_id = $4 RETURNING *`,
            [notificationFrequency, notificationSensitivity, weeklySubmary, userId]
        );
        return result.rows[0];
    },

    async getByUserId(userId) {
        const result = await db.query('SELECT * FROM app_user WHERE user_id = $1', [userId]);
        return result.rows[0];
    },

    async getAllWithPushTokens() {
        const result = await db.query('SELECT * FROM app_user WHERE push_token IS NOT NULL');
        return result.rows;
    }
};

// Holdings operations
const holdings = {
    async upsert(userId, symbol, data) {
        const { name, allocation, note } = data;
        const result = await db.query(
            `INSERT INTO holding (user_id, symbol, name, allocation, note)
             VALUES ($1, $2, $3, $4, $5)
             ON CONFLICT (user_id, symbol)
             DO UPDATE SET name = $3, allocation = $4, note = $5
             RETURNING *`,
            [userId, symbol, name, allocation, note]
        );
        return result.rows[0];
    },

    async getByUser(userId) {
        const result = await db.query(
            'SELECT * FROM holding WHERE user_id = $1 ORDER BY symbol',
            [userId]
        );
        return result.rows;
    },

    async delete(userId, symbol) {
        await db.query('DELETE FROM holding WHERE user_id = $1 AND symbol = $2', [userId, symbol]);
    },

    async getAllUniqueSymbols() {
        const result = await db.query('SELECT DISTINCT symbol FROM holding ORDER BY symbol');
        return result.rows.map(row => row.symbol);
    }
};

// Price point operations
const pricePoints = {
    async create(symbol, price, changePercent, volume) {
        const result = await db.query(
            'INSERT INTO price_point (symbol, price, change_percent, volume) VALUES ($1, $2, $3, $4) RETURNING *',
            [symbol, price, changePercent, volume]
        );
        return result.rows[0];
    },

    async getRecent(symbol, minutes = 15) {
        const result = await db.query(
            `SELECT * FROM price_point
             WHERE symbol = $1
             AND timestamp > NOW() - INTERVAL '${minutes} minutes'
             ORDER BY timestamp DESC`,
            [symbol]
        );
        return result.rows;
    },

    async getLatest(symbol) {
        const result = await db.query(
            'SELECT * FROM price_point WHERE symbol = $1 ORDER BY timestamp DESC LIMIT 1',
            [symbol]
        );
        return result.rows[0];
    },

    async cleanup(daysOld = 7) {
        await db.query(
            `DELETE FROM price_point WHERE timestamp < NOW() - INTERVAL '${daysOld} days'`
        );
    }
};

// Alert log operations
const alertLogs = {
    async create(userId, alertType, symbol, contentHash, data) {
        const { title, message, url, metadata } = data;
        const result = await db.query(
            `INSERT INTO alert_log (user_id, alert_type, symbol, content_hash, title, message, url, metadata)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
            [userId, alertType, symbol, contentHash, title, message, url, JSON.stringify(metadata)]
        );
        return result.rows[0];
    },

    async exists(contentHash) {
        const result = await db.query(
            'SELECT id FROM alert_log WHERE content_hash = $1',
            [contentHash]
        );
        return result.rows.length > 0;
    },

    async getTodayCount(userId) {
        const result = await db.query(
            `SELECT COUNT(*) as count FROM alert_log
             WHERE user_id = $1
             AND sent_at > CURRENT_DATE`,
            [userId]
        );
        return parseInt(result.rows[0].count);
    },

    async getRecent(userId, limit = 50) {
        const result = await db.query(
            'SELECT * FROM alert_log WHERE user_id = $1 ORDER BY sent_at DESC LIMIT $2',
            [userId, limit]
        );
        return result.rows;
    }
};

// News items operations
const newsItems = {
    async create(symbol, data) {
        const { title, url, source, sourceTier, publishedAt, contentHash } = data;
        try {
            const result = await db.query(
                `INSERT INTO news_item (symbol, title, url, source, source_tier, published_at, content_hash)
                 VALUES ($1, $2, $3, $4, $5, $6, $7)
                 ON CONFLICT (url) DO NOTHING
                 RETURNING *`,
                [symbol, title, url, source, sourceTier, publishedAt, contentHash]
            );
            return result.rows[0];
        } catch (error) {
            // Ignore duplicate key errors
            if (error.code === '23505') return null;
            throw error;
        }
    },

    async getRecent(symbol, hours = 24) {
        const result = await db.query(
            `SELECT * FROM news_item
             WHERE symbol = $1
             AND fetched_at > NOW() - INTERVAL '${hours} hours'
             ORDER BY published_at DESC`,
            [symbol]
        );
        return result.rows;
    }
};

// Social mentions operations
const socialMentions = {
    async create(symbol, data) {
        const { mentionCount, subreddit, periodStart, periodEnd, baseline7day } = data;
        const result = await db.query(
            `INSERT INTO social_mention (symbol, mention_count, subreddit, period_start, period_end, baseline_7day)
             VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
            [symbol, mentionCount, subreddit, periodStart, periodEnd, baseline7day]
        );
        return result.rows[0];
    },

    async getBaseline(symbol, subreddit, days = 7) {
        const result = await db.query(
            `SELECT AVG(mention_count) as average
             FROM social_mention
             WHERE symbol = $1
             AND subreddit = $2
             AND period_start > NOW() - INTERVAL '${days} days'`,
            [symbol, subreddit]
        );
        return parseFloat(result.rows[0].average) || 0;
    },

    async getRecent(symbol, hours = 24) {
        const result = await db.query(
            `SELECT * FROM social_mention
             WHERE symbol = $1
             AND period_start > NOW() - INTERVAL '${hours} hours'
             ORDER BY period_start DESC`,
            [symbol]
        );
        return result.rows;
    }
};

module.exports = {
    users,
    holdings,
    pricePoints,
    alertLogs,
    newsItems,
    socialMentions
};
