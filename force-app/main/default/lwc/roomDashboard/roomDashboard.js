import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import getRoomDetails from '@salesforce/apex/RoomController.getRoomDetails';
import updateRoomStatus from '@salesforce/apex/RoomController.updateRoomStatus';
import addRoomMembers from '@salesforce/apex/RoomController.addRoomMembers';
import searchUsers from '@salesforce/apex/TeamController.searchUsers';
import getVoteHistory from '@salesforce/apex/VotingController.getVoteHistory';
import getStoriesByRoom from '@salesforce/apex/StoryController.getStoriesByRoom';

export default class RoomDashboard extends LightningElement {
    @api roomId;
    @track roomDetails = {};
    @track stories = [];
    @track isLoading = true;
    @track processedMembers = [];

    // Add Members Modal state
    @track showAddMembersModal = false;
    @track searchTerm = '';
    @track searchResults = [];
    @track selectedMembers = [];
    @track isSearching = false;
    searchTimeout;
    searchTimeout;

    // Session timer state
    @track liveSessionDuration = '00:00:00';
    sessionTimerInterval = null;

    @track voteHistory = [];
    @track expandedStories = new Set();
    @track isLoadingHistory = false;
    @track currentUserHasVoted = false;

    @track error;


    connectedCallback() {
        this.handleRefresh();
        this.startSessionTimer();
        this.loadVoteHistory();
    }

    disconnectedCallback() {
        this.stopSessionTimer();
    }



