import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitVote from '@salesforce/apex/VotingController.submitVote';
import getVotesForStory from '@salesforce/apex/VotingController.getVotesForStory';
import revealVotes from '@salesforce/apex/VotingController.revealVotes';
import resetVotes from '@salesforce/apex/VotingController.resetVotes';
import finalizeEstimate from '@salesforce/apex/VotingController.finalizeEstimate';
import setStoryStatus from '@salesforce/apex/StoryController.setStoryStatus';
import broadcastTimer from '@salesforce/apex/VotingController.broadcastTimer';

// Helper to extract error message from various error formats
function getErrorMessage(error) {
    // Array of errors
    if (Array.isArray(error?.body)) {
        return error.body.map(e => e.message).join(', ');
    }
    // Single error with body.message
    if (error?.body?.message) {
        return error.body.message;
    }
    // UI API error format
    if (error?.body?.output?.errors) {
        return error.body.output.errors.map(e => e.message).join(', ');
    }
    // fieldErrors
    if (error?.body?.output?.fieldErrors) {
        const fieldErrors = Object.values(error.body.output.fieldErrors).flat();
        return fieldErrors.map(e => e.message).join(', ');
    }
    // Plain message property
    if (error?.message) {
        return error.message;
    }
    // String error
    if (typeof error === 'string') {
        return error;
    }
    return 'An unexpected error occurred';
}

export default class VotingPanel extends LightningElement {
    _storyId;
    @api 
    get storyId() {
        return this._storyId;
    }
    set storyId(value) {
        if (this._storyId === value) return;
        this._storyId = value;
        
        // Reset all voting state for the new story
        this.selectedCardValue = null;
        this.votesRevealed = false;
        this.revealedVotes = [];
        this.voteStatistics = {};
        this.finalEstimate = null;
        this.hasVoted = false;
        this.voteCount = 0;
        this.isSubmitting = false;
        this.showCommentInput = false;
        this.confidenceLevel = 'medium';
        this.voteComment = '';
        this.showClarificationAlert = false;
        this.showBreakAlert = false;

        // Reset and restart the individual timer
        // If we have a votingStartTime from the story record, use it for persistence
        if (this.votingStartTime) {
            this.initialStartTime = new Date(this.votingStartTime);
        } else {
            this.initialStartTime = new Date();
        }
        
        this.localVotingStartTime = this.initialStartTime;
        this.startLocalVotingTimer();
        
        this.loadVotingStatus();
    }

    @api roomId;
    @track _votingStartTime;
    @api 
    get votingStartTime() {
        return this._votingStartTime;
    }
    set votingStartTime(value) {
        if (this._votingStartTime === value) return;
        this._votingStartTime = value;
        
        // Re-calculate the initial start time from the new value
        if (this._votingStartTime) {
            this.initialStartTime = new Date(this._votingStartTime);
        } else {
            this.initialStartTime = new Date();
        }
        
        // Restart the timer with the new start time
        if (this.canVote && !this.hasVoted && !this.votesRevealed) {
            this.startLocalVotingTimer();
        }
    }

    @api scaleValues = [];
    @api isFacilitator = false;
    @api canVote = false;

    @track selectedCardValue = null;
    @track memberVotingStatus = [];
    @track voteCount = 0;
    @track totalMembers = 0;
    @track votesRevealed = false;
    @track revealedVotes = [];
    @track voteStatistics = {};
    @track finalEstimate = null;
    @track isSubmitting = false;
    @track hasVoted = false;

    // Vote comment
    @track voteComment = '';
    @track storyTotalTime = null;
    @track showCommentInput = false;

    // Discussion timer (after votes revealed)
    @track discussionTime = '00:00';
    @track discussionStartTime = null;
    discussionTimerInterval = null;

    // Voting timer (countdown)
    @track votingTimeLimit = 0; // in seconds, 0 = no limit
    @track votingTimeRemaining = 0;
    @track showVotingTimer = false;
    @track timerPaused = false;
    votingTimerInterval = null;

    // Special cards tracking
    @track clarificationRequests = 0; // ? card votes
    @track breakRequests = 0; // ☕ card votes
    @track showClarificationAlert = false;
    @track showBreakAlert = false;

