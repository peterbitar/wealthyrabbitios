const express = require('express');
const router = express.Router();
const { holdings } = require('../database/models');

// Get user's holdings
router.get('/:userId', async (req, res) => {
    try {
        const { userId } = req.params;
        const userHoldings = await holdings.getByUser(userId);
        res.json(userHoldings);
    } catch (error) {
        console.error('Error fetching holdings:', error);
        res.status(500).json({ error: 'Failed to fetch holdings' });
    }
});

// Add or update holding
router.post('/', async (req, res) => {
    try {
        const { userId, symbol, name, allocation, note } = req.body;

        if (!userId || !symbol) {
            return res.status(400).json({ error: 'userId and symbol are required' });
        }

        const holding = await holdings.upsert(userId, symbol.toUpperCase(), {
            name,
            allocation,
            note
        });

        res.json({ success: true, holding });
    } catch (error) {
        console.error('Error adding holding:', error);
        res.status(500).json({ error: 'Failed to add holding' });
    }
});

// Delete holding
router.delete('/:userId/:symbol', async (req, res) => {
    try {
        const { userId, symbol } = req.params;
        await holdings.delete(userId, symbol.toUpperCase());
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting holding:', error);
        res.status(500).json({ error: 'Failed to delete holding' });
    }
});

// Get all unique symbols (for monitoring)
router.get('/symbols/all', async (req, res) => {
    try {
        const symbols = await holdings.getAllUniqueSymbols();
        res.json(symbols);
    } catch (error) {
        console.error('Error fetching symbols:', error);
        res.status(500).json({ error: 'Failed to fetch symbols' });
    }
});

module.exports = router;
