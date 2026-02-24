import { LightningElement, api, track } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class RealtimeEventHandler extends LightningElement {
    @api showDebug = false;

    @track lastEventTime;
    @track isConnected = false;
    @track connectionError = null;

    // Internal roomId storage
    _roomId = null;
    _isSubscribed = false;
    _retryCount = 0;
    _maxRetries = 3;
    _retryDelay = 2000;

    // Subscription references
    voteSubscription = null;
    roomSubscription = null;
    storySubscription = null;
    presenceSubscription = null;

    // Channel names
    voteChannel = '/event/Poker_Vote_Event__e';
    roomChannel = '/event/Poker_Room_Event__e';
    storyChannel = '/event/Poker_Story_Event__e';
    presenceChannel = '/event/Poker_Presence_Event__e';

    // Getter and setter for roomId to handle reactive changes
    @api
    get roomId() {
        return this._roomId;
    }

    set roomId(value) {
        this._roomId = value;

        // If we haven't subscribed yet, do it now.
        // If we ARE subscribed, we don't need to resubscribe because our channels are global.
        // The handlers will automatically start/stop filtering based on the new _roomId.
        if (!this._isSubscribed) {
            this.logDebug('Subscribing for the first time...');
            this.initializeSubscriptions();
        } else {
            this.logDebug(`Room ID updated to ${value}. Filtering will adjust accordingly.`);
        }
    }

    connectedCallback() {
        this.registerErrorListener();

        // Always initialize subscriptions to catch global/list events
        if (!this._isSubscribed) {
            this.initializeSubscriptions();
        }
    }

    disconnectedCallback() {
        this.unsubscribeFromAllChannels();
    }

    @api
    async refresh() {
        await this.resubscribe();
    }

    async resubscribe() {
        await this.unsubscribeFromAllChannels();
        await this.initializeSubscriptions();
    }

    registerErrorListener() {
        onError(error => {
            console.error('EMP API Error:', JSON.stringify(error));
            this.connectionError = error;
            this.isConnected = false;

            // Attempt to reconnect
            this.attemptReconnect();
        });
    }

    async attemptReconnect() {
        if (this._retryCount >= this._maxRetries) {
            console.error(`Max reconnection attempts (${this._maxRetries}) reached`);
            return;
        }

        this._retryCount++;
        this.logDebug(`Attempting reconnection (${this._retryCount}/${this._maxRetries})...`);

        // Wait before retrying
        await new Promise(resolve => setTimeout(resolve, this._retryDelay * this._retryCount));

        try {
            await this.resubscribe();
            this._retryCount = 0; // Reset on success
        } catch (error) {
            console.error('Reconnection failed:', error);
            this.attemptReconnect();
        }
    }

    async initializeSubscriptions() {
        // We no longer block on _roomId being set to allow for global/home page events
        try {
            await this.subscribeToAllChannels();
            this._isSubscribed = true;
            this.isConnected = true;
            this.connectionError = null;
            this._retryCount = 0;
            this.logDebug('Real-time subscriptions initialized successfully.');
        } catch (error) {
            console.error('Failed to initialize subscriptions:', error);
            this.connectionError = error;
            this.attemptReconnect();
        }
    }

    async subscribeToAllChannels() {
        try {
            this.logDebug(`Subscribing to channels for room: ${this._roomId}`);

            // Use -2 to get all available retained events, or -1 for only new events
            // -2 = Get all retained events (last 24 hours for high-volume events, up to 72 hours for standard)
            // -1 = Get only new events from this point forward
            // For real-time collaboration, -1 is correct BUT we need all users subscribed BEFORE events happen
            // The real issue is that users need to be subscribed to see events
            const replayId = -1;

            // Subscribe to vote events
            this.voteSubscription = await subscribe(
                this.voteChannel,
                replayId,
                (message) => {
                    this.handleVoteEvent(message);
                }
            );
            this.logDebug('Subscribed to vote channel');

            // Subscribe to room events
            this.roomSubscription = await subscribe(
                this.roomChannel,
                replayId,
                (message) => {
                    this.handleRoomEvent(message);
                }
            );
            this.logDebug('Subscribed to room channel');

            // Subscribe to story events
            this.storySubscription = await subscribe(
                this.storyChannel,
                replayId,
                (message) => {
                    this.handleStoryEvent(message);
                }
            );
            this.logDebug('Subscribed to story channel');

            // Subscribe to presence events
            this.presenceSubscription = await subscribe(
                this.presenceChannel,
                replayId,
                (message) => {
                    this.handlePresenceEvent(message);
                }
            );
            this.logDebug('Subscribed to presence channel');

            console.log(`[RealtimeEventHandler] Successfully subscribed to all channels.`);
        } catch (error) {
            console.error('Error subscribing to channels:', error);
            throw error;
        }
    }

    async unsubscribeFromAllChannels() {
        this._isSubscribed = false;

        try {
            // Helper function to safely unsubscribe
            const safeUnsubscribe = async (subscription, name) => {
                if (subscription && subscription.callback) {
                    try {
                        await unsubscribe(subscription);
                        this.logDebug(`Unsubscribed from ${name}`);
                    } catch (error) {
                        console.error(`Error unsubscribing from ${name}:`, error);
                    }
                }
            };

            // Unsubscribe from all channels
            if (this.voteSubscription) {
                await safeUnsubscribe(this.voteSubscription, 'vote channel');
                this.voteSubscription = null;
            }
            if (this.roomSubscription) {
                await safeUnsubscribe(this.roomSubscription, 'room channel');
                this.roomSubscription = null;
            }
            if (this.storySubscription) {
                await safeUnsubscribe(this.storySubscription, 'story channel');
                this.storySubscription = null;
            }
            if (this.presenceSubscription) {
                await safeUnsubscribe(this.presenceSubscription, 'presence channel');
                this.presenceSubscription = null;
            }

            this.logDebug('Finished unsubscribing from all channels');
        } catch (error) {
            console.error('Error unsubscribing from channels:', error);
        }
    }

    handleVoteEvent(message) {
        try {
            if (!message || !message.data || !message.data.payload) {
                console.error('Invalid vote event message structure:', message);
                return;
            }

            const payload = message.data.payload;

            // Filter by room if one is specified
            if (this._roomId && payload.Room_Id__c !== this._roomId) {
                return;
            }

            this.logDebug(`Vote Event received: ${payload.Action__c}`, payload);
            this.updateLastEventTime();

            const action = payload.Action__c;

            switch (action) {
                case 'voted':
                    this.dispatchEvent(new CustomEvent('votereceived', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'vote_updated':
                    this.dispatchEvent(new CustomEvent('voteupdated', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'vote_deleted':
                    this.dispatchEvent(new CustomEvent('votedeleted', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'votes_revealed':
                    this.dispatchEvent(new CustomEvent('votesrevealed', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'votes_reset':
                    this.dispatchEvent(new CustomEvent('votesreset', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'estimate_finalized':
                    this.dispatchEvent(new CustomEvent('estimatefinalized', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                default:
                    this.logDebug('Unknown vote action:', action);
            }
        } catch (error) {
            console.error('Error handling vote event:', error);
        }
    }

    handleRoomEvent(message) {
        try {
            if (!message || !message.data || !message.data.payload) {
                console.error('Invalid room event message structure:', message);
                return;
            }

            const payload = message.data.payload;

            // Filter by room
            if (this._roomId && payload.Room_Id__c !== this._roomId) {
                return;
            }

            this.logDebug(`Room Event received: ${payload.Action__c}`, payload);
            this.updateLastEventTime();

            const action = payload.Action__c;

            switch (action) {
                case 'member_joined':
                    this.dispatchEvent(new CustomEvent('memberjoined', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'member_left':
                    this.dispatchEvent(new CustomEvent('memberleft', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'story_selected':
                case 'story_changed':
                    this.dispatchEvent(new CustomEvent('storychanged', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'status_updated':
                    this.dispatchEvent(new CustomEvent('statusupdated', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'session_started':
                    this.dispatchEvent(new CustomEvent('sessionstarted', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'session_ended':
                    this.dispatchEvent(new CustomEvent('sessionended', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'session_paused':
                    this.dispatchEvent(new CustomEvent('sessionpaused', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                case 'session_resumed':
                    this.dispatchEvent(new CustomEvent('sessionresumed', {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;

                // Timer events
                case 'timer_started':
                case 'timer_paused':
                case 'timer_resumed':
                case 'timer_stopped': {
                    const eventName = action.replace('_', '');
                    this.dispatchEvent(new CustomEvent(eventName, {
                        detail: payload,
                        bubbles: true,
                        composed: true
                    }));
                    break;
                }

                default:
                    this.logDebug('Unknown room action:', action);
            }
        } catch (error) {
            console.error('Error handling room event:', error);
        }
    }

    handleStoryEvent(message) {
        try {
            if (!message || !message.data || !message.data.payload) {
                console.error('Invalid story event message structure:', message);
                return;
            }

            const payload = message.data.payload;

            // Filter by room
            if (this._roomId && payload.Room_Id__c !== this._roomId) {
                return;
            }

            this.logDebug(`Story Event received: ${payload.Action__c}`, payload);
            this.updateLastEventTime();

            const action = payload.Action__c;

            const safeDispatch = (eventName, detail) => {
                try {
                    this.dispatchEvent(new CustomEvent(eventName, {
                        detail: detail,
                        bubbles: true,
                        composed: true
                    }));
                } catch (dispatchError) {
                    console.error(`Error dispatching ${eventName}:`, dispatchError);
                }
            };

            switch (action) {
                case 'created':
                    safeDispatch('storycreated', payload);
                    break;

                case 'updated':
                    safeDispatch('storyupdated', payload);
                    break;

                case 'deleted':
                    safeDispatch('storydeleted', payload);
                    break;

                case 'activated':
                    safeDispatch('storyactivated', payload);
                    break;

                case 'estimated':
                    safeDispatch('storyestimated', payload);
                    break;

                case 'skipped':
                    safeDispatch('storyskipped', payload);
                    break;

                case 'reordered':
                    safeDispatch('storiesreordered', payload);
                    break;

                default:
                    this.logDebug('Unknown story action:', action);
            }
        } catch (error) {
            console.error('Error handling story event:', error);
        }
    }

    handlePresenceEvent(message) {
        try {
            if (!message || !message.data || !message.data.payload) {
                console.error('Invalid presence event message structure:', message);
                return;
            }

            const payload = message.data.payload;

            // Filter by room
            if (this._roomId && payload.Room_Id__c !== this._roomId) {
                return;
            }

            this.logDebug(`Presence Event received: ${payload.Status__c}`, payload);
            this.updateLastEventTime();

            this.dispatchEvent(new CustomEvent('presencechanged', {
                detail: payload,
                bubbles: true,
                composed: true
            }));
        } catch (error) {
            console.error('Error handling presence event:', error);
        }
    }

    updateLastEventTime() {
        this.lastEventTime = new Date().toLocaleTimeString();
    }

    logDebug(message, data) {
        if (this.showDebug) {
            if (data) {
                console.log(`[RealtimeEventHandler] ${message}`, data);
            } else {
                console.log(`[RealtimeEventHandler] ${message}`);
            }
        }
    }
}