/**
 * Sensitivity threshold mappings based on user preferences
 */

const SENSITIVITY_THRESHOLDS = {
    // Price movement thresholds (15-minute change)
    price: {
        calm: 3.0,    // Only alert on 3%+ moves
        curious: 2.0,  // Alert on 2%+ moves (default)
        alert: 1.0     // Alert on 1%+ moves
    },

    // Social buzz spike multipliers (vs 7-day baseline)
    social: {
        calm: 3.0,    // Only alert on 3× spike
        curious: 2.0,  // Alert on 2× spike (default)
        alert: 1.5     // Alert on 1.5× spike
    },

    // News source tiers
    newsTiers: {
        calm: ['tier1'],           // Only Reuters, FT, Bloomberg, WSJ
        curious: ['tier1', 'tier2'], // + CNBC, MarketWatch, Seeking Alpha
        alert: ['tier1', 'tier2', 'tier3'] // + most reputable domains
    }
};

// News source classification
const NEWS_SOURCES = {
    tier1: [
        'reuters.com',
        'ft.com',
        'bloomberg.com',
        'wsj.com',
        'financial-times'
    ],
    tier2: [
        'cnbc.com',
        'marketwatch.com',
        'seekingalpha.com',
        'barrons.com',
        'investor.com',
        'morningstar.com'
    ],
    tier3: [
        'forbes.com',
        'businessinsider.com',
        'thestreet.com',
        'benzinga.com',
        'fool.com',
        'investing.com'
    ]
};

function getPriceThreshold(sensitivity) {
    return SENSITIVITY_THRESHOLDS.price[sensitivity] || SENSITIVITY_THRESHOLDS.price.curious;
}

function getSocialThreshold(sensitivity) {
    return SENSITIVITY_THRESHOLDS.social[sensitivity] || SENSITIVITY_THRESHOLDS.social.curious;
}

function getAllowedNewsTiers(sensitivity) {
    return SENSITIVITY_THRESHOLDS.newsTiers[sensitivity] || SENSITIVITY_THRESHOLDS.newsTiers.curious;
}

function getSourceTier(sourceDomain) {
    for (const [tier, domains] of Object.entries(NEWS_SOURCES)) {
        if (domains.some(domain => sourceDomain.toLowerCase().includes(domain))) {
            return tier;
        }
    }
    return null; // Unknown source
}

function shouldAlertOnNews(sourceDomain, userSensitivity) {
    const sourceTier = getSourceTier(sourceDomain);
    if (!sourceTier) return false; // Don't alert on unknown sources

    const allowedTiers = getAllowedNewsTiers(userSensitivity);
    return allowedTiers.includes(sourceTier);
}

function shouldAlertOnPrice(changePercent, userSensitivity) {
    const threshold = getPriceThreshold(userSensitivity);
    return Math.abs(changePercent) >= threshold;
}

function shouldAlertOnSocial(spikeMultiple, userSensitivity) {
    const threshold = getSocialThreshold(userSensitivity);
    return spikeMultiple >= threshold;
}

module.exports = {
    getPriceThreshold,
    getSocialThreshold,
    getAllowedNewsTiers,
    getSourceTier,
    shouldAlertOnNews,
    shouldAlertOnPrice,
    shouldAlertOnSocial,
    SENSITIVITY_THRESHOLDS,
    NEWS_SOURCES
};
