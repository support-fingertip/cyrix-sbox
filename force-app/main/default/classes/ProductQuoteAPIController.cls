// Cyrix Product Quote API Controller - Updated for Product Master Module 7
/****************************************************************
* Class Name   : ProductQuoteAPIController
* Company      : Fingertipplus
* Created Date : 27-03-2026
* @description : REST API for Product catalog, Price Book, and Quote operations.
*                Supports GET (retrieve) and POST (create/update) for external integrations.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 27-03-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
@RestResource(urlMapping='/ProductQuote/*')
global without sharing class ProductQuoteAPIController {

    /**
     * GET /services/apexrest/ProductQuote?type=products&key=xxx
     * GET /services/apexrest/ProductQuote?type=pricebook&key=xxx
     * GET /services/apexrest/ProductQuote?type=quote&quoteId=xxx&key=xxx
     * GET /services/apexrest/ProductQuote?type=product&productId=xxx&key=xxx
     */
    @HttpGet
    global static void getRecords() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String key = req.params.get('key');
        if (Label.API_Key != key) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, 'Unauthorized: Invalid API Key', null)
            ));
            return;
        }

        String recordType = req.params.get('type');
        try {
            if (recordType == 'products') {
                res.responseBody = Blob.valueOf(JSON.serialize(getProducts(req)));
            } else if (recordType == 'product') {
                res.responseBody = Blob.valueOf(JSON.serialize(getProductById(req)));
            } else if (recordType == 'pricebook') {
                res.responseBody = Blob.valueOf(JSON.serialize(getPriceBook(req)));
            } else if (recordType == 'quote') {
                res.responseBody = Blob.valueOf(JSON.serialize(getQuote(req)));
            } else {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, 'Invalid type parameter. Use: products, product, pricebook, or quote', null)
                ));
            }
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, 'Error: ' + e.getMessage(), null)
            ));
        }
    }

    /**
     * POST /services/apexrest/ProductQuote?type=product&key=xxx  (Create/Update Product)
     * POST /services/apexrest/ProductQuote?type=quote&key=xxx    (Create Quote with Line Items)
     */
    @HttpPost
    global static void createRecords() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String key = req.params.get('key');
        if (Label.API_Key != key) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, 'Unauthorized: Invalid API Key', null)
            ));
            return;
        }

        String recordType = req.params.get('type');
        String requestBody = req.requestBody.toString();

        // Log the request
        Log__c log = new Log__c();
        log.Object__c = 'ProductQuoteAPI ' + recordType;
        log.Request__c = requestBody.length() > 32000
            ? requestBody.substring(0, 32000) : requestBody;

        try {
            if (recordType == 'product') {
                res.responseBody = Blob.valueOf(JSON.serialize(upsertProduct(requestBody)));
            } else if (recordType == 'quote') {
                res.responseBody = Blob.valueOf(JSON.serialize(createQuote(requestBody)));
            } else {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, 'Invalid type parameter. Use: product or quote', null)
                ));
            }
            log.Response__c = 'Success';
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, 'Error: ' + e.getMessage(), null)
            ));
            log.Response__c = 'Error: ' + e.getMessage();
        }

        insert log;
    }

    // ---- GET Handlers ----

    private static ApiResponse getProducts(RestRequest req) {
        String category = req.params.get('category');
        String productType = req.params.get('productType');
        String vertical = req.params.get('vertical');
        Integer limitVal = req.params.get('limit') != null
            ? Integer.valueOf(req.params.get('limit')) : 200;

        String query = 'SELECT Id, Name, ProductCode, Item_Code__c, SAP_Item_Code__c, ' +
            'Product_Category__c, Sub_Category__c, Product_Type__c, Product_Vertical__c, ' +
            'Brand__c, Make__c, Model__c, Equipment_Name__c, Line_Description__c, ' +
            'Standard_Price__c, Tax__c, Standard_Price_with_Tax__c, ' +
            'HSN_Code__c, HSN_Code_International__c, Source__c, Description, IsActive, ' +
            'Default_Warranty_Months__c, Is_Installation_Required__c, Is_Training_Required__c, ' +
            'Product_Status__c, ERP_Sync_Status__c, Last_ERP_Sync_Date__c, ' +
            'Product_Group__r.Name, Product_Group__r.Group_Code__c ' +
            'FROM Product2 WHERE IsActive = true';

        if (String.isNotBlank(category)) {
            query += ' AND Product_Category__c = :category';
        }
        if (String.isNotBlank(productType)) {
            query += ' AND Product_Type__c = :productType';
        }
        if (String.isNotBlank(vertical)) {
            query += ' AND Product_Vertical__c = :vertical';
        }
        query += ' ORDER BY Name ASC LIMIT :limitVal';

        List<Product2> products = Database.query(query);
        return new ApiResponse(true, products.size() + ' product(s) found', products);
    }

    private static ApiResponse getProductById(RestRequest req) {
        String productId = req.params.get('productId');
        String itemCode = req.params.get('itemCode');

        if (String.isBlank(productId) && String.isBlank(itemCode)) {
            return new ApiResponse(false, 'productId or itemCode is required', null);
        }

        String query = 'SELECT Id, Name, ProductCode, Item_Code__c, SAP_Item_Code__c, SAP_Item_New_Code__c, ' +
            'Product_Category__c, Sub_Category__c, Product_Type__c, Product_Vertical__c, Category__c, ' +
            'Brand__c, Make__c, Model__c, Equipment_Name__c, OEM_Part_Number__c, Source__c, ' +
            'Line_Description__c, Standard_Price__c, Tax__c, Standard_Price_with_Tax__c, ' +
            'HSN_Code__c, HSN_Code_International__c, ' +
            'Quantity_Pack_Size__c, Specification__c, Description, Detailed_Description__c, ' +
            'Compatibility__c, Remarks__c, Any_Other_Levies__c, IsActive, ' +
            'Default_Warranty_Months__c, Warranty_Terms_Description__c, ' +
            'Installation_Terms__c, Is_Installation_Required__c, Is_Training_Required__c, ' +
            'Product_Status__c, ERP_Sync_Status__c, Last_ERP_Sync_Date__c, ' +
            'Manager_Discount_Up_to__c, VP_Sales_Discount_Up_to__c, CEO_Sales_Discount_Up_to__c, ' +
            'Shipping_Charges_Percent__c, Packing_Charges_Percent__c, Installation_Cost_Percent__c, ' +
            'Training_Cost_Percent__c, Promotional_Cost_Percent__c, Insurance_Cost_Percent__c, ' +
            'Internal_Transport_Cost_Percent__c, Warranty_Cost_Percent__c, ' +
            'Product_Image_URL__c, Product_Image_URL_2__c, Product_Image_URL_3__c, ' +
            'Product_Group__r.Name, Product_Group__r.Group_Code__c, ' +
            'Parent_Equipment__r.Name ' +
            'FROM Product2 WHERE ';

        if (String.isNotBlank(productId)) {
            query += 'Id = :productId';
        } else {
            query += 'Item_Code__c = :itemCode';
        }
        query += ' LIMIT 1';

        List<Product2> products = Database.query(query);
        if (products.isEmpty()) {
            return new ApiResponse(false, 'Product not found', null);
        }
        return new ApiResponse(true, 'Product found', products[0]);
    }

    private static ApiResponse getPriceBook(RestRequest req) {
        String pricebookName = req.params.get('pricebookName');
        String productId = req.params.get('productId');

        String query = 'SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, ' +
            'Product2.Item_Code__c, Pricebook2Id, Pricebook2.Name, ' +
            'UnitPrice, IsActive, CurrencyIsoCode, ' +
            'Dealer_Price__c, Max_Retail_Price__c, Volume__c, ' +
            'Effective_Customer_Price__c, Effective_Customer_Price_with_Tax__c ' +
            'FROM PricebookEntry WHERE IsActive = true';

        if (String.isNotBlank(pricebookName)) {
            query += ' AND Pricebook2.Name = :pricebookName';
        }
        if (String.isNotBlank(productId)) {
            query += ' AND Product2Id = :productId';
        }
        query += ' ORDER BY Product2.Name ASC LIMIT 500';

        List<PricebookEntry> entries = Database.query(query);
        return new ApiResponse(true, entries.size() + ' price book entry(s) found', entries);
    }

    private static ApiResponse getQuote(RestRequest req) {
        String quoteId = req.params.get('quoteId');
        if (String.isBlank(quoteId)) {
            return new ApiResponse(false, 'quoteId is required', null);
        }

        List<Quote> quotes = [
            SELECT Id, Name, QuoteNumber, Quote_Id__c, Quote_Date__c, Valid_Till__c,
                   Status, OpportunityId, Opportunity.Name, AccountId, Account.Name,
                   ContactId, Contact.Name, Billing_Address__c, Shipping_Address__c,
                   Shipping_Mode__c, is_Active__c, Vertical__c, Price_Status__c,
                   Subtotal, TotalPrice, GrandTotal,
                   (SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                           Quantity, UnitPrice, TotalPrice, Discount, ListPrice,
                           Price_Status__c, Tax_Type__c,
                           Product_Line_Description__c, Product_Detailed_Description__c
                    FROM QuoteLineItems
                    ORDER BY CreatedDate ASC)
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        if (quotes.isEmpty()) {
            return new ApiResponse(false, 'Quote not found', null);
        }
        return new ApiResponse(true, 'Quote found', quotes[0]);
    }

    // ---- POST Handlers ----

    private static ApiResponse upsertProduct(String requestBody) {
        ProductWrapper pw = (ProductWrapper) JSON.deserialize(requestBody, ProductWrapper.class);

        Product2 product = new Product2();
        if (String.isNotBlank(pw.itemCode)) {
            product.Item_Code__c = pw.itemCode;
        }
        product.Name = pw.name;
        product.ProductCode = pw.productCode;
       product.SAP_Item_Code__c = pw.sapItemCode;
        product.SAP_Item_New_Code__c = pw.sapItemNewCode;
        product.Product_Category__c = pw.category;
        product.Product_Type__c = pw.productType;
        product.Product_Vertical__c = pw.vertical;
        product.Sub_Category__c = pw.subCategory;
        product.Make__c = pw.make;
        product.Model__c = pw.model;
        product.Equipment_Name__c = pw.equipmentName;
        product.OEM_Part_Number__c = pw.oemPartNumber;
        product.Source__c = pw.source;
        product.Standard_Price__c = pw.standardPrice;
        product.Tax__c = pw.taxPercent;
        product.HSN_Code__c = pw.hsnCode;
        product.Quantity_Pack_Size__c = pw.quantityPackSize;
        product.Specification__c = pw.specification;
        product.Description = pw.shortDescription;
        product.Detailed_Description__c = pw.detailedDescription;
        product.Compatibility__c = pw.compatibility;
        product.Remarks__c = pw.remarks;
        product.IsActive = pw.isActive != null ? pw.isActive : true;
        product.Brand__c = pw.brand;
        product.Sub_Category__c = pw.subCategory;
        product.Line_Description__c = pw.lineDescription;
        product.HSN_Code_International__c = pw.hsnCodeInternational;
        product.Default_Warranty_Months__c = pw.defaultWarrantyMonths;
        product.Warranty_Terms_Description__c = pw.warrantyTerms;
        product.Installation_Terms__c = pw.installationTerms;
        product.Is_Installation_Required__c = pw.isInstallationRequired;
        product.Is_Training_Required__c = pw.isTrainingRequired;
        product.Product_Status__c = pw.productStatus;
        product.Product_Image_URL__c = pw.imageUrl1;
        product.Product_Image_URL_2__c = pw.imageUrl2;
        product.Product_Image_URL_3__c = pw.imageUrl3;
        product.ERP_Sync_Status__c = 'Synced';
        product.Last_ERP_Sync_Date__c = Datetime.now();

        if (String.isNotBlank(pw.itemCode)) {
            upsert product Item_Code__c;
        } else {
            insert product;
        }

        return new ApiResponse(true, 'Product upserted successfully', product.Id);
    }

    private static ApiResponse createQuote(String requestBody) {
        QuoteWrapper qw = (QuoteWrapper) JSON.deserialize(requestBody, QuoteWrapper.class);

        Quote qt = new Quote();
        qt.Name = qw.name;
        qt.OpportunityId = qw.opportunityId;
        qt.Pricebook2Id = qw.pricebookId;
        qt.Quote_Date__c = qw.quoteDate;
        qt.Valid_Till__c = qw.validTill;
        qt.Billing_Address__c = qw.billingAddress;
        qt.Shipping_Address__c = qw.shippingAddress;
        qt.Shipping_Mode__c = qw.shippingMode;
        qt.Vertical__c = qw.vertical;
        qt.Status = 'Draft';
        insert qt;

        // Create line items
        if (qw.lineItems != null && !qw.lineItems.isEmpty()) {
            List<QuoteLineItem> qlis = new List<QuoteLineItem>();
            for (QuoteLineItemInput li : qw.lineItems) {
                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = qt.Id;
                qli.Product2Id = li.productId;
                qli.PricebookEntryId = li.pricebookEntryId;
                qli.Quantity = li.quantity;
                qli.UnitPrice = li.unitPrice;
                qli.Discount = li.discount;
                qli.Tax_Type__c = li.taxType;
                qli.Product_Line_Description__c = li.lineDescription;
                qli.Product_Detailed_Description__c = li.detailedDescription;
                qlis.add(qli);
            }
            insert qlis;
        }

        return new ApiResponse(true, 'Quote created successfully', qt.Id);
    }

    // ---- Response & Request Wrappers ----

    global class ApiResponse {
        public Boolean success;
        public String message;
        public Object data;

        public ApiResponse(Boolean success, String message, Object data) {
            this.success = success;
            this.message = message;
            this.data = data;
        }
    }

    global class ProductWrapper {
        public String itemCode;
        public String name;
        public String productCode;
        public String sapItemCode;
        public String sapItemNewCode;
        public String category;
        public String productType;
        public String vertical;
        public String subCategory;
        public String brand;
        public String make;
        public String lineDescription;
        public String model;
        public String equipmentName;
        public String oemPartNumber;
        public String source;
        public Decimal standardPrice;
        public Decimal taxPercent;
        public String hsnCode;
        public String hsnCodeInternational;
        public Decimal quantityPackSize;
        public String specification;
        public String shortDescription;
        public String detailedDescription;
        public String compatibility;
        public String remarks;
        public Boolean isActive;
        public Decimal defaultWarrantyMonths;
        public String warrantyTerms;
        public String installationTerms;
        public String isInstallationRequired;
        public String isTrainingRequired;
        public String productStatus;
        public String imageUrl1;
        public String imageUrl2;
        public String imageUrl3;
    }

    global class QuoteWrapper {
        public String name;
        public Id opportunityId;
        public Id pricebookId;
        public Date quoteDate;
        public Date validTill;
        public String billingAddress;
        public String shippingAddress;
        public String shippingMode;
        public String vertical;
        public List<QuoteLineItemInput> lineItems;
    }

    global class QuoteLineItemInput {
        public Id productId;
        public Id pricebookEntryId;
        public Decimal quantity;
        public Decimal unitPrice;
        public Decimal discount;
        public String taxType;
        public String lineDescription;
        public String detailedDescription;
    }
}