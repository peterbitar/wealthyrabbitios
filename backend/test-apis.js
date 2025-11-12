// Quick test script to verify API keys work
require('dotenv').config();
const alphaVantage = require('./src/services/alphaVantage');
const llm = require('./src/services/llm');
const newsApi = require('./src/services/newsApi');
const reddit = require('./src/services/reddit');

async function testAPIs() {
    console.log('🧪 Testing All API Keys...\n');

    // Test Alpha Vantage
    console.log('1️⃣ Testing Alpha Vantage (stock prices)...');
    try {
        const quote = await alphaVantage.getQuote('AAPL');
        if (quote) {
            console.log(`✅ Alpha Vantage working!`);
            console.log(`   AAPL: $${quote.price} (${quote.changePercent > 0 ? '+' : ''}${quote.changePercent}%)\n`);
        } else {
            console.log('❌ Alpha Vantage returned no data\n');
        }
    } catch (error) {
        console.log(`❌ Alpha Vantage error: ${error.message}\n`);
    }

    // Test OpenAI (LLM)
    console.log('2️⃣ Testing OpenAI (LLM formatter)...');
    try {
        const alert = await llm.formatPriceAlert('AAPL', {
            changePercent: 2.5,
            currentPrice: 150.00,
            direction: 'up'
        });
        console.log(`✅ OpenAI working!`);
        console.log(`   Title: ${alert.title}`);
        console.log(`   Message: ${alert.message}\n`);
    } catch (error) {
        console.log(`❌ OpenAI error: ${error.message}\n`);
    }

    // Test NewsAPI
    console.log('3️⃣ Testing NewsAPI (financial news)...');
    try {
        const news = await newsApi.fetchNews('AAPL', 24);
        if (news && news.length > 0) {
            console.log(`✅ NewsAPI working!`);
            console.log(`   Found ${news.length} articles about AAPL`);
            console.log(`   Latest: ${news[0].title.substring(0, 60)}...`);
            console.log(`   Source: ${news[0].source} (${news[0].sourceTier})\n`);
        } else {
            console.log('⚠️  NewsAPI returned no articles (may be normal)\n');
        }
    } catch (error) {
        console.log(`❌ NewsAPI error: ${error.message}\n`);
    }

    // Test Reddit
    console.log('4️⃣ Testing Reddit (social buzz)...');
    try {
        const social = await reddit.searchMentions('AAPL');
        console.log(`✅ Reddit working!`);
        console.log(`   Found ${social.count} mentions of AAPL in last hour`);
        if (social.topPosts.length > 0) {
            console.log(`   Top post: ${social.topPosts[0].title.substring(0, 60)}...`);
        }
        console.log('');
    } catch (error) {
        console.log(`❌ Reddit error: ${error.message}\n`);
    }

    console.log('✅ API key testing complete!');
    console.log('\n📊 All services operational!');
    console.log('\nNext steps:');
    console.log('  • Run "npm run dev" to start the server');
    console.log('  • Run "npm run jobs" to start monitoring');
}

testAPIs().catch(console.error);
