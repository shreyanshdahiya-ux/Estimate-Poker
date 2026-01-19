import { LightningElement, api, track } from 'lwc';

export default class PokerCards extends LightningElement {
    @api scaleValues = [];
    @api disabled = false;
    @api disabledMessage = 'Voting is currently disabled';
    @api revealed = false;

    @api 
    get value() {
        return this._selectedValue;
    }
    set value(val) {
        this._selectedValue = val;
    }
    
    @track _selectedValue = null;

    get cards() {
        return this.scaleValues.map(value => {
            const isSelected = this._selectedValue === value;
            const isSpecial = value === '?' || value === '☕';

            let cardClass = 'poker-card';
            if (isSelected) cardClass += ' selected';
            if (isSpecial) cardClass += ' special';
            if (this.disabled || this.revealed) cardClass += ' disabled';

            return {
                value,
                displayValue: this.getDisplayValue(value),
                description: this.getCardDescription(value),
                cardClass,
                isSelected
            };
        });
    }

    get isDisabled() {
        return this.disabled || this.revealed;
    }

    getDisplayValue(value) {
        // Handle special values
        if (value === '?') return '?';
        if (value === '☕') return '☕';
        if (value === 'coffee') return '☕';
        return value;
    }

    getCardDescription(value) {
        // Provide helpful descriptions for scale values
        const descriptions = {
            '0': 'Zero - No effort',
            '0.5': 'Half - Trivial',
            '1': 'One - Very Small',
            '2': 'Two - Small',
            '3': 'Three - Medium',
            '5': 'Five - Large',
            '8': 'Eight - Very Large',
            '13': 'Thirteen - Huge',
            '20': 'Twenty - Massive',
            '40': 'Forty - Epic',
            '100': 'Hundred - Too Large',
            '?': 'Need Clarification',
            '☕': 'Need a Break',
            'XS': 'Extra Small',
            'S': 'Small',
            'M': 'Medium',
            'L': 'Large',
            'XL': 'Extra Large',
            'XXL': 'Double XL'
        };
        return descriptions[value] || value;
    }

    handleCardClick(event) {
        if (this.isDisabled) return;

        const value = event.currentTarget.dataset.value;

        if (this._selectedValue === value) {
            // Deselect if clicking same card
            this._selectedValue = null;
        } else {
            this._selectedValue = value;
        }

        this.dispatchEvent(new CustomEvent('cardselect', {
            detail: { value: this._selectedValue }
        }));
    }

    handleClearSelection() {
        this._selectedValue = null;
        this.dispatchEvent(new CustomEvent('cardselect', {
            detail: { value: null }
        }));
    }

    @api
    setSelectedValue(value) {
        this._selectedValue = value;
    }

    @api
    clearSelection() {
        this._selectedValue = null;
    }
}