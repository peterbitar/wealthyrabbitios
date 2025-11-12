const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
const usersRoutes = require('./routes/users');
const holdingsRoutes = require('./routes/holdings');
const alertsRoutes = require('./routes/alerts');

app.use('/api/users', usersRoutes);
app.use('/api/holdings', holdingsRoutes);
app.use('/api/alerts', alertsRoutes);

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong!', message: err.message });
});

// Start server
app.listen(PORT, () => {
    console.log(`🐇 WealthyRabbit Backend running on port ${PORT}`);
    console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);

    // Start background scheduler for monitoring jobs and mock notifications
    console.log('🔄 Starting background job scheduler...');
    require('./jobs/scheduler');
});

module.exports = app;
