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

    // Company constants
    public static final String COMPANY_NAME = 'Cyrix Healthcare Pvt. Ltd';
    public static final String COMPANY_ADDRESS = '30/641B, Petta, Poonithura, Ernakulam, Kerala, India';
    public static final String COMPANY_STATE = 'Kerala';
    public static final String COMPANY_PHONE = '';
    public static final String COMPANY_EMAIL = '';
    public static final String COMPANY_WEBSITE = '';
    public static final String COMPANY_TAGLINE = 'The X-Factor in Medical Technology Reliability';
    public static final String COMPANY_CIN = 'CIN: U74140KL2013PTC034081';

    // Bank detail constants (placeholders - to be configured)
    public static final String BANK_NAME = '';
    public static final String BANK_ACCOUNT_NUMBER = '';
    public static final String BANK_IFSC = '';
    public static final String BANK_BRANCH = '';
    public static final String BANK_ACCOUNT_HOLDER = 'Cyrix Healthcare Pvt. Ltd';

    // Default tax rate for Product quotations (5%)
    private static final Decimal DEFAULT_TAX_RATE = 5.0;

    // Properties
    public Quote quote { get; set; }
    public Account account { get; set; }
    public Opportunity opportunity { get; set; }
    public Contact primaryContact { get; set; }
    public List<QuoteLineItem> lineItems { get; set; }

    public Decimal subtotal { get; set; }
    public Decimal taxRate { get; set; }
    public Decimal taxAmount { get; set; }
    public Decimal cgstRate { get; set; }
    public Decimal sgstRate { get; set; }
    public Decimal cgstAmount { get; set; }
    public Decimal sgstAmount { get; set; }
    public Decimal igstRate { get; set; }
    public Decimal igstAmount { get; set; }
    public Decimal grandTotal { get; set; }
    public String grandTotalInWords { get; set; }
    public Boolean isSameState { get; set; }
    public Boolean isExempt { get; set; }

    public String quoteDate { get; set; }
    public String validTillDate { get; set; }
    public String salesEngineerName { get; set; }
    public String salesEngineerTitle { get; set; }
    public String salesEngineerPhone { get; set; }
    public String salesEngineerEmail { get; set; }
    public String productNamesList { get; set; }
    public List<String> productNamesNumbered { get; set; }
    public String quoteRefNumber { get; set; }
    public String quotationTitle { get; set; }

    // Dynamic T&C fields
    public String validityDays { get; set; }
    public String advancePercent { get; set; }
    public String shippingPercent { get; set; }
    public String deliveryPercent { get; set; }
    public String installationPercent { get; set; }
    public String deliveryWeeks { get; set; }
    public String installationScope { get; set; }
    public String gstDisplayRate { get; set; }
    public String warrantyExtra { get; set; }

    public String companyName { get { return COMPANY_NAME; } }
    public String companyAddress { get { return COMPANY_ADDRESS; } }
    public String companyPhone { get { return COMPANY_PHONE; } }
    public String companyEmail { get { return COMPANY_EMAIL; } }
    public String companyWebsite { get { return COMPANY_WEBSITE; } }
    public String companyTagline { get { return COMPANY_TAGLINE; } }
    public String companyCin { get { return COMPANY_CIN; } }

    public String bankName { get; set; }
    public String bankAccountNumber { get; set; }
    public String bankIfsc { get; set; }
    public String bankBranch { get; set; }
    public String bankAccountHolder { get; set; }

    public QuotationPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        lineItems = new List<QuoteLineItem>();
        subtotal = 0;
        taxAmount = 0;
        cgstAmount = 0;
        sgstAmount = 0;
        igstAmount = 0;
        grandTotal = 0;
        isSameState = false;
        isExempt = false;
        taxRate = DEFAULT_TAX_RATE;
        cgstRate = 0;
        sgstRate = 0;
        igstRate = 0;

        productNamesNumbered = new List<String>();
        quoteRefNumber = '';
        quotationTitle = '';

        // Default T&C values
        validityDays = '30 days';
        advancePercent = '40%';
        shippingPercent = '45%';
        deliveryPercent = '10%';
        installationPercent = '5%';
        deliveryWeeks = '12-15 weeks';
        installationScope = 'installation and commissioning';
        gstDisplayRate = '';
        warrantyExtra = '';

        // Initialize bank details with defaults
        bankName = BANK_NAME;
        bankAccountNumber = BANK_ACCOUNT_NUMBER;
        bankIfsc = BANK_IFSC;
        bankBranch = BANK_BRANCH;
        bankAccountHolder = BANK_ACCOUNT_HOLDER;

        if (quoteId != null) {
            loadData(quoteId);
        }
    }

    private void loadData(Id quoteId) {
        // Query Quote with parent relationships
        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c, Quote_Date__c, Valid_Till__c,
                   Status, Price_Status__c, is_Active__c, Vertical__c,
                   Billing_Address__c, Shipping_Address__c, Shipping_Mode__c,
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
                   Account.Payment_Terms__c,
                   Bank_Name__c, Bank_Name__r.Name,
                   Bank_Name__r.Account_No__c, Bank_Name__r.Bank_Name__c,
                   Bank_Name__r.Branch_Name__c, Bank_Name__r.IFSC_CODE__c,
                   ContactId, Contact.Name, Contact.Email, Contact.Phone, Contact.Title
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (quotes.isEmpty()) {
            return;
        }

        quote = quotes[0];
        account = quote.Account;
        opportunity = quote.Opportunity;
        primaryContact = quote.Contact;

        // Format dates
        quoteDate = quote.Quote_Date__c != null
            ? formatDate(quote.Quote_Date__c) : '';
        validTillDate = quote.Valid_Till__c != null
            ? formatDate(quote.Valid_Till__c) : '';

        // Validity days from Quote_Valid_Till_in_days__c picklist field
        if (quote.Quote_Valid_Till_in_days__c != null) {
            validityDays = quote.Quote_Valid_Till_in_days__c;
        }

        // Bank details from Quote's Bank lookup
        if (quote.Bank_Name__c != null && quote.Bank_Name__r != null) {
            bankAccountNumber = quote.Bank_Name__r.Account_No__c != null ? quote.Bank_Name__r.Account_No__c : '';
            bankName = quote.Bank_Name__r.Bank_Name__c != null ? quote.Bank_Name__r.Bank_Name__c : '';
            bankBranch = quote.Bank_Name__r.Branch_Name__c != null ? quote.Bank_Name__r.Branch_Name__c : '';
            bankIfsc = quote.Bank_Name__r.IFSC_CODE__c != null ? quote.Bank_Name__r.IFSC_CODE__c : '';
        }

        // Delivery weeks from Quote
        if (quote.Delivery__c != null) {
            deliveryWeeks = quote.Delivery__c;
        }

        // Payment terms from Account
        if (account != null && account.Payment_Terms__c != null) {
            String pt = account.Payment_Terms__c;
            if (pt == '100% Advance') {
                advancePercent = '100%';
                shippingPercent = '0%';
                deliveryPercent = '0%';
                installationPercent = '0%';
            } else if (pt == '50% Advance - 50% After Installation') {
                advancePercent = '50%';
                shippingPercent = '0%';
                deliveryPercent = '0%';
                installationPercent = '50%';
            } else if (pt == '30% Advance - 70% After Installation') {
                advancePercent = '30%';
                shippingPercent = '0%';
                deliveryPercent = '0%';
                installationPercent = '70%';
            }
        }

        // Sales Engineer info from Quote Owner (User object)
        if (quote.OwnerId != null) {
            List<User> owners = [
                SELECT Id, Name, Title, Phone, Email
                FROM User
                WHERE Id = :quote.OwnerId
                LIMIT 1
            ];
            if (!owners.isEmpty()) {
                salesEngineerName = owners[0].Name;
                salesEngineerTitle = owners[0].Title;
                salesEngineerPhone = owners[0].Phone;
                salesEngineerEmail = owners[0].Email;
            }
        }

        // Query line items
        lineItems = [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Product2.Item_Code__c, Product2.Make__c, Product2.Model__c,
                   Product2.Description, Product2.HSN_Code__c, Product2.Tax__c,
                   Product2.QuantityUnitOfMeasure,
                   PricebookEntryId, Quantity, UnitPrice, TotalPrice, Discount, ListPrice,
                   Price_Status__c, Tax_Type__c,
                   Product_Line_Description__c, Product_Detailed_Description__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY CreatedDate ASC
        ];

        // Build product names list
        List<String> prodNames = new List<String>();
        productNamesNumbered = new List<String>();
        Integer prodIndex = 1;
        for (QuoteLineItem qli : lineItems) {
            if (qli.Product2 != null && String.isNotBlank(qli.Product2.Name)) {
                prodNames.add(qli.Product2.Name);
                productNamesNumbered.add(qli.Product2.Name);
                prodIndex++;
            }
        }
        productNamesList = String.join(prodNames, ', ');

        // Build quote reference number: C-KL/<VERTICAL>/<Quote_Id__c>
        String vertical = quote.Vertical__c != null ? quote.Vertical__c : '';
        String qtnId = quote.Quote_Id__c != null ? quote.Quote_Id__c : quote.QuoteNumber;
        quoteRefNumber = 'C-KL/' + vertical + '/' + qtnId;

        // Build quotation title: QUOTATION FOR CYRIX <Product name & Vertical>
        quotationTitle = 'QUOTATION FOR CYRIX ' + productNamesList +
            (String.isNotBlank(vertical) ? ' & ' + vertical : '');

        // Compute tax and totals
        computeTax();
    }

    private void computeTax() {
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
        }

        grandTotal = (subtotal + taxAmount).setScale(2, RoundingMode.HALF_UP);
        grandTotalInWords = convertNumberToWords(grandTotal);

        // Set GST display rate for PDF
        if (!isExempt && taxRate != null) {
            Integer rateInt = taxRate.intValue();
            gstDisplayRate = 'GST ' + String.valueOf(rateInt) + '%';
        }
    }

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