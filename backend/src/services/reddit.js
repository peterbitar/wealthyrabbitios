const axios = require('axios');
require('dotenv').config();

class RedditService {
    constructor() {
        this.userAgent = 'WealthyRabbit/1.0';
        this.baseURL = 'https://www.reddit.com';
    }

    async searchMentions(symbol, subreddits = ['stocks', 'investing', 'wallstreetbets']) {
        try {
            let totalCount = 0;
            const allPosts = [];

            for (const subreddit of subreddits) {
                const { count, posts } = await this.searchSubreddit(symbol, subreddit);
                totalCount += count;
                allPosts.push(...posts);
            }

            // Sort by score and take top posts
            const topPosts = allPosts
                .sort((a, b) => b.score - a.score)
                .slice(0, 5)
                .map(post => ({
                    title: post.title,
                    url: post.url,
                    score: post.score,
                    subreddit: post.subreddit
                }));

            return {
                count: totalCount,
                topPosts
            };

        } catch (error) {
            console.error(`Error searching Reddit for ${symbol}:`, error.message);
            return {
                count: 0,
                topPosts: []
            };
        }
    }

    async searchSubreddit(symbol, subreddit) {
        try {
            const url = `${this.baseURL}/r/${subreddit}/search.json`;

            const response = await axios.get(url, {
                params: {
                    q: symbol,
                    restrict_sr: 1,
                    t: 'hour',  // Last hour
                    sort: 'hot',
                    limit: 100
                },
                headers: {
                    'User-Agent': this.userAgent
                },
                timeout: 10000
            });

            const posts = response.data.data.children;
            let count = 0;
            const matchingPosts = [];

            posts.forEach(post => {
                const data = post.data;
                const titleUpper = data.title.toUpperCase();
                const selfTextUpper = (data.selftext || '').toUpperCase();

                // Check if symbol is mentioned in title or body
                if (titleUpper.includes(symbol) || selfTextUpper.includes(symbol)) {
                    count++;
                    matchingPosts.push({
                        title: data.title,
                        url: `https://reddit.com${data.permalink}`,
                        score: data.score,
                        subreddit: data.subreddit,
                        created: data.created_utc
                    });
                }
            });

            return { count, posts: matchingPosts };

        } catch (error) {
            console.error(`Error searching r/${subreddit} for ${symbol}:`, error.message);
            return { count: 0, posts: [] };
        }
    }

    async getHotPosts(subreddit = 'stocks', limit = 25) {
        try {
            const url = `${this.baseURL}/r/${subreddit}/hot.json`;

            const response = await axios.get(url, {
                params: { limit },
                headers: {
                    'User-Agent': this.userAgent
                },
                timeout: 10000
            });

            return response.data.data.children.map(post => ({
                title: post.data.title,
                url: `https://reddit.com${post.data.permalink}`,
                score: post.data.score,
                subreddit: post.data.subreddit
            }));

        } catch (error) {
            console.error(`Error fetching hot posts from r/${subreddit}:`, error.message);
            return [];
        }
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = new RedditService();
