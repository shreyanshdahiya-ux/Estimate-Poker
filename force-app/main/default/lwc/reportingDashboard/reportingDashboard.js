import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDashboardSummary from '@salesforce/apex/ReportController.getDashboardSummary';
import getRoomsForReport from '@salesforce/apex/ReportController.getRoomsForReport';
import generateRoomReport from '@salesforce/apex/ReportController.generateRoomReport';
import getVelocityTrend from '@salesforce/apex/ReportController.getVelocityTrend';
import getEstimateDistribution from '@salesforce/apex/ReportController.getEstimateDistribution';
import getKpiDetails from '@salesforce/apex/ReportController.getKpiDetails';
import generateAllRoomsReport from '@salesforce/apex/ReportController.generateAllRoomsReport';

export default class ReportingDashboard extends LightningElement {
    @track summary = {};
    @track rooms = [];
    @track velocityData = [];
    @track distributionData = [];
    @track reportData = { room: {}, summary: {}, stories: [], members: [] };
    @track allRoomsData = null;
    @track isAllRoomsReport = false;

    @track isLoading = true;
    @track selectedRoomId = '';
    @track showReportModal = false;
    @track isGeneratingReport = false;

    // KPI Modal state
    @track showKpiModal = false;
    @track kpiModalTitle = '';
    @track kpiDetails = [];
    @track isLoadingKpiDetails = false;
    @track selectedKpiType = '';

    wiredSummaryResult;
    wiredRoomsResult;
    wiredVelocityResult;
    wiredDistributionResult;

