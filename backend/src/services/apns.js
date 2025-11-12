const apn = require('apn');
require('dotenv').config();

class APNsService {
    constructor() {
        this.provider = null;
        this.isConfigured = false;

        // Check if APNs is configured
        if (process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID && process.env.APNS_KEY_PATH) {
            this.initializeProvider();
        } else {
            console.warn('⚠️  APNs not configured. Push notifications will be simulated.');
        }
    }

    initializeProvider() {
        try {
            const options = {
                token: {
                    key: process.env.APNS_KEY_PATH,
                    keyId: process.env.APNS_KEY_ID,
                    teamId: process.env.APNS_TEAM_ID
                },
                production: process.env.APNS_PRODUCTION === 'true'
            };

            this.provider = new apn.Provider(options);
            this.isConfigured = true;
            console.log('✅ APNs provider initialized');
        } catch (error) {
            console.error('❌ Failed to initialize APNs provider:', error.message);
            this.isConfigured = false;
        }
    }

    async sendNotification(deviceToken, payload) {
        if (!deviceToken) {
            console.warn('⚠️  No device token provided');
            return { sent: false, reason: 'no_device_token' };
        }

        // If APNs not configured, simulate notification
        if (!this.isConfigured) {
            console.log(`📱 [SIMULATED] Push to ${deviceToken.substring(0, 10)}...`);
            console.log(`   Title: ${payload.title}`);
            console.log(`   Body: ${payload.body}`);
            console.log(`   Data:`, payload.data);
            return { sent: true, simulated: true };
        }

        try {
            const notification = new apn.Notification();
            notification.alert = { title: payload.title, body: payload.body };
            if (payload.badge !== undefined) notification.badge = payload.badge;
            notification.sound = payload.sound || 'default';
            if (payload.data) notification.payload = payload.data;
            notification.topic = payload.bundleId || 'com.wealthyrabbit.app';

            const result = await this.provider.send(notification, deviceToken);

            if (result.failed && result.failed.length > 0) {
                const failure = result.failed[0];
                console.error('❌ APNs send failed:', failure.response);
                return { sent: false, reason: failure.response.reason, error: failure.response };
            }

            console.log(`✅ Push sent to ${deviceToken.substring(0, 10)}...`);
            return { sent: true, result };
        } catch (error) {
            console.error('❌ Error sending push:', error.message);
            return { sent: false, error: error.message };
        }
    }

    async sendToMultiple(deviceTokens, payload) {
        const results = { total: deviceTokens.length, sent: 0, failed: 0, errors: [] };
        for (const token of deviceTokens) {
            const result = await this.sendNotification(token, payload);
            if (result.sent) results.sent++;
            else { results.failed++; results.errors.push({ token: token.substring(0, 10) + '...', reason: result.reason || result.error }); }
            await this.delay(100);
        }
        return results;
    }

    isValidToken(token) {
        if (!token || typeof token !== 'string') return false;
        return /^[a-f0-9]{64}$/i.test(token);
    }

    async shutdown() {
        if (this.provider) {
            await this.provider.shutdown();
            console.log('✅ APNs provider shut down');
        }
    }

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

module.exports = new APNsService();
