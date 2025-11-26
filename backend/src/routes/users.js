const express = require('express');
const router = express.Router();
const { users } = require('../database/models');

// Register or update user
router.post('/register', async (req, res) => {
    try {
        const { userId, name, pushToken } = req.body;

        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }

        let user = await users.create(userId, name);

        if (pushToken) {
            user = await users.updatePushToken(userId, pushToken);
        }

        res.json({ success: true, user });
    } catch (error) {
        console.error('Error registering user:', error);
        res.status(500).json({ error: 'Failed to register user' });
    }
});

// Update push token
router.post('/push-token', async (req, res) => {
    try {
        const { userId, pushToken } = req.body;

        if (!userId || !pushToken) {
            return res.status(400).json({ error: 'userId and pushToken are required' });
        }

        const user = await users.updatePushToken(userId, pushToken);
        res.json({ success: true, user });
    } catch (error) {
        console.error('Error updating push token:', error);
        res.status(500).json({ error: 'Failed to update push token' });
    }
});

// Update push token (iOS app format)
router.put('/:userId/push-token', async (req, res) => {
    try {
        const { userId } = req.params;
        const { pushToken } = req.body;

        if (!pushToken) {
            return res.status(400).json({ error: 'pushToken is required' });
        }

        await users.updatePushToken(userId, pushToken);
        console.log(`✅ Updated push token for user ${userId}: ${pushToken.substring(0, 20)}...`);
        res.json({});  // Empty response for iOS app
    } catch (error) {
        console.error('Error updating push token:', error);
        res.status(500).json({ error: 'Failed to update push token' });
    }
});

// Update notification settings
router.post('/settings', async (req, res) => {
    try {
        const { userId, notificationFrequency, notificationSensitivity, weeklySubmary } = req.body;

        if (!userId) {
            return res.status(400).json({ error: 'userId is required' });
        }

        const user = await users.updateSettings(userId, {
            notificationFrequency,
            notificationSensitivity,
            weeklySubmary
        });

        res.json({ success: true, user });
    } catch (error) {
        console.error('Error updating settings:', error);
        res.status(500).json({ error: 'Failed to update settings' });
    }
});

// Update notification settings (iOS app format)
router.put('/:userId/settings', async (req, res) => {
    try {
        const { userId } = req.params;
        const { notificationFrequency, notificationSensitivity, weeklySummary } = req.body;

        const user = await users.updateSettings(userId, {
            notificationFrequency,
            notificationSensitivity,
            weeklySummary
        });

        res.json({ success: true, user });
    } catch (error) {
        console.error('Error updating settings:', error);
        res.status(500).json({ error: 'Failed to update settings' });
    }
});

// Get user
router.get('/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const user = await users.getByUserId(userId);

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json(user);
    } catch (error) {
        console.error('Error fetching user:', error);
        res.status(500).json({ error: 'Failed to fetch user' });
    }
});

module.exports = router;