    // Confidence level
    @track confidenceLevel = 'medium'; // low, medium, high

    @api roomMemberId;

    connectedCallback() {
        this.loadVotingStatus();
        
        // If votingStartTime is provided by parent (persistent timer), use it
        if (this.votingStartTime) {
            this.initialStartTime = new Date(this.votingStartTime);
        } else {
            this.initialStartTime = new Date();
        }
        
        this.startLocalVotingTimer();
    }

    // ========== TIMER METHODS ==========

    // Discussion Timer (starts after votes revealed)
    startDiscussionTimer() {
        this.stopDiscussionTimer(); // Clear any existing timer
        this.discussionStartTime = new Date();
        this.discussionTime = '00:00';

        this.discussionTimerInterval = setInterval(() => {
            this.updateDiscussionTime();
        }, 1000);
    }

    stopDiscussionTimer() {
        if (this.discussionTimerInterval) {
            clearInterval(this.discussionTimerInterval);
            this.discussionTimerInterval = null;
        }
    }

    // Pause/Resume Voting Timer
    // Timer methods are defined below in async section

    updateDiscussionTime() {
        if (!this.discussionStartTime) return;

        const now = new Date();
        const elapsed = Math.floor((now - this.discussionStartTime) / 1000);
        const minutes = Math.floor(elapsed / 60);
        const seconds = elapsed % 60;

        this.discussionTime = String(minutes).padStart(2, '0') + ':' +
                              String(seconds).padStart(2, '0');
    }

    // Voting Timer (countdown)
    startVotingTimer(seconds) {
        this.stopVotingTimer(); // Clear any local interval
        this.votingTimeLimit = seconds;
        this.votingTimeRemaining = seconds;
        this.showVotingTimer = true;
        this.timerPaused = false;

        // Start local countdown
        this.votingTimerInterval = setInterval(() => {
            if (!this.timerPaused) {
                this.updateVotingTimer();
            }
        }, 1000);
    }

    stopVotingTimer() {
        if (this.votingTimerInterval) {
            clearInterval(this.votingTimerInterval);
            this.votingTimerInterval = null;
        }
        this.showVotingTimer = false;
        this.timerPaused = false;
    }

    // ========== INDIVIDUAL TIMER ==========
    @track individualTimerDisplay = '00:00';
    individualTimerInterval = null;

    startLocalVotingTimer() {
        this.stopLocalVotingTimer();
        
        // Use initialStartTime set in storyId setter
        this.localVotingStartTime = this.initialStartTime || new Date();

        this.individualTimerInterval = setInterval(() => {
            if (this.localVotingStartTime) {
                const now = new Date();
                const diff = Math.floor((now - this.localVotingStartTime) / 1000);
                this.updateIndividualTimerDisplay(diff);
            }
        }, 1000);
    }

    updateIndividualTimerDisplay(durationInSeconds) {
        const mins = Math.floor(durationInSeconds / 60);
        const secs = durationInSeconds % 60;
        const timeString = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
        this.individualTimerDisplay = timeString;
        this.dispatchTimerUpdate(timeString);
    }

    dispatchTimerUpdate(timeString) {
        this.dispatchEvent(new CustomEvent('timerupdate', {
            detail: { time: timeString }
        }));
    }

    stopLocalVotingTimer() {
        if (this.individualTimerInterval) {
            clearInterval(this.individualTimerInterval);
            this.individualTimerInterval = null;
        }
    }

    get showIndividualTimer() {
        // Show if I haven't voted yet and voting isn't revealed
        return !this.hasVoted && !this.votesRevealed && this.canVote;
    }

    updateVotingTimer() {
        if (this.votingTimeRemaining > 0) {
            this.votingTimeRemaining--;
        } else {
            this.stopVotingTimer();
            // Timer expired - auto reveal if facilitator
            if (this.isFacilitator && this.voteCount > 0 && !this.votesRevealed) {
                this.handleRevealVotes();
                this.showToast('Timer Expired', 'Voting time is up! Revealing votes.', 'info');
            }
        }
    }

