({
    loadOpportunityDetails: function(component) {
        var action = component.get('c.getOpportunityDetails');
        action.setParams({ opportunityId: component.get('v.recordId') });
        action.setCallback(this, function(response) {
            if (response.getState() === 'SUCCESS') {
                component.set('v.oppDetails', response.getReturnValue());
            } else {
                this.handleErrors(response);
            }
        });
        $A.enqueueAction(action);
    },

    loadExistingQuotes: function(component) {
        component.set('v.isLoading', true);
        var action = component.get('c.getQuotesForOpportunity');
        action.setParams({ opportunityId: component.get('v.recordId') });
        action.setCallback(this, function(response) {
            component.set('v.isLoading', false);
            if (response.getState() === 'SUCCESS') {
                component.set('v.existingQuotes', response.getReturnValue());
            } else {
                this.handleErrors(response);
            }
        });
        $A.enqueueAction(action);
    },

    doProductSearch: function(component) {
        var searchTerm = component.get('v.searchTerm');
        if (!searchTerm || searchTerm.length < 2) {
            component.set('v.searchResults', []);
            return;
        }

        var oppDetails = component.get('v.oppDetails');
        var action = component.get('c.searchProducts');
        action.setParams({
            searchTerm: searchTerm,
            pricebookId: oppDetails.pricebookId
        });
        action.setCallback(this, function(response) {
            if (response.getState() === 'SUCCESS') {
                component.set('v.searchResults', response.getReturnValue());
            } else {
                this.handleErrors(response);
            }
        });
        $A.enqueueAction(action);
    },

    createQuote: function(component) {
        component.set('v.isLoading', true);
        var oppDetails = component.get('v.oppDetails');

        var quoteInput = {
            name: component.get('v.quoteName'),
            opportunityId: component.get('v.recordId'),
            pricebookId: oppDetails.pricebookId,
            quoteDate: component.get('v.quoteDate'),
            validTill: component.get('v.validTill'),
            billingAddress: component.get('v.billingAddress'),
            shippingAddress: component.get('v.shippingAddress'),
            shippingMode: component.get('v.shippingMode'),
            vertical: component.get('v.vertical')
        };

        var selectedProducts = component.get('v.selectedProducts');
        var lineItems = selectedProducts.map(function(sp) {
            return {
                productId: sp.productId,
                pricebookEntryId: sp.pricebookEntryId,
                quantity: sp.quantity || 1,
                unitPrice: sp.unitPrice || 0,
                discount: sp.discount || 0,
                taxType: sp.taxType || 'GST',
                lineDescription: sp.lineDescription || '',
                detailedDescription: sp.detailedDescription || ''
            };
        });

        var action = component.get('c.createQuoteWithLineItems');
        action.setParams({
            quoteJSON: JSON.stringify(quoteInput),
            lineItemsJSON: JSON.stringify(lineItems)
        });
        action.setCallback(this, function(response) {
            component.set('v.isLoading', false);
            if (response.getState() === 'SUCCESS') {
                var quoteId = response.getReturnValue();
                component.set('v.showCreateForm', false);
                component.set('v.selectedProducts', []);
                component.set('v.searchResults', []);
                this.showToast('Success', 'Quote created successfully.', 'success');
                this.loadExistingQuotes(component);
            } else {
                this.handleErrors(response);
            }
        });
        $A.enqueueAction(action);
    },

    loadQuoteDetails: function(component, quoteId) {
        component.set('v.isLoading', true);
        var action = component.get('c.getQuoteDetails');
        action.setParams({ quoteId: quoteId });
        action.setCallback(this, function(response) {
            component.set('v.isLoading', false);
            if (response.getState() === 'SUCCESS') {
                component.set('v.quoteDetail', response.getReturnValue());
            } else {
                this.handleErrors(response);
            }
        });
        $A.enqueueAction(action);
    },

    doDeleteLineItem: function(component, lineItemId) {
        component.set('v.isLoading', true);
        var action = component.get('c.deleteLineItem');
        action.setParams({ lineItemId: lineItemId });
        action.setCallback(this, function(response) {
            component.set('v.isLoading', false);
            if (response.getState() === 'SUCCESS') {
                this.showToast('Success', 'Line item removed.', 'success');
                this.loadQuoteDetails(component, component.get('v.selectedQuoteId'));
            } else {
                this.handleErrors(response);
            }
        });
        $A.enqueueAction(action);
    },

    doAddItemsToExistingQuote: function(component) {
        component.set('v.isLoading', true);
        var selectedProducts = component.get('v.selectedProducts');
        var lineItems = selectedProducts.map(function(sp) {
            return {
                productId: sp.productId,
                pricebookEntryId: sp.pricebookEntryId,
                quantity: sp.quantity || 1,
                unitPrice: sp.unitPrice || 0,
                discount: sp.discount || 0,
                taxType: sp.taxType || 'GST',
                lineDescription: sp.lineDescription || '',
                detailedDescription: sp.detailedDescription || ''
            };
        });

        var action = component.get('c.addLineItemsToQuote');
        action.setParams({
            quoteId: component.get('v.selectedQuoteId'),
            lineItemsJSON: JSON.stringify(lineItems)
        });
        action.setCallback(this, function(response) {
            component.set('v.isLoading', false);
            if (response.getState() === 'SUCCESS') {
                component.set('v.showProductSearch', false);
                component.set('v.selectedProducts', []);
                component.set('v.searchResults', []);
                this.showToast('Success', 'Products added to quote.', 'success');
                this.loadQuoteDetails(component, component.get('v.selectedQuoteId'));
            } else {
                this.handleErrors(response);
            }
        });
        $A.enqueueAction(action);
    },

    showToast: function(title, message, type) {
        var toastEvent = $A.get('e.force:showToast');
        toastEvent.setParams({
            title: title,
            message: message,
            type: type
        });
        toastEvent.fire();
    },

    handleErrors: function(response) {
        var errors = response.getError();
        var errorMessage = 'An error occurred.';
        if (errors && errors[0] && errors[0].message) {
            errorMessage = errors[0].message;
        }
        this.showToast('Error', errorMessage, 'error');
    }
})