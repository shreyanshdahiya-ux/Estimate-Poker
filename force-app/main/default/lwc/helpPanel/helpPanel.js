import { LightningElement, api, track, wire } from 'lwc';
import getHelpForContext from '@salesforce/apex/GuidanceController.getHelpForContext';
import searchHelp from '@salesforce/apex/GuidanceController.searchHelp';

export default class HelpPanel extends LightningElement {
    @api context;
    @track articles = [];
    @track searchTerm = '';
    @track isLoading = true;

    @wire(getHelpForContext, { component: '$context' })
    wiredHelp({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.articles = data.map((article, index) => ({
                ...article,
                key: article.Id || `article-${index}`
            }));
        } else if (error) {
            console.error('Error loading help articles:', error);
        }
    }

    async handleSearch(event) {
        this.searchTerm = event.target.value;
        if (this.searchTerm.length >= 2) {
            try {
                const results = await searchHelp({ searchTerm: this.searchTerm });
                this.articles = results.map((article, index) => ({
                    ...article,
                    key: article.Id || `search-${index}`
                }));
            } catch (error) {
                console.error('Error searching help:', error);
            }
        }
    }

    get hasArticles() {
        return this.articles && this.articles.length > 0;
    }

    get noArticles() {
        return !this.isLoading && (!this.articles || this.articles.length === 0);
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}