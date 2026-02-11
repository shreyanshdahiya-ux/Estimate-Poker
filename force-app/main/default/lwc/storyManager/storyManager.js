import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getStoriesByRoom from '@salesforce/apex/StoryController.getStoriesByRoom';
import createStory from '@salesforce/apex/StoryController.createStory';
import updateStory from '@salesforce/apex/StoryController.updateStory';
import deleteStory from '@salesforce/apex/StoryController.deleteStory';
import deleteAllStoriesByRoom from '@salesforce/apex/StoryController.deleteAllStoriesByRoom';
import reorderStories from '@salesforce/apex/StoryController.reorderStories';
import LightningConfirm from 'lightning/confirm';

export default class StoryManager extends LightningElement {
    @api roomId;
    @api isFacilitator = false;
    @api isRoomCompleted = false;
    @api
    get stories() {
        return this._stories;
    }

    set stories(data) {
        if (data) {
            this._stories = data.map(s => {
                let status = s.Status__c || 'Pending';
                
                // If story has a final estimate, it should always show as 'Estimated'
                if (s.Final_Estimate__c) {
                    status = 'Estimated';
                }
                // If session is completed and story is still 'Voting' without estimate, show as 'Pending'
                else if (this.isRoomCompleted && status === 'Voting') {
                    status = 'Pending';
                }

                return {
                    ...s,
                    Status__c: status,
                    statusClass: `status-badge status-${status.toLowerCase()}`,
                    statusIcon: status === 'Estimated' ? 'utility:check' : status === 'Voting' ? 'utility:record' : 'utility:clock'
                };
            });
        } else {
            this._stories = [];
        }
    }

    @track _stories = [];
    @track showAddModal = false;
    @track newStory = { title: '', description: '', acceptanceCriteria: '', notes: '' };
    @track editStoryId = null;
    @track editStoryData = null;

    // Drag and drop state
    draggedStoryId = null;
    draggedOverStoryId = null;

    @api
    refresh() {
        // No-op: Parent controls data refresh now
        return Promise.resolve();
    }

    getStatusClass(status) {
        // Handled in setter now for better performance
        return `status-badge status-${(status || 'Pending').toLowerCase()}`;
    }

    get modalTitle() { return this.editStoryId ? 'Edit Story' : 'Add Story'; }


    get noStories() { return this.stories.length === 0; }
    
    get canManageStories() {
        return this.isFacilitator && !this.isRoomCompleted;
    }
    
    get isAddDisabled() {
        return this.isRoomCompleted;
    }
    
    get isDeleteAllDisabled() {
        return this.noStories || this.isRoomCompleted;
    }

    handleAddStory() {
        this.newStory = { title: '', description: '', acceptanceCriteria: '', notes: '' };
        this.editStoryId = null;
        this.editStoryData = null;
        this.showAddModal = true;
    }

    handleMenuSelect(event) {
        if (this.isRoomCompleted) return;
        
        const action = event.detail.value;
        const storyId = event.currentTarget.dataset.id;
        
        if (action === 'edit') {
            this.doEditStory(storyId);
        } else if (action === 'delete') {
            this.doDeleteStory(storyId);
        }
    }

    doEditStory(id) {
        const story = this.stories.find(s => s.Id === id);
        if (!story) return;
        
        // Helper to strip empty tags
        const cleanRichText = (val) => {
            if (!val || val === '<p></p>' || val === '<p><br></p>') return '';
            return val;
        };

        this.newStory = {
            title: story.Story_Title__c || '',
            description: cleanRichText(story.Story_Description__c),
            acceptanceCriteria: cleanRichText(story.Acceptance_Criteria__c),
            notes: story.Notes__c || '',
            status: story.Status__c || 'Pending',                   
        };
        this.editStoryId = id;
        this.editStoryData = story; // Store full story data for read-only fields
        this.showAddModal = true;
    }

    // Getter to check if editing mode
    get isEditMode() {
        return this.editStoryId !== null;
    }

    // Status options for dropdown
    get statusOptions() {
        return [
            { label: 'Pending', value: 'Pending' },
            { label: 'Voting', value: 'Voting' },
            { label: 'Estimated', value: 'Estimated' },
            { label: 'Skipped', value: 'Skipped' }
        ];
    }

    async doDeleteStory(id) {
        const result = await LightningConfirm.open({
            message: 'Are you sure you want to delete this story?',
            variant: 'headerless',
            label: 'Delete Story',
            theme: 'error'
        });

        if (result) {
            try {
                await deleteStory({ storyId: id });
                this.showToast('Success', 'Story deleted', 'success');
                this.dispatchEvent(new CustomEvent('storydeleted'));
            } catch (error) {
                this.showToast('Error', error.body?.message, 'error');
            }
        }
    }

    async handleDeleteAll() {
        if (!this.stories.length) return;

        const result = await LightningConfirm.open({
            message: `Are you sure you want to delete all ${this.stories.length} stories? This cannot be undone.`,
            variant: 'headerless',
            label: 'Delete All Stories',
            theme: 'error'
        });

        if (result) {
            try {
                await deleteAllStoriesByRoom({ roomId: this.roomId });
                this.showToast('Success', 'All stories deleted', 'success');
                this.dispatchEvent(new CustomEvent('storydeleted'));
            } catch (error) {
                this.showToast('Error', error.body?.message, 'error');
            }
        }
    }

    handleInputChange(event) {
        this.newStory[event.target.dataset.field] = event.target.value;
    }

    closeModal() { this.showAddModal = false; }

    async handleSaveStory() {
        // Validation
        const titleInput = this.template.querySelector('[data-field="title"]');
        if (!this.newStory.title || !this.newStory.title.trim()) {
            titleInput.setCustomValidity('Story title is required');
            titleInput.reportValidity();
            return;
        } else {
            titleInput.setCustomValidity('');
            titleInput.reportValidity();
        }

        try {
            // Helper to strip empty tags for saving
            const cleanForSave = (val) => {
                if (!val) return null;
                const text = val.replace(/<[^>]*>/g, '').trim();
                if (text.length === 0 && !val.includes('<img') && !val.includes('<table')) return null;
                return val;
            };

            // Prepare story data
            const storyData = {
                title: this.newStory.title,
                description: cleanForSave(this.newStory.description),
                acceptanceCriteria: cleanForSave(this.newStory.acceptanceCriteria),
                externalId: null, 
                notes: this.newStory.notes
            };

            if (this.editStoryId) {
                storyData.status = this.newStory.status;
                await updateStory({ storyId: this.editStoryId, storyData });
            } else {
                await createStory({ storyData, roomId: this.roomId });
            }
            this.showToast('Success', 'Story saved', 'success');
            this.closeModal();
            // refreshApex(this.wiredStoriesResult); // Handled by parent via event
            this.dispatchEvent(new CustomEvent('storycreated', { detail: { Story_Title__c: this.newStory.title } }));
        } catch (error) {
            this.showToast('Error', error.body?.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // Drag and Drop handlers
    handleDragStart(event) {
        if (!this.isFacilitator) {
            event.preventDefault();
            return;
        }
        this.draggedStoryId = event.currentTarget.dataset.id;
        event.currentTarget.classList.add('dragging');
        event.dataTransfer.effectAllowed = 'move';
    }

    handleDragEnd(event) {
        event.currentTarget.classList.remove('dragging');
        this.draggedStoryId = null;
        this.draggedOverStoryId = null;

        // Remove all drag-over classes
        this.template.querySelectorAll('.story-row').forEach(item => {
            item.classList.remove('drag-over');
        });
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';

        const targetStoryId = event.currentTarget.dataset.id;
        if (targetStoryId !== this.draggedStoryId && targetStoryId !== this.draggedOverStoryId) {
            // Remove previous drag-over class
            this.template.querySelectorAll('.story-row').forEach(item => {
                item.classList.remove('drag-over');
            });
            // Add drag-over class to current target
            event.currentTarget.classList.add('drag-over');
            this.draggedOverStoryId = targetStoryId;
        }
    }

    handleDragLeave(event) {
        event.currentTarget.classList.remove('drag-over');
    }

    async handleDrop(event) {
        event.preventDefault();
        const targetStoryId = event.currentTarget.dataset.id;

        if (!this.draggedStoryId || this.draggedStoryId === targetStoryId) {
            return;
        }

        // Remove drag-over class
        event.currentTarget.classList.remove('drag-over');

        // Find indices
        const draggedIndex = this.stories.findIndex(s => s.Id === this.draggedStoryId);
        const targetIndex = this.stories.findIndex(s => s.Id === targetStoryId);

        if (draggedIndex === -1 || targetIndex === -1) return;

        // Reorder stories array locally
        const reorderedStories = [...this.stories];
        const [draggedStory] = reorderedStories.splice(draggedIndex, 1);
        reorderedStories.splice(targetIndex, 0, draggedStory);

        // Update local state immediately for better UX
        this._stories = reorderedStories.map((story, index) => ({
            ...story,
            Story_Order__c: index + 1
        }));

        // Prepare data for Apex
        const storyOrders = this._stories.map((story, index) => ({
            storyId: story.Id,
            order: index + 1
        }));

        try {
            await reorderStories({ roomId: this.roomId, storyOrders });
            // this.showToast('Success', 'Story order updated', 'success');
            // Notify parent that order has changed
            this.dispatchEvent(new CustomEvent('storyreordered'));
        } catch (error) {
            // this.showToast('Error', 'Failed to save story order', 'error');
            // Refresh to restore original order from server
            this.dispatchEvent(new CustomEvent('storyreordered'));
        }
    }
}