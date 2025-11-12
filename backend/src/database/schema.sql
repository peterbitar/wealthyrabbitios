-- WealthyRabbit PostgreSQL Schema
-- Drop tables if they exist (for development)
DROP TABLE IF EXISTS social_mention CASCADE;
DROP TABLE IF EXISTS news_item CASCADE;
DROP TABLE IF EXISTS alert_log CASCADE;
DROP TABLE IF EXISTS price_point CASCADE;
DROP TABLE IF EXISTS holding CASCADE;
DROP TABLE IF EXISTS app_user CASCADE;

-- Users table
CREATE TABLE app_user (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) UNIQUE NOT NULL,  -- From iOS (UUID)
    name VARCHAR(255) DEFAULT 'User',
    push_token VARCHAR(500),  -- APNs device token
    notification_frequency VARCHAR(20) DEFAULT 'balanced',  -- quiet, balanced, active
    notification_sensitivity VARCHAR(20) DEFAULT 'curious',  -- calm, curious, alert
    weekly_summary BOOLEAN DEFAULT true,
    max_daily_pushes INTEGER DEFAULT 5,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Holdings table
CREATE TABLE holding (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES app_user(user_id) ON DELETE CASCADE,
    symbol VARCHAR(10) NOT NULL,
    name VARCHAR(255),
    allocation DECIMAL(5,2),  -- Percentage
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, symbol)
);

-- Price points for tracking 15-minute movements
CREATE TABLE price_point (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    price DECIMAL(12,4) NOT NULL,
    change_percent DECIMAL(8,4),
    volume BIGINT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_symbol_timestamp ON price_point(symbol, timestamp);

-- Alert log for deduplication and rate limiting
CREATE TABLE alert_log (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) REFERENCES app_user(user_id) ON DELETE CASCADE,
    alert_type VARCHAR(20) NOT NULL,  -- price, news, social
    symbol VARCHAR(10),
    content_hash VARCHAR(64) NOT NULL,  -- For deduplication
    title TEXT,
    message TEXT,
    url TEXT,
    metadata JSONB,  -- Store alert-specific data
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_user_date ON alert_log(user_id, sent_at);
CREATE INDEX idx_content_hash ON alert_log(content_hash);

-- News items cache
CREATE TABLE news_item (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    title TEXT NOT NULL,
    url TEXT UNIQUE NOT NULL,
    source VARCHAR(255),
    source_tier VARCHAR(10),  -- tier1, tier2, tier3
    published_at TIMESTAMP,
    content_hash VARCHAR(64) UNIQUE,
    fetched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_symbol_published ON news_item(symbol, published_at);

-- Social mentions baseline tracking
CREATE TABLE social_mention (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(10) NOT NULL,
    mention_count INTEGER DEFAULT 0,
    subreddit VARCHAR(50),
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    baseline_7day DECIMAL(10,2),  -- 7-day average for comparison
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_symbol_period ON social_mention(symbol, period_start);

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for app_user
CREATE TRIGGER update_app_user_updated_at
    BEFORE UPDATE ON app_user
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Sample data for testing
INSERT INTO app_user (user_id, name, notification_frequency, notification_sensitivity)
VALUES ('test-user-123', 'Peter', 'balanced', 'curious');

INSERT INTO holding (user_id, symbol, name, allocation, note)
VALUES
    ('test-user-123', 'AAPL', 'Apple Inc.', 25.0, 'Core tech holding'),
    ('test-user-123', 'NVDA', 'NVIDIA Corporation', 15.0, 'AI exposure'),
    ('test-user-123', 'TSLA', 'Tesla Inc.', 10.0, 'Speculative');
