#!/bin/bash

echo "🐇 WealthyRabbit Backend Setup"
echo "==============================="
echo ""

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL not found. Installing..."
    brew install postgresql@15
    brew services start postgresql@15
    echo "✅ PostgreSQL installed and started"
else
    echo "✅ PostgreSQL already installed"
fi

# Check if database exists
if psql -lqt | cut -d \| -f 1 | grep -qw wealthyrabbit; then
    echo "✅ Database 'wealthyrabbit' already exists"
else
    echo "📊 Creating database..."
    createdb wealthyrabbit
    echo "✅ Database created"
fi

# Load schema
echo "📋 Loading database schema..."
psql wealthyrabbit < src/database/schema.sql
echo "✅ Schema loaded"

# Install npm dependencies
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo "✅ Dependencies installed"
else
    echo "✅ Dependencies already installed"
fi

# Test database connection
echo ""
echo "🔍 Testing database connection..."
psql wealthyrabbit -c "SELECT COUNT(*) as users FROM app_user;"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start the server: npm run dev"
echo "  2. In another terminal, test: curl http://localhost:3000/health"
echo "  3. Run monitoring jobs: npm run jobs"
echo ""
