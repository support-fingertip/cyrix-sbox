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
     *
     * Blocks the load if the Quote is not in 'Approved' status — Sales Orders
     * may only be created from a finalized/approved Quote.
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

        if (q.Status != 'Approved') {
            throw new AuraHandledException(
                'Sales Order can only be created from an Approved Quote. ' +
                'Current Quote status: ' + (q.Status == null ? 'None' : q.Status) + '.'
            );
        }

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
     * Returns PricebookEntries (products) available in the Quote's Pricebook,
     * so the LWC can render an "Add Product" picker. Each option carries the
     * unit price and tax so the UI can render a row without an extra callout.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProductOption> getPricebookProducts(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        Quote q = [
            SELECT Id, Pricebook2Id
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        if (q.Pricebook2Id == null) {
            return new List<ProductOption>();
        }

        List<ProductOption> result = new List<ProductOption>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.Tax__c, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :q.Pricebook2Id
              AND IsActive = true
              AND Product2.IsActive = true
            ORDER BY Product2.Name ASC
            LIMIT 1000
        ]) {
            ProductOption opt = new ProductOption();
            opt.value = pbe.Id;
            opt.label = pbe.Product2.Name;
            opt.productId = pbe.Product2Id;
            opt.productName = pbe.Product2.Name;
            opt.unitPrice = pbe.UnitPrice;
            opt.tax = pbe.Product2.Tax__c;
            result.add(opt);
        }
        return result;
    }

    /**
     * Creates an Order and its OrderItems from the given Quote and form inputs.
     * Returns the newly created Order Id so the LWC can navigate to it.
     *
     * Flat parameters are used instead of a wrapper class so LWC → Apex
     * deserialization is fully deterministic.
     */
    @AuraEnabled
    public static Id createSalesOrder(
        Id quoteId,
        String remarks,
        List<Id> selectedLineIds,
        Map<Id, Decimal> quantityByLineId,
        Map<Id, Decimal> discountByLineId,
        List<Id> manualPricebookEntryIds,
        Map<Id, Decimal> manualQuantityByPbeId,
        Map<Id, Decimal> manualDiscountByPbeId
    ) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }
        Boolean hasQuoteLines = selectedLineIds != null && !selectedLineIds.isEmpty();
        Boolean hasManualLines = manualPricebookEntryIds != null && !manualPricebookEntryIds.isEmpty();
        if (!hasQuoteLines && !hasManualLines) {
            throw new AuraHandledException('Please add at least one product to the Sales Order.');
        }

        Quote q = [
            SELECT Id, Status, AccountId, Pricebook2Id, OpportunityId, ContactId,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Quote_Date__c, Shipping_Mode__c,
                   Valid_Till__c, Vertical__c, Reason_for_Revision__c, Billing_Address__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        // Gate: only Approved Quotes can be converted to Sales Orders.
        if (q.Status != 'Approved') {
            throw new AuraHandledException(
                'Sales Order can only be created from an Approved Quote. ' +
                'Current Quote status: ' + (q.Status == null ? 'None' : q.Status) + '.'
            );
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Order ord = new Order();
            ord.AccountId      = q.AccountId;
            ord.Pricebook2Id   = q.Pricebook2Id;
            ord.QuoteId        = q.Id;
            ord.OpportunityId  = q.OpportunityId;
            ord.BillToContactId = q.ContactId;
            ord.EffectiveDate  = Date.today();
            ord.Status         = 'Draft';
            ord.Description    = remarks;
            ord.Approval_Status__c = 'Pending';
            ord.Quote_Approved_Date_Time__c = System.now();

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

            // Copy mirrored custom header fields from Quote.
            // Note: Quote_Id__c on Order is an AutoNumber and cannot be
            // written. Revised_Quote__c is skipped here to avoid cross-org
            // field-drift deploy failures.
            ord.Quote_Date__c            = q.Quote_Date__c;
            ord.Shipping_Mode__c         = q.Shipping_Mode__c;
            ord.Valid_Till__c            = q.Valid_Till__c;
            ord.Vertical__c              = q.Vertical__c;
            ord.Reason_for_Revision__c   = q.Reason_for_Revision__c;
            ord.Billing_Address__c       = q.Billing_Address__c;

            insert ord;

            List<OrderItem> orderItems = new List<OrderItem>();

            // Build OrderItems from selected Quote lines.
            if (hasQuoteLines) {
                Map<Id, QuoteLineItem> quoteLinesById = new Map<Id, QuoteLineItem>([
                    SELECT Id, Product2Id, PricebookEntryId, Quantity, UnitPrice,
                           Discount, Description, Tax__c, Tax_Amount__c,
                           Source_Pricebook_Ref__c, Source_Pricebook__c
                    FROM QuoteLineItem
                    WHERE QuoteId = :quoteId
                ]);

                for (Id lineId : selectedLineIds) {
                    QuoteLineItem src = quoteLinesById.get(lineId);
                    if (src == null) continue;

                    Decimal qty = (quantityByLineId != null && quantityByLineId.get(lineId) != null)
                        ? quantityByLineId.get(lineId)
                        : src.Quantity;
                    Decimal disc = (discountByLineId != null && discountByLineId.get(lineId) != null)
                        ? discountByLineId.get(lineId)
                        : src.Discount;

                    OrderItem oi = new OrderItem();
                    oi.OrderId                 = ord.Id;
                    oi.Product2Id              = src.Product2Id;
                    oi.PricebookEntryId        = src.PricebookEntryId;
                    oi.Quantity                = qty;
                    oi.UnitPrice               = src.UnitPrice;
                    oi.Description             = src.Description;
                    oi.Tax__c                  = src.Tax__c;
                    oi.Tax_Amount__c           = src.Tax_Amount__c;
                    oi.Source_Pricebook_Ref__c = src.Source_Pricebook_Ref__c;
                    oi.Source_Pricebook__c     = src.Source_Pricebook__c;
                    if (disc != null) {
                        oi.Discount__c = disc;
                    }
                    orderItems.add(oi);
                }
            }

            // Build OrderItems from manually-added products.
            if (hasManualLines) {
                // Validate manual PricebookEntries belong to the Quote's Pricebook.
                Map<Id, PricebookEntry> pbeById = new Map<Id, PricebookEntry>([
                    SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive,
                           Product2.Tax__c
                    FROM PricebookEntry
                    WHERE Id IN :manualPricebookEntryIds
                ]);
                for (Id pbeId : manualPricebookEntryIds) {
                    PricebookEntry pbe = pbeById.get(pbeId);
                    if (pbe == null) continue;
                    if (pbe.Pricebook2Id != q.Pricebook2Id) {
                        throw new AuraHandledException(
                            'Manually added product must belong to the Quote\'s Pricebook.'
                        );
                    }
                    if (pbe.IsActive != true) continue;

                    Decimal qty = (manualQuantityByPbeId != null && manualQuantityByPbeId.get(pbeId) != null)
                        ? manualQuantityByPbeId.get(pbeId)
                        : 1;
                    Decimal disc = (manualDiscountByPbeId != null && manualDiscountByPbeId.get(pbeId) != null)
                        ? manualDiscountByPbeId.get(pbeId)
                        : 0;

                    OrderItem oi = new OrderItem();
                    oi.OrderId          = ord.Id;
                    oi.Product2Id       = pbe.Product2Id;
                    oi.PricebookEntryId = pbe.Id;
                    oi.Quantity         = qty;
                    oi.UnitPrice        = pbe.UnitPrice;
                    if (pbe.Product2 != null && pbe.Product2.Tax__c != null) {
                        oi.Tax__c = pbe.Product2.Tax__c;
                    }
                    if (disc != null) {
                        oi.Discount__c = disc;
                    }
                    orderItems.add(oi);
                }
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

    public class ProductOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;        // PricebookEntry Id
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal tax;
    }

}