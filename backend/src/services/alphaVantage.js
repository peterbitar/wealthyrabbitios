const axios = require('axios');
require('dotenv').config();

const API_KEY = process.env.ALPHA_VANTAGE_API_KEY;
const BASE_URL = 'https://www.alphavantage.co/query';

// Note: Free tier = 25 requests/day, 5 requests/minute
// Cache aggressively to stay within limits

class AlphaVantageService {
    constructor() {
        this.requestCount = 0;
        this.lastRequestTime = null;
    }

    async getQuote(symbol) {
        try {
            // Rate limiting check (5 per minute)
            await this.rateLimit();

            const response = await axios.get(BASE_URL, {
                params: {
                    function: 'GLOBAL_QUOTE',
                    symbol: symbol,
                    apikey: API_KEY
                },
                timeout: 10000
            });

            this.requestCount++;

            const quote = response.data['Global Quote'];

            if (!quote || Object.keys(quote).length === 0) {
                console.error(`No quote data for ${symbol}:`, response.data);
                return null;
            }

            return {
                symbol: quote['01. symbol'],
                price: parseFloat(quote['05. price']),
                changePercent: parseFloat(quote['10. change percent'].replace('%', '')),
                volume: parseInt(quote['06. volume']),
                latestTradingDay: quote['07. latest trading day'],
                timestamp: new Date()
            };
        } catch (error) {
            console.error(`Error fetching quote for ${symbol}:`, error.message);
            return null;
        }
    }

    async getQuotes(symbols) {
        const quotes = [];

        for (const symbol of symbols) {
            const quote = await this.getQuote(symbol);
            if (quote) {
                quotes.push(quote);
            }

            // Small delay between requests
            await this.delay(12000); // 12 seconds = 5 req/min max
        }

        return quotes;
    }

    async rateLimit() {
        const now = Date.now();

        // Reset counter every minute
        if (this.lastRequestTime && (now - this.lastRequestTime) > 60000) {
            this.requestCount = 0;
        }

        // Wait if we've hit the limit
        if (this.requestCount >= 5) {
            const waitTime = 60000 - (now - this.lastRequestTime);
            if (waitTime > 0) {
                console.log(`Rate limit reached, waiting ${waitTime}ms`);
                await this.delay(waitTime);
                this.requestCount = 0;
            }
        }

        this.lastRequestTime = now;
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    // Calculate 15-minute change from price points
    calculate15MinChange(currentPrice, pricePoints) {
        if (!pricePoints || pricePoints.length === 0) {
            return null;
        }

        // Find price from 15 minutes ago
        const fifteenMinAgo = new Date(Date.now() - 15 * 60 * 1000);
        const oldPoint = pricePoints.find(p => new Date(p.timestamp) <= fifteenMinAgo);

        if (!oldPoint) {
            return null;
        }

        const oldPrice = parseFloat(oldPoint.price);
        const changePercent = ((currentPrice - oldPrice) / oldPrice) * 100;

        return {
            currentPrice,
            oldPrice,
            changePercent: parseFloat(changePercent.toFixed(2)),
            minutesAgo: Math.round((Date.now() - new Date(oldPoint.timestamp)) / 60000)
        };
    }
}

module.exports = new AlphaVantageService();
