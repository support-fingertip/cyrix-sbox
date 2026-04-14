/**
 * Controller for the "Create Sales Order" LWC launched from a Quote record.
 * Provides methods to fetch Quote context (customer info + line items),
 * list available warehouses (Branch__c), and create an Order + OrderItems
 * from the selected quote lines.
 */
public with sharing class CreateSalesOrderController {

    /**
     * Returns the Quote header info (customer, owner, addresses) plus its line items
     * so the LWC can render the Sales Order modal.
     */
    @AuraEnabled(cacheable=true)
    public static QuoteContext getQuoteDetails(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        Quote q = [
            SELECT Id, Name, QuoteNumber, AccountId, Account.Name,
                   Pricebook2Id, OpportunityId,
                   ContactId, Contact.Name, Contact.Email, Contact.Phone,
                   Email, Phone,
                   OwnerId, Owner.Name,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Status, GrandTotal, TotalPrice
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        List<QuoteLineItem> items = [
            SELECT Id, Product2Id, Product2.Name, PricebookEntryId,
                   Quantity, UnitPrice, TotalPrice, Discount, Description,
                   Tax__c, Tax_Amount__c, Source_Pricebook_Ref__c, Source_Pricebook__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY SortOrder NULLS LAST, CreatedDate
        ];

        QuoteContext ctx = new QuoteContext();
        ctx.quoteId           = q.Id;
        ctx.quoteName         = q.Name;
        ctx.quoteNumber       = q.QuoteNumber;
        ctx.accountId         = q.AccountId;
        ctx.customerName      = q.Account != null ? q.Account.Name : null;
        ctx.pricebookId       = q.Pricebook2Id;
        ctx.opportunityId     = q.OpportunityId;
        ctx.email             = q.Email != null ? q.Email : (q.Contact != null ? q.Contact.Email : null);
        ctx.phone             = q.Phone != null ? q.Phone : (q.Contact != null ? q.Contact.Phone : null);
        ctx.executiveAssigned = q.Owner != null ? q.Owner.Name : null;
        ctx.billingAddress    = formatAddress(q.BillingStreet, q.BillingCity, q.BillingState, q.BillingPostalCode, q.BillingCountry);
        ctx.shippingAddress   = formatAddress(q.ShippingStreet, q.ShippingCity, q.ShippingState, q.ShippingPostalCode, q.ShippingCountry);

        List<QuoteItemWrap> wraps = new List<QuoteItemWrap>();
        for (QuoteLineItem qli : items) {
            QuoteItemWrap w = new QuoteItemWrap();
            w.lineId           = qli.Id;
            w.productId        = qli.Product2Id;
            w.productName      = qli.Product2 != null ? qli.Product2.Name : null;
            w.pricebookEntryId = qli.PricebookEntryId;
            w.quantity         = qli.Quantity;
            w.unitPrice        = qli.UnitPrice;
            w.totalPrice       = qli.TotalPrice;
            w.discount         = qli.Discount;
            w.description      = qli.Description;
            w.tax              = qli.Tax__c;
            w.taxAmount        = qli.Tax_Amount__c;
            w.sourcePricebookId = qli.Source_Pricebook_Ref__c;
            wraps.add(w);
        }
        ctx.items = wraps;

        return ctx;
    }

    /**
     * Returns the list of active warehouses (Branch__c records) to populate
     * the Warehouse picklist in the modal.
     */
    @AuraEnabled(cacheable=true)
    public static List<WarehouseOption> getWarehouses() {
        List<WarehouseOption> options = new List<WarehouseOption>();
        for (Branch__c b : [
            SELECT Id, Name
            FROM Branch__c
            ORDER BY Name ASC
            LIMIT 200
        ]) {
            WarehouseOption opt = new WarehouseOption();
            opt.value = b.Id;
            opt.label = b.Name;
            options.add(opt);
        }
        return options;
    }

    /**
     * Creates an Order and its OrderItems from the given Quote and form inputs.
     * Returns the newly created Order Id so the LWC can navigate to it.
     */
    @AuraEnabled
    public static Id createSalesOrder(Id quoteId, SalesOrderInput input) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        if (input == null) {
            throw new AuraHandledException('Order input is required.');
        }
        if (String.isBlank(input.deliveryCommittedDate)) {
            throw new AuraHandledException('Delivery Committed Date is required.');
        }
        if (String.isBlank(input.warehouseId)) {
            throw new AuraHandledException('Warehouse is required.');
        }
        if (input.selectedItems == null || input.selectedItems.isEmpty()) {
            throw new AuraHandledException('Please select at least one quote item.');
        }

        Date deliveryDate;
        try {
            deliveryDate = Date.valueOf(input.deliveryCommittedDate);
        } catch (Exception ex) {
            throw new AuraHandledException('Invalid Delivery Committed Date: ' + input.deliveryCommittedDate);
        }

        Quote q = [
            SELECT Id, AccountId, Pricebook2Id, OpportunityId, ContactId,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        Savepoint sp = Database.setSavepoint();
        try {
            Order ord = new Order();
            ord.AccountId      = q.AccountId;
            ord.Pricebook2Id   = q.Pricebook2Id;
            ord.QuoteId        = q.Id;
            ord.OpportunityId  = q.OpportunityId;
            ord.EffectiveDate  = deliveryDate;
            ord.Status         = 'Draft';
            ord.Branch__c      = input.warehouseId;
            ord.Description    = input.remarks;
            ord.is_Active__c   = input.creditOrder == true;

            // Copy addresses
            ord.BillingStreet     = q.BillingStreet;
            ord.BillingCity       = q.BillingCity;
            ord.BillingState      = q.BillingState;
            ord.BillingPostalCode = q.BillingPostalCode;
            ord.BillingCountry    = q.BillingCountry;
            ord.ShippingStreet     = q.ShippingStreet;
            ord.ShippingCity       = q.ShippingCity;
            ord.ShippingState      = q.ShippingState;
            ord.ShippingPostalCode = q.ShippingPostalCode;
            ord.ShippingCountry    = q.ShippingCountry;

            insert ord;

            // Build OrderItems from selected quote lines
            Map<Id, QuoteLineItem> quoteLinesById = new Map<Id, QuoteLineItem>([
                SELECT Id, Product2Id, PricebookEntryId, Quantity, UnitPrice,
                       Discount, Description, Tax__c, Tax_Amount__c,
                       Source_Pricebook_Ref__c, Source_Pricebook__c
                FROM QuoteLineItem
                WHERE QuoteId = :quoteId
            ]);

            List<OrderItem> orderItems = new List<OrderItem>();
            for (SelectedItem si : input.selectedItems) {
                QuoteLineItem src = quoteLinesById.get(si.lineId);
                if (src == null) continue;

                Decimal qty = si.quantity != null ? si.quantity : src.Quantity;

                OrderItem oi = new OrderItem();
                oi.OrderId             = ord.Id;
                oi.Product2Id          = src.Product2Id;
                oi.PricebookEntryId    = src.PricebookEntryId;
                oi.Quantity            = qty;
                oi.UnitPrice           = src.UnitPrice;
                oi.Description         = src.Description;
                oi.Tax__c              = src.Tax__c;
                oi.Tax_Amount__c       = src.Tax_Amount__c;
                oi.Source_Pricebook_Ref__c = src.Source_Pricebook_Ref__c;
                oi.Source_Pricebook__c     = src.Source_Pricebook__c;
                orderItems.add(oi);
            }

            if (!orderItems.isEmpty()) {
                insert orderItems;
            }

            return ord.Id;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Failed to create Sales Order: ' + e.getMessage());
        }
    }

    private static String formatAddress(String street, String city, String state, String zip, String country) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(street))  parts.add(street);
        if (String.isNotBlank(city))    parts.add(city);
        if (String.isNotBlank(state))   parts.add(state);
        if (String.isNotBlank(zip))     parts.add(zip);
        if (String.isNotBlank(country)) parts.add(country);
        return String.join(parts, ', ');
    }

    // ===== Wrapper classes =====

    public class QuoteContext {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String customerName;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String executiveAssigned;
        @AuraEnabled public String billingAddress;
        @AuraEnabled public String shippingAddress;
        @AuraEnabled public List<QuoteItemWrap> items;
    }

    public class QuoteItemWrap {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal taxAmount;
        @AuraEnabled public Id sourcePricebookId;
    }

    public class WarehouseOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class SalesOrderInput {
        // Kept as String to avoid JSON deserialization edge cases;
        // parsed to Date in createSalesOrder.
        @AuraEnabled public String deliveryCommittedDate;
        @AuraEnabled public String warehouseId;
        @AuraEnabled public String remarks;
        @AuraEnabled public Boolean creditOrder;
        @AuraEnabled public List<SelectedItem> selectedItems;
    }

    public class SelectedItem {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Decimal quantity;
    }
}