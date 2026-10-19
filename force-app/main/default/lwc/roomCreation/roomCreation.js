import { LightningElement, track } from "lwc";
import createRoom from "@salesforce/apex/RoomController.createRoom";
import getAllTeams from "@salesforce/apex/TeamController.getAllTeams";
import getTeamMembers from "@salesforce/apex/TeamController.getTeamMembers";
import searchUsers from "@salesforce/apex/TeamController.searchUsers";

const SCALE_VALUES = {
  Fibonacci: [
    "0",
    "1",
    "2",
    "3",
    "5",
    "8",
    "13",
    "21",
    "34",
    "55",
    "89",
    "?",
    "☕"
  ],
  "Modified Fibonacci": [
    "0",
    "0.5",
    "1",
    "2",
    "3",
    "5",
    "8",
    "13",
    "20",
    "40",
    "100",
    "?",
    "☕"
  ],
  "T-Shirt Sizes": ["XS", "S", "M", "L", "XL", "XXL", "?", "☕"],
  "Powers of 2": ["0", "1", "2", "4", "8", "16", "32", "64", "?", "☕"],
  Custom: []
};

export default class RoomCreation extends LightningElement {
  @track currentStep = "1";
  @track roomData = {
    name: "",
    description: "",
    estimationScale: "Fibonacci",
    customScaleValues: "",
    isTimerEnabled: false
  };

  @track teams = [];
  @track loadingTeams = false;
  @track selectedTeamId = null;
  @track selectedTeamName = "";
  @track teamMembers = [];
  @track selectedMembers = [];
  @track userSearchTerm = "";
  @track searchResults = [];
  @track isCreating = false;

  scaleOptions = [
    { label: "Fibonacci (0, 1, 2, 3, 5, 8, 13...)", value: "Fibonacci" },
    {
      label: "Modified Fibonacci (0, 0.5, 1, 2, 3, 5...)",
      value: "Modified Fibonacci"
    },
    { label: "T-Shirt Sizes (XS, S, M, L, XL, XXL)", value: "T-Shirt Sizes" },
    { label: "Powers of 2 (1, 2, 4, 8, 16...)", value: "Powers of 2" },
    { label: "Custom", value: "Custom" }
  ];

  roomRoleOptions = [
    { label: "Voter", value: "Voter" },
    { label: "Observer", value: "Observer" },
    { label: "Product Owner", value: "Product Owner" }
  ];

  // Step getters
  get isStep1() {
    return this.currentStep === "1";
  }
  get isStep2() {
    return this.currentStep === "2";
  }
  get isStep3() {
    return this.currentStep === "3";
  }

  get showBackButton() {
    return this.currentStep !== "1";
  }
  get showNextButton() {
    return this.currentStep !== "3";
  }
  get showCreateButton() {
    return this.currentStep === "3";
  }

  get isCustomScale() {
    return this.roomData.estimationScale === "Custom";
  }

  get scalePreview() {
    let values;
    if (this.isCustomScale && this.roomData.customScaleValues) {
      values = this.roomData.customScaleValues
        .split(",")
        .map((v) => v.trim())
        .filter((v) => v);
    } else {
      values = SCALE_VALUES[this.roomData.estimationScale] || [];
    }
    return values.map((value, index) => ({ id: `scale-${index}`, value }));
  }

  get hasTeams() {
    return !this.loadingTeams && this.teams.length > 0;
  }

  get noTeams() {
    return !this.loadingTeams && this.teams.length === 0;
  }

  get selectedMemberCount() {
    return this.selectedMembers.length;
  }

  get canProceed() {
    if (this.currentStep === "1") {
      return this.roomData.name && this.roomData.name.trim().length > 0;
    }
    return true;
  }

  get cannotProceed() {
    return !this.canProceed;
  }

  // Event handlers
  handleInputChange(event) {
    const field = event.target.dataset.field;
    this.roomData[field] = event.target.value;
  }

  handleScaleChange(event) {
    this.roomData.estimationScale = event.detail.value;
  }

