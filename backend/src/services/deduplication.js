const crypto = require('crypto');
const { alertLogs } = require('../database/models');

class DeduplicationService {
    /**
     * Generate a unique hash for alert content
     * @param {string} symbol - Stock symbol
     * @param {string} title - Alert title or news headline
     * @param {string} url - Source URL (optional)
     * @param {number} timestamp - Timestamp in milliseconds
     * @returns {string} SHA-256 hash
     */
    generateContentHash(symbol, title, url = '', timestamp) {
        // Round timestamp to nearest hour to prevent duplicates within same hour
        const roundedTimestamp = Math.floor(timestamp / (60 * 60 * 1000));

        const content = `${symbol}:${title}:${url}:${roundedTimestamp}`;
        return crypto
            .createHash('sha256')
            .update(content)
            .digest('hex');
    }

    /**
     * Check if an alert with this content hash already exists
     * @param {string} contentHash
     * @returns {Promise<boolean>}
     */
    async isDuplicate(contentHash) {
        return await alertLogs.exists(contentHash);
    }

    /**
     * Generate hash and check if duplicate in one call
     * @param {string} symbol
     * @param {string} title
     * @param {string} url
     * @param {number} timestamp
     * @returns {Promise<{hash: string, isDuplicate: boolean}>}
     */
    async checkDuplicate(symbol, title, url = '', timestamp = Date.now()) {
        const hash = this.generateContentHash(symbol, title, url, timestamp);
        const isDuplicate = await this.isDuplicate(hash);

        return { hash, isDuplicate };
    }

    /**
     * Generate hash for a price alert
     * Price alerts are unique per symbol + hour
     */
    generatePriceHash(symbol, timestamp = Date.now()) {
        const hourTimestamp = Math.floor(timestamp / (60 * 60 * 1000));
        const content = `price:${symbol}:${hourTimestamp}`;
        return crypto
            .createHash('sha256')
            .update(content)
            .digest('hex');
    }

    /**
     * Generate hash for a news alert
     * News alerts are unique by URL
     */
    generateNewsHash(url) {
        return crypto
            .createHash('sha256')
            .update(`news:${url}`)
            .digest('hex');
    }

    /**
     * Generate hash for a social alert
     * Social alerts are unique per symbol + hour
     */
    generateSocialHash(symbol, timestamp = Date.now()) {
        const hourTimestamp = Math.floor(timestamp / (60 * 60 * 1000));
        const content = `social:${symbol}:${hourTimestamp}`;
        return crypto
            .createHash('sha256')
            .update(content)
            .digest('hex');
    }
}

module.exports = new DeduplicationService();
