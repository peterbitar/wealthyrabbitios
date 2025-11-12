const axios = require('axios');
const { getSourceTier } = require('../utils/sensitivity');
require('dotenv').config();

const API_KEY = process.env.NEWS_API_KEY;
const BASE_URL = 'https://newsapi.org/v2/everything';

class NewsAPIService {
    constructor() {
        this.requestCount = 0;
        this.lastRequestTime = null;
    }

    async fetchNews(symbol, hoursAgo = 24) {
        try {
            const from = new Date(Date.now() - hoursAgo * 60 * 60 * 1000).toISOString();

            const response = await axios.get(BASE_URL, {
                params: {
                    q: symbol,
                    from: from,
                    language: 'en',
                    sortBy: 'publishedAt',
                    apiKey: API_KEY
                },
                timeout: 10000
            });

            this.requestCount++;

            if (!response.data.articles) {
                console.error(`No articles found for ${symbol}`);
                return [];
            }

            // Map articles and add source tier
            const articles = response.data.articles.map(article => {
                const sourceTier = this.getSourceTier(article.url || article.source.name);

                return {
                    title: article.title,
                    url: article.url,
                    source: article.source.name,
                    sourceTier: sourceTier,
                    publishedAt: article.publishedAt,
                    description: article.description,
                    content: article.content
                };
            });

            // Filter out articles without a tier (unknown sources)
            return articles.filter(a => a.sourceTier !== null);

        } catch (error) {
            console.error(`Error fetching news for ${symbol}:`, error.message);
            return [];
        }
    }

    async fetchNewsForSymbols(symbols, hoursAgo = 24) {
        const allNews = [];

        for (const symbol of symbols) {
            const news = await this.fetchNews(symbol, hoursAgo);
            allNews.push(...news.map(n => ({ ...n, symbol })));

            // Small delay to avoid rate limits
            await this.delay(1000);
        }

        return allNews;
    }

    getSourceTier(sourceUrl) {
        const source = sourceUrl.toLowerCase();

        // Tier 1 - Most trusted
        const tier1 = ['reuters', 'ft.com', 'bloomberg', 'wsj.com', 'financial-times'];
        if (tier1.some(s => source.includes(s))) return 'tier1';

        // Tier 2 - Mainstream finance
        const tier2 = ['cnbc', 'marketwatch', 'seekingalpha', 'barrons', 'investor.com', 'morningstar'];
        if (tier2.some(s => source.includes(s))) return 'tier2';

        // Tier 3 - Reputable but less rigorous
        const tier3 = ['forbes', 'businessinsider', 'thestreet', 'benzinga', 'fool.com', 'investing.com'];
        if (tier3.some(s => source.includes(s))) return 'tier3';

        // Unknown source - don't use
        return null;
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = new NewsAPIService();