  handleTeamSelect(event) {
    const teamId = event.currentTarget.dataset.teamId;

    if (this.selectedTeamId === teamId) {
      // Deselect
      this.selectedTeamId = null;
      this.selectedTeamName = "";
      this.teamMembers = [];
    } else {
      // Select new team - clear previous selection
      this.selectedTeamId = teamId;
      const team = this.teams.find((t) => t.id === teamId);
      this.selectedTeamName = team ? team.name : "";
      this.loadTeamMembers(teamId);
    }

    // Update team cards - only one selected at a time
    this.teams = this.teams.map((team) => {
      const isSelected = team.id === this.selectedTeamId;
      return {
        ...team,
        isSelected: isSelected,
        cardClass: isSelected
          ? "team-card slds-box slds-box_x-small selected"
          : "team-card slds-box slds-box_x-small"
      };
    });
  }

  handleMemberToggle(event) {
    const memberId = event.target.dataset.memberId;
    const isChecked = event.target.checked;

    // Update team member selection
    this.teamMembers = this.teamMembers.map((member) => {
      if (member.odataUserId === memberId) {
        return { ...member, selected: isChecked };
      }
      return member;
    });

    this.updateSelectedMembers();
  }

  handleRoleChange(event) {
    const memberId = event.target.dataset.memberId;
    const role = event.detail.value;

    // Update team members
    this.teamMembers = this.teamMembers.map((member) => {
      if (member.odataUserId === memberId) {
        return { ...member, roomRole: role };
      }
      return member;
    });

    // Update selected members
    this.selectedMembers = this.selectedMembers.map((member) => {
      if (member.odataUserId === memberId) {
        return { ...member, roomRole: role };
      }
      return member;
    });
  }

  handleUserSearch(event) {
    this.userSearchTerm = event.target.value;

    if (this.userSearchTerm.length >= 2) {
      this.searchUsersDebounced();
    } else {
      this.searchResults = [];
    }
  }

  searchUsersDebounced() {
    clearTimeout(this._searchTimeout);
    // eslint-disable-next-line @lwc/lwc/no-async-operation -- debounces the user search while typing
    this._searchTimeout = setTimeout(() => {
      this.doSearchUsers();
    }, 300);
  }

  async doSearchUsers() {
    try {
      const results = await searchUsers({ searchTerm: this.userSearchTerm });
      const selectedIds = new Set(
        this.selectedMembers.map((m) => m.odataUserId)
      );
      this.searchResults = results.filter((u) => !selectedIds.has(u.Id));
    } catch (error) {
      console.error("Error searching users:", error);
    }
  }

  handleAddUser(event) {
    const odataUserId = event.currentTarget.dataset.userId;
    const user = this.searchResults.find((u) => u.Id === odataUserId);

    if (user) {
      const newMember = {
        id: user.Id,
        odataUserId: user.Id,
        name: user.Name,
        photoUrl: user.SmallPhotoUrl || "",
        roomRole: "Voter",
        selected: true
      };

      this.selectedMembers = [...this.selectedMembers, newMember];

      // Remove from search results
      this.searchResults = this.searchResults.filter(
        (u) => u.Id !== odataUserId
      );
      this.userSearchTerm = "";
    }
  }

  handleRemoveMember(event) {
    const memberId = event.detail.name;

    // Remove from selected members
    this.selectedMembers = this.selectedMembers.filter(
      (m) => m.odataUserId !== memberId
    );

    // Update team members checkbox if from team
    if (this.teamMembers.length > 0) {
      this.teamMembers = this.teamMembers.map((member) => {
        if (member.odataUserId === memberId) {
          return { ...member, selected: false };
        }
        return member;
      });
    }
  }

