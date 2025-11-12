const { alertLogs, users } = require('../database/models');

class RateLimiter {
    /**
     * Check if user has reached their daily push notification limit
     * @param {string} userId
     * @returns {Promise<{allowed: boolean, count: number, limit: number}>}
     */
    async canSendPush(userId) {
        const user = await users.getByUserId(userId);
        if (!user) {
            return { allowed: false, count: 0, limit: 0, reason: 'User not found' };
        }

        const limit = user.max_daily_pushes || 5;
        const count = await alertLogs.getTodayCount(userId);

        return {
            allowed: count < limit,
            count,
            limit,
            remaining: Math.max(0, limit - count)
        };
    }

    /**
     * Check and increment (atomically check before sending)
     * @param {string} userId
     * @returns {Promise<boolean>} - True if push is allowed
     */
    async checkAndReserve(userId) {
        const status = await this.canSendPush(userId);
        return status.allowed;
    }

    /**
     * Get user's daily push status
     * @param {string} userId
     * @returns {Promise<Object>}
     */
    async getStatus(userId) {
        return await this.canSendPush(userId);
    }

    /**
     * Create a digest message for overflow alerts
     * @param {Array} pendingAlerts - Alerts that couldn't be sent
     * @returns {Object} - Digest message
     */
    createDigest(pendingAlerts) {
        const byType = {
            price: [],
            news: [],
            social: []
        };

        // Group by type
        pendingAlerts.forEach(alert => {
            if (byType[alert.type]) {
                byType[alert.type].push(alert);
            }
        });

        // Create summary
        const summary = [];

        if (byType.price.length > 0) {
            const symbols = byType.price.map(a => a.symbol).join(', ');
            summary.push(`Price moves: ${symbols}`);
        }

        if (byType.news.length > 0) {
            const count = byType.news.length;
            summary.push(`${count} news ${count === 1 ? 'article' : 'articles'}`);
        }

        if (byType.social.length > 0) {
            const symbols = [...new Set(byType.social.map(a => a.symbol))].join(', ');
            summary.push(`Social buzz: ${symbols}`);
        }

        return {
            type: 'digest',
            title: 'Daily Digest',
            message: `You've reached your daily notification limit. Here's what you missed: ${summary.join(' • ')}`,
            count: pendingAlerts.length,
            alerts: pendingAlerts
        };
    }
}

module.exports = new RateLimiter();
