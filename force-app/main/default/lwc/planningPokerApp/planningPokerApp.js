import { LightningElement, track } from 'lwc';

export default class PlanningPokerApp extends LightningElement {
    @track currentView = 'roomList';
    @track selectedRoomId = null;
    @track showHelp = false;

    // View getters
    get showHeader() {
        return this.currentView !== 'estimationSession';
    }

    get contentClass() {
        return this.isEstimationSessionView ? 'app-content full-width' : 'app-content';
    }

    get isRoomListView() {
        return this.currentView === 'roomList';
    }

    get isRoomCreationView() {
        return this.currentView === 'roomCreation';
    }

    get isRoomDashboardView() {
        return this.currentView === 'roomDashboard';
    }

    get isEstimationSessionView() {
        return this.currentView === 'estimationSession';
    }

    get isTeamsView() {
        return this.currentView === 'teams';
    }

    get isReportsView() {
        return this.currentView === 'reports';
    }

    // Button variant getters
    get roomListVariant() {
        return this.currentView === 'roomList' ? 'brand' : 'neutral';
    }

    get teamsVariant() {
        return this.currentView === 'teams' ? 'brand' : 'neutral';
    }

    get reportsVariant() {
        return this.currentView === 'reports' ? 'brand' : 'neutral';
    }

    // Navigation handlers
    handleNavigate(event) {
        const view = event.target.dataset.view;
        this.currentView = view;
        if (view === 'roomList') {
            this.selectedRoomId = null;
        }
    }

    handleRoomSelect(event) {
        this.selectedRoomId = event.detail.roomId;
        this.currentView = 'roomDashboard';
    }

    handleCreateRoom() {
        this.currentView = 'roomCreation';
    }

    handleRoomCreated(event) {
        this.selectedRoomId = event.detail.roomId;
        this.currentView = 'roomDashboard';
    }

    handleCancelCreate() {
        this.currentView = 'roomList';
    }

    handleBackToList() {
        this.selectedRoomId = null;
        this.currentView = 'roomList';
    }

    handleStartSession() {
        this.currentView = 'estimationSession';
    }

    handleBackToRoom() {
        this.currentView = 'roomDashboard';
    }

    handleSessionEnd() {
        this.currentView = 'roomDashboard';
    }

    // Help panel
    toggleHelp() {
        this.showHelp = !this.showHelp;
    }

    // Real-time event handlers
    handleVoteEvent(event) {
        // Safely check if event and detail exist
        if (!event || !event.detail) {
            console.warn('Invalid vote event received');
            return;
        }

        if (this.isEstimationSessionView) {
            const session = this.template.querySelector('c-estimation-session');
            if (session && session.handleVoteEvent) {
                session.handleVoteEvent(event.detail);
            }
        }
    }

    handleMemberEvent(event) {
        // Safely check if event exists
        if (!event) {
            console.warn('Invalid member event received');
            return;
        }

        if (this.isRoomListView) {
            const roomList = this.template.querySelector('c-room-list');
            if (roomList && roomList.refresh) {
                roomList.refresh();
            }
        } else if (this.isRoomDashboardView) {
            const dashboard = this.template.querySelector('c-room-dashboard');
            if (dashboard && dashboard.handleMemberEvent) {
                dashboard.handleMemberEvent(event);
            }
        } else if (this.isEstimationSessionView) {
            const session = this.template.querySelector('c-estimation-session');
            if (session && session.handleMemberEvent) {
                session.handleMemberEvent(event);
            }
        }
    }

    handleStoryEvent(event) {
        // Safely check if event and detail exist
        if (!event || !event.detail) {
            console.warn('Invalid story event received');
            return;
        }

        const action = event.detail.Action__c;

        // Refresh room list if story count changes
        if (this.isRoomListView) {
            const roomList = this.template.querySelector('c-room-list');
            if (roomList && roomList.refresh) {
                roomList.refresh();
            }
        } else if (this.isRoomDashboardView) {
            const dashboard = this.template.querySelector('c-room-dashboard');
            if (dashboard && dashboard.handleRefresh) {
                dashboard.handleRefresh();
            }
        } else if (this.isEstimationSessionView) {
            const session = this.template.querySelector('c-estimation-session');
            if (session) {
                // For story_changed/story_selected events, call the dedicated handler
                if (action === 'story_changed' || action === 'story_selected' || action === 'activated') {
                    if (session.handleStoryChangedEvent) {
                        session.handleStoryChangedEvent(event);
                    }
                } else {
                    // For other story events, refresh the session data
                    if (session.loadSessionData) {
                        session.loadSessionData();
                    }
                }
            }
        }
    }

    handleRoomEvent(event) {
        // Safely check if event and detail exist
        if (!event || !event.detail) {
            console.warn('Invalid room event received');
            return;
        }

        const action = event.detail.Action__c;
        console.log(`[PlanningPokerApp] Received Room Event: ${action}`, event.detail);

        // Refresh room list on status changes
        if (this.isRoomListView || 
            action === 'status_updated' || 
            action === 'session_started' || 
            action === 'session_ended' ||
            action === 'session_paused' ||
            action === 'session_resumed') {
            const roomList = this.template.querySelector('c-room-list');
            if (roomList && roomList.refresh) {
                roomList.refresh();
            }
        } else if (this.isRoomDashboardView) {
            const dashboard = this.template.querySelector('c-room-dashboard');
            if (dashboard && dashboard.handleRoomEvent) {
                dashboard.handleRoomEvent(event);
            }
        } else if (this.isEstimationSessionView) {
            // Forward room events (including session end/pause/timer) to the session
            // The session component now handles its own delay and celebration before signaling an exit
            const session = this.template.querySelector('c-estimation-session');
            if (session && session.handleRoomEvent) {
                session.handleRoomEvent(event);
            }
        }
    }

    handlePresenceEvent(event) {
        // Safely check if event exists
        if (!event) {
            console.warn('Invalid presence event received');
            return;
        }

        if (this.isEstimationSessionView) {
            const session = this.template.querySelector('c-estimation-session');
            if (session && session.handlePresenceEvent) {
                session.handlePresenceEvent(event);
            }
        }
    }
}