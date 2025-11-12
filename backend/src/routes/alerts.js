const express = require('express');
const router = express.Router();
const { alertLogs } = require('../database/models');

// Get user's recent alerts
router.get('/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const limit = parseInt(req.query.limit) || 50;

        const alerts = await alertLogs.getRecent(userId, limit);
        res.json(alerts);
    } catch (error) {
        console.error('Error fetching alerts:', error);
        res.status(500).json({ error: 'Failed to fetch alerts' });
    }
});

// Get today's alert count for user
router.get('/:userId/count/today', async (req, res) => {
    try {
        const { userId } = req.params;
        const count = await alertLogs.getTodayCount(userId);
        res.json({ count });
    } catch (error) {
        console.error('Error fetching alert count:', error);
        res.status(500).json({ error: 'Failed to fetch alert count' });
    }
});

module.exports = router;
