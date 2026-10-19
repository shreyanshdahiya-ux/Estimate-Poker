import { LightningElement, track, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMyRooms from "@salesforce/apex/RoomController.getMyRooms";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import { getEventChannel, stripNamespace } from "c/nsUtil";
import canFacilitate from "@salesforce/customPermission/Facilitate_Estimation_Rooms";

export default class RoomList extends LightningElement {
  @track rooms = [];
  @track isLoading = true;
  @track searchTerm = "";
  @track statusFilter = "all";

  // Granted by the Facilitator and Admin permission sets; only these users can create rooms
  canCreateRoom = canFacilitate;

  wiredRoomsResult;
  subscription = {};
  channelName;

  statusOptions = [
    { label: "All", value: "all" },
    { label: "Draft", value: "Draft" },
    { label: "Active", value: "Active" },
    { label: "Completed", value: "Completed" }
  ];

  @wire(getMyRooms)
  wiredRooms(result) {
    this.wiredRoomsResult = result;
    if (result.data) {
      this.rooms = stripNamespace(result.data).map((room) =>
        this.formatRoom(room)
      );
      this.isLoading = false;
    } else if (result.error) {
      this.showToast("Error", "Failed to load rooms", "error");
      console.error("Error loading rooms:", result.error);
      this.isLoading = false;
    }
  }

  connectedCallback() {
    this.handleSubscribe();
  }

  disconnectedCallback() {
    this.handleUnsubscribe();
  }

  async handleSubscribe() {
    this.channelName = await getEventChannel("Poker_Room_Event__e");
    const messageCallback = (response) => {
      console.log("Room List event received: ", JSON.stringify(response));
      this.refresh();
    };

    subscribe(this.channelName, -1, messageCallback).then((response) => {
      this.subscription = response;
    });

    onError((error) => {
      console.error("EMP API error: ", JSON.stringify(error));
    });
  }

  handleUnsubscribe() {
    unsubscribe(this.subscription, () => {
      console.log("Unsubscribed from channel: ", this.channelName);
    });
  }

  @api
  async refresh() {
    if (!this.wiredRoomsResult) {
      return;
    }
    this.isLoading = true;
    try {
      await refreshApex(this.wiredRoomsResult);
    } catch (error) {
      this.showToast("Error", "Failed to refresh rooms", "error");
      console.error("Error refreshing rooms:", error);
    } finally {
      this.isLoading = false;
    }
  }

  handleRefreshClick() {
    this.refresh();
  }

  formatRoom(room) {
    const statusClasses = {
      Draft: "slds-badge slds-badge_lightest",
      Active: "slds-badge slds-theme_success",
      Completed: "slds-badge slds-theme_info"
    };

    return {
      ...room,
      statusClass: statusClasses[room.status] || "slds-badge",
      formattedDate: this.formatDate(room.createdDate)
    };
  }

  formatDate(dateString) {
    if (!dateString) return "";
    const date = new Date(dateString);
    const now = new Date();
    const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));

    if (diffDays === 0) return "Today";
    if (diffDays === 1) return "Yesterday";
    if (diffDays < 7) return `${diffDays} days ago`;

    return date.toLocaleDateString();
  }

  get isEmpty() {
    return !this.isLoading && this.rooms.length === 0;
  }

  get hasRooms() {
    return !this.isLoading && this.rooms.length > 0;
  }

  get filteredRooms() {
    return this.rooms.filter((room) => {
      const matchesSearch =
        !this.searchTerm ||
        room.name.toLowerCase().includes(this.searchTerm.toLowerCase()) ||
        room.roomCode.toLowerCase().includes(this.searchTerm.toLowerCase());

      const matchesStatus =
        this.statusFilter === "all" || room.status === this.statusFilter;

      return matchesSearch && matchesStatus;
    });
  }

  handleSearch(event) {
    this.searchTerm = event.target.value;
  }

  handleStatusFilter(event) {
    this.statusFilter = event.detail.value;
  }

  handleRoomClick(event) {
    const roomId = event.currentTarget.dataset.roomId;
    this.isLoading = true; // Show spinner while transitioning to room
    this.dispatchEvent(
      new CustomEvent("roomselect", {
        detail: { roomId }
      })
    );
  }

  handleCreateRoom() {
    this.dispatchEvent(new CustomEvent("createroom"));
  }

  // eslint-disable-next-line no-unused-vars
  showToast(_title, _message, _variant) {
    // Toast placeholder
  }
}
