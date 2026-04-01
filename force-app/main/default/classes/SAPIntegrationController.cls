@RestResource(urlMapping='/api/*')
global without sharing class SAPIntegrationController {

/* Class Name   : SAPIntegrationController
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : REST API for SAP Product integration.
*                Supports POST (upsert products from SAP) and GET (retrieve products)
*                JSON format: {"data":[{...product fields...}]}
*                Includes API Key validation and per-item error reporting.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Nanma            | 30-03-2026 | Initial version
* 1.1 | Claude AI        | 01-04-2026 | Updated field mappings, per-item response
* 1.2 | Claude AI        | 01-04-2026 | Added customer address query (billing + shipping)
* -----------------------------------------------------------------------------
**************************************************************/

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String key = req.params.get('key');
        String value = req.params.get('value');
        String data = req.requestBody.toString();

        // API Key validation
        if (String.isBlank(key) || key != Label.SAP_API) {
            res.statusCode = 401;
            List<Response> lstResponse = new List<Response>();
            lstResponse.add(new Response(null, null, 'Failure', 'Invalid Key.'));
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
            return;
        }

        if (value == 'productMaster') {
            upsertProducts(data, res);
        } else {
            res.statusCode = 403;
            List<Response> lstResponse = new List<Response>();
            lstResponse.add(new Response(null, null, 'Failure', 'Invalid Parameter Value.'));
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
        }
    }

    private static void upsertProducts(String data, RestResponse res) {
        List<Response> lstResponse = new List<Response>();

        // Log the request
        Log__c log = new Log__c();
        log.Object__c = 'Product';
        log.Request__c = data.length() > 32000 ? data.substring(0, 32000) : data;

        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(data);
            List<Object> dataList = (List<Object>) parsed.get('data');

            if (dataList == null || dataList.isEmpty()) {
                res.statusCode = 400;
                lstResponse.add(new Response(null, null, 'Failure', 'No data provided'));
                res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
                log.Response__c = 'Error: No data provided';
                log.Status_Code__c = '400';
                insert log;
                return;
            }

            List<Product2> productsToUpsert = new List<Product2>();
            List<String> productCodes = new List<String>();

            for (Object item : dataList) {
                Map<String, Object> sp = (Map<String, Object>) item;
                Product2 p = new Product2();

                String productCode = getStr(sp, 'ProductCode');
                p.Item_Code__c = productCode;
                p.ProductCode = productCode;
                p.Name = getStr(sp, 'Name');
                p.SAP_Item_Code__c = getStr(sp, 'SAP_Item_Code__c');
                p.Product_Category__c = getStr(sp, 'Product_Category__c');
                p.Product_Vertical__c = getStr(sp, 'Product_Vertical__c');
                p.Product_Type__c = getStr(sp, 'Product_Type__c');
                p.Source__c = getStr(sp, 'Source__c');
                p.Equipment_Name__c = getStr(sp, 'Equipment_Name__c');
                p.Make__c = getStr(sp, 'Make__c');
                p.Model__c = getStr(sp, 'Model__c');
                p.OEM_Part_Number__c = getStr(sp, 'OEM_Part_Number__c');
                p.QuantityUnitOfMeasure = getStr(sp, 'QuantityUnitOfMeasure');
                p.Compatibility__c = getStr(sp, 'Compatibility__c');
                p.Specification__c = getStr(sp, 'Specification__c');
                p.HSN_Code__c = getStr(sp, 'HSN_Code__c');
                p.IsActive = Boolean.valueOf(getStr(sp, 'IsActive'));
                p.ERP_Sync_Status__c = 'Synced';
                p.Last_ERP_Sync_Date__c = Datetime.now();

                String packSize = getStr(sp, 'Quantity_Pack_Size__c');
                if (String.isNotBlank(packSize)) {
                    p.Quantity_Pack_Size__c = Decimal.valueOf(packSize);
                }

                String tax = getStr(sp, 'Tax__c');
                if (String.isNotBlank(tax)) {
                    p.Tax__c = Decimal.valueOf(tax);
                }

                p.Product_Image_URL__c = getStr(sp, 'Product_Image_URL__c');
                p.Product_Image_URL_2__c = getStr(sp, 'Product_Image_URL_2__c');
                p.Product_Image_URL_3__c = getStr(sp, 'Product_Image_URL_3__c');

                String itemDesc = getStr(sp, 'Description');
                if (String.isNotBlank(itemDesc)) {
                    p.Description = itemDesc;
                }

                p.Remarks__c = getStr(sp, 'Remarks__c');
                p.Any_Other_Levies__c = getStr(sp, 'Any_Other_Levies__c');

                productsToUpsert.add(p);
                productCodes.add(productCode);
            }

            // Use allOrNone=false so partial success is possible
            List<Database.UpsertResult> upsertResults = Database.upsert(productsToUpsert, Product2.Item_Code__c, false);

            // Build per-item response
            Integer successCount = 0;
            Integer failCount = 0;

            for (Integer i = 0; i < upsertResults.size(); i++) {
                Database.UpsertResult ur = upsertResults[i];
                if (ur.isSuccess()) {
                    successCount++;
                    lstResponse.add(new Response(ur.getId(), productCodes[i], 'Success', ur.isCreated() ? 'Created' : 'Updated'));
                } else {
                    failCount++;
                    String errorMsg = '';
                    for (Database.Error err : ur.getErrors()) {
                        errorMsg += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    lstResponse.add(new Response(null, productCodes[i], 'Failure', errorMsg));
                }
            }

            res.statusCode = (failCount == 0) ? 200 : 207;
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));

            log.Response__c = successCount + ' succeeded, ' + failCount + ' failed';
            log.Status_Code__c = String.valueOf(res.statusCode);
        } catch (Exception e) {
            res.statusCode = 500;
            lstResponse.add(new Response(null, null, 'Failure', 'Error: ' + e.getMessage()));
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
            log.Response__c = 'Error: ' + e.getMessage();
            log.Status_Code__c = '500';
        }

        if (Label.Enable_Logs == 'TRUE') {
            insert log;
        }
    }

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        // API Key validation
        String key = req.params.get('key');
        if (String.isBlank(key) || key != Label.SAP_API) {
            res.statusCode = 401;
            List<Response> lstResponse = new List<Response>();
            lstResponse.add(new Response(null, null, 'Failure', 'Invalid Key.'));
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
            return;
        }

        String value = req.params.get('value');

        if (value == 'productMaster') {
            getProducts(req, res);
        } else if (value == 'customerAddress') {
            getCustomerAddresses(req, res);
        } else {
            res.statusCode = 403;
            List<Response> lstResponse = new List<Response>();
            lstResponse.add(new Response(null, null, 'Failure', 'Invalid Parameter Value. Use: productMaster or customerAddress'));
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
        }
    }

    private static void getProducts(RestRequest req, RestResponse res) {
        try {
            String productCode = req.params.get('productCode');
            String category = req.params.get('category');
            String brand = req.params.get('brand');
            Integer limitVal = req.params.get('limit') != null
                ? Integer.valueOf(req.params.get('limit')) : 200;

            String query = 'SELECT Id, Name, ProductCode, Item_Code__c, ' +
                'SAP_Item_Code__c, Product_Category__c, Product_Vertical__c, ' +
                'Product_Type__c, Source__c, Equipment_Name__c, ' +
                'Make__c, Model__c, OEM_Part_Number__c, QuantityUnitOfMeasure, ' +
                'Compatibility__c, Specification__c, Quantity_Pack_Size__c, ' +
                'HSN_Code__c, Tax__c, Description, Remarks__c, ' +
                'Any_Other_Levies__c, Brand__c, IsActive, ' +
                'Product_Image_URL__c, Product_Image_URL_2__c, Product_Image_URL_3__c, ' +
                'ERP_Sync_Status__c, Last_ERP_Sync_Date__c ' +
                'FROM Product2 WHERE IsActive = true';

            if (String.isNotBlank(productCode)) {
                query += ' AND Item_Code__c = :productCode';
            }
            if (String.isNotBlank(category)) {
                query += ' AND Product_Category__c = :category';
            }
            if (String.isNotBlank(brand)) {
                query += ' AND Brand__c = :brand';
            }
            query += ' ORDER BY Name ASC LIMIT :limitVal';

            List<Product2> products = Database.query(query);

            List<Response> lstResponse = new List<Response>();
            for (Product2 p : products) {
                lstResponse.add(new Response(p.Id, p.Item_Code__c, 'Success', p.Name));
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
        } catch (Exception e) {
            res.statusCode = 500;
            List<Response> lstResponse = new List<Response>();
            lstResponse.add(new Response(null, null, 'Failure', 'Error: ' + e.getMessage()));
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
        }
    }

    private static void getCustomerAddresses(RestRequest req, RestResponse res) {
        try {
            String accountId = req.params.get('accountId');
            String customerCode = req.params.get('customerCode');
            Integer limitVal = req.params.get('limit') != null
                ? Integer.valueOf(req.params.get('limit')) : 200;

            // Query Accounts with billing address
            String query = 'SELECT Id, Name, Customer_Code__c, ' +
                'BillingStreet, BillingCity, BillingState, BillingStateCode, ' +
                'BillingPostalCode, BillingCountry, BillingCountryCode, ' +
                'ShippingStreet, ShippingCity, ShippingState, ShippingStateCode, ' +
                'ShippingPostalCode, ShippingCountry, ShippingCountryCode, ' +
                '(SELECT Id, Name, ' +
                    'Address__Street__s, Address__City__s, Address__StateCode__s, ' +
                    'Address__PostalCode__s, Address__CountryCode__s, ' +
                    'Same_as_BillingAddress__c ' +
                 'FROM Shipping_Addresses__r) ' +
                'FROM Account WHERE Id != null';

            if (String.isNotBlank(accountId)) {
                query += ' AND Id = :accountId';
            }
            if (String.isNotBlank(customerCode)) {
                query += ' AND Customer_Code__c = :customerCode';
            }
            query += ' ORDER BY Name ASC LIMIT :limitVal';

            List<Account> accounts = Database.query(query);

            List<Map<String, Object>> results = new List<Map<String, Object>>();
            for (Account acc : accounts) {
                Map<String, Object> accMap = new Map<String, Object>();
                accMap.put('AccountId', acc.Id);
                accMap.put('AccountName', acc.Name);
                accMap.put('CustomerCode', acc.Customer_Code__c);

                // Billing Address
                Map<String, String> billing = new Map<String, String>();
                billing.put('Street', acc.BillingStreet != null ? acc.BillingStreet : '');
                billing.put('City', acc.BillingCity != null ? acc.BillingCity : '');
                billing.put('State', acc.BillingState != null ? acc.BillingState : '');
                billing.put('PostalCode', acc.BillingPostalCode != null ? acc.BillingPostalCode : '');
                billing.put('Country', acc.BillingCountry != null ? acc.BillingCountry : '');
                accMap.put('BillingAddress', billing);

                // Standard Shipping Address
                Map<String, String> shipping = new Map<String, String>();
                shipping.put('Street', acc.ShippingStreet != null ? acc.ShippingStreet : '');
                shipping.put('City', acc.ShippingCity != null ? acc.ShippingCity : '');
                shipping.put('State', acc.ShippingState != null ? acc.ShippingState : '');
                shipping.put('PostalCode', acc.ShippingPostalCode != null ? acc.ShippingPostalCode : '');
                shipping.put('Country', acc.ShippingCountry != null ? acc.ShippingCountry : '');
                accMap.put('ShippingAddress', shipping);

                // Additional Shipping Addresses from Shipping_Address__c
                List<Map<String, String>> additionalShipping = new List<Map<String, String>>();
                if (acc.Shipping_Addresses__r != null) {
                    for (Shipping_Address__c sa : acc.Shipping_Addresses__r) {
                        Map<String, String> saMap = new Map<String, String>();
                        saMap.put('Id', sa.Id);
                        saMap.put('Name', sa.Name);
                        saMap.put('Street', sa.Address__Street__s != null ? sa.Address__Street__s : '');
                        saMap.put('City', sa.Address__City__s != null ? sa.Address__City__s : '');
                        saMap.put('State', sa.Address__StateCode__s != null ? sa.Address__StateCode__s : '');
                        saMap.put('PostalCode', sa.Address__PostalCode__s != null ? sa.Address__PostalCode__s : '');
                        saMap.put('Country', sa.Address__CountryCode__s != null ? sa.Address__CountryCode__s : '');
                        saMap.put('SameAsBilling', String.valueOf(sa.Same_as_BillingAddress__c));
                        additionalShipping.add(saMap);
                    }
                }
                accMap.put('AdditionalShippingAddresses', additionalShipping);

                results.add(accMap);
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(results));
        } catch (Exception e) {
            res.statusCode = 500;
            List<Response> lstResponse = new List<Response>();
            lstResponse.add(new Response(null, null, 'Failure', 'Error: ' + e.getMessage()));
            res.responseBody = Blob.valueOf(JSON.serialize(lstResponse));
        }
    }

    // Helper to safely get a string value from a map
    private static String getStr(Map<String, Object> m, String key) {
        Object val = m.get(key);
        return val != null ? String.valueOf(val) : '';
    }

    // ---- Response Wrapper ----

    public class Response {
        public String SF_RecordId;
        public String SAPUniqueId;
        public String Status;
        public String Message;

        public Response(String sfId, String sapId, String status, String message) {
            this.SF_RecordId = sfId;
            this.SAPUniqueId = sapId;
            this.Status = status;
            this.Message = message;
        }
    }
}
