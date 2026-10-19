import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getRoomDetails from "@salesforce/apex/RoomController.getRoomDetails";
import getCurrentUserMember from "@salesforce/apex/RoomController.getCurrentUserMember";
import setCurrentStory from "@salesforce/apex/RoomController.setCurrentStory";
import updateRoomStatus from "@salesforce/apex/RoomController.updateRoomStatus";
import getStoriesByRoom from "@salesforce/apex/StoryController.getStoriesByRoom";
import getNextPendingStory from "@salesforce/apex/StoryController.getNextPendingStory";
import reorderStories from "@salesforce/apex/StoryController.reorderStories";
import sendMemberLike from "@salesforce/apex/RoomController.sendMemberLike";
import { stripNamespace } from "c/nsUtil";

export default class EstimationSession extends LightningElement {
  @api roomId;

  @track isLoading = true;
  @track roomDetails = {};
  @track stories = [];
  @track members = [];
  @track currentStory = null;
  @track currentUserMember = null;
  @track canManageRoom = false;
  @track scaleValues = [];
  @track likedUserIds = new Set();

  // Session timer state
  @track sessionElapsedTime = "00:00:00";
  @track myTimeDisplay = "00:00:00";

  sessionStartTime = null;
  timerInterval = null;

  // Drag and drop state
  draggedStoryId = null;
  draggedOverStoryId = null;

  // Debounce timer for loadSessionData
  _loadDataDebounceTimer = null;
  _loadDataDebounceDelay = 300; // ms

  connectedCallback() {
    this.loadSessionData(true); // Immediate load on init
  }

  disconnectedCallback() {
    // Clean up timer when component is removed
    this.stopTimer();
  }

  startTimer() {
    if (this.timerInterval) {
      return; // Timer already running
    }

    // eslint-disable-next-line @lwc/lwc/no-async-operation -- session elapsed-time clock
    this.timerInterval = setInterval(() => {
      this.updateElapsedTime();
    }, 1000);
  }

  stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval);
      this.timerInterval = null;
    }
  }

  updateElapsedTime() {
    const now = new Date();

    // 1. Session Elapsed Time (Room Stopwatch from start)
    if (this.sessionStartTime) {
      // Handle timezone differences if needed - Salesforce returns UTC ISO string usually
      const elapsed = now.getTime() - this.sessionStartTime.getTime();
      this.sessionElapsedTime = this.formatDuration(elapsed);
    } else {
      // Reset if no start time
      this.sessionElapsedTime = "00:00:00";
    }

    // 3. My Time is now handled via event from votingPanel
  }

  formatDuration(ms, isShort = false) {
    if (ms < 0) ms = 0;
    const totalSeconds = Math.floor(ms / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    const mm = String(minutes).padStart(2, "0");
    const ss = String(seconds).padStart(2, "0");

    if (isShort && hours === 0) {
      return `${mm}:${ss}`;
    }

    const hh = String(hours).padStart(2, "0");
    return `${hh}:${mm}:${ss}`;
  }

  @api
  async loadSessionData(immediate = false) {
    // Debounce to prevent excessive reloads from rapid platform events
    if (!immediate) {
      if (this._loadDataDebounceTimer) {
        clearTimeout(this._loadDataDebounceTimer);
      }

      // eslint-disable-next-line @lwc/lwc/no-async-operation -- debounces bursts of realtime events into a single reload
      this._loadDataDebounceTimer = setTimeout(() => {
        this._actuallyLoadSessionData();
      }, this._loadDataDebounceDelay);
      return;
    }

    // Immediate load (for initial load)
    await this._actuallyLoadSessionData();
  }

  async _actuallyLoadSessionData() {
    // Don't set isLoading = true here to avoid flickering on updates
    try {
      const [roomResult, memberResult, storiesResult] = await Promise.all([
        getRoomDetails({ roomId: this.roomId }),
        getCurrentUserMember({ roomId: this.roomId }),
        getStoriesByRoom({ roomId: this.roomId })
      ]);
      const roomData = stripNamespace(roomResult);
      const memberData = stripNamespace(memberResult);
      const storiesData = stripNamespace(storiesResult);

      this.roomDetails = roomData.room;
      this.members = this.formatMembers(roomData.members);
      this.scaleValues = roomData.scaleValues;
      this.currentUserMember = memberData;
      this.canManageRoom = roomData.isFacilitator === true;

      // Set current story if one is active. This must happen before formatting the queue,
      // because the queue marks the current story as active.
      if (this.roomDetails.Current_Story__c) {
        this.currentStory = storiesData.find(
          (s) => s.Id === this.roomDetails.Current_Story__c
        );
      } else {
        // No current story recorded on the room: fall back to a story that is being voted on
        this.currentStory =
          storiesData.find(
            (s) => s.Status__c === "Voting" || s.Status__c === "Discussing"
          ) || this.currentStory;
      }
      this.stories = this.formatStories(storiesData);

      // Initialize session timer based on Start_DateTime__c
      if (this.roomDetails.Start_DateTime__c) {
        this.sessionStartTime = new Date(this.roomDetails.Start_DateTime__c);
        this.updateElapsedTime();
        this.startTimer();
      }
    } catch (error) {
      this.showToast("Error", "Failed to load session data", "error");
      console.error("Error loading session:", error);
    } finally {
      this.isLoading = false;
    }
  }

  formatStories(stories) {
    const statusClasses = {
      Pending: "slds-badge slds-badge_lightest",
      Discussing: "slds-badge slds-theme_warning",
      Voting: "slds-badge slds-theme_info",
      Estimated: "slds-badge slds-theme_success",
      Skipped: "slds-badge"
    };

    return stories.map((story) => ({
      ...story,
      statusBadge: statusClasses[story.Status__c] || "slds-badge",
      itemClass: `story-item slds-box slds-box_x-small slds-m-bottom_x-small ${
        story.Id === this.currentStory?.Id ? "active" : ""
      } ${story.Status__c === "Estimated" ? "estimated" : ""}`
    }));
  }

  formatMembers(members) {
    return members.map((member) => {
      const isLiked = this.likedUserIds.has(member.User__c);
      const isInSession = member.Is_Online__c === true;
      // Is_Current_User__c is set by the server; the comparison covers members formatted after the user is known
      const isCurrentUser =
        member.Is_Current_User__c === true ||
        (!!this.currentUserMember?.User__c &&
          member.User__c === this.currentUserMember.User__c);

      return {
        ...member,
        userName: member.User__r?.Name || "Unknown",
        photoUrl: member.User__r?.SmallPhotoUrl,
        onlineIndicator: isInSession
          ? "online-indicator online"
          : "online-indicator offline",
        isLiked: isLiked,
        likeClass: isLiked ? "like-button liked" : "like-button",
        roleDisplay: member.Role_In_Room__c || "Voter",
        isVoter: member.Can_Vote__c,
        isCurrentUser,
        // You can't like yourself
        canBeLiked: member.Can_Vote__c && !isCurrentUser
      };
    });
  }

  // Computed properties
  get roomName() {
    return this.roomDetails?.Name || "Estimation Session";
  }

  get roomCode() {
    return this.roomDetails?.Room_Code__c || "";
  }

  // The server decides: facilitating needs the Facilitator permission as well as the room role
  get isFacilitator() {
    return this.canManageRoom === true;
  }

  get canVote() {
    return this.currentUserMember?.Can_Vote__c || false;
  }

  get currentUserMemberId() {
    return this.currentUserMember?.Id;
  }

  get noStories() {
    return this.stories.length === 0;
  }

  get isReady() {
    return !this.isLoading;
  }

  get noCurrentStory() {
    return !this.currentStory;
  }

  get sessionTime() {
    return this.sessionElapsedTime;
  }

  get individualTimerDisplay() {
    return this.myTimeDisplay;
  }

  get showIndividualTimer() {
    return this.currentStory !== null;
  }

  // Event handlers
  async handleStoryClick(event) {
    const storyId = event.currentTarget.dataset.storyId;
    if (!storyId) return;

    // Find the selected story
    const selectedStory = this.stories.find((s) => s.Id === storyId);
    if (!selectedStory) return;

    if (!this.isFacilitator) {
      // Non-facilitators can only view
      this.currentStory = selectedStory;
      this.updateStoryClasses();
      return;
    }

    // If it's already the current story, do nothing (a skipped story can be re-selected to vote again)
    if (
      this.currentStory?.Id === storyId &&
      selectedStory.Status__c !== "Skipped"
    )
      return;

    try {
      // UI update first for speed
      // Re-map all stories to ensure only the selected one is 'Voting'
      // and others revert to their correct state (Estimated or Pending)
      this.stories = this.stories.map((s) => {
        if (s.Id === storyId) {
          // Mirrors RoomController.setCurrentStory: an Estimated story keeps its status
          return s.Status__c === "Estimated"
            ? s
            : { ...s, Status__c: "Voting" };
        }

        // If it was previously voting, reset it
        if (s.Status__c === "Voting") {
          return {
            ...s,
            Status__c: s.Final_Estimate__c ? "Estimated" : "Pending"
          };
        }

        return s;
      });

      this.currentStory = this.stories.find((s) => s.Id === storyId);
      this.updateStoryClasses();

      // Then sync with server
      await setCurrentStory({ roomId: this.roomId, storyId });
    } catch (error) {
      console.error("Error selecting story:", error);
      this.showToast(
        "Error",
        "Failed to select story. Please try again.",
        "error"
      );
      // Reload to ensure state is correct
      this.loadSessionData();
    }
  }

  handleBack() {
    this.dispatchEvent(new CustomEvent("back"));
  }

  handleRefresh() {
    this.loadSessionData();
    this.showToast("Success", "Session refreshed", "success");
  }

  async handlePauseSession() {
    try {
      await updateRoomStatus({ roomId: this.roomId, status: "Paused" });
      // Redirection is now handled by handleRoomEventFromHandler to keep users synced
    } catch {
      this.showToast("Error", "Failed to pause session", "error");
    }
  }

  async handleEndSession() {
    try {
      await updateRoomStatus({ roomId: this.roomId, status: "Completed" });
      // Redirection is now handled by the consolidated handleRoomEvent method
    } catch {
      this.showToast("Error", "Failed to end session", "error");
    }
  }

  handleEstimateFinalized(event) {
    const { storyId, estimate } = event.detail;

    // Update story in list
    this.stories = this.stories.map((story) => {
      if (story.Id === storyId) {
        return {
          ...story,
          Status__c: "Estimated",
          Final_Estimate__c: estimate,
          statusBadge: "slds-badge slds-theme_success",
          itemClass:
            "story-item slds-box slds-box_x-small slds-m-bottom_x-small estimated"
        };
      }
      return story;
    });

    // Keep the Current Story card in step (the finalized vote event is the only signal; no full reload follows)
    if (this.currentStory?.Id === storyId) {
      this.currentStory = {
        ...this.currentStory,
        Status__c: "Estimated",
        Final_Estimate__c: estimate
      };
    }

    // Auto-advance to next story
    this.advanceToNextStory();
  }

  async advanceToNextStory() {
    try {
      const nextStory = stripNamespace(
        await getNextPendingStory({
          roomId: this.roomId,
          currentStoryId: this.currentStory?.Id
        })
      );

      if (nextStory && this.isFacilitator) {
        await setCurrentStory({ roomId: this.roomId, storyId: nextStory.Id });
        this.currentStory = this.stories.find((s) => s.Id === nextStory.Id);
        this.updateStoryClasses();
      }
    } catch (error) {
      console.error("Error advancing to next story:", error);
    }
  }

  /**
   * Updates a story's status locally (queue + current story) when it is currently in `fromStatus`.
   */
  applyStoryStatus(storyId, newStatus, fromStatus) {
    if (!storyId) return;

    this.stories = this.stories.map((s) => {
      if (s.Id === storyId && (!fromStatus || s.Status__c === fromStatus)) {
        return { ...s, Status__c: newStatus };
      }
      return s;
    });

    if (
      this.currentStory?.Id === storyId &&
      (!fromStatus || this.currentStory.Status__c === fromStatus)
    ) {
      this.currentStory = { ...this.currentStory, Status__c: newStatus };
    }

    this.updateStoryClasses();
  }

  updateStoryClasses() {
    this.stories = this.formatStories(this.stories);
  }

  // Platform Event handlers
  @api
  handleVoteEvent(payload) {
    // Add null check for payload
    if (!payload) {
      console.error("Invalid vote event received:", payload);
      return;
    }

    // Forward to voting panel
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  @api
  handleVotesRevealedEvent(payload) {
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  @api
  handleVotesResetEvent(payload) {
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  @api
  handleEstimateFinalizedEvent(payload) {
    // Add null checks for payload
    if (!payload) {
      console.error("Invalid estimate finalized event received:", payload);
      return;
    }

    this.handleEstimateFinalized({
      detail: {
        storyId: payload.Story_Id__c,
        estimate: payload.Final_Estimate__c
      }
    });
  }

  @api
  handleStoryChangedEvent(event) {
    const payload = event.detail;
    const storyId = payload.Current_Story_Id__c;

    if (storyId) {
      // Reload session data to get the updated story with Voting_Start_Time
      // This ensures the votingPanel's storyId setter is triggered with fresh data
      this.loadSessionData();
    }
  }

  @api
  handleMemberEvent() {
    // Refresh all session data when members change
    this.loadSessionData();
  }

  @api
  handleRoomEvent(event) {
    // Safely check if event and detail exist
    if (!event || !event.detail) {
      console.warn("Invalid room event received in estimation session");
      return;
    }

    const payload = event.detail;
    const action = payload.Action__c;

    // Handle session status changes in real-time
    if (action === "session_paused" || action === "session_ended") {
      this.stopTimer();
      // Redirect back to room dashboard
      this.dispatchEvent(new CustomEvent("sessionend"));
    } else if (action === "session_resumed" || action === "session_started") {
      // Refresh data when session resumes
      this.loadSessionData();
    } else if (action === "story_changed" || action === "story_selected") {
      // Handle story selection changes - reload to get fresh data including voting start time
      this.loadSessionData();
    } else if (
      action === "timer_started" ||
      action === "timer_paused" ||
      action === "timer_resumed" ||
      action === "timer_stopped"
    ) {
      // Forward timer events to voting panel
      const votingPanel = this.template.querySelector("c-voting-panel");
      if (votingPanel) {
        votingPanel.handleVoteEvent(payload);
      }
    }
  }

  @api
  handlePresenceEvent(event) {
    // Safely check if event and detail exist
    if (!event || !event.detail) {
      console.warn("Invalid presence event received");
      return;
    }

    const payload = event.detail;
    const odataUserId = payload.User_Id__c;
    const status = payload.Status__c;

    this.members = this.members.map((member) => {
      if (member.User__c === odataUserId) {
        return {
          ...member,
          Is_Online__c: status === "online",
          onlineIndicator:
            status === "online"
              ? "online-indicator online"
              : "online-indicator offline"
        };
      }
      return member;
    });
  }

  // Drag and Drop handlers
  handleDragStart(event) {
    if (!this.isFacilitator) {
      event.preventDefault();
      return;
    }
    this.draggedStoryId = event.currentTarget.dataset.storyId;
    event.currentTarget.classList.add("dragging");
    event.dataTransfer.effectAllowed = "move";
  }

  handleDragEnd(event) {
    event.currentTarget.classList.remove("dragging");
    this.draggedStoryId = null;
    this.draggedOverStoryId = null;

    // Remove all drag-over classes
    this.template.querySelectorAll(".story-item").forEach((item) => {
      item.classList.remove("drag-over");
    });
  }

  handleDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";

    const targetStoryId = event.currentTarget.dataset.storyId;
    if (
      targetStoryId !== this.draggedStoryId &&
      targetStoryId !== this.draggedOverStoryId
    ) {
      // Remove previous drag-over class
      this.template.querySelectorAll(".story-item").forEach((item) => {
        item.classList.remove("drag-over");
      });
      // Add drag-over class to current target
      event.currentTarget.classList.add("drag-over");
      this.draggedOverStoryId = targetStoryId;
    }
  }

  handleDragLeave(event) {
    event.currentTarget.classList.remove("drag-over");
  }

  async handleDrop(event) {
    event.preventDefault();
    const targetStoryId = event.currentTarget.dataset.storyId;

    if (!this.draggedStoryId || this.draggedStoryId === targetStoryId) {
      return;
    }

    // Remove drag-over class
    event.currentTarget.classList.remove("drag-over");

    // Find indices
    const draggedIndex = this.stories.findIndex(
      (s) => s.Id === this.draggedStoryId
    );
    const targetIndex = this.stories.findIndex((s) => s.Id === targetStoryId);

    if (draggedIndex === -1 || targetIndex === -1) return;

    // Reorder stories array locally
    const reorderedStories = [...this.stories];
    const [draggedStory] = reorderedStories.splice(draggedIndex, 1);
    reorderedStories.splice(targetIndex, 0, draggedStory);

    // Update local state immediately for better UX
    this.stories = reorderedStories.map((story, index) => ({
      ...story,
      Story_Order__c: index + 1
    }));
    this.updateStoryClasses();

    // Prepare data for Apex
    const storyOrders = this.stories.map((story, index) => ({
      storyId: story.Id,
      order: index + 1
    }));

    try {
      await reorderStories({ roomId: this.roomId, storyOrders });
    } catch {
      this.showToast("Error", "Failed to save story order", "error");
      // Reload to get correct order
      this.loadSessionData();
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  // ========== REAL-TIME EVENT HANDLERS (from realtimeEventHandler) ==========

  handleVoteEventFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    // Forward to voting panel
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  handleVotesRevealedFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    // Votes revealed -> story moves from Voting to Discussing (mirrors VotingController.revealVotes)
    this.applyStoryStatus(payload.Story_Id__c, "Discussing", "Voting");

    // Forward to voting panel
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  handleVotesResetFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    // Votes reset -> story goes back from Discussing to Voting (mirrors VotingController.resetVotes)
    this.applyStoryStatus(payload.Story_Id__c, "Voting", "Discussing");

    // Forward to voting panel
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  handleEstimateFinalizedFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    // Update local story list
    this.handleEstimateFinalized({
      detail: {
        storyId: payload.Story_Id__c,
        estimate: payload.Final_Estimate__c
      }
    });

    // Forward to voting panel
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  handleStoryChangedFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    const storyId = payload.Current_Story_Id__c;
    if (storyId) {
      // Selecting a story starts voting on it (unless already Estimated); a previous Voting story reverts
      this.stories = this.stories.map((s) => {
        if (s.Id === storyId) {
          return s.Status__c === "Estimated"
            ? s
            : { ...s, Status__c: "Voting" };
        }
        if (s.Status__c === "Voting") {
          return {
            ...s,
            Status__c: s.Final_Estimate__c ? "Estimated" : "Pending"
          };
        }
        return s;
      });
      this.currentStory = this.stories.find((s) => s.Id === storyId);

      // If the event contains votingStartTime in additional data, update it
      if (payload.Data__c && this.currentStory) {
        try {
          const data = JSON.parse(payload.Data__c);
          if (data.votingStartTime) {
            this.currentStory = {
              ...this.currentStory,
              Voting_Start_Time__c: data.votingStartTime
            };
          }
        } catch (e) {
          console.error("Error parsing room event data:", e);
        }
      }

      this.updateStoryClasses();

      // Refresh voting panel for new story
      const votingPanel = this.template.querySelector("c-voting-panel");
      if (votingPanel) {
        votingPanel.refreshVotes();
      }
    }
  }

  handleMemberEventFromHandler() {
    // Refresh session data when members join/leave
    this.loadSessionData();
  }

  // Fired by the voting panel (detail.storyId) and by the realtime handler (detail.Story_Id__c)
  handleStorySkipped(event) {
    const detail = event.detail;
    const storyId = detail?.Story_Id__c || detail?.storyId;
    this.applyStoryStatus(storyId, "Skipped");
  }

  handleStoryActivated(event) {
    const payload = event.detail;
    if (!payload || !payload.Story_Id__c) return;

    // Find the story in the list
    const storyIndex = this.stories.findIndex(
      (s) => s.Id === payload.Story_Id__c
    );
    if (storyIndex !== -1) {
      let votingStartTime = null;
      if (payload.Story_Data__c) {
        try {
          const storyData = JSON.parse(payload.Story_Data__c);
          votingStartTime = storyData.votingStartTime;
        } catch (e) {
          console.error("Error parsing story data:", e);
        }
      }

      // Update the story in the array
      this.stories = this.stories.map((s, idx) => {
        if (idx === storyIndex) {
          return {
            ...s,
            Status__c: "Voting",
            Voting_Start_Time__c: votingStartTime
          };
        }
        // Reset other voting stories to pending
        if (s.Status__c === "Voting" && s.Id !== payload.Story_Id__c) {
          return {
            ...s,
            Status__c: "Pending"
          };
        }
        return s;
      });

      // If this is the current story, update it to trigger re-render of votingPanel
      if (this.currentStory?.Id === payload.Story_Id__c) {
        this.currentStory = {
          ...this.currentStory,
          Status__c: "Voting",
          Voting_Start_Time__c: votingStartTime
        };
      }

      this.updateStoryClasses();
    }
  }

  handleRoomEventFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    const action = payload.Action__c;

    if (action === "session_paused" || action === "session_ended") {
      this.stopTimer();
      // Dispatch session end immediately
      this.dispatchEvent(new CustomEvent("sessionend"));
    } else if (action === "session_resumed" || action === "session_started") {
      this.loadSessionData();
    } else if (action === "member_like") {
      const data = payload.Data__c ? JSON.parse(payload.Data__c) : {};
      const targetUserId = data.targetUserId;
      const senderName = data.senderName;

      // Use the current user ID directly from the session
      const myUserId = this.currentUserMember?.User__c;

      // If I am the target, show a toast/notification
      if (targetUserId && targetUserId === myUserId) {
        this.showToast(
          "Reacted",
          `${senderName} liked your vibe! 👍`,
          "success"
        );
      }

      // Persistence: Add to likedUserIds set
      if (targetUserId) {
        this.likedUserIds.add(targetUserId);
        // Trigger reactivity by re-formatting members
        this.members = this.formatMembers(this.members);
      }

      // Animate effect for the target user in the list
      // Find the member item in DOM
      const memberItemButton = this.template.querySelector(
        `button[data-user-id="${targetUserId}"]`
      );
      if (memberItemButton) {
        memberItemButton.classList.add("received-like");
        // eslint-disable-next-line @lwc/lwc/no-async-operation -- removes the like-received highlight after its animation
        setTimeout(
          () => memberItemButton.classList.remove("received-like"),
          2000
        );
      }
    }
  }

  handleTimerEventFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    // Forward timer events to voting panel
    const votingPanel = this.template.querySelector("c-voting-panel");
    if (votingPanel) {
      votingPanel.handleVoteEvent(payload);
    }
  }

  handlePresenceEventFromHandler(event) {
    const payload = event.detail;
    if (!payload) return;

    const userId = payload.User_Id__c;
    const status = payload.Status__c;

    this.members = this.members.map((member) => {
      if (member.User__c === userId) {
        return {
          ...member,
          Is_Online__c: status === "online",
          onlineIndicator:
            status === "online"
              ? "online-indicator online"
              : "online-indicator offline"
        };
      }
      return member;
    });
  }

  async handleLikeMember(event) {
    // Prevent bubbling if nested
    event.stopPropagation();

    const targetUserId = event.currentTarget.dataset.userId;
    if (!targetUserId) return;

    // Add visual feedback class immediately
    const button = event.currentTarget;
    button.classList.add("liked-animate");
    // eslint-disable-next-line @lwc/lwc/no-async-operation -- removes the like-sent animation class
    setTimeout(() => button.classList.remove("liked-animate"), 500);

    try {
      await sendMemberLike({ roomId: this.roomId, targetUserId: targetUserId });
    } catch (error) {
      console.error("Error sending like:", error);
      // Don't toast for minor interaction errors to keep it smooth
    }
  }

  handleMyTimerUpdate(event) {
    if (event && event.detail) {
      this.myTimeDisplay = event.detail.time;
    }
  }
}
