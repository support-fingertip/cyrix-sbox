({
    doInit: function(component, event, helper) {
        helper.loadOpportunityDetails(component);
        helper.loadExistingQuotes(component);
    },

    openCreateForm: function(component, event, helper) {
        var oppDetails = component.get('v.oppDetails');
        component.set('v.quoteName', oppDetails.opportunityName + ' - Quote');
        component.set('v.quoteDate', new Date().toISOString().split('T')[0]);
        component.set('v.billingAddress', oppDetails.billingAddress || '');
        component.set('v.shippingAddress', oppDetails.shippingAddress || '');
        component.set('v.vertical', oppDetails.vertical || '');
        component.set('v.selectedProducts', []);
        component.set('v.searchResults', []);
        component.set('v.searchTerm', '');
        component.set('v.showCreateForm', true);
    },

    closeCreateForm: function(component, event, helper) {
        component.set('v.showCreateForm', false);
        component.set('v.selectedProducts', []);
        component.set('v.searchResults', []);
        component.set('v.searchTerm', '');
    },

    handleSearchKeyChange: function(component, event, helper) {
        var searchTerm = component.get('v.searchTerm');
        if (searchTerm && searchTerm.length >= 2) {
            window.clearTimeout(component._searchTimeout);
            component._searchTimeout = window.setTimeout(
                $A.getCallback(function() {
                    helper.doProductSearch(component);
                }), 400
            );
        } else {
            component.set('v.searchResults', []);
        }
    },

    searchProducts: function(component, event, helper) {
        helper.doProductSearch(component);
    },

    addProductToCart: function(component, event, helper) {
        var searchResults = component.get('v.searchResults');
        var row = event.currentTarget;

        // Find which row was clicked by traversing up to TR
        var tr = row;
        while (tr && tr.tagName !== 'TR') {
            tr = tr.parentElement;
        }
        if (!tr) return;

        var rowIndex = Array.from(tr.parentElement.children).indexOf(tr);
        if (rowIndex < 0 || rowIndex >= searchResults.length) return;

        var product = searchResults[rowIndex];
        var selectedProducts = component.get('v.selectedProducts') || [];

        // Check if already added
        var alreadyAdded = selectedProducts.some(function(sp) {
            return sp.productId === product.productId;
        });

        if (alreadyAdded) {
            helper.showToast('Info', 'This product is already in the list.', 'info');
            return;
        }

        selectedProducts.push({
            productId: product.productId,
            pricebookEntryId: product.pricebookEntryId,
            productName: product.productName,
            productCode: product.productCode,
            hsnCode: product.hsnCode,
            uom: product.uom,
            unitPrice: product.unitPrice,
            quantity: 1,
            discount: 0,
            taxType: 'GST',
            lineDescription: '',
            detailedDescription: ''
        });

        component.set('v.selectedProducts', selectedProducts);
        helper.showToast('Success', product.productName + ' added.', 'success');
    },

    removeFromCart: function(component, event, helper) {
        var idx = parseInt(event.getSource().get('v.value'));
        var selectedProducts = component.get('v.selectedProducts');
        selectedProducts.splice(idx, 1);
        component.set('v.selectedProducts', selectedProducts);
    },

    updateLineItem: function(component, event, helper) {
        // Two-way binding handles it automatically
    },

    saveQuote: function(component, event, helper) {
        var quoteName = component.get('v.quoteName');
        var quoteDate = component.get('v.quoteDate');

        if (!quoteName || !quoteDate) {
            helper.showToast('Error', 'Please fill in Quote Name and Quote Date.', 'error');
            return;
        }

        var selectedProducts = component.get('v.selectedProducts');
        if (!selectedProducts || selectedProducts.length === 0) {
            helper.showToast('Error', 'Please add at least one product.', 'error');
            return;
        }

        helper.createQuote(component);
    },

    viewQuoteDetails: function(component, event, helper) {
        var quoteId = event.getSource().get('v.value');
        component.set('v.selectedQuoteId', quoteId);
        helper.loadQuoteDetails(component, quoteId);
    },

    backToList: function(component, event, helper) {
        component.set('v.selectedQuoteId', '');
        component.set('v.quoteDetail', null);
        helper.loadExistingQuotes(component);
    },

    deleteLineItem: function(component, event, helper) {
        var lineItemId = event.getSource().get('v.value');
        helper.doDeleteLineItem(component, lineItemId);
    },

    openProductSearchForExisting: function(component, event, helper) {
        component.set('v.selectedProducts', []);
        component.set('v.searchResults', []);
        component.set('v.searchTerm', '');
        component.set('v.showProductSearch', true);
    },

    closeProductSearch: function(component, event, helper) {
        component.set('v.showProductSearch', false);
        component.set('v.selectedProducts', []);
        component.set('v.searchResults', []);
        component.set('v.searchTerm', '');
    },

    addItemsToExistingQuote: function(component, event, helper) {
        var selectedProducts = component.get('v.selectedProducts');
        if (!selectedProducts || selectedProducts.length === 0) {
            helper.showToast('Error', 'Please select at least one product.', 'error');
            return;
        }
        helper.doAddItemsToExistingQuote(component);
    }
})
