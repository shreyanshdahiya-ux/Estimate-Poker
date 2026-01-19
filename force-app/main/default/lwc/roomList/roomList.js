import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyRooms from '@salesforce/apex/RoomController.getMyRooms';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class RoomList extends LightningElement {
    @track rooms = [];
    @track isLoading = true;
    @track searchTerm = '';
    @track statusFilter = 'all';
    
    subscription = {};
    channelName = '/event/Poker_Room_Event__e';

    statusOptions = [
        { label: 'All', value: 'all' },
        { label: 'Draft', value: 'Draft' },
        { label: 'Active', value: 'Active' },
        { label: 'Completed', value: 'Completed' }
    ];

    connectedCallback() {
        this.loadRooms();
        this.handleSubscribe();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            console.log('Room List event received: ', JSON.stringify(response));
            this.refresh();
        };

        subscribe(this.channelName, -1, messageCallback).then(response => {
            this.subscription = response;
        });

        onError(error => {
            console.error('EMP API error: ', JSON.stringify(error));
        });
    }

    handleUnsubscribe() {
        unsubscribe(this.subscription, response => {
            console.log('Unsubscribed from channel: ', this.channelName);
        });
    }

    async loadRooms() {
        this.isLoading = true;
        try {
            const data = await getMyRooms();
            this.rooms = data.map(room => this.formatRoom(room));
        } catch (error) {
            this.showToast('Error', 'Failed to load rooms', 'error');
            console.error('Error loading rooms:', error);
        } finally {
            this.isLoading = false;
        }
    }

    @api
    async refresh() {
        await this.loadRooms();
    }

    formatRoom(room) {
        const statusClasses = {
            'Draft': 'slds-badge slds-badge_lightest',
            'Active': 'slds-badge slds-theme_success',
            'Completed': 'slds-badge slds-theme_info'
        };

        return {
            ...room,
            statusClass: statusClasses[room.status] || 'slds-badge',
            formattedDate: this.formatDate(room.createdDate)
        };
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        const now = new Date();
        const diffDays = Math.floor((now - date) / (1000 * 60 * 60 * 24));

        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
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
        return this.rooms.filter(room => {
            const matchesSearch = !this.searchTerm ||
                room.name.toLowerCase().includes(this.searchTerm.toLowerCase()) ||
                room.roomCode.toLowerCase().includes(this.searchTerm.toLowerCase());

            const matchesStatus = this.statusFilter === 'all' ||
                room.status === this.statusFilter;

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
        this.dispatchEvent(new CustomEvent('roomselect', {
            detail: { roomId }
        }));
    }

    handleCreateRoom() {
        this.dispatchEvent(new CustomEvent('createroom'));
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