    // Sound effects using Web Audio API
    playSound(type) {
        try {
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();

            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);

            // Different sounds for different events
            switch(type) {
                case 'start':
                    // Ascending chime
                    oscillator.frequency.setValueAtTime(523.25, audioContext.currentTime); // C5
                    oscillator.frequency.exponentialRampToValueAtTime(783.99, audioContext.currentTime + 0.1); // G5
                    gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
                    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3);
                    oscillator.start(audioContext.currentTime);
                    oscillator.stop(audioContext.currentTime + 0.3);
                    break;
                case 'pause':
                    // Descending tone
                    oscillator.frequency.setValueAtTime(659.25, audioContext.currentTime); // E5
                    oscillator.frequency.exponentialRampToValueAtTime(523.25, audioContext.currentTime + 0.15); // C5
                    gainNode.gain.setValueAtTime(0.25, audioContext.currentTime);
                    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.2);
                    oscillator.start(audioContext.currentTime);
                    oscillator.stop(audioContext.currentTime + 0.2);
                    break;
                case 'resume':
                    // Quick ascending beep
                    oscillator.frequency.setValueAtTime(587.33, audioContext.currentTime); // D5
                    oscillator.frequency.exponentialRampToValueAtTime(698.46, audioContext.currentTime + 0.08); // F5
                    gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
                    gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.15);
                    oscillator.start(audioContext.currentTime);
                    oscillator.stop(audioContext.currentTime + 0.15);
                    break;
                case 'end':
                    // Success chime (3 notes)
                    const playNote = (freq, delay, duration) => {
                        const osc = audioContext.createOscillator();
                        const gain = audioContext.createGain();
                        osc.connect(gain);
                        gain.connect(audioContext.destination);
                        osc.frequency.setValueAtTime(freq, audioContext.currentTime + delay);
                        gain.gain.setValueAtTime(0.25, audioContext.currentTime + delay);
                        gain.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + delay + duration);
                        osc.start(audioContext.currentTime + delay);
                        osc.stop(audioContext.currentTime + delay + duration);
                    };
                    playNote(523.25, 0, 0.15);    // C5
                    playNote(659.25, 0.12, 0.15); // E5
                    playNote(783.99, 0.24, 0.3);  // G5
                    break;
            }
        } catch (error) {
            console.error('Error playing sound:', error);
        }
    }



    startSessionTimer() {
        if (this.sessionTimerInterval) return;

        this.sessionTimerInterval = setInterval(() => {
            this.updateLiveSessionDuration();
        }, 1000);
    }

    stopSessionTimer() {
        if (this.sessionTimerInterval) {
            clearInterval(this.sessionTimerInterval);
            this.sessionTimerInterval = null;
        }
    }

    updateLiveSessionDuration() {
        const startDateTime = this.roomDetails?.room?.Start_DateTime__c;
        const endDateTime = this.roomDetails?.room?.End_DateTime__c;
        const status = this.roomDetails?.room?.Status__c;

        if (!startDateTime) {
            this.liveSessionDuration = '00:00:00';
            return;
        }

        const start = new Date(startDateTime);
        let end;

        // If session is completed or paused, use end time or current time frozen
        if (status === 'Completed' && endDateTime) {
            end = new Date(endDateTime);
            // Stop the timer for completed sessions
            this.stopSessionTimer();
        } else if (status === 'Paused') {
            // For paused, show current duration but stop counting
            end = new Date();
            this.stopSessionTimer();
        } else {
            // Active session - keep counting
            end = new Date();
        }

        const diffMs = end - start;

        if (diffMs < 0) {
            this.liveSessionDuration = '00:00:00';
            return;
        }

        const totalSeconds = Math.floor(diffMs / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;

        this.liveSessionDuration = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }

    get showSessionTimer() {
        const status = this.roomDetails?.room?.Status__c;
        return status === 'Active' || status === 'Paused' || status === 'Completed';
    }

    get isSessionActive() {
        return this.roomDetails?.room?.Status__c === 'Active';
    }

    get isSessionPausedOrCompleted() {
        const status = this.roomDetails?.room?.Status__c;
        return status === 'Paused' || status === 'Completed';
    }

    // Chart data for pie chart
    get pieChartData() {
        const estimated = this.estimatedStories || 0;
        const pending = this.pendingStories || 0;
        const total = estimated + pending;

        if (total === 0) return { estimated: 0, pending: 0, estimatedPercent: 0, pendingPercent: 0, total: 0 };

        const estimatedPercent = Math.round((estimated / total) * 100);

        return {
            estimated: estimated,
            pending: pending,
            total: total,
            estimatedPercent: estimatedPercent,
            pendingPercent: 100 - estimatedPercent,
            hasEstimated: estimated > 0,
            hasPending: pending > 0
        };
    }

    // CSS for pie chart segments
    get pieChartStyle() {
        const data = this.pieChartData;
        // Using a smooth conic-gradient for the pie chart
        // Estimated: Green (#10B981), Pending: Amber (#F59E0B)
        return `--pie-estimated: ${data.estimatedPercent}%; --pie-color-1: #10B981; --pie-color-2: #F59E0B;`;
    }

    // Get story estimates for bar chart
    get storyEstimatesForChart() {
        if (!this.roomDetails?.stories) return [];

        // Group stories by estimate value (use Final_Estimate__c presence, not status)
        const estimatesMap = new Map();
        this.roomDetails.stories.forEach(story => {
            if (story.Final_Estimate__c) {
                const est = story.Final_Estimate__c;
                estimatesMap.set(est, (estimatesMap.get(est) || 0) + 1);
            }
        });

        const chartData = Array.from(estimatesMap.entries())
            .map(([estimate, count]) => ({ estimate, count }));

        if (chartData.length === 0) return [];

        // Calculate max for scaling
        const maxCount = Math.max(...chartData.map(d => d.count), 1);
        const estimatedCount = this.estimatedStories || 1;

        // Electric Sunset Palette: Violet → Magenta → Ruby → Orange
        const premiumHues = [270, 310, 345, 12, 35]; 

        // Find the most frequent estimate for consensus highlighting
        const sortedData = [...chartData].sort((a,b) => b.count - a.count);
        const maxOccurrences = sortedData[0]?.count || 0;
        const consensusEstimate = sortedData[0]?.estimate;

        // Calculate bar heights (max 100px) and add style
        return chartData.map((item, index) => {
            const percentage = Math.round((item.count / estimatedCount) * 100);
            const hue = premiumHues[index % premiumHues.length];
            const barHeight = Math.round((item.count / maxCount) * 100);
            
            // Item is consensus if it's the most frequent and has > 1 occurrence or is the only one
            const isConsensus = item.estimate === consensusEstimate && (maxOccurrences > 1 || chartData.length === 1);

            return {
                ...item,
                percentage: percentage,
                barHeight: barHeight,
                isConsensus: isConsensus,
                tooltip: `${item.count} stories (${percentage}%) were estimated as ${item.estimate}`,
                tooltipMain: `${percentage}%`,
                tooltipSub: `${item.count} Votes`,
                barStyle: `--bar-height: ${barHeight}px; 
                           --bar-color: hsla(${hue}, 90%, 55%, 1.0); 
                           --bar-glow: hsla(${hue}, 90%, 55%, 0.45); 
                           --anim-delay: ${index * 0.12}s;`,
                itemClass: `bar-chart-item ${isConsensus ? 'is-consensus' : ''} ${isConsensus ? 'pulse-consensus' : ''}`
            };
        });
    }

    get complexityScore() {
        const avg = parseFloat(this.averageEstimate);
        if (isNaN(avg) || avg === 0) return 'LOW';
        if (avg > 8) return 'HIGH';
        if (avg > 3) return 'MED';
        return 'LOW';
    }

    get averageEstimate() {
        const estimatedStories = this.roomDetails?.stories?.filter(s => s.Status__c === 'Estimated' && s.Final_Estimate__c) || [];
        if (estimatedStories.length === 0) return '0.0';
        
        let sum = 0;
        let count = 0;
        
        estimatedStories.forEach(s => {
            const val = parseFloat(s.Final_Estimate__c);
            if (!isNaN(val)) {
                sum += val;
                count++;
            }
        });
        
        return count > 0 ? (sum / count).toFixed(1) : '0.0';
    }

    get hasChartData() {
        return this.storyEstimatesForChart && this.storyEstimatesForChart.length > 0;
    }

    // Process members to add display properties
    processMembersWithStatus() {
        if (this.roomDetails?.members && Array.isArray(this.roomDetails.members)) {
            this.processedMembers = this.roomDetails.members.map(member => {
                // Check if user is online/in session
                const isInSession = member.Is_Online__c === true;

                return {
                    ...member,
                    isInSession: isInSession,
                    statusClass: member.Can_Vote__c
                        ? 'member-status'
                        : 'member-status member-status-offline',
                    onlineStatusClass: isInSession
                        ? 'online-indicator online'
                        : 'online-indicator offline',
                    roleDisplay: `${member.Role_In_Room__c || 'Voter'}${member.Can_Vote__c ? ' • Can Vote' : ''}`,
                    // Format joined time for display
                    joinedTimeDisplay: this.formatMemberTime(member.Joined_Date__c),
                    lastActivityDisplay: this.formatMemberTime(member.Last_Activity__c)
                };
            });
            console.log('processedMembers Details:', JSON.stringify(this.processedMembers));
        } else {
            this.processedMembers = [];
        }
    }

    // Format member time for display
    formatMemberTime(dateTimeStr) {
        if (!dateTimeStr) return '';
        const dt = new Date(dateTimeStr);
        const now = new Date();
        const diffMs = now - dt;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;

        return dt.toLocaleDateString();
    }

    // ========== VOTE HISTORY METHODS ==========

    async loadVoteHistory() {
        if (!this.roomId) return;

        this.isLoadingHistory = true;
        try {
            const history = await getVoteHistory({ roomId: this.roomId });
            this.voteHistory = this.formatVoteHistory(history);
        } catch (error) {
            console.error('Error loading vote history:', error);
        } finally {
            this.isLoadingHistory = false;
        }
    }

    formatVoteHistory(history) {
        if (!history || !Array.isArray(history)) return [];

        return history.map(item => {
            const isExpanded = this.expandedStories.has(item.storyId);
            const votes = (item.votes || []).map(vote => ({
                ...vote,
                formattedTime: this.formatMemberTime(vote.votedAt),
                formattedDuration: this.formatDuration(vote.duration),
                confidenceClass: this.getConfidenceClass(vote.confidence),
                confidenceLabel: this.getConfidenceLabel(vote.confidence),
                hasComment: !!vote.comment
            }));

            // Calculate status colors for the mini status line
            let statusColor = '#94a3b8'; // Neutral
            if (item.status === 'Estimated') statusColor = '#10B981';
            if (item.status === 'Discussing') statusColor = '#6366f1';
            if (item.status === 'Voting') statusColor = '#f59e0b';

            return {
                ...item,
                isExpanded: isExpanded,
                expandIcon: isExpanded ? 'utility:chevrondown' : 'utility:chevronright',
                statusStyle: `background-color: ${statusColor}; color: ${statusColor};`, 
                formattedDate: this.formatMemberTime(item.estimatedDate),
                votes: votes,
                hasVotes: votes.length > 0
            };
        });
    }

    formatDuration(seconds) {
        if (typeof seconds !== 'number') return '';
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }

    getConfidenceClass(confidence) {
        const classes = {
            'low': 'confidence-badge confidence-low',
            'medium': 'confidence-badge confidence-medium',
            'high': 'confidence-badge confidence-high'
        };
        return classes[confidence] || 'confidence-badge';
    }

    getConfidenceLabel(confidence) {
        const labels = {
            'low': 'Low',
            'medium': 'Med',
            'high': 'High'
        };
        return labels[confidence] || '';
    }

    getHistoryStatusClass(status) {
        const classes = {
            'Estimated': 'history-status history-estimated',
            'Discussing': 'history-status history-discussing',
            'Voting': 'history-status history-voting'
        };
        return classes[status] || 'history-status';
    }

    handleToggleStoryExpand(event) {
        const storyId = event.currentTarget.dataset.storyId;

        // Create a new Set to trigger reactivity
        const newExpandedStories = new Set(this.expandedStories);

        if (newExpandedStories.has(storyId)) {
            newExpandedStories.delete(storyId);
        } else {
            newExpandedStories.add(storyId);
        }

        this.expandedStories = newExpandedStories;
        // Re-format to update UI
        this.voteHistory = this.formatVoteHistory(this.voteHistory.map(item => ({
            ...item,
            isExpanded: undefined // Remove computed property before re-formatting
        })));
    }

    get hasVoteHistory() {
        return this.voteHistory && this.voteHistory.length > 0;
    }

    get noVoteHistory() {
        return !this.isLoadingHistory && (!this.voteHistory || this.voteHistory.length === 0);
    }

    get shouldShowVoteHistory() {
        const hasVotesInRoom = this.voteHistory && this.voteHistory.length > 0;
        const isCompleted = this.roomDetails?.room?.Status__c === 'Completed';
        return hasVotesInRoom || isCompleted;
    }

    get statusBadgeClass() {
        const status = this.roomDetails?.room?.Status__c || '';
        const classes = {
            'Draft': 'status-badge status-draft',
            'Active': 'status-badge status-active',
            'Paused': 'status-badge status-paused',
            'Completed': 'status-badge status-completed'
        };
        return classes[status] || 'status-badge';
    }

    get totalStories() {
        return this.roomDetails?.stories?.length || 0;
    }

    get estimatedStories() {
        // Count stories that have Final_Estimate__c (these show as 'Estimated')
        return this.roomDetails?.stories?.filter(s => s.Final_Estimate__c)?.length || 0;
    }

    get pendingStories() {
        // Count stories without Final_Estimate__c (these show as 'Pending' or 'Voting')
        return this.roomDetails?.stories?.filter(s => !s.Final_Estimate__c)?.length || 0;
    }

    get votingMembers() {
        return this.roomDetails?.votingMembers || 0;
    }

    get estimationProgress() {
        if (!this.totalStories) return 0;
        return Math.round((this.estimatedStories / this.totalStories) * 100);
    }

    get participationProgress() {
        const totalMembers = this.processedMembers ? this.processedMembers.length : 0;
        if (!totalMembers) return 0;
        return Math.round((this.votingMembers / totalMembers) * 100);
    }

    get formattedSessionDuration() {
        if (!this.roomDetails?.Start_DateTime__c) return '0h 0m';
        
        const start = new Date(this.roomDetails.Start_DateTime__c);
        const end = this.roomDetails.End_DateTime__c ? new Date(this.roomDetails.End_DateTime__c) : new Date();
        
        const diffMs = end - start;
        const diffMins = Math.floor(diffMs / 60000);
        const hours = Math.floor(diffMins / 60);
        const mins = diffMins % 60;
        
        if (hours > 0) return `${hours}h ${mins}m`;
        return `${mins}m`;
    }

    get hasMembers() {
        return this.processedMembers && this.processedMembers.length > 0;
    }

    get canStartSession() {
        return this.roomDetails?.room?.Status__c === 'Draft' && this.roomDetails?.isFacilitator;
    }

    get canResumeSession() {
        // Only show Resume when session is Paused
        return this.roomDetails?.room?.Status__c === 'Paused' && this.roomDetails?.isFacilitator;
    }

    get canEnterSession() {
        // Allow entering an active session (for all members)
        return this.roomDetails?.room?.Status__c === 'Active';
    }

    get isSessionCompleted() {
        return this.roomDetails?.room?.Status__c === 'Completed';
    }

    get hasRoomData() {
        // Show data if available, regardless of loading state (prevents flickering)
        return this.roomDetails && this.roomDetails.room;
    }

    get roomName() {
        return this.roomDetails?.room?.Name || '';
    }

    get roomCode() {
        return this.roomDetails?.room?.Room_Code__c || '';
    }

    get roomStatus() {
        return this.roomDetails?.room?.Status__c || '';
    }

    get showEmptyState() {
        return !this.isLoading && !this.hasRoomData && !this.error;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    async handleStartSession() {
        try {
            if (this.roomDetails?.room?.Status__c === 'Draft') {
                await updateRoomStatus({ roomId: this.roomId, status: 'Active' });
                await this.handleRefresh();
            }
            this.dispatchEvent(new CustomEvent('startsession'));
        } catch (error) {
            console.error('Error starting session:', error);
            this.showToast('Error', error.body?.message || 'Failed to start session', 'error');
        }
    }

    async handleResumeSession() {
        try {
            // Resume from Paused state
            await updateRoomStatus({ roomId: this.roomId, status: 'Active' });
            await this.handleRefresh();
            this.dispatchEvent(new CustomEvent('startsession'));
        } catch (error) {
            console.error('Error resuming session:', error);
            this.showToast('Error', error.body?.message || 'Failed to resume session', 'error');
        }
    }

    handleEnterSession() {
        // Enter an already active session
        this.dispatchEvent(new CustomEvent('startsession'));
    }

    get canAddMembers() {
        return !this.isSessionCompleted;
    }

    get isAddMembersDisabled() {
        return this.isSessionCompleted;
    }

    handleAddMembers() {
        if (this.isSessionCompleted) return;
        this.showAddMembersModal = true;
        this.searchTerm = '';
        this.searchResults = [];
        this.selectedMembers = [];
    }

    handleCloseAddMembersModal() {
        this.showAddMembersModal = false;
        this.searchTerm = '';
        this.searchResults = [];
        this.selectedMembers = [];
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;

        // Clear previous timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }

        // Debounce search
        if (this.searchTerm.length >= 2) {
            this.searchTimeout = setTimeout(() => {
                this.performSearch();
            }, 300);
        } else {
            this.searchResults = [];
        }
    }

    async performSearch() {
        this.isSearching = true;
        try {
            const results = await searchUsers({ searchTerm: this.searchTerm });

            // Get existing member IDs
            const existingMemberIds = new Set(
                (this.roomDetails?.members || []).map(m => m.User__c)
            );
            const selectedIds = new Set(this.selectedMembers.map(m => m.Id));

            // Mark users who are already members or selected
            this.searchResults = results.map(user => ({
                ...user,
                isAlreadyMember: existingMemberIds.has(user.Id) || selectedIds.has(user.Id)
            }));
        } catch (error) {
            console.error('Error searching users:', error);
            this.showToast('Error', 'Failed to search users', 'error');
        } finally {
            this.isSearching = false;
        }
    }

    handleAddUser(event) {
        const userId = event.target.dataset.userId;
        const user = this.searchResults.find(u => u.Id === userId);

        if (user && !this.selectedMembers.find(m => m.Id === userId)) {
            this.selectedMembers = [...this.selectedMembers, user];

            // Update search results to disable the added user
            this.searchResults = this.searchResults.map(u => ({
                ...u,
                isAlreadyMember: u.Id === userId ? true : u.isAlreadyMember
            }));
        }
    }

    handleRemoveSelectedMember(event) {
        const userId = event.target.name;
        this.selectedMembers = this.selectedMembers.filter(m => m.Id !== userId);

        // Update search results to re-enable the removed user
        this.searchResults = this.searchResults.map(u => ({
            ...u,
            isAlreadyMember: u.Id === userId ? false : u.isAlreadyMember
        }));
    }

    async handleSaveMembers() {
        if (this.selectedMembers.length === 0) return;

        this.isLoading = true;
        try {
            const memberDataList = this.selectedMembers.map(member => ({
                userId: member.Id,
                role: 'Voter',
                canVote: true
            }));

            await addRoomMembers({ roomId: this.roomId, memberDataList });

            this.showToast('Success', `${this.selectedMembers.length} member(s) added successfully`, 'success');

            // Close modal first
            this.handleCloseAddMembersModal();

            // Force refresh the room details by re-fetching
            await this.handleRefresh();

        } catch (error) {
            console.error('Error adding members:', error);
            this.showToast('Error', error.body?.message || 'Failed to add members', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Getters for Add Members Modal
    get hasSearchResults() {
        return !this.isSearching && this.searchResults.length > 0;
    }

    get noSearchResults() {
        return !this.isSearching && this.searchTerm.length >= 2 && this.searchResults.length === 0;
    }

    get hasSelectedMembers() {
        return this.selectedMembers.length > 0;
    }

    get noSelectedMembers() {
        return this.selectedMembers.length === 0;
    }

    get selectedMembersCount() {
        return this.selectedMembers.length;
    }

    
    async handleRefresh() {
        try {
            // Update room details imperatively
            const roomData = await getRoomDetails({ roomId: this.roomId });
            if (roomData) {
                this.roomDetails = JSON.parse(JSON.stringify(roomData));
                this.currentUserHasVoted = roomData.currentUserHasVoted || false;
                this.error = undefined;
                this.processMembersWithStatus();
            }
            
            // Always fetch stories imperatively since they are not in the wire
            const storiesData = await getStoriesByRoom({ roomId: this.roomId });
            this.stories = storiesData;
            
            // We can still attach to roomDetails for the charts if needed, or update charts to use this.stories
            this.roomDetails = { ...this.roomDetails, stories: this.stories }; 
            
        } catch (error) {
            console.error('Error refreshing data:', error);
            // Don't show toast on background refreshes to avoid spamming
        } finally {
            this.isLoading = false;
            // Notify parent that dashboard has loaded
            this.dispatchEvent(new CustomEvent('loaded'));
        }
    }

    // Real-time event handlers for platform events

    refreshStoryManager() {
        console.log('Refreshing Story Manager...');
        const storyManager = this.template.querySelector('c-story-manager');
        if (storyManager) {
            storyManager.refresh();
        } else {
            console.warn('StoryManager component not found to refresh');
        }
    }

    // Story events
    handleStoryCreated(event) {
        const payload = event.detail;
        this.showToast('Story Created', `${payload.Story_Title__c} was added`, 'info');
        this.handleRefresh();
        this.refreshStoryManager();
    }

    handleStoryUpdated(event) {
        const payload = event.detail;
        this.showToast('Story Updated', `${payload.Story_Title__c} was updated`, 'info');
        this.handleRefresh();
        this.refreshStoryManager();
    }

    handleStoryDeleted(event) {
        const payload = event.detail;
        this.showToast('Story Deleted', `A story was removed`, 'info');
        this.handleRefresh();
        this.refreshStoryManager();
    }

    // Member events
    handleMemberJoined(event) {
        const payload = event.detail;
        this.showToast('Member Joined', `${payload.User_Name__c} joined the room`, 'success');
        this.handleRefresh();
    }

    handleMemberLeft(event) {
        const payload = event.detail;
        this.showToast('Member Left', `${payload.User_Name__c} left the room`, 'info');
        this.handleRefresh();
    }

    // Session status events
    handleStatusUpdated(event) {
        const payload = event.detail;
        this.handleRefresh();
    }

    handleSessionStarted(event) {
        const payload = event.detail;
        this.playSound('start');
        this.showToast('Session Started', 'The estimation session has started', 'success');
        this.startSessionTimer();
        this.handleRefresh();
    }

    handleSessionEnded(event) {
        const payload = event.detail;
        this.playSound('end');
        this.stopSessionTimer();
        this.handleRefresh();
    }

    handleSessionPaused(event) {
        const payload = event.detail;
        this.playSound('pause');
        this.showToast('Session Paused', 'The session has been paused', 'info');
        this.stopSessionTimer();
        this.handleRefresh();
    }

    handleSessionResumed(event) {
        const payload = event.detail;
        this.playSound('resume');
        this.showToast('Session Resumed', 'The session has resumed', 'success');
        this.startSessionTimer();
        this.handleRefresh();
    }

    // Vote events
    handleVoteEvent(event) {
        // Refresh to get updated stats if needed
        this.handleRefresh();
        // Check if votes were revealed and refresh history
        if (event?.detail?.Action__c === 'votes_revealed') {
            this.loadVoteHistory();
        }
    }

    handleEstimateFinalized(event) {
        const payload = event.detail;
        this.showToast('Estimate Finalized', `Story estimate finalized: ${payload.Final_Estimate__c}`, 'success');
        this.handleRefresh(); // Updates charts
        this.refreshStoryManager(); // Updates story list status
        this.loadVoteHistory(); // Updates vote history
    }

    // Presence events
    handlePresenceChanged(event) {
        const payload = event.detail;
        // Update member presence status without showing toast (too noisy)
        this.processMembersWithStatus();
    }

    // Legacy event handlers (kept for backward compatibility)
    @api
    handleMemberEvent(event) {
        this.handleRefresh();
    }

    @api
    handleRoomEvent(event) {
        const action = event.detail?.Action__c;
        // Refresh on any status change for real-time updates
        if (action === 'session_started' ||
            action === 'session_paused' ||
            action === 'session_resumed' ||
            action === 'session_ended' ||
            action === 'status_updated') {

            // Handle timer state based on session status
            if (action === 'session_ended' || action === 'session_paused') {
                // Stop the timer immediately for all users
                this.stopSessionTimer();
            } else if (action === 'session_started' || action === 'session_resumed') {
                // Restart the timer for all users
                this.startSessionTimer();
            }

            // Refresh data to get latest room details including End_DateTime__c
            this.handleRefresh();
        }
    }

    showToast(title, message, variant) {
        // this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}