    @wire(getDashboardSummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.summary = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Failed to load summary', 'error');
            this.isLoading = false;
        }
    }

    @wire(getRoomsForReport)
    wiredRooms(result) {
        this.wiredRoomsResult = result;
        if (result.data) {
            this.rooms = result.data;
        }
    }

    @wire(getVelocityTrend)
    wiredVelocity(result) {
        this.wiredVelocityResult = result;
        if (result.data) {
            this.velocityData = result.data.map(item => ({
                ...item,
                formattedDate: this.formatDate(item.completedDate)
            }));
        }
    }

    @wire(getEstimateDistribution)
    wiredDistribution(result) {
        this.wiredDistributionResult = result;
        if (result.data) {
            this.processDistributionData(result.data);
        }
    }

    processDistributionData(data) {
        const entries = Object.entries(data);
        if (entries.length === 0) {
            this.distributionData = [];
            return;
        }

        // Sort by estimate value (numeric first, then special values)
        entries.sort((a, b) => {
            const numA = parseFloat(a[0]);
            const numB = parseFloat(b[0]);
            if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
            if (!isNaN(numA)) return -1;
            if (!isNaN(numB)) return 1;
            return a[0].localeCompare(b[0]);
        });

        const maxCount = Math.max(...entries.map(e => e[1]));

        this.distributionData = entries.map(([estimate, count]) => ({
            estimate,
            count,
            barStyle: `width: ${(count / maxCount) * 100}%`
        }));
    }

    // Getters
    get isReady() {
        return !this.isLoading;
    }

    get roomOptions() {
        return this.rooms.map(room => ({
            label: `${room.name} (${room.roomCode})`,
            value: room.id
        }));
    }

    get noRoomSelected() {
        return !this.selectedRoomId;
    }

    get hasDistribution() {
        return this.distributionData && this.distributionData.length > 0;
    }

    get hasVelocityData() {
        return this.velocityData && this.velocityData.length > 0;
    }

    get hasReportData() {
        return !this.isGeneratingReport && !this.isAllRoomsReport && this.reportData && this.reportData.room && this.reportData.room.id;
    }

    get hasAllRoomsData() {
        return !this.isGeneratingReport && this.isAllRoomsReport && this.allRoomsData && this.allRoomsData.rooms;
    }

    get reportModalTitle() {
        if (this.isAllRoomsReport) {
            return 'All Rooms Report';
        }
        return this.reportData?.room?.name ? `Room Report: ${this.reportData.room.name}` : 'Room Report';
    }

    get isExportDisabled() {
        if (this.isGeneratingReport) return true;
        if (this.isAllRoomsReport) {
            return !this.allRoomsData || !this.allRoomsData.rooms || this.allRoomsData.rooms.length === 0;
        }
        return !this.reportData || !this.reportData.stories || this.reportData.stories.length === 0;
    }

    // KPI Modal getters
    get hasKpiDetails() {
        return !this.isLoadingKpiDetails && this.kpiDetails &&
            (Array.isArray(this.kpiDetails) ? this.kpiDetails.length > 0 : Object.keys(this.kpiDetails).length > 0);
    }

    get noKpiDetails() {
        return !this.isLoadingKpiDetails && !this.hasKpiDetails;
    }

    get showRoomsList() {
        return this.selectedKpiType === 'totalRooms' || this.selectedKpiType === 'activeRooms';
    }

    get showStoriesList() {
        return this.selectedKpiType === 'totalStories' || this.selectedKpiType === 'estimatedStories';
    }

    get showVotesSummary() {
        return this.selectedKpiType === 'totalVotes';
    }

    get reportStatusClass() {
        const status = this.reportData?.room?.status || '';
        const classes = {
            'Draft': 'status-badge status-draft',
            'Active': 'status-badge status-active',
            'Completed': 'status-badge status-completed'
        };
        return classes[status] || 'status-badge';
    }

    get formattedDuration() {
        const minutes = this.reportData?.room?.durationMinutes;
        if (!minutes) return '';
        const hours = Math.floor(minutes / 60);
        const mins = minutes % 60;
        if (hours > 0) {
            return `${hours}h ${mins}m`;
        }
        return `${mins}m`;
    }

    get formattedGeneratedAt() {
        const timestamp = this.isAllRoomsReport
            ? this.allRoomsData?.generatedAt
            : this.reportData?.generatedAt;
        if (!timestamp) return '';
        return new Date(timestamp).toLocaleString();
    }

    // Event Handlers
    handleRoomChange(event) {
        this.selectedRoomId = event.detail.value;
    }

    // KPI Click Handlers
    async handleKpiClick(event) {
        const kpiType = event.currentTarget.dataset.kpi;
        this.selectedKpiType = kpiType;

        const titles = {
            'totalRooms': 'All Rooms',
            'activeRooms': 'Active Rooms',
            'totalStories': 'All Stories',
            'estimatedStories': 'Estimated Stories',
            'totalVotes': 'Voting Summary'
        };

        this.kpiModalTitle = titles[kpiType] || 'Details';
        this.showKpiModal = true;
        this.isLoadingKpiDetails = true;
        this.kpiDetails = [];

        try {
            const data = await getKpiDetails({ kpiType });

            if (kpiType === 'totalRooms' || kpiType === 'activeRooms') {
                this.kpiDetails = data.map(room => ({
                    ...room,
                    statusClass: this.getRoomStatusClass(room.status)
                }));
            } else if (kpiType === 'totalStories' || kpiType === 'estimatedStories') {
                this.kpiDetails = data.map(story => ({
                    ...story,
                    statusClass: this.getStoryStatusClass(story.status)
                }));
            } else {
                this.kpiDetails = data;
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to load details', 'error');
            this.kpiDetails = [];
        } finally {
            this.isLoadingKpiDetails = false;
        }
    }

    handleCloseKpiModal() {
        this.showKpiModal = false;
        this.kpiDetails = [];
        this.selectedKpiType = '';
    }

    handleRoomSelect(event) {
        const roomId = event.currentTarget.dataset.roomId;
        if (roomId) {
            this.selectedRoomId = roomId;
            this.handleCloseKpiModal();
            this.handleGenerateReport();
        }
    }

    getRoomStatusClass(status) {
        const classes = {
            'Draft': 'status-badge status-draft',
            'Active': 'status-badge status-active',
            'Completed': 'status-badge status-completed'
        };
        return classes[status] || 'status-badge';
    }

    async handleGenerateReport() {
        if (!this.selectedRoomId) {
            this.showToast('Error', 'Please select a room', 'error');
            return;
        }

        this.isAllRoomsReport = false;
        this.showReportModal = true;
        this.isGeneratingReport = true;

        try {
            const data = await generateRoomReport({ roomId: this.selectedRoomId });

            // Process stories for display
            data.stories = data.stories.map(story => ({
                ...story,
                statusClass: this.getStoryStatusClass(story.status),
                averageEstimate: story.averageEstimate != null ? story.averageEstimate : '-'
            }));

            // Process members for display
            data.members = data.members.map(member => ({
                ...member,
                participationStyle: `width: ${member.participationRate}%`
            }));

            this.reportData = data;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to generate report', 'error');
            this.showReportModal = false;
        } finally {
            this.isGeneratingReport = false;
        }
    }

    async handleGenerateAllRoomsReport() {
        this.isAllRoomsReport = true;
        this.showReportModal = true;
        this.isGeneratingReport = true;
        this.allRoomsData = null;

        try {
            const data = await generateAllRoomsReport();

            // Process rooms for display with status classes
            data.rooms = data.rooms.map(room => ({
                ...room,
                statusClass: this.getRoomStatusClass(room.status)
            }));

            this.allRoomsData = data;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to generate all rooms report', 'error');
            this.showReportModal = false;
        } finally {
            this.isGeneratingReport = false;
        }
    }

    handleCloseReport() {
        this.showReportModal = false;
        this.isAllRoomsReport = false;
        this.reportData = { room: {}, summary: {}, stories: [], members: [] };
        this.allRoomsData = null;
    }

    async handleRefresh() {
        this.isLoading = true;
        try {
            await Promise.all([
                refreshApex(this.wiredSummaryResult),
                refreshApex(this.wiredRoomsResult),
                refreshApex(this.wiredVelocityResult),
                refreshApex(this.wiredDistributionResult)
            ]);
            this.showToast('Success', 'Dashboard refreshed', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to refresh dashboard', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleExportCSV() {
        try {
            let csvContent = '';
            let fileName = '';

            if (this.isAllRoomsReport && this.allRoomsData) {
                // All Rooms Report CSV
                csvContent = 'Room Name,Room Code,Status,Total Stories,Estimated Stories,Total Points\n';

                this.allRoomsData.rooms.forEach(room => {
                    const name = this.escapeCSV(room.name);
                    const roomCode = this.escapeCSV(room.roomCode);
                    const status = this.escapeCSV(room.status);
                    csvContent += `${name},${roomCode},${status},${room.totalStories},${room.estimatedStories},${room.totalPoints || ''}\n`;
                });

                csvContent += '\nSummary\n';
                csvContent += `Total Rooms,${this.allRoomsData.summary.totalRooms}\n`;
                csvContent += `Total Stories,${this.allRoomsData.summary.totalStories}\n`;
                csvContent += `Estimated Stories,${this.allRoomsData.summary.estimatedStories}\n`;
                csvContent += `Total Points,${this.allRoomsData.summary.totalPoints}\n`;
                csvContent += `Avg Points per Story,${this.allRoomsData.summary.avgPointsPerStory}\n`;

                fileName = 'all_rooms_report.csv';
            } else if (this.reportData && this.reportData.stories) {
                // Single Room Report CSV
                csvContent = 'Story Title,Status,Final Estimate,Average,Vote Count\n';

                this.reportData.stories.forEach(story => {
                    const title = this.escapeCSV(story.title);
                    const status = this.escapeCSV(story.status);
                    csvContent += `${title},${status},${story.finalEstimate || ''},${story.averageEstimate || ''},${story.voteCount}\n`;
                });

                csvContent += '\nMember,Role,Votes Cast,Participation Rate\n';

                this.reportData.members.forEach(member => {
                    const name = this.escapeCSV(member.name);
                    const role = this.escapeCSV(member.role);
                    csvContent += `${name},${role},${member.voteCount},${member.participationRate}%\n`;
                });

                const roomName = this.reportData.room.name ? this.reportData.room.name.replace(/[^a-zA-Z0-9]/g, '_') : 'room';
                fileName = `${roomName}_report.csv`;
            } else {
                this.showToast('Error', 'No data available to export', 'error');
                return;
            }

            // Create download using data URI approach for better LWC compatibility
            const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent);
            const link = document.createElement('a');
            link.setAttribute('href', encodedUri);
            link.setAttribute('download', fileName);
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);

            this.showToast('Success', 'Report exported successfully', 'success');
        } catch (error) {
            console.error('Export error:', error);
            this.showToast('Error', 'Failed to export report', 'error');
        }
    }

    escapeCSV(value) {
        if (value === null || value === undefined) return '';
        const stringValue = String(value);
        if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
            return `"${stringValue.replace(/"/g, '""')}"`;
        }
        return stringValue;
    }

    // Helper methods
    getStoryStatusClass(status) {
        const classes = {
            'Pending': 'story-status status-pending',
            'Voting': 'story-status status-voting',
            'Discussing': 'story-status status-discussing',
            'Estimated': 'story-status status-estimated',
            'Skipped': 'story-status status-skipped'
        };
        return classes[status] || 'story-status';
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleDateString();
    }

    showToast(title, message, variant) {
        // this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}