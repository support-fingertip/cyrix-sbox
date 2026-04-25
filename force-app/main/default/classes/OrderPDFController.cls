/* Class Name   : OrderPDFController
* Company       : Fingertipplus
* @description  : Apex controller for ProductOrder PDF Visualforce page.
*                 Mirrors QuotationPDFController for the Order object —
*                 queries Order, Account, Opportunity, OrderItem, then
*                 computes per-line GST and the AMC contract summary.
*/
public with sharing class OrderPDFController {
    public Order order { get; set; }
    public List<OrderItem> lineItems { get; set; }
    public List<Payment_Term__c> paymentTerms { get; set; }
    public List<Terms_Condition__c> termsConditions { get; set; }
    public String productNamesList { get; set; }
    public String grandTotalInWords { get; set; }
    public String productName { get; set; }
    public General_Settings__c general { get; set; }
    public String productStringify { get; set; }

    // AMC page summary — single-row contract table sums rate/GST/total
    // across every line item. GST on AMC is fixed at 18%.
    public Decimal amcTotalRate { get; set; }
    public Decimal amcGstAmount { get; set; }
    public Decimal amcGrandTotal { get; set; }

    // Per-line GST amount and line grand total, keyed by OrderItem Id.
    public Map<Id, Decimal> lineGstAmount { get; set; }
    public Map<Id, Decimal> lineGrandTotal { get; set; }

    // Order.Name pre-split on '/' so the PDF header can color each segment
    // independently (matches the Quote PDF header treatment).
    public String orderNamePart1 { get; set; }
    public String orderNamePart2 { get; set; }
    public String orderNamePart3 { get; set; }
    public String orderNamePart4 { get; set; }

    public OrderPDFController(ApexPages.StandardController stdController) {
        Id orderId = stdController.getId();
        if (orderId != null) {
            loadData(orderId);
        }
    }

    private void loadData(Id orderId) {
        List<Order> orders = [
            SELECT Id, Name, OrderNumber, Quote_Id__c, Quote_Date__c,
                   Status, Price_Status__c, is_Active__c,
                   Shipping_Mode__c, Quote_Valid_Till_in_days__c, Delivery__c,
                   TotalAmount, CurrencyIsoCode, Description, OwnerId,
                   OpportunityId, Opportunity.Name,
                   Opportunity.OwnerId, Opportunity.Owner.Name,
                   Opportunity.Owner.Title, Opportunity.Owner.Phone, Opportunity.Owner.Email,
                   AccountId, Account.Name, Account.Phone, Account.Website,
                   Account.GST_Number__c, Account.PAN_Number__c,
                   Account.BillingStreet, Account.BillingCity, Account.BillingState,
                   Account.BillingPostalCode, Account.BillingCountry,
                   BillingStreet, BillingCity, BillingState, BillingCountry, BillingPostalCode,
                   Business_Vertical__c, Vertical__c,
                   Account.Payment_Terms__c, Additional_Warranty__c,
                   Contract_Period_From_Date__c, Contract_Period_End_Date__c,
                   BillToContactId, BillToContact.Name, BillToContact.Email,
                   BillToContact.Phone, BillToContact.Title,
                   Owner.Name, Owner.Title, Owner.Phone
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            return;
        }

        order = orders[0];

        if (String.isNotBlank(order.Name)) {
            List<String> parts = order.Name.split('/');
            orderNamePart1 = parts.size() > 0 ? parts[0] : '';
            orderNamePart2 = parts.size() > 1 ? parts[1] : '';
            orderNamePart3 = parts.size() > 2 ? parts[2] : '';
            orderNamePart4 = parts.size() > 3 ? parts[3] : '';
        }

        grandTotalInWords = convertNumberToWords(order.TotalAmount);

        lineItems = [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.Item_Code__c, Product2.Make__c, Product2.Model__c,
                   Product2.Description, Product2.HSN_Code__c, Product2.Tax__c,
                   Product2.QuantityUnitOfMeasure,
                   Product2.Equipment_Name__c, Product2.Parameters__c,
                   PricebookEntryId, Quantity, UnitPrice, TotalPrice, ListPrice,
                   Discount__c, Price_Status__c, Tax_Type__c,
                   Product_Line_Description__c, Product_Detailed_Description__c,
                   Product2.Product_Type__c
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY CreatedDate ASC
        ];

        // AMC single-row summary: sum of line totals, fixed 18% GST.
        amcTotalRate = 0;
        lineGstAmount = new Map<Id, Decimal>();
        lineGrandTotal = new Map<Id, Decimal>();
        productStringify = '';
        for (OrderItem oli : lineItems) {
            Decimal rate = oli.TotalPrice != null ? oli.TotalPrice : 0;
            amcTotalRate += rate;

            Decimal taxPct = (oli.Product2 != null && oli.Product2.Tax__c != null)
                ? oli.Product2.Tax__c : 0;
            Decimal gst = (rate * taxPct / 100).setScale(2, RoundingMode.HALF_UP);
            lineGstAmount.put(oli.Id, gst);
            lineGrandTotal.put(oli.Id, (rate + gst).setScale(2, RoundingMode.HALF_UP));
        }
        amcGstAmount = (amcTotalRate * 0.18).setScale(2, RoundingMode.HALF_UP);
        amcGrandTotal = (amcTotalRate + amcGstAmount).setScale(2, RoundingMode.HALF_UP);

        paymentTerms = [
            SELECT Id, Name, Payment_Term__c, Percentage__c
            FROM Payment_Term__c
            WHERE Order__c = :orderId
            ORDER BY CreatedDate ASC
        ];

        // Terms_Condition__c only has a Quote__c lookup — there is no
        // Order__c relationship — so leave the list empty for orders.
        termsConditions = new List<Terms_Condition__c>();

        List<General_Settings__c> gs = [
            SELECT Id, Bank_Name__c, Account_No__c, Branch_Code__c, IFSC_Code__c
            FROM General_Settings__c
            LIMIT 1
        ];
        general = gs.isEmpty() ? new General_Settings__c() : gs[0];

        List<String> prodNames = new List<String>();
        for (OrderItem oli : lineItems) {
            if (oli.Product2 != null && String.isNotBlank(oli.Product2.Name)) {
                prodNames.add(oli.Product2.Name);
                if (oli.Product2.Product_Type__c != null) {
                    productStringify += oli.Product2.Product_Type__c + ',';
                }
            }
        }
        if (lineItems.size() == 1) {
            productName = lineItems[0].Product2.Name;
        }
        productNamesList = String.join(prodNames, ', ');
    }

    public static String convertNumberToWords(Decimal number_x) {
        if (number_x == null || number_x == 0) return 'Rupees Zero Only';

        Boolean isNegative = number_x < 0;
        number_x = number_x.abs();

        Long rupees = number_x.longValue();
        Integer paise = ((number_x - rupees) * 100).intValue();

        String result = 'Rupees ' + convertToWords(rupees);

        if (paise > 0) {
            result += ' and ' + convertToWords(paise) + ' Paise';
        }

        result += ' Only';
        return isNegative ? 'Minus ' + result : result;
    }

    private static String convertToWords(Long num) {
        if (num == 0) return 'Zero';

        String[] ones = new String[]{
            '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
            'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
            'Seventeen', 'Eighteen', 'Nineteen'
        };
        String[] tens = new String[]{
            '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
        };

        String words = '';

        if (num >= 10000000) {
            words += convertToWords(num / 10000000) + ' Crore ';
            num = Math.mod(num, 10000000);
        }
        if (num >= 100000) {
            words += convertToWords(num / 100000) + ' Lakh ';
            num = Math.mod(num, 100000);
        }
        if (num >= 1000) {
            words += convertToWords(num / 1000) + ' Thousand ';
            num = Math.mod(num, 1000);
        }
        if (num >= 100) {
            words += ones[(Integer)(num / 100)] + ' Hundred ';
            num = Math.mod(num, 100);
        }
        if (num > 0) {
            if (words != '') {
                words += 'and ';
            }
            if (num < 20) {
                words += ones[(Integer)num];
            } else {
                words += tens[(Integer)(num / 10)];
                if (Math.mod(num, 10) > 0) {
                    words += ' ' + ones[(Integer)Math.mod(num, 10)];
                }
            }
        }

        return words.trim();
    }
}