  updateSelectedMembers() {
    // Get selected members from team with all required fields
    const fromTeam = this.teamMembers
      .filter((m) => m.selected)
      .map((m) => ({
        id: m.odataUserId,
        odataUserId: m.odataUserId,
        name: m.name || "Unknown",
        photoUrl: m.photoUrl || "",
        roomRole: m.roomRole || "Voter",
        selected: true
      }));

    // Keep manually added members (not from current team)
    const teamMemberIds = new Set(this.teamMembers.map((m) => m.odataUserId));
    const manuallyAdded = this.selectedMembers.filter(
      (m) => !teamMemberIds.has(m.odataUserId)
    );

    // Merge and ensure unique by odataUserId
    const merged = [...fromTeam, ...manuallyAdded];
    const uniqueMap = new Map();
    merged.forEach((member) => {
      if (member.odataUserId && !uniqueMap.has(member.odataUserId)) {
        uniqueMap.set(member.odataUserId, member);
      }
    });

    this.selectedMembers = Array.from(uniqueMap.values());
  }

  // Navigation
  handleBack() {
    const step = parseInt(this.currentStep, 10);
    this.currentStep = String(step - 1);

    if (this.currentStep === "2") {
      // Going back to team selection - keep selected members
    } else if (this.currentStep === "1") {
      // Going back to room details - reset everything
      this.selectedTeamId = null;
      this.selectedTeamName = "";
      this.teamMembers = [];
      this.selectedMembers = [];
      this.loadingTeams = false;
      this.teams = [];
      this.userSearchTerm = "";
      this.searchResults = [];
    }
  }

  handleNext() {
    const step = parseInt(this.currentStep, 10);
    this.currentStep = String(step + 1);

    if (this.currentStep === "2") {
      this.loadTeams();
    }
  }

  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  async handleCreateRoom() {
    if (this.selectedMembers.length === 0) {
      this.showToast("Warning", "Please select at least one member", "warning");
      return;
    }

    this.isCreating = true;

    try {
      // ✅ FIX: Prepare member data correctly
      const memberRoles = this.selectedMembers.map((m) => ({
        userId: m.odataUserId,
        role: m.roomRole
      }));

      const roomId = await createRoom({
        roomData: this.roomData,
        teamId: this.selectedTeamId,
        memberRoles: JSON.stringify(memberRoles)
      });

      this.showToast("Success", "Room created successfully!", "success");

      this.dispatchEvent(
        new CustomEvent("roomcreated", {
          detail: { roomId }
        })
      );
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Failed to create room",
        "error"
      );
      console.error("Error creating room:", error);
    } finally {
      this.isCreating = false;
    }
  }

  // Data loading
  async loadTeams() {
    this.loadingTeams = true;
    try {
      const teamsData = await getAllTeams();

      this.teams = teamsData.map((team) => {
        const count = team.memberCount || 0;
        return {
          id: team.id,
          name: team.name,
          description: team.description,
          department: team.department,
          teamLead: team.teamLead,
          memberCount: count,
          memberCountDisplay: count === 1 ? "1 member" : `${count} members`,
          isSelected: team.id === this.selectedTeamId,
          cardClass:
            team.id === this.selectedTeamId
              ? "team-card slds-box slds-box_x-small selected"
              : "team-card slds-box slds-box_x-small"
        };
      });
    } catch (error) {
      console.error("Error loading teams:", error);
      this.showToast("Error", "Failed to load teams", "error");
    } finally {
      this.loadingTeams = false;
    }
  }

  async loadTeamMembers(teamId) {
    try {
      const members = await getTeamMembers({ teamId });

      // Ensure all member fields are populated correctly with unique keys
      // IMPORTANT: odataUserId must be the User ID (005...), not Team_Member__c ID (a0F...)
      this.teamMembers = members.map((member, index) => ({
        id: member.odataUserId || `member-${index}`,
        odataUserId: member.odataUserId,
        name: member.name || member.email || "Unknown User",
        role: member.role || "",
        photoUrl: member.photoUrl || "",
        selected: true,
        roomRole: "Voter"
      }));

      this.updateSelectedMembers();
    } catch (error) {
      console.error("Error loading team members:", error);
      this.showToast("Error", "Failed to load team members", "error");
    }
  }

  // eslint-disable-next-line no-unused-vars
  showToast(_title, _message, _variant) {
    // Toast placeholder
  }
}
