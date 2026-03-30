// Cyrix SAP Product API Controller - Module 7
/****************************************************************
* Class Name   : SAPProductController
* Company      : Fingertipplus
* Created Date : 30-03-2026
* @description : REST API for SAP Product integration.
*                Supports POST (upsert products from SAP) and GET (retrieve products).
*                JSON format: {"data":[{...product fields...}]}
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 30-03-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
@RestResource(urlMapping='/SAPProduct/*')
global without sharing class SAPProductController {

    /**
     * POST /services/apexrest/SAPProduct
     * Accepts: {"data":[{"Company_Id__c":"Dev","Product_Code__c":"F01706",...}]}
     * Upserts products using Product_Code__c mapped to Item_Code__c as external ID.
     */
    @HttpPost
    global static void upsertProducts() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String requestBody = req.requestBody.toString();

        // Log the request
        Log__c log = new Log__c();
        log.Object__c = 'SAPProduct POST';
        log.Request__c = requestBody.length() > 32000
            ? requestBody.substring(0, 32000) : requestBody;

        try {
            SAPRequestWrapper wrapper = (SAPRequestWrapper) JSON.deserialize(requestBody, SAPRequestWrapper.class);

            if (wrapper.data == null || wrapper.data.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, 'No data provided', null)
                ));
                log.Response__c = 'Error: No data provided';
                insert log;
                return;
            }

            List<Product2> productsToUpsert = new List<Product2>();

            for (SAPProductWrapper sp : wrapper.data) {
                Product2 p = new Product2();
                p.Item_Code__c = sp.Product_Code__c;
                p.ProductCode = sp.SKU__c;
                p.Name = sp.Name;
                p.Brand__c = sp.Brand__c;
                p.HSN_Code__c = sp.HSN_Code__c;
                p.IsActive = true;
                p.ERP_Sync_Status__c = 'Synced';
                p.Last_ERP_Sync_Date__c = Datetime.now();

                if (String.isNotBlank(sp.Sales_Tax__c)) {
                    p.Tax__c = Decimal.valueOf(sp.Sales_Tax__c);
                }

                if (String.isNotBlank(sp.Item_Description__c)) {
                    p.Line_Description__c = sp.Item_Description__c;
                }

                if (String.isNotBlank(sp.Company_Id__c)) {
                    p.Source__c = sp.Company_Id__c;
                }

                if (String.isNotBlank(sp.Fixed_Price_Item__c)) {
                    p.Remarks__c = 'Fixed Price: ' + sp.Fixed_Price_Item__c;
                }

                if (String.isNotBlank(sp.GST__c)) {
                    p.Tax__c = Decimal.valueOf(sp.GST__c);
                }

                if (String.isNotBlank(sp.Purchase_Tax__c)) {
                    // Store purchase tax info if different from sales tax
                }

                productsToUpsert.add(p);
            }

            upsert productsToUpsert Item_Code__c;

            List<Map<String, String>> results = new List<Map<String, String>>();
            for (Product2 p : productsToUpsert) {
                results.add(new Map<String, String>{
                    'Id' => p.Id,
                    'Item_Code__c' => p.Item_Code__c,
                    'Name' => p.Name
                });
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(true, productsToUpsert.size() + ' product(s) upserted successfully', results)
            ));
            log.Response__c = 'Success: ' + productsToUpsert.size() + ' products upserted';
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, 'Error: ' + e.getMessage(), null)
            ));
            log.Response__c = 'Error: ' + e.getMessage();
        }

        insert log;
    }

    /**
     * GET /services/apexrest/SAPProduct?productCode=F01706
     * GET /services/apexrest/SAPProduct?category=Critical+Care
     * GET /services/apexrest/SAPProduct (returns all active, limit 200)
     * Returns: {"data":[{...product fields...}]}
     */
    @HttpGet
    global static void getProducts() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String productCode = req.params.get('productCode');
            String category = req.params.get('category');
            String brand = req.params.get('brand');
            Integer limitVal = req.params.get('limit') != null
                ? Integer.valueOf(req.params.get('limit')) : 200;

            String query = 'SELECT Id, Name, ProductCode, Item_Code__c, ' +
                'Product_Category__c, Brand__c, Make__c, Model__c, ' +
                'Line_Description__c, Standard_Price__c, Tax__c, ' +
                'HSN_Code__c, Source__c, Remarks__c, IsActive, ' +
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

            // Map to SAP JSON format
            List<SAPProductWrapper> sapProducts = new List<SAPProductWrapper>();
            for (Product2 p : products) {
                SAPProductWrapper sp = new SAPProductWrapper();
                sp.Company_Id__c = p.Source__c;
                sp.Product_Code__c = p.Item_Code__c;
                sp.SKU__c = p.ProductCode;
                sp.Name = p.Name;
                sp.Item_Description__c = p.Line_Description__c;
                sp.Brand__c = p.Brand__c;
                sp.Sales_Tax__c = p.Tax__c != null ? String.valueOf(p.Tax__c) : '';
                sp.Purchase_Tax__c = p.Tax__c != null ? String.valueOf(p.Tax__c) : '';
                sp.HSN_Code__c = p.HSN_Code__c != null ? p.HSN_Code__c : '';
                sp.GST__c = p.Tax__c != null ? String.valueOf(p.Tax__c) : '';
                sp.Fixed_Price_Item__c = 'N';
                sapProducts.add(sp);
            }

            SAPResponseWrapper responseWrapper = new SAPResponseWrapper();
            responseWrapper.data = sapProducts;

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseWrapper));
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, 'Error: ' + e.getMessage(), null)
            ));
        }
    }

    // ---- Wrapper Classes ----

    global class SAPRequestWrapper {
        public List<SAPProductWrapper> data;
    }

    global class SAPResponseWrapper {
        public List<SAPProductWrapper> data;
    }

    global class SAPProductWrapper {
        public String Company_Id__c;
        public String Product_Code__c;
        public String SKU__c;
        public String Item_Description__c;
        public String Name;
        public String Brand__c;
        public String Sales_Tax__c;
        public String Purchase_Tax__c;
        public String HSN_Code__c;
        public String GST__c;
        public String Fixed_Price_Item__c;
    }

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
}
