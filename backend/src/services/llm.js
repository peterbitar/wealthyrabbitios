const axios = require('axios');
require('dotenv').config();

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

class LLMService {
    constructor() {
        this.endpoint = 'https://api.openai.com/v1/chat/completions';
    }

    async formatPriceAlert(symbol, data) {
        const { changePercent, currentPrice, direction } = data;

        // STRICT RULE: Never let LLM generate numbers
        const systemPrompt = `You are a calm financial assistant. Format this price movement into 2-3 gentle, non-alarming sentences.

CRITICAL RULES:
- NEVER generate any numbers yourself
- Use ONLY the numbers provided in the user message
- No panic words ("crash", "plummet", "soar", "disaster")
- Use calm alternatives ("dipped", "rose", "steady", "gradual")
- End with a gentle question like "Want to understand why?"

Tone: Calm, reassuring, like talking to someone who gets anxious about money.`;

        const userMessage = `${symbol} ${direction === 'up' ? 'rose' : 'dipped'} ${Math.abs(changePercent)}% to $${currentPrice} in the last 15 minutes. This is a ${direction === 'up' ? 'steady upward' : 'gradual downward'} move.`;

        try {
            const response = await this.callOpenAI(systemPrompt, userMessage);
            return {
                message: response,
                title: `${symbol} ${direction === 'up' ? '↑' : '↓'} ${Math.abs(changePercent)}%`,
                symbol,
                changePercent,
                currentPrice,
                showSourcesButton: true,
                sourceUrl: `https://finance.yahoo.com/quote/${symbol}`
            };
        } catch (error) {
            console.error('LLM failed, using fallback template:', error.message);
            return this.fallbackPriceMessage(symbol, data);
        }
    }

    async formatNewsAlert(symbol, newsData) {
        const { title, source, url } = newsData;

        const systemPrompt = `You are a calm financial news explainer. Summarize this news in 2-3 calm sentences explaining WHY it matters to someone holding ${symbol}.

CRITICAL RULES:
- Be calm and reassuring
- Explain significance, not just facts
- No panic language
- End with "Want more context?" or similar

Tone: Like a wise friend explaining news over coffee.`;

        const userMessage = `News headline: "${title}" from ${source}. Explain why this matters for someone who owns ${symbol} stock.`;

        try {
            const response = await this.callOpenAI(systemPrompt, userMessage);
            return {
                message: response,
                title: `${symbol}: ${source} — ${title.substring(0, 50)}...`,
                symbol,
                showSourcesButton: true,
                sourceUrl: url
            };
        } catch (error) {
            console.error('LLM failed, using fallback template:', error.message);
            return this.fallbackNewsMessage(symbol, newsData);
        }
    }

    async formatSocialAlert(symbol, socialData) {
        const { spikeMultiple, mentionCount, topPosts } = socialData;

        const systemPrompt = `You are a calm social sentiment analyst. Explain this social media buzz in 2-3 reassuring sentences.

CRITICAL RULES:
- Don't create FOMO (fear of missing out)
- Distinguish hype from substance
- Be skeptical but curious
- No panic language

Tone: Like a savvy friend who's seen trends come and go.`;

        const userMessage = `${symbol} is being mentioned ${spikeMultiple}× more than usual on Reddit (${mentionCount} mentions in the last hour). Top discussion topics: ${topPosts.join(', ')}.`;

        try {
            const response = await this.callOpenAI(systemPrompt, userMessage);
            return {
                message: response,
                title: `${symbol} social chatter ↑ ${spikeMultiple}×`,
                symbol,
                showSourcesButton: true,
                sourceUrl: topPosts[0]?.url || `https://www.reddit.com/search/?q=${symbol}`
            };
        } catch (error) {
            console.error('LLM failed, using fallback template:', error.message);
            return this.fallbackSocialMessage(symbol, socialData);
        }
    }

    async callOpenAI(systemPrompt, userMessage) {
        const response = await axios.post(
            this.endpoint,
            {
                model: 'gpt-3.5-turbo',
                messages: [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: userMessage }
                ],
                temperature: 0.7,
                max_tokens: 150
            },
            {
                headers: {
                    'Authorization': `Bearer ${OPENAI_API_KEY}`,
                    'Content-Type': 'application/json'
                },
                timeout: 10000
            }
        );

        return response.data.choices[0].message.content.trim();
    }

    // Fallback templates if LLM fails
    fallbackPriceMessage(symbol, data) {
        const { changePercent, direction } = data;
        return {
            message: `${symbol} ${direction === 'up' ? 'moved up' : 'dipped'} ${Math.abs(changePercent)}% in the last 15 minutes. This is a ${direction === 'up' ? 'steady' : 'gradual'} move. Want to understand what's driving it?`,
            title: `${symbol} ${direction === 'up' ? '↑' : '↓'} ${Math.abs(changePercent)}%`,
            symbol,
            changePercent: data.changePercent,
            currentPrice: data.currentPrice,
            showSourcesButton: true,
            sourceUrl: `https://finance.yahoo.com/quote/${symbol}`
        };
    }

    fallbackNewsMessage(symbol, newsData) {
        return {
            message: `There's news about ${symbol} from ${newsData.source}. It might affect your holdings. Check the link for details.`,
            title: `${symbol}: ${newsData.source} update`,
            symbol,
            showSourcesButton: true,
            sourceUrl: newsData.url
        };
    }

    fallbackSocialMessage(symbol, socialData) {
        return {
            message: `${symbol} is being discussed ${socialData.spikeMultiple}× more than usual on social media. Might be worth a calm look.`,
            title: `${symbol} social chatter ↑`,
            symbol,
            showSourcesButton: true,
            sourceUrl: `https://www.reddit.com/search/?q=${symbol}`
        };
    }
}

module.exports = new LLMService();