    get votingTimerDisplay() {
        const minutes = Math.floor(this.votingTimeRemaining / 60);
        const seconds = this.votingTimeRemaining % 60;
        return String(minutes).padStart(2, '0') + ':' +
               String(seconds).padStart(2, '0');
    }

    get votingTimerClass() {
        if (this.votingTimeRemaining <= 10) {
            return 'voting-timer timer-critical';
        } else if (this.votingTimeRemaining <= 30) {
            return 'voting-timer timer-warning';
        }
        return 'voting-timer';
    }

    // Timer control handler for facilitator
    async handleStartVotingTimer(event) {
        const seconds = parseInt(event.target.dataset.seconds, 10);
        try {
            await broadcastTimer({
                roomId: this.roomId,
                action: 'timer_started',
                durationInSeconds: seconds
            });
            // Local start happens via event feedback, but for facilitator responsiveness we can optimistic start
            // or just wait for event. Waiting is safer to avoid double-timers.
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    async handleStopVotingTimer() {
        try {
            await broadcastTimer({
                roomId: this.roomId,
                action: 'timer_stopped',
                durationInSeconds: 0
            });
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    async handlePauseTimer() {
        try {
            await broadcastTimer({
                roomId: this.roomId,
                action: 'timer_paused',
                durationInSeconds: this.votingTimeRemaining
            });
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    async handleResumeTimer() {
        try {
            await broadcastTimer({
                roomId: this.roomId,
                action: 'timer_resumed',
                durationInSeconds: this.votingTimeRemaining
            });
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    // ========== SKIP STORY ==========

    async handleSkipStory() {
        try {
            await setStoryStatus({
                storyId: this.storyId,
                status: 'Skipped'
            });

            this.showToast('Story Skipped', 'This story has been skipped.', 'info');

            // Dispatch event to parent to move to next story
            this.dispatchEvent(new CustomEvent('storyskipped', {
                detail: { storyId: this.storyId }
            }));
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    // ========== VOTE COMMENTS ==========

    handleToggleComment() {
        this.showCommentInput = !this.showCommentInput;
    }

    handleCommentChange(event) {
        this.voteComment = event.target.value;
    }

    get hasComment() {
        return this.voteComment && this.voteComment.trim().length > 0;
    }

    get commentButtonVariant() {
        return this.hasComment ? 'brand' : 'border';
    }

    // ========== TIMER COMPUTED PROPERTIES ==========

    get showPauseButton() {
        return this.showVotingTimer && !this.timerPaused && this.isFacilitator;
    }

    get showResumeButton() {
        return this.showVotingTimer && this.timerPaused && this.isFacilitator;
    }

    get timerStatusText() {
        if (this.timerPaused) {
            return 'Paused';
        }
        return 'Running';
    }

    // ========== CONFIDENCE LEVEL ==========

    handleConfidenceChange(event) {
        this.confidenceLevel = event.target.value;
    }

    get confidenceOptions() {
        return [
            { label: 'Low - Not sure', value: 'low' },
            { label: 'Medium - Somewhat confident', value: 'medium' },
            { label: 'High - Very confident', value: 'high' }
        ];
    }

    // ========== SPECIAL CARDS DETECTION ==========

    detectSpecialCards() {
        if (!this.revealedVotes || this.revealedVotes.length === 0) return;

        let clarificationCount = 0;
        let breakCount = 0;

        this.revealedVotes.forEach(vote => {
            const value = vote.value || vote.Vote_Value__c;
            if (value === '?' || value === '❓') {
                clarificationCount++;
            } else if (value === '☕' || value === 'coffee' || value === 'break') {
                breakCount++;
            }
        });

        this.clarificationRequests = clarificationCount;
        this.breakRequests = breakCount;

        // Show alerts if any special cards
        this.showClarificationAlert = clarificationCount > 0;
        this.showBreakAlert = breakCount > 0;
    }

    get hasClarificationRequests() {
        return this.clarificationRequests > 0;
    }

    get hasBreakRequests() {
        return this.breakRequests > 0;
    }

    get clarificationMessage() {
        return `${this.clarificationRequests} member(s) need clarification on this story`;
    }

    get breakMessage() {
        return `${this.breakRequests} member(s) requested a break`;
    }

    // ========== CONSENSUS DETECTION ==========

    get hasConsensus() {
        if (!this.voteStatistics?.distribution) return false;
        const distribution = this.voteStatistics.distribution;
        const values = Object.keys(distribution);

        // Filter out special cards
        const numericVotes = values.filter(v => !isNaN(parseFloat(v)) ||
            ['XS', 'S', 'M', 'L', 'XL', 'XXL'].includes(v));

        return numericVotes.length === 1;
    }

    get consensusValue() {
        if (!this.hasConsensus) return null;
        const distribution = this.voteStatistics.distribution;
        return Object.keys(distribution).find(v => !isNaN(parseFloat(v)) ||
            ['XS', 'S', 'M', 'L', 'XL', 'XXL'].includes(v));
    }

    get hasDisagreement() {
        if (!this.voteStatistics?.range) return false;
        // If range is more than 3 Fibonacci steps, it's significant disagreement
        return this.voteStatistics.range > 5;
    }

    get disagreementMessage() {
        if (!this.voteStatistics) return '';
        return `Vote range: ${this.voteStatistics.min} to ${this.voteStatistics.max}`;
    }

    disconnectedCallback() {
        this.stopDiscussionTimer();
        this.stopVotingTimer();
    }

    @api
    refreshVotes() {
        this.loadVotingStatus();
    }

    @api
    handleVoteEvent(eventData) {
        // Add null check for event data
        if (!eventData) {
            console.error('Invalid vote event data received:', eventData);
            return;
        }

        const action = eventData.Action__c;

        switch (action) {
            case 'voted':
            case 'vote_updated':
            case 'vote_deleted':
                this.updateMemberVoteStatus(eventData);
                break;
            case 'votes_revealed':
                this.handleVotesRevealedEvent(eventData);
                break;
            case 'votes_reset':
                let resetStartTime = null;
                if (eventData.Data__c) { // Fixed: changed payload to eventData
                    try {
                        const data = JSON.parse(eventData.Data__c);
                        resetStartTime = data.votingStartTime;
                    } catch (e) {
                        console.error('Error parsing reset event data:', e);
                    }
                }
                this.handleVotesResetEvent(resetStartTime);
                break;
            case 'estimate_finalized':
                this.handleEstimateFinalizedEvent(eventData);
                break;
            case 'timer_started':
            case 'timer_paused':
            case 'timer_resumed':
            case 'timer_stopped':
                this.handleTimerEvent(eventData);
                break;
            default:
                break;
        }
    }

    handleTimerEvent(eventData) {
        // Parse data JSON if present
        let data = {};
        if (eventData.Data__c) {
            try {
                data = JSON.parse(eventData.Data__c);
            } catch (e) {
                console.error('Error parsing timer data:', e);
            }
        }

        switch (eventData.Action__c) {
            case 'timer_started':
                if (data.duration) {
                    this.startVotingTimer(data.duration);
                    // Sync individual stopwatch start time
                    this.initialStartTime = new Date();
                    this.startLocalVotingTimer();
                }
                break;
            case 'timer_paused':
                this.timerPaused = true;
                if (data.duration) {
                    this.votingTimeRemaining = data.duration;
                }
                break;
            case 'timer_resumed':
                this.timerPaused = false;
                break;
            case 'timer_stopped':
                this.stopVotingTimer();
                break;
        }
    }

    async loadVotingStatus() {
        try {
            const result = await getVotesForStory({
                storyId: this.storyId,
                revealed: this.votesRevealed
            });

            this.memberVotingStatus = result.votes || [];
            this.voteCount = result.voteCount || 0;
            this.totalMembers = result.totalMembers || 0;
            this.votesRevealed = result.revealed || false;
            this.storyTotalTime = result.storyTotalTime;

            if (this.votesRevealed) {
                this.revealedVotes = result.votes || [];
                this.voteStatistics = result.statistics || {};
            }

            // Check if current user has voted
            const myVote = this.memberVotingStatus.find(
                v => v.roomMemberId === this.roomMemberId
            );
            this.hasVoted = myVote?.hasVoted || false;
            
            if (this.hasVoted) {
                this.stopLocalVotingTimer();
                if (myVote.duration) {
                     const mins = Math.floor(myVote.duration / 60);
                     const secs = myVote.duration % 60;
                     this.individualTimerDisplay = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
                     this.dispatchTimerUpdate(this.individualTimerDisplay);
                }
            }

            if (myVote?.value) {
                this.selectedCardValue = myVote.value;
            }
        } catch (error) {
            console.error('Error loading voting status:', error);
        }
    }

    updateMemberVoteStatus(eventData) {
        const odataUserId = eventData.User_Id__c;
        const userName = eventData.User_Name__c;

        // Update vote count
        this.voteCount = eventData.Vote_Count__c || this.voteCount;
        this.totalMembers = eventData.Total_Members__c || this.totalMembers;

        // Update member status
        const memberIndex = this.memberVotingStatus.findIndex(
            m => m.odataUserId === odataUserId
        );

        if (memberIndex >= 0) {
            this.memberVotingStatus = this.memberVotingStatus.map((member, index) => {
                if (index === memberIndex) {
                    return {
                        ...member,
                        hasVoted: eventData.Action__c !== 'vote_deleted'
                    };
                }
                return member;
            });
        } else {
            // Add new member
            this.memberVotingStatus = [
                ...this.memberVotingStatus,
                {
                    odataUserId,
                    voterName: userName,
                    hasVoted: true
                }
            ];
        }
    }

    handleVotesRevealedEvent(eventData) {
        this.votesRevealed = true;

        if (eventData.All_Votes_Data__c) {
            try {
                this.revealedVotes = JSON.parse(eventData.All_Votes_Data__c);
                this.detectSpecialCards(); // Check for ? and ☕ votes
            } catch (e) {
                console.error('Error parsing votes data:', e);
            }
        }

        // Start discussion timer when votes are revealed
        this.startDiscussionTimer();
        this.stopVotingTimer(); // Stop voting timer if running

        this.loadVotingStatus(); // Refresh to get full data
    }

    handleVotesResetEvent(newStartTime = null) {
        this.votesRevealed = false;
        this.revealedVotes = [];
        this.voteStatistics = {};
        this.voteCount = 0;
        this.selectedCardValue = null;
        this.hasVoted = false;
        this.finalEstimate = null;

        // Synchronize stopwatch if a new start time is provided
        if (newStartTime) {
            this.votingStartTime = newStartTime;
        } else {
            // Default to now if not provided (should be provided via event)
            this.votingStartTime = new Date().toISOString();
        }

        // Reset timers
        this.stopDiscussionTimer();
        this.discussionTime = '00:00';

        // Reset special cards
        this.clarificationRequests = 0;
        this.breakRequests = 0;
        this.showClarificationAlert = false;
        this.showBreakAlert = false;

        // Reset vote comment
        this.voteComment = '';
        this.showCommentInput = false;
        this.confidenceLevel = 'medium';

        // Clear selection in poker cards component
        const pokerCards = this.template.querySelector('c-poker-cards');
        if (pokerCards) {
            pokerCards.clearSelection();
        }

        this.loadVotingStatus();
    }

    handleEstimateFinalizedEvent(eventData) {
        // Add null check for event data
        if (!eventData) {
            console.error('Invalid estimate finalized event data:', eventData);
            return;
        }

        this.finalEstimate = eventData.Final_Estimate__c;

        this.dispatchEvent(new CustomEvent('estimatefinalized', {
            detail: {
                storyId: this.storyId,
                estimate: this.finalEstimate
            }
        }));
    }

    // Computed properties
    get voteProgress() {
        if (this.totalMembers === 0) return 0;
        return Math.round((this.voteCount / this.totalMembers) * 100);
    }

    get canSubmitVote() {
        return this.canVote && !this.votesRevealed;
    }

    get cardsDisabled() {
        return !this.canVote || this.votesRevealed;
    }

    get cardsDisabledMessage() {
        if (this.votesRevealed) return 'Votes have been revealed';
        if (!this.canVote) return 'You cannot vote on this story';
        return '';
    }

    get submitButtonLabel() {
        return this.hasVoted ? 'Update Vote' : 'Submit Vote';
    }

    get canRevealVotes() {
        return !this.votesRevealed && this.voteCount > 0;
    }

    get canStartVotingTimer() {
        return !this.votesRevealed && !this.showVotingTimer;
    }

    get hasNoVotes() {
        return this.voteCount === 0;
    }

    get noCardSelected() {
        return !this.selectedCardValue;
    }

    get noFinalEstimate() {
        return !this.finalEstimate;
    }

    get scaleOptions() {
        return this.scaleValues.map(value => ({
            label: value,
            value: value
        }));
    }

    get suggestedEstimate() {
        if (!this.voteStatistics?.median) return null;
        // Find closest scale value to median
        const median = this.voteStatistics.median;
        let closest = this.scaleValues[0];
        let closestDiff = Infinity;

        for (const value of this.scaleValues) {
            const numValue = parseFloat(value);
            if (!isNaN(numValue)) {
                const diff = Math.abs(numValue - median);
                if (diff < closestDiff) {
                    closestDiff = diff;
                    closest = value;
                }
            }
        }

        return closest;
    }

    get suggestedEstimateLabel() {
        return `Median: ${this.suggestedEstimate}`;
    }

    get mostCommonVote() {
        if (!this.voteStatistics?.distribution) return null;
        const distribution = this.voteStatistics.distribution;
        let maxCount = 0;
        let mostCommon = null;

        for (const [value, count] of Object.entries(distribution)) {
            if (count > maxCount) {
                maxCount = count;
                mostCommon = value;
            }
        }

        return mostCommon;
    }

    get mostCommonVoteLabel() {
        return `Most common: ${this.mostCommonVote}`;
    }

    // Event handlers
    handleCardSelect(event) {
        this.selectedCardValue = event.detail.value;
    }

    async handleSubmitVote() {
        if (!this.selectedCardValue) return;

        this.isSubmitting = true;
        
        // Calculate duration in seconds
        let duration = 0;
        if (this.localVotingStartTime) {
            const now = new Date();
            duration = Math.floor((now - this.localVotingStartTime) / 1000);
        }

        try {
            await submitVote({
                storyId: this.storyId,
                roomMemberId: this.roomMemberId,
                voteValue: this.selectedCardValue,
                voteComment: this.voteComment || null,
                confidenceLevel: this.confidenceLevel || 'medium',
                duration: duration
            });

            this.hasVoted = true;
            this.stopLocalVotingTimer(); // Stop the visible timer
            this.showCommentInput = false; // Hide comment after submit
            this.showToast('Success', 'Vote submitted!', 'success');
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    async handleRevealVotes() {
        try {
            const stats = await revealVotes({ storyId: this.storyId });
            this.votesRevealed = true;
            this.voteStatistics = stats;
            this.loadVotingStatus();
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    async handleResetVotes() {
        try {
            await resetVotes({ storyId: this.storyId });
            this.handleVotesResetEvent();
            this.showToast('Success', 'Votes reset. Ready for re-voting.', 'success');
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    handleFinalEstimateChange(event) {
        this.finalEstimate = event.detail.value;
    }

    handleSelectSuggested() {
        this.finalEstimate = this.suggestedEstimate;
    }

    handleSelectMostCommon() {
        this.finalEstimate = this.mostCommonVote;
    }

    async handleFinalizeEstimate() {
        if (!this.finalEstimate) return;

        try {
            await finalizeEstimate({
                storyId: this.storyId,
                finalValue: this.finalEstimate
            });

            this.showToast('Success', `Estimate finalized: ${this.finalEstimate}`, 'success');

            this.dispatchEvent(new CustomEvent('estimatefinalized', {
                detail: {
                    storyId: this.storyId,
                    estimate: this.finalEstimate
                }
            }));
        } catch (error) {
            this.showToast('Error', getErrorMessage(error), 'error');
        }
    }

    showToast(title, message, variant) {
        /*
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
        */
    }
}