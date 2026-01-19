import { LightningElement, api } from 'lwc';

export default class CurrentStory extends LightningElement {
    @api story;

    get statusBadge() {
        const statusClasses = {
            'Pending': 'slds-badge slds-badge_lightest',
            'Discussing': 'slds-badge slds-theme_warning',
            'Voting': 'slds-badge slds-theme_info',
            'Estimated': 'slds-badge slds-theme_success',
            'Skipped': 'slds-badge'
        };

        return statusClasses[this.story?.Status__c] || 'slds-badge';
    }

    get statusBadgeClass() {
        const statusClasses = {
            'Pending': 'status-badge status-pending',
            'Discussing': 'status-badge status-discussing',
            'Voting': 'status-badge status-voting',
            'Estimated': 'status-badge status-estimated',
            'Skipped': 'status-badge status-pending'
        };

        return statusClasses[this.story?.Status__c] || 'status-badge status-pending';
    }

    get hasDescription() {
        return this.isValidRichText(this.story?.Story_Description__c);
    }

    get hasCriteria() {
        return this.isValidRichText(this.story?.Acceptance_Criteria__c);
    }

    isValidRichText(html) {
        if (!html) return false;
        // Strip basic tags and check if anything remains
        const text = html.replace(/<[^>]*>/g, '').trim();
        // Also check if it contains images or tables even if no text
        return text.length > 0 || html.includes('<img') || html.includes('<table');
    }
}