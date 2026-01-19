import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllTeams from '@salesforce/apex/TeamController.getAllTeams';
import createTeam from '@salesforce/apex/TeamController.createTeam';
import getTeamMembers from '@salesforce/apex/TeamController.getTeamMembers';
import addTeamMember from '@salesforce/apex/TeamController.addTeamMember';
import removeTeamMember from '@salesforce/apex/TeamController.removeTeamMember';
import updateTeamMemberRole from '@salesforce/apex/TeamController.updateTeamMemberRole';
import searchUsers from '@salesforce/apex/TeamController.searchUsers';
import updateTeam from '@salesforce/apex/TeamController.updateTeam';
import { refreshApex } from '@salesforce/apex';

export default class TeamManagement extends LightningElement {
    @track teams = [];
    @track isLoading = true;
    @track showNewTeamModal = false;
    @track newTeam = { name: '', description: '', department: '' };

    // Team Detail Modal state
    @track showTeamDetailModal = false;
    @track selectedTeam = null;
    @track teamMembers = [];
    @track isLoadingMembers = false;

    // Add Member state
    @track showAddMemberSection = false;
    @track memberSearchTerm = '';
    @track memberSearchResults = [];
    @track isSearchingMembers = false;
    memberSearchTimeout;

    wiredTeamsResult;

    @wire(getAllTeams)
    wiredTeams(result) {
        this.wiredTeamsResult = result;
        this.isLoading = false;
        if (result.data) {
            console.log('team data : ', result.data);
            // Apex already returns formatted map with lowercase keys
            this.teams = result.data;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load teams', 'error');
        }
    }

    get noTeams() {
        return !this.isLoading && this.teams.length === 0;
    }

    get hasTeams() {
        return this.teams.length > 0;
    }

    handleNewTeam() {
        this.showNewTeamModal = true;
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await refreshApex(this.wiredTeamsResult);
            this.showToast('Success', 'Teams refreshed', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to refresh teams', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCloseModal() {
        this.showNewTeamModal = false;
        this.newTeam = { name: '', description: '', department: '' };
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.newTeam[field] = event.target.value;
    }

    async handleSaveTeam() {
        if (!this.newTeam.name) {
            this.showToast('Error', 'Team name is required', 'error');
            return;
        }

        try {
            this.isLoading = true;
            await createTeam({ teamData: this.newTeam });
            this.showToast('Success', 'Team created successfully', 'success');
            this.handleCloseModal();
            await refreshApex(this.wiredTeamsResult);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to create team', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Team Detail Modal handlers
    async handleTeamClick(event) {
        const teamId = event.currentTarget.dataset.teamId;
        this.selectedTeam = this.teams.find(t => t.id === teamId);
        this.showTeamDetailModal = true;
        this.showAddMemberSection = false;
        this.memberSearchTerm = '';
        this.memberSearchResults = [];
        await this.loadTeamMembers(teamId);
    }

    async loadTeamMembers(teamId) {
        this.isLoadingMembers = true;
        try {
            this.teamMembers = await getTeamMembers({ teamId });
        } catch (error) {
            this.showToast('Error', 'Failed to load team members', 'error');
            console.error('Error loading members:', error);
        } finally {
            this.isLoadingMembers = false;
        }
    }

    handleCloseTeamDetailModal() {
        this.showTeamDetailModal = false;
        this.selectedTeam = null;
        this.teamMembers = [];
        this.showAddMemberSection = false;
    }

    // Add Member handlers
    handleShowAddMember() {
        this.showAddMemberSection = true;
        this.memberSearchTerm = '';
        this.memberSearchResults = [];
    }

    handleCancelAddMember() {
        this.showAddMemberSection = false;
        this.memberSearchTerm = '';
        this.memberSearchResults = [];
    }

    handleMemberSearchChange(event) {
        this.memberSearchTerm = event.target.value;

        if (this.memberSearchTimeout) {
            clearTimeout(this.memberSearchTimeout);
        }

        if (this.memberSearchTerm.length >= 2) {
            this.memberSearchTimeout = setTimeout(() => {
                this.performMemberSearch();
            }, 300);
        } else {
            this.memberSearchResults = [];
        }
    }

    async performMemberSearch() {
        this.isSearchingMembers = true;
        try {
            const results = await searchUsers({ searchTerm: this.memberSearchTerm });

            // Filter out existing members
            const existingMemberIds = new Set(this.teamMembers.map(m => m.odataUserId));
            this.memberSearchResults = results
                .filter(user => !existingMemberIds.has(user.Id))
                .map(user => ({
                    ...user,
                    isAlreadyMember: false
                }));
        } catch (error) {
            this.showToast('Error', 'Failed to search users', 'error');
        } finally {
            this.isSearchingMembers = false;
        }
    }

    async handleAddMemberToTeam(event) {
        const userId = event.target.dataset.userId;

        try {
            await addTeamMember({
                teamId: this.selectedTeam.id,
                odataUserId: userId,
                role: 'Developer'
            });

            this.showToast('Success', 'Member added successfully', 'success');

            // Remove from search results
            this.memberSearchResults = this.memberSearchResults.filter(u => u.Id !== userId);

            // Reload members
            await this.loadTeamMembers(this.selectedTeam.id);

            // Refresh teams to update member count
            await refreshApex(this.wiredTeamsResult);

        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to add member', 'error');
        }
    }

    async handleRemoveMember(event) {
        const memberId = event.target.dataset.memberId;

        try {
            await removeTeamMember({ teamMemberId: memberId });
            this.showToast('Success', 'Member removed', 'success');

            // Reload members
            await this.loadTeamMembers(this.selectedTeam.id);

            // Refresh teams to update member count
            await refreshApex(this.wiredTeamsResult);

        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to remove member', 'error');
        }
    }

    async handleRoleChange(event) {
        const memberId = event.target.dataset.memberId;
        const newRole = event.target.value;

        try {
            await updateTeamMemberRole({ teamMemberId: memberId, role: newRole });
            this.showToast('Success', 'Role updated', 'success');

            // Update local state
            this.teamMembers = this.teamMembers.map(m => {
                if (m.id === memberId) {
                    return { ...m, role: newRole };
                }
                return m;
            });
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to update role', 'error');
        }
    }

    // Getters for Team Detail Modal
    get hasTeamMembers() {
        return this.teamMembers.length > 0;
    }

    get noTeamMembers() {
        return !this.isLoadingMembers && this.teamMembers.length === 0;
    }

    get hasMemberSearchResults() {
        return !this.isSearchingMembers && this.memberSearchResults.length > 0;
    }

    get noMemberSearchResults() {
        return !this.isSearchingMembers && this.memberSearchTerm.length >= 2 && this.memberSearchResults.length === 0;
    }

    get roleOptions() {
        return [
            { label: 'Scrum Master', value: 'Scrum Master' },
            { label: 'Product Owner', value: 'Product Owner' },
            { label: 'Developer', value: 'Developer' },
            { label: 'QA Engineer', value: 'QA Engineer' },
            { label: 'Designer', value: 'Designer' }
        ];
    }

    showToast(title, message, variant) {
        // this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}