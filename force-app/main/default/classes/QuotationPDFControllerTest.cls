@isTest
private class QuotationPDFControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Account with Kerala billing (same state as company)
        Account acc = new Account(
            Name = 'Test Hospital Kerala',
            Phone = '1234567890',
            Website = 'www.testhospital.com',
            Industry = 'Healthcare',
            BillingStreet = '123 MG Road',
            BillingCity = 'Kochi',
            BillingState = 'Kerala',
            BillingPostalCode = '682001',
            BillingCountry = 'India'
        );
        insert acc;

        // Create Account with different state billing (for IGST test)
        Account accOther = new Account(
            Name = 'Test Hospital TN',
            BillingStreet = '456 Anna Nagar',
            BillingCity = 'Chennai',
            BillingState = 'Tamil Nadu',
            BillingPostalCode = '600001',
            BillingCountry = 'India'
        );
        insert accOther;

        Id stdPbId = Test.getStandardPricebookId();

        // Create Products
        Product2 prod = new Product2(
            Name = 'Ultrasound Scanner',
            ProductCode = 'USG-001',
            Item_Code__c = 'USG-001',
            Make__c = 'CyrixMed',
            Model__c = 'CX-500',
            HSN_Code__c = '90189090',
            IsActive = true,
            Description = 'Portable ultrasound scanner with advanced imaging'
        );
        insert prod;

        // Create PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 150000,
            IsActive = true
        );
        insert pbe;

        // Create Opportunity for Kerala account
        Opportunity opp1 = new Opportunity(
            Name = 'Kerala Hospital Deal',
            AccountId = acc.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(60),
            Pricebook2Id = stdPbId
        );
        insert opp1;

        // Create Opportunity for TN account
        Opportunity opp2 = new Opportunity(
            Name = 'TN Hospital Deal',
            AccountId = accOther.Id,
            StageName = 'Qualified',
            CloseDate = Date.today().addDays(60),
            Pricebook2Id = stdPbId
        );
        insert opp2;

        // Create Quote with GST (same state)
        Quote qt1 = new Quote(
            Name = 'Kerala Quote',
            OpportunityId = opp1.Id,
            Pricebook2Id = stdPbId,
            Quote_Date__c = Date.today(),
            Valid_Till__c = Date.today().addDays(30),
            Status = 'Draft',
            Price_Status__c = 'Draft',
            is_Active__c = true,
            Vertical__c = 'Medical Equipment',
            Billing_Address__c = '123 MG Road, Kochi, Kerala - 682001',
           
            Shipping_Mode__c = 'By Road'
        );
        insert qt1;

        QuoteLineItem qli1 = new QuoteLineItem(
            QuoteId = qt1.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 150000,
            Tax_Type__c = 'GST',
            Price_Status__c = 'Not Required',
            Product_Line_Description__c = 'Portable Ultrasound Scanner',
            Product_Detailed_Description__c = 'Advanced imaging with 3 probes included'
        );
        insert qli1;

        // Create Quote with IGST (different state)
        Quote qt2 = new Quote(
            Name = 'TN Quote',
            OpportunityId = opp2.Id,
            Pricebook2Id = stdPbId,
            Quote_Date__c = Date.today(),
            Valid_Till__c = Date.today().addDays(45),
            Status = 'Draft',
            Price_Status__c = 'Draft',
            is_Active__c = true,
            Vertical__c = 'Lab Equipment',
            Billing_Address__c = '456 Anna Nagar, Chennai, Tamil Nadu',
            Shipping_Mode__c = 'By Air'
        );
        insert qt2;

        QuoteLineItem qli2 = new QuoteLineItem(
            QuoteId = qt2.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 150000,
            Tax_Type__c = 'IGST',
            Price_Status__c = 'Not Required',
            Product_Line_Description__c = 'Lab Ultrasound'
        );
        insert qli2;

        // Create Quote with no line items (empty quote)
        Quote qt3 = new Quote(
            Name = 'Empty Quote',
            OpportunityId = opp1.Id,
            Pricebook2Id = stdPbId,
            Quote_Date__c = Date.today(),
            Valid_Till__c = Date.today().addDays(15),
            Status = 'Draft',
            Price_Status__c = 'Draft',
            is_Active__c = false,
            Vertical__c = 'Consumables'
        );
        insert qt3;

        // Create Quote with exempt tax
        Quote qt4 = new Quote(
            Name = 'Exempt Quote',
            OpportunityId = opp1.Id,
            Pricebook2Id = stdPbId,
            Quote_Date__c = Date.today(),
            Valid_Till__c = Date.today().addDays(30),
            Status = 'Draft',
            Price_Status__c = 'Draft',
            is_Active__c = true,
            Vertical__c = 'Services'
        );
        insert qt4;

        QuoteLineItem qli4 = new QuoteLineItem(
            QuoteId = qt4.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 50000,
            Tax_Type__c = 'Exempt',
            Price_Status__c = 'Not Required'
        );
        insert qli4;
    }

    @isTest
    static void testControllerWithGST() {
        Quote qt = [SELECT Id FROM Quote WHERE Name = 'Kerala Quote' LIMIT 1];

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(qt);
        QuotationPDFController ctrl = new QuotationPDFController(stdCtrl);
        Test.stopTest();

        System.assertNotEquals(null, ctrl.quote, 'Quote should be loaded');
        System.assertNotEquals(null, ctrl.account, 'Account should be loaded');
        System.assertEquals(1, ctrl.lineItems.size(), 'Should have 1 line item');
        System.assertEquals(300000, ctrl.subtotal, 'Subtotal should be 300000');
        System.assertEquals(true, ctrl.isSameState, 'Should be same state (Kerala)');
        System.assert(ctrl.cgstAmount > 0, 'CGST should be > 0');
        System.assert(ctrl.sgstAmount > 0, 'SGST should be > 0');
        System.assertEquals(0, ctrl.igstAmount, 'IGST should be 0 for same state');
        System.assert(ctrl.grandTotal > ctrl.subtotal, 'Grand total should include tax');
        System.assert(ctrl.grandTotalInWords.contains('Rupees'), 'Should contain Rupees');
        System.assertEquals('Medical Equipment', ctrl.quote.Vertical__c);
        System.assert(String.isNotBlank(ctrl.productNamesList), 'Product names should be populated');
        System.assert(String.isNotBlank(ctrl.quoteDate), 'Quote date should be formatted');
        System.assert(String.isNotBlank(ctrl.validTillDate), 'Valid till should be formatted');
    }

    @isTest
    static void testControllerWithIGST() {
        Quote qt = [SELECT Id FROM Quote WHERE Name = 'TN Quote' LIMIT 1];

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(qt);
        QuotationPDFController ctrl = new QuotationPDFController(stdCtrl);
        Test.stopTest();

        System.assertEquals(false, ctrl.isSameState, 'Should be different state');
        System.assertEquals(0, ctrl.cgstAmount, 'CGST should be 0 for different state');
        System.assertEquals(0, ctrl.sgstAmount, 'SGST should be 0 for different state');
        System.assert(ctrl.igstAmount > 0, 'IGST should be > 0');
        System.assertEquals(150000, ctrl.subtotal, 'Subtotal should be 150000');
    }

    @isTest
    static void testControllerWithExemptTax() {
        Quote qt = [SELECT Id FROM Quote WHERE Name = 'Exempt Quote' LIMIT 1];

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(qt);
        QuotationPDFController ctrl = new QuotationPDFController(stdCtrl);
        Test.stopTest();

        System.assertEquals(true, ctrl.isExempt, 'Should be tax exempt');
        System.assertEquals(0, ctrl.taxAmount, 'Tax should be 0');
        System.assertEquals(0, ctrl.cgstAmount, 'CGST should be 0');
        System.assertEquals(0, ctrl.sgstAmount, 'SGST should be 0');
        System.assertEquals(0, ctrl.igstAmount, 'IGST should be 0');
        System.assertEquals(ctrl.subtotal, ctrl.grandTotal, 'Grand total should equal subtotal');
    }

    @isTest
    static void testControllerEmptyQuote() {
        Quote qt = [SELECT Id FROM Quote WHERE Name = 'Empty Quote' LIMIT 1];

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(qt);
        QuotationPDFController ctrl = new QuotationPDFController(stdCtrl);
        Test.stopTest();

        System.assertEquals(0, ctrl.lineItems.size(), 'Should have no line items');
        System.assertEquals(0, ctrl.subtotal, 'Subtotal should be 0');
        System.assertEquals(0, ctrl.grandTotal, 'Grand total should be 0');
        System.assert(ctrl.grandTotalInWords.contains('Zero'), 'Should say Zero');
    }

    @isTest
    static void testNumberToWords() {
        System.assertEquals('Rupees Zero Only', QuotationPDFController.convertNumberToWords(0));
        System.assertEquals('Rupees One Only', QuotationPDFController.convertNumberToWords(1));
        System.assertEquals('Rupees Ten Only', QuotationPDFController.convertNumberToWords(10));
        System.assertEquals('Rupees One Hundred Only', QuotationPDFController.convertNumberToWords(100));
        System.assertEquals('Rupees One Thousand Only', QuotationPDFController.convertNumberToWords(1000));
        System.assert(QuotationPDFController.convertNumberToWords(100000).contains('Lakh'), 'Should contain Lakh');
        System.assert(QuotationPDFController.convertNumberToWords(10000000).contains('Crore'), 'Should contain Crore');
        System.assert(QuotationPDFController.convertNumberToWords(150.50).contains('Paise'), 'Should contain Paise');
    }

    @isTest
    static void testNumberToWordsLargeAmount() {
        String result = QuotationPDFController.convertNumberToWords(315000);
        System.assert(result.contains('Three'), 'Should contain Three');
        System.assert(result.contains('Lakh'), 'Should contain Lakh');
        System.assert(result.contains('Fifteen'), 'Should contain Fifteen');
        System.assert(result.contains('Thousand'), 'Should contain Thousand');
    }

    @isTest
    static void testFormatIndianCurrency() {
        System.assertEquals('0.00', QuotationPDFController.formatIndianCurrency(null));
        System.assertEquals('0.00', QuotationPDFController.formatIndianCurrency(0));
        System.assertEquals('999.00', QuotationPDFController.formatIndianCurrency(999));
        System.assertEquals('1,000.00', QuotationPDFController.formatIndianCurrency(1000));
        System.assertEquals('1,50,000.00', QuotationPDFController.formatIndianCurrency(150000));
        System.assertEquals('3,15,000.00', QuotationPDFController.formatIndianCurrency(315000));
        System.assertEquals('1,00,00,000.00', QuotationPDFController.formatIndianCurrency(10000000));
    }

    @isTest
    static void testPageRendering() {
        Quote qt = [SELECT Id FROM Quote WHERE Name = 'Kerala Quote' LIMIT 1];

        Test.startTest();
        PageReference pageRef = Page.ProductQuotation;
        pageRef.getParameters().put('id', qt.Id);
        Test.setCurrentPage(pageRef);

        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(qt);
        QuotationPDFController ctrl = new QuotationPDFController(stdCtrl);
        Test.stopTest();

        // Verify company property accessors
        System.assertEquals('Cyrix Healthcare Pvt. Ltd', ctrl.companyName);
        System.assert(ctrl.companyAddress.contains('Ernakulam'));
        System.assertEquals('Cyrix Healthcare Pvt. Ltd', ctrl.bankAccountHolder);
    }

    @isTest
    static void testNullQuoteId() {
        Quote qt = new Quote();

        Test.startTest();
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(qt);
        QuotationPDFController ctrl = new QuotationPDFController(stdCtrl);
        Test.stopTest();

        System.assertEquals(null, ctrl.quote, 'Quote should be null for invalid id');
        System.assertEquals(0, ctrl.lineItems.size(), 'Should have empty line items');
    }
}