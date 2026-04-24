/* Class Name   : QuotationPDFController
* Company      : Fingertipplus
* Created Date : 05-04-2026
* @description : Apex controller for Product Quotation PDF Visualforce page.
*                Queries Quote, Account, Opportunity, and QuoteLineItem data.
*                Computes tax (GST/IGST), grand total, and total in words.
*                Used as extension on Quote standard controller.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 05-04-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
public with sharing class QuotationPDFController {
    public  quote quote{get;set;}
    public list<QuoteLineItem> lineItems{get;set;}
    public list<Payment_Term__c> paymentTerms{get;set;}
    public list<Terms_Condition__c> termsConditions{get;set;}
   public String productNamesList { get; set; }
    // Default tax rate for Product quotations (5%)
      public String grandTotalInWords { get; set; }
    public String productName { get; set; }
   public  General_Settings__c general{get;set;}
     public String productStringify { get; set; }

    // AMC page summary — single-row contract table sums rate/GST/total
    // across every line item. GST on AMC is fixed at 18%.
    public Decimal amcTotalRate { get; set; }
    public Decimal amcGstAmount { get; set; }
    public Decimal amcGrandTotal { get; set; }


    public QuotationPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
       

        if (quoteId != null) {
            loadData(quoteId);
        }
    }

    private void loadData(Id quoteId) {
        // Query Quote with parent relationships
        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c, Quote_Date__c,
                   Status, Price_Status__c, is_Active__c,
                    Shipping_Mode__c,
                   Quote_Valid_Till_in_days__c,
                   Delivery__c,
                   Subtotal, TotalPrice, GrandTotal, Discount, Tax, ShippingHandling,
                   CurrencyIsoCode, Description, OwnerId,
                   OpportunityId, Opportunity.Name,
                   Opportunity.OwnerId, Opportunity.Owner.Name,
                   Opportunity.Owner.Title, Opportunity.Owner.Phone, Opportunity.Owner.Email,
                   AccountId, Account.Name, Account.Phone, Account.Website,
                   Account.GST_Number__c, Account.PAN_Number__c,
                   Account.BillingStreet, Account.BillingCity, Account.BillingState,
                   Account.BillingPostalCode, Account.BillingCountry,
          BillingStreet,
BillingCity,
BillingState,
BillingCountry,
BillingPostalCode,Business_Vertical__c,
                   Account.Payment_Terms__c,Additional_Warranty__c,Notes__c,Sub_Vertical__c,
                   Contract_Period_From_Date__c, Contract_Period_End_Date__c,
         ContactId, Contact.Name, Contact.Email, Contact.Phone, Contact.Title, owner.Name,Owner_Designation__c,Owner_Phone__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (quotes.isEmpty()) {
            return;
        }

        quote = quotes[0];
       

        grandTotalInWords = convertNumberToWords(quote.grandTotal);


        // Query line items
        lineItems = [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.Item_Code__c, Product2.Make__c, Product2.Model__c,
                   Product2.Description, Product2.HSN_Code__c, Product2.Tax__c,
                   Product2.QuantityUnitOfMeasure,
                   Product2.Equipment_Name__c, Product2.Parameters__c,
                   PricebookEntryId, Quantity, UnitPrice, TotalPrice, Discount, ListPrice,
                   Price_Status__c, Tax_Type__c,
                   Product_Line_Description__c, Product_Detailed_Description__c,Product2.Product_Type__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ];

        // AMC single-row summary: sum of line totals, fixed 18% GST.
        amcTotalRate = 0;
        for (QuoteLineItem qli : lineItems) {
            if (qli.TotalPrice != null) {
                amcTotalRate += qli.TotalPrice;
            }
        }
        amcGstAmount = (amcTotalRate * 0.18).setScale(2, RoundingMode.HALF_UP);
        amcGrandTotal = (amcTotalRate + amcGstAmount).setScale(2, RoundingMode.HALF_UP);

        // Query Payment Terms for this Quote
        paymentTerms = [
            SELECT Id, Name, Payment_Term__c, Percentage__c
            FROM Payment_Term__c
            WHERE Quote__c = :quoteId
            ORDER BY CreatedDate ASC
        ];

        // Query Terms & Conditions for this Quote
        termsConditions = [
            SELECT Id, Name, Titile__c, T_C__c
            FROM Terms_Condition__c
            WHERE Quote__c = :quoteId
            ORDER BY CreatedDate ASC
        ];
general =[select id,Bank_Name__c,Account_No__c,Branch_Code__c,IFSC_Code__c from General_Settings__c limit 1];
    // Build product names list
        List<String> prodNames = new List<String>();
    
        Integer prodIndex = 1;
        for (QuoteLineItem qli : lineItems) {
            if (qli.Product2 != null && String.isNotBlank(qli.Product2.Name)) {
                prodNames.add(qli.Product2.Name);
 productStringify += qli.Product2.Product_Type__c+','; 
                prodIndex++;
            }
        }
        if(lineItems.size() ==1){
            productName=lineItems[0].Product2.Name;
        }
        productNamesList = String.join(prodNames, ', ');
    }

  /*  private void computeTax() {
        subtotal = 0;
        for (QuoteLineItem qli : lineItems) {
            subtotal += (qli.TotalPrice != null) ? qli.TotalPrice : 0;
        }

        // Determine tax type from line items
        String determinedTaxType = 'GST';
        if (!lineItems.isEmpty() && lineItems[0].Tax_Type__c != null) {
            determinedTaxType = lineItems[0].Tax_Type__c;
        }

        // Determine tax rate: use product-level Tax__c if available, else default
        taxRate = DEFAULT_TAX_RATE;
        if (!lineItems.isEmpty() && lineItems[0].Product2 != null
            && lineItems[0].Product2.Tax__c != null && lineItems[0].Product2.Tax__c > 0) {
            taxRate = lineItems[0].Product2.Tax__c;
        }

        if (determinedTaxType == 'Exempt') {
            isExempt = true;
            taxAmount = 0;
            cgstAmount = 0;
            sgstAmount = 0;
            igstAmount = 0;
        } else {
            isExempt = false;
            taxAmount = (subtotal * taxRate / 100).setScale(2, RoundingMode.HALF_UP);

            // Determine same state by comparing Account billing state with company state
            String customerState = '';
            if (account != null && account.BillingState != null) {
                customerState = account.BillingState.trim().toLowerCase();
            }
            isSameState = customerState == COMPANY_STATE.toLowerCase();

            // Override with explicit Tax_Type__c if set
            if (determinedTaxType == 'IGST') {
                isSameState = false;
            } else if (determinedTaxType == 'GST') {
                isSameState = true;
            }

            if (isSameState) {
                cgstRate = (taxRate / 2).setScale(2, RoundingMode.HALF_UP);
                sgstRate = (taxRate / 2).setScale(2, RoundingMode.HALF_UP);
                cgstAmount = (taxAmount / 2).setScale(2, RoundingMode.HALF_UP);
                sgstAmount = (taxAmount / 2).setScale(2, RoundingMode.HALF_UP);
                igstAmount = 0;
                igstRate = 0;
            } else {
                igstRate = taxRate;
                igstAmount = taxAmount;
                cgstAmount = 0;
                sgstAmount = 0;
                cgstRate = 0;
                sgstRate = 0;
            }
        }*/

        // Use Grand Total from Quote object
     /*   if (quote.GrandTotal != null) {
            grandTotal = quote.GrandTotal;
        } else {
            grandTotal = (subtotal + taxAmount).setScale(2, RoundingMode.HALF_UP);
        }

        // Use Subtotal from Quote object
        if (quote.Subtotal != null) {
            subtotal = quote.Subtotal;
        }

        // Use Tax from Quote object
        if (quote.Tax != null) {
            taxAmount = quote.Tax;
        }

        grandTotalInWords = convertNumberToWords(grandTotal);

        // Set GST display rate for PDF
        if (!isExempt && taxRate != null) {
            Integer rateInt = taxRate.intValue();
            gstDisplayRate = 'GST ' + String.valueOf(rateInt) + '%';
        }*/
    

    private String formatDate(Date d) {
        return String.valueOf(d.day()).leftPad(2, '0') + '-' +
               String.valueOf(d.month()).leftPad(2, '0') + '-' +
               String.valueOf(d.year());
    }

    // Indian number formatting (1,23,456.00)
    public static String formatIndianCurrency(Decimal amount) {
        if (amount == null) return '0.00';
        Boolean isNegative = amount < 0;
        amount = amount.abs().setScale(2, RoundingMode.HALF_UP);

        String[] parts = String.valueOf(amount).split('\\.');
        String intPart = parts[0];
        String decPart = parts.size() > 1 ? parts[1].rightPad(2, '0').substring(0, 2) : '00';

        String formatted = '';
        if (intPart.length() <= 3) {
            formatted = intPart;
        } else {
            formatted = intPart.substring(intPart.length() - 3);
            String remaining = intPart.substring(0, intPart.length() - 3);
            while (remaining.length() > 2) {
                formatted = remaining.substring(remaining.length() - 2) + ',' + formatted;
                remaining = remaining.substring(0, remaining.length() - 2);
            }
            if (remaining.length() > 0) {
                formatted = remaining + ',' + formatted;
            }
        }

        return (isNegative ? '-' : '') + formatted + '.' + decPart;
    }

    // Convert number to Indian Rupees in words
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

        // Crores (1,00,00,000)
        if (num >= 10000000) {
            words += convertToWords(num / 10000000) + ' Crore ';
            num = Math.mod(num, 10000000);
        }

        // Lakhs (1,00,000)
        if (num >= 100000) {
            words += convertToWords(num / 100000) + ' Lakh ';
            num = Math.mod(num, 100000);
        }

        // Thousands (1,000)
        if (num >= 1000) {
            words += convertToWords(num / 1000) + ' Thousand ';
            num = Math.mod(num, 1000);
        }

        // Hundreds
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