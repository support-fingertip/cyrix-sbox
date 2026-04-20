/**
 * Controller for the Create / Edit Sales Order LWC.
 * Provides methods to fetch Quote context (customer info + line items),
 * list available warehouses (Branch__c), list Pricebook products, and
 * create an Order + OrderItems from the selected quote lines.
 */
public with sharing class CreateSalesOrderController {

    /**
     * Returns the Quote header info (customer, owner, addresses, commercial
     * and operational fields) plus its line items so the LWC can render a
     * full Quote-like read-only view in the Sales Order modal.
     *
     * Quote-status gating is done at the Quick Action button visibility
     * level, not here -- this method assumes it's only invoked for Quotes
     * that are eligible to be converted.
     */
    @AuraEnabled(cacheable=true)
    public static QuoteContext getQuoteDetails(Id quoteId) {
        if (quoteId == null) {
            throw new AuraHandledException('Quote Id is required.');
        }

        Quote q = [
            SELECT Id, Name, QuoteNumber, AccountId, Account.Name,
                   Pricebook2Id, Pricebook2.Name,
                   OpportunityId, Opportunity.Name,
                   ContactId, Contact.Name, Contact.Email, Contact.Phone,
                   Email, Phone,
                   OwnerId, Owner.Name,
                   BillingName, BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingName, ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Status, GrandTotal, TotalPrice, Subtotal, Discount, ShippingHandling, Tax,
                   ExpirationDate, Description,
                   Quote_Date__c, Shipping_Mode__c, Valid_Till__c, Vertical__c,
                   Reason_for_Revision__c, Billing_Address__c, is_Active__c,
                   Quote_Valid_Till_in_days__c, Business_Vertical__c,
                   Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                   Delivery__c, Bank_Name__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];


        List<QuoteLineItem> items = [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure, Product2.Tax__c,
                   PricebookEntryId, PricebookEntry.UnitPrice,
                   PricebookEntry.Pricebook2Id, PricebookEntry.Pricebook2.Name,
                   PricebookEntry.Max_Discount_Percentage__c,
                   Quantity, UnitPrice, TotalPrice, Discount, Description,
                   Tax__c, Tax_Amount__c, Price_Status__c,
                   Source_Pricebook_Ref__c, Source_Pricebook__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY SortOrder NULLS LAST, CreatedDate
        ];

        QuoteContext ctx = new QuoteContext();
        ctx.quoteId                = q.Id;
        ctx.quoteName              = q.Name;
        ctx.quoteNumber            = q.QuoteNumber;
        ctx.accountId              = q.AccountId;
        ctx.customerName           = q.Account != null ? q.Account.Name : null;
        ctx.pricebookId            = q.Pricebook2Id;
        ctx.pricebookName          = q.Pricebook2 != null ? q.Pricebook2.Name : null;
        ctx.opportunityId          = q.OpportunityId;
        ctx.opportunityName        = q.Opportunity != null ? q.Opportunity.Name : null;
        ctx.email                  = q.Email != null ? q.Email : (q.Contact != null ? q.Contact.Email : null);
        ctx.phone                  = q.Phone != null ? q.Phone : (q.Contact != null ? q.Contact.Phone : null);
        ctx.executiveAssigned      = q.Owner != null ? q.Owner.Name : null;
        ctx.status                 = q.Status;
        ctx.description            = q.Description;
        ctx.quoteDate              = q.Quote_Date__c;
        ctx.validTill              = q.Valid_Till__c;
        ctx.quoteValidTillInDays   = q.Quote_Valid_Till_in_days__c != null ? String.valueOf(q.Quote_Valid_Till_in_days__c) : null;
        ctx.businessVertical       = q.Business_Vertical__c;
        ctx.vertical               = q.Vertical__c;
        ctx.shippingMode           = q.Shipping_Mode__c;
        ctx.delivery               = q.Delivery__c;
        ctx.contractPeriodFromDate = q.Contract_Period_From_Date__c;
        ctx.contractPeriodEndDate  = q.Contract_Period_End_Date__c;
        ctx.bankName               = q.Bank_Name__c;
        ctx.isActive               = q.is_Active__c;
        ctx.grandTotal             = q.GrandTotal;
        ctx.totalPrice             = q.TotalPrice;
        ctx.subtotal               = q.Subtotal;
        ctx.discount               = q.Discount;
        ctx.shippingHandling       = q.ShippingHandling;
        ctx.tax                    = q.Tax;
        // Bill To
        ctx.billToName             = q.BillingName;
        ctx.billToStreet           = q.BillingStreet;
        ctx.billToCity             = q.BillingCity;
        ctx.billToState            = q.BillingState;
        ctx.billToPostalCode       = q.BillingPostalCode;
        ctx.billToCountry          = q.BillingCountry;
        ctx.billingAddress         = formatAddress(q.BillingStreet, q.BillingCity, q.BillingState, q.BillingPostalCode, q.BillingCountry);
        // Ship To
        ctx.shipToName             = q.ShippingName;
        ctx.shipToStreet           = q.ShippingStreet;
        ctx.shipToCity             = q.ShippingCity;
        ctx.shipToState            = q.ShippingState;
        ctx.shipToPostalCode       = q.ShippingPostalCode;
        ctx.shipToCountry          = q.ShippingCountry;
        ctx.shippingAddress        = formatAddress(q.ShippingStreet, q.ShippingCity, q.ShippingState, q.ShippingPostalCode, q.ShippingCountry);

        // Payment Terms (child records on Quote). Formatted into a text summary
        // so the LWC modal and the Order.Payment_Terms__c field can display it
        // read-only. No structure retained -- purely display.
        ctx.paymentTerms = buildPaymentTermsText(quoteId);

        List<QuoteItemWrap> wraps = new List<QuoteItemWrap>();
        for (QuoteLineItem qli : items) {
            QuoteItemWrap w = new QuoteItemWrap();
            w.lineId           = qli.Id;
            w.productId        = qli.Product2Id;
            w.productName      = qli.Product2 != null ? qli.Product2.Name : null;
            w.productCode      = qli.Product2 != null ? qli.Product2.ProductCode : null;
            w.uom              = qli.Product2 != null ? qli.Product2.QuantityUnitOfMeasure : null;
            w.pricebookEntryId = qli.PricebookEntryId;
            w.pricebookName    = (qli.PricebookEntry != null && qli.PricebookEntry.Pricebook2 != null)
                                 ? qli.PricebookEntry.Pricebook2.Name : null;
            w.listPrice        = qli.PricebookEntry != null ? qli.PricebookEntry.UnitPrice : null;
            w.quantity         = qli.Quantity;
            w.unitPrice        = qli.UnitPrice;
            w.totalPrice       = qli.TotalPrice;
            w.discount         = qli.Discount;
            w.description      = qli.Description;
            w.tax              = qli.Tax__c;
            w.taxAmount        = qli.Tax_Amount__c;
            w.priceStatus      = qli.Price_Status__c;
            w.sourcePricebookId = qli.Source_Pricebook_Ref__c;
            w.maxDiscount      = qli.PricebookEntry != null ? qli.PricebookEntry.Max_Discount_Percentage__c : null;
            wraps.add(w);
        }
        ctx.items = wraps;

        return ctx;
    }

    /**
     * Returns the list of active warehouses (Branch__c records) to populate
     * the Warehouse picklist. Retained for backward compatibility.
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
                   Product2.QuantityUnitOfMeasure, Product2.Tax__c,
                   Product2.Product_Category__c, Product2.Make__c, Product2.Model__c,
                   Product2.HSN_Code__c, UnitPrice,
                   Max_Discount_Percentage__c,
                   Pricebook2Id, Pricebook2.Name
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
            opt.productCode = pbe.Product2.ProductCode;
            opt.uom = pbe.Product2.QuantityUnitOfMeasure;
            opt.listPrice = pbe.UnitPrice;
            opt.unitPrice = pbe.UnitPrice;
            opt.tax = pbe.Product2.Tax__c;
            opt.maxDiscount = pbe.Max_Discount_Percentage__c;
            opt.category = pbe.Product2.Product_Category__c;
            opt.makeModel = (pbe.Product2.Make__c != null ? pbe.Product2.Make__c : '') +
                            (pbe.Product2.Model__c != null ? ' / ' + pbe.Product2.Model__c : '');
            opt.hsnCode = pbe.Product2.HSN_Code__c;
            opt.priceSource = pbe.Pricebook2 != null ? pbe.Pricebook2.Name : null;
            result.add(opt);
        }
        return result;
    }

    /**
     * Creates an Order and its OrderItems from the given Quote and form inputs.
     * Returns the newly created Order Id so the LWC can navigate to it.
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
                   Valid_Till__c, Vertical__c, Reason_for_Revision__c, Billing_Address__c,
                   Quote_Valid_Till_in_days__c, Business_Vertical__c,
                   Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                   Delivery__c, Bank_Name__c, is_Active__c
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
            ord.BillToContactId = q.ContactId;
            ord.EffectiveDate  = Date.today();
            ord.Status         = 'Draft';
            ord.Description    = remarks;
            ord.Approval_Status__c = 'Pending';
            ord.Quote_Approved_Date_Time__c = System.now();

            // Addresses
            ord.BillingStreet      = q.BillingStreet;
            ord.BillingCity        = q.BillingCity;
            ord.BillingState       = q.BillingState;
            ord.BillingPostalCode  = q.BillingPostalCode;
            ord.BillingCountry     = q.BillingCountry;
            ord.ShippingStreet     = q.ShippingStreet;
            ord.ShippingCity       = q.ShippingCity;
            ord.ShippingState      = q.ShippingState;
            ord.ShippingPostalCode = q.ShippingPostalCode;
            ord.ShippingCountry    = q.ShippingCountry;

            // Mirrored custom header fields from Quote -> Order.
            ord.Quote_Date__c                 = q.Quote_Date__c;
            ord.Shipping_Mode__c              = q.Shipping_Mode__c;
            ord.Valid_Till__c                 = q.Valid_Till__c;
            ord.Vertical__c                   = q.Vertical__c;
            ord.Reason_for_Revision__c        = q.Reason_for_Revision__c;
            ord.Billing_Address__c            = q.Billing_Address__c;
            ord.Quote_Valid_Till_in_days__c   = q.Quote_Valid_Till_in_days__c;
            ord.Business_Vertical__c          = q.Business_Vertical__c;
            ord.Contract_Period_From_Date__c  = q.Contract_Period_From_Date__c;
            ord.Contract_Period_End_Date__c   = q.Contract_Period_End_Date__c;
            ord.Delivery__c                   = q.Delivery__c;
            ord.Bank_Name__c                  = q.Bank_Name__c;
            ord.is_Active__c                  = q.is_Active__c == true;
            ord.Payment_Terms__c              = buildPaymentTermsText(quoteId);

            insert ord;

            List<OrderItem> orderItems = new List<OrderItem>();

            // Build OrderItems from selected Quote lines.
            if (hasQuoteLines) {
                Map<Id, QuoteLineItem> quoteLinesById = new Map<Id, QuoteLineItem>([
                    SELECT Id, Product2Id, PricebookEntryId, Quantity, UnitPrice,
                           Discount, Description, Tax__c, Tax_Amount__c, Price_Status__c,
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
                    oi.Price_Status__c         = src.Price_Status__c;
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

    /**
     * Formats the Quote's Payment_Term__c child records into a single
     * multi-line text block for display on the Sales Order modal and
     * for storage on Order.Payment_Terms__c.
     *
     * Output example:
     *   1. 50.00% - Advance on PO
     *   2. 40.00% - Before Dispatch
     *   3. 10.00% - After Installation
     */
    private static String buildPaymentTermsText(Id quoteId) {
        if (quoteId == null) return null;
        List<Payment_Term__c> terms = [
            SELECT Id, Payment_Term__c, Percentage__c
            FROM Payment_Term__c
            WHERE Quote__c = :quoteId
            ORDER BY CreatedDate ASC
            LIMIT 200
        ];
        if (terms.isEmpty()) return null;

        List<String> lines = new List<String>();
        Integer idx = 1;
        for (Payment_Term__c pt : terms) {
            String pct = pt.Percentage__c != null ? pt.Percentage__c.setScale(2).toPlainString() + '%' : '';
            String termDesc = pt.Payment_Term__c != null ? String.valueOf(pt.Payment_Term__c) : '';
            String line;
            if (String.isNotBlank(pct) && String.isNotBlank(termDesc)) {
                line = idx + '. ' + pct + ' - ' + termDesc;
            } else if (String.isNotBlank(pct)) {
                line = idx + '. ' + pct;
            } else {
                line = idx + '. ' + termDesc;
            }
            lines.add(line);
            idx++;
        }
        return String.join(lines, '\n');
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

    @AuraEnabled(cacheable=true)
    public static QuoteContext getOrderDetails(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        Order o = [
            SELECT Id, OrderNumber, AccountId, Account.Name,
                   Pricebook2Id, Pricebook2.Name,
                   OpportunityId, Opportunity.Name,
                   BillToContactId,
                   OwnerId, Owner.Name,
                   BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                   ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   Status, TotalAmount, Description,
                   Quote_Date__c, Shipping_Mode__c, Valid_Till__c, Vertical__c,
                   Reason_for_Revision__c, Billing_Address__c, is_Active__c,
                   Quote_Valid_Till_in_days__c, Business_Vertical__c,
                   Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                   Delivery__c, Bank_Name__c, Payment_Terms__c,
                   Approval_Status__c, Price_Status__c, EffectiveDate
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        List<OrderItem> items = [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure, Product2.Tax__c,
                   PricebookEntryId, PricebookEntry.UnitPrice,
                   PricebookEntry.Pricebook2Id, PricebookEntry.Pricebook2.Name,
                   PricebookEntry.Max_Discount_Percentage__c,
                   Quantity, UnitPrice, TotalPrice, Description,
                   Tax__c, Tax_Amount__c, Price_Status__c, Discount__c,
                   Source_Pricebook_Ref__c, Source_Pricebook__c
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY CreatedDate
        ];

        QuoteContext ctx = new QuoteContext();
        ctx.quoteId                = o.Id;
        ctx.quoteName              = o.OrderNumber;
        ctx.quoteNumber            = o.OrderNumber;
        ctx.accountId              = o.AccountId;
        ctx.customerName           = o.Account != null ? o.Account.Name : null;
        ctx.pricebookId            = o.Pricebook2Id;
        ctx.pricebookName          = o.Pricebook2 != null ? o.Pricebook2.Name : null;
        ctx.opportunityId          = o.OpportunityId;
        ctx.opportunityName        = o.Opportunity != null ? o.Opportunity.Name : null;
        ctx.executiveAssigned      = o.Owner != null ? o.Owner.Name : null;
        ctx.status                 = o.Status;
        ctx.description            = o.Description;
        ctx.quoteDate              = o.Quote_Date__c;
        ctx.validTill              = o.Valid_Till__c;
        ctx.quoteValidTillInDays   = o.Quote_Valid_Till_in_days__c != null ? String.valueOf(o.Quote_Valid_Till_in_days__c) : null;
        ctx.businessVertical       = o.Business_Vertical__c;
        ctx.vertical               = o.Vertical__c;
        ctx.shippingMode           = o.Shipping_Mode__c;
        ctx.delivery               = o.Delivery__c;
        ctx.contractPeriodFromDate = o.Contract_Period_From_Date__c;
        ctx.contractPeriodEndDate  = o.Contract_Period_End_Date__c;
        ctx.bankName               = o.Bank_Name__c;
        ctx.isActive               = o.is_Active__c;
        ctx.grandTotal             = o.TotalAmount;
        ctx.billToName             = o.Account != null ? o.Account.Name : null;
        ctx.billToStreet           = o.BillingStreet;
        ctx.billToCity             = o.BillingCity;
        ctx.billToState            = o.BillingState;
        ctx.billToPostalCode       = o.BillingPostalCode;
        ctx.billToCountry          = o.BillingCountry;
        ctx.billingAddress         = formatAddress(o.BillingStreet, o.BillingCity, o.BillingState, o.BillingPostalCode, o.BillingCountry);
        ctx.shipToName             = o.Account != null ? o.Account.Name : null;
        ctx.shipToStreet           = o.ShippingStreet;
        ctx.shipToCity             = o.ShippingCity;
        ctx.shipToState            = o.ShippingState;
        ctx.shipToPostalCode       = o.ShippingPostalCode;
        ctx.shipToCountry          = o.ShippingCountry;
        ctx.shippingAddress        = formatAddress(o.ShippingStreet, o.ShippingCity, o.ShippingState, o.ShippingPostalCode, o.ShippingCountry);
        ctx.paymentTerms           = o.Payment_Terms__c;

        List<QuoteItemWrap> wraps = new List<QuoteItemWrap>();
        for (OrderItem oi : items) {
            QuoteItemWrap w = new QuoteItemWrap();
            w.lineId           = oi.Id;
            w.productId        = oi.Product2Id;
            w.productName      = oi.Product2 != null ? oi.Product2.Name : null;
            w.productCode      = oi.Product2 != null ? oi.Product2.ProductCode : null;
            w.uom              = oi.Product2 != null ? oi.Product2.QuantityUnitOfMeasure : null;
            w.pricebookEntryId = oi.PricebookEntryId;
            w.pricebookName    = (oi.PricebookEntry != null && oi.PricebookEntry.Pricebook2 != null)
                                 ? oi.PricebookEntry.Pricebook2.Name : null;
            w.listPrice        = oi.PricebookEntry != null ? oi.PricebookEntry.UnitPrice : null;
            w.quantity         = oi.Quantity;
            w.unitPrice        = oi.UnitPrice;
            w.totalPrice       = oi.TotalPrice;
            w.discount         = oi.Discount__c;
            w.description      = oi.Description;
            w.tax              = oi.Tax__c;
            w.taxAmount        = oi.Tax_Amount__c;
            w.priceStatus      = oi.Price_Status__c;
            w.sourcePricebookId = oi.Source_Pricebook_Ref__c;
            w.maxDiscount      = oi.PricebookEntry != null ? oi.PricebookEntry.Max_Discount_Percentage__c : null;
            wraps.add(w);
        }
        ctx.items = wraps;

        return ctx;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductOption> getPricebookProductsForOrder(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        Order o = [SELECT Id, Pricebook2Id FROM Order WHERE Id = :orderId LIMIT 1];
        if (o.Pricebook2Id == null) {
            return new List<ProductOption>();
        }
        List<ProductOption> result = new List<ProductOption>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure, Product2.Tax__c,
                   Product2.Product_Category__c, Product2.Make__c, Product2.Model__c,
                   Product2.HSN_Code__c, UnitPrice,
                   Max_Discount_Percentage__c,
                   Pricebook2Id, Pricebook2.Name
            FROM PricebookEntry
            WHERE Pricebook2Id = :o.Pricebook2Id
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
            opt.productCode = pbe.Product2.ProductCode;
            opt.uom = pbe.Product2.QuantityUnitOfMeasure;
            opt.listPrice = pbe.UnitPrice;
            opt.unitPrice = pbe.UnitPrice;
            opt.tax = pbe.Product2.Tax__c;
            opt.maxDiscount = pbe.Max_Discount_Percentage__c;
            opt.category = pbe.Product2.Product_Category__c;
            opt.makeModel = (pbe.Product2.Make__c != null ? pbe.Product2.Make__c : '') +
                            (pbe.Product2.Model__c != null ? ' / ' + pbe.Product2.Model__c : '');
            opt.hsnCode = pbe.Product2.HSN_Code__c;
            opt.priceSource = pbe.Pricebook2 != null ? pbe.Pricebook2.Name : null;
            result.add(opt);
        }
        return result;
    }

    @AuraEnabled
    public static Id updateSalesOrder(
        Id orderId,
        String remarks,
        List<Id> existingLineIds,
        Map<Id, Decimal> quantityByLineId,
        Map<Id, Decimal> discountByLineId,
        List<Id> manualPricebookEntryIds,
        Map<Id, Decimal> manualQuantityByPbeId,
        Map<Id, Decimal> manualDiscountByPbeId
    ) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }

        Order o = [SELECT Id, Pricebook2Id, Status FROM Order WHERE Id = :orderId LIMIT 1];

        Savepoint sp = Database.setSavepoint();
        try {
            o.Description = remarks;
            update o;

            Set<Id> keepLineIds = new Set<Id>();
            if (existingLineIds != null) keepLineIds.addAll(existingLineIds);

            List<OrderItem> currentItems = [
                SELECT Id FROM OrderItem WHERE OrderId = :orderId
            ];
            List<OrderItem> toDelete = new List<OrderItem>();
            for (OrderItem oi : currentItems) {
                if (!keepLineIds.contains(oi.Id)) {
                    toDelete.add(oi);
                }
            }
            if (!toDelete.isEmpty()) {
                delete toDelete;
            }

            List<OrderItem> toUpdate = new List<OrderItem>();
            if (existingLineIds != null) {
                for (Id lineId : existingLineIds) {
                    OrderItem oi = new OrderItem(Id = lineId);
                    if (quantityByLineId != null && quantityByLineId.containsKey(lineId)) {
                        oi.Quantity = quantityByLineId.get(lineId);
                    }
                    if (discountByLineId != null && discountByLineId.containsKey(lineId)) {
                        oi.Discount__c = discountByLineId.get(lineId);
                    }
                    toUpdate.add(oi);
                }
            }
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }

            if (manualPricebookEntryIds != null && !manualPricebookEntryIds.isEmpty()) {
                Map<Id, PricebookEntry> pbeById = new Map<Id, PricebookEntry>([
                    SELECT Id, Product2Id, Pricebook2Id, UnitPrice, IsActive,
                           Product2.Tax__c
                    FROM PricebookEntry
                    WHERE Id IN :manualPricebookEntryIds
                ]);
                List<OrderItem> newItems = new List<OrderItem>();
                for (Id pbeId : manualPricebookEntryIds) {
                    PricebookEntry pbe = pbeById.get(pbeId);
                    if (pbe == null || pbe.IsActive != true) continue;

                    Decimal qty = (manualQuantityByPbeId != null && manualQuantityByPbeId.get(pbeId) != null)
                        ? manualQuantityByPbeId.get(pbeId) : 1;
                    Decimal disc = (manualDiscountByPbeId != null && manualDiscountByPbeId.get(pbeId) != null)
                        ? manualDiscountByPbeId.get(pbeId) : 0;

                    OrderItem oi = new OrderItem();
                    oi.OrderId          = orderId;
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
                    newItems.add(oi);
                }
                if (!newItems.isEmpty()) {
                    insert newItems;
                }
            }

            return orderId;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Failed to update Sales Order: ' + e.getMessage());
        }
    }

    // ===== Wrapper classes =====

    public class QuoteContext {
        @AuraEnabled public Id quoteId;
        @AuraEnabled public String quoteName;
        @AuraEnabled public String quoteNumber;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String customerName;
        @AuraEnabled public Id pricebookId;
        @AuraEnabled public String pricebookName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String executiveAssigned;
        @AuraEnabled public String status;
        @AuraEnabled public String description;
        @AuraEnabled public Date quoteDate;
        @AuraEnabled public Date validTill;
        @AuraEnabled public String quoteValidTillInDays;
        @AuraEnabled public String businessVertical;
        @AuraEnabled public String vertical;
        @AuraEnabled public String shippingMode;
        @AuraEnabled public String delivery;
        @AuraEnabled public Date contractPeriodFromDate;
        @AuraEnabled public Date contractPeriodEndDate;
        @AuraEnabled public String bankName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Decimal subtotal;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal shippingHandling;
        @AuraEnabled public Decimal tax;
        // Bill To
        @AuraEnabled public String billToName;
        @AuraEnabled public String billToStreet;
        @AuraEnabled public String billToCity;
        @AuraEnabled public String billToState;
        @AuraEnabled public String billToPostalCode;
        @AuraEnabled public String billToCountry;
        @AuraEnabled public String billingAddress;
        // Ship To
        @AuraEnabled public String shipToName;
        @AuraEnabled public String shipToStreet;
        @AuraEnabled public String shipToCity;
        @AuraEnabled public String shipToState;
        @AuraEnabled public String shipToPostalCode;
        @AuraEnabled public String shipToCountry;
        @AuraEnabled public String shippingAddress;
        @AuraEnabled public String paymentTerms;
        @AuraEnabled public List<QuoteItemWrap> items;
    }

    public class QuoteItemWrap {
        @AuraEnabled public Id lineId;
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String uom;
        @AuraEnabled public Id pricebookEntryId;
        @AuraEnabled public String pricebookName;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPrice;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal taxAmount;
        @AuraEnabled public String priceStatus;
        @AuraEnabled public Id sourcePricebookId;
        @AuraEnabled public Decimal maxDiscount;
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
        @AuraEnabled public String productCode;
        @AuraEnabled public String uom;
        @AuraEnabled public Decimal listPrice;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public Decimal maxDiscount;
        @AuraEnabled public String category;
        @AuraEnabled public String makeModel;
        @AuraEnabled public String hsnCode;
        @AuraEnabled public String priceSource;
    }

}