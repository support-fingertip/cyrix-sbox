// Cyrix SAP Product API Controller - Module 7.
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

    // SAP JSON field key constants
    private static final String KEY_COMPANY_ID = 'Company_Id__c';
    private static final String KEY_PRODUCT_CODE = 'Product_Code__c';
    private static final String KEY_SKU = 'SKU__c';
    private static final String KEY_ITEM_DESC = 'Item_Description__c';
    private static final String KEY_NAME = 'Name';
    private static final String KEY_BRAND = 'Brand__c';
    private static final String KEY_SALES_TAX = 'Sales_Tax__c';
    private static final String KEY_PURCHASE_TAX = 'Purchase_Tax__c';
    private static final String KEY_HSN_CODE = 'HSN_Code__c';
    private static final String KEY_GST = 'GST__c';
    private static final String KEY_FIXED_PRICE = 'Fixed_Price_Item__c';

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
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            List<Object> dataList = (List<Object>) parsed.get('data');

            if (dataList == null || dataList.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(
                    new ApiResponse(false, 'No data provided', null)
                ));
                log.Response__c = 'Error: No data provided';
                insert log;
                return;
            }

            List<Product2> productsToUpsert = new List<Product2>();

            for (Object item : dataList) {
                Map<String, Object> sp = (Map<String, Object>) item;
                Product2 p = new Product2();

                p.Item_Code__c = getStr(sp, KEY_PRODUCT_CODE);
                p.ProductCode = getStr(sp, KEY_SKU);
                p.Name = getStr(sp, KEY_NAME);
                p.Brand__c = getStr(sp, KEY_BRAND);
                p.HSN_Code__c = getStr(sp, KEY_HSN_CODE);
                p.IsActive = true;
                p.ERP_Sync_Status__c = 'Synced';
                p.Last_ERP_Sync_Date__c = Datetime.now();

                String salesTax = getStr(sp, KEY_SALES_TAX);
                String gst = getStr(sp, KEY_GST);
                if (String.isNotBlank(gst)) {
                    p.Tax__c = Decimal.valueOf(gst);
                } else if (String.isNotBlank(salesTax)) {
                    p.Tax__c = Decimal.valueOf(salesTax);
                }

                String itemDesc = getStr(sp, KEY_ITEM_DESC);
                if (String.isNotBlank(itemDesc)) {
                    p.Line_Description__c = itemDesc;
                }

                String companyId = getStr(sp, KEY_COMPANY_ID);
                if (String.isNotBlank(companyId)) {
                    p.Source__c = companyId;
                }

                String fixedPrice = getStr(sp, KEY_FIXED_PRICE);
                if (String.isNotBlank(fixedPrice)) {
                    p.Remarks__c = 'Fixed Price: ' + fixedPrice;
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
     * Returns: {"data":[{"Company_Id__c":"...","Product_Code__c":"...",...}]}
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

            // Build response in SAP JSON format using maps to preserve __c keys
            List<Map<String, String>> sapProducts = new List<Map<String, String>>();
            for (Product2 p : products) {
                Map<String, String> sp = new Map<String, String>();
                sp.put(KEY_COMPANY_ID, p.Source__c != null ? p.Source__c : '');
                sp.put(KEY_PRODUCT_CODE, p.Item_Code__c != null ? p.Item_Code__c : '');
                sp.put(KEY_SKU, p.ProductCode != null ? p.ProductCode : '');
                sp.put(KEY_NAME, p.Name != null ? p.Name : '');
                sp.put(KEY_ITEM_DESC, p.Line_Description__c != null ? p.Line_Description__c : '');
                sp.put(KEY_BRAND, p.Brand__c != null ? p.Brand__c : '');
                sp.put(KEY_SALES_TAX, p.Tax__c != null ? String.valueOf(p.Tax__c) : '');
                sp.put(KEY_PURCHASE_TAX, p.Tax__c != null ? String.valueOf(p.Tax__c) : '');
                sp.put(KEY_HSN_CODE, p.HSN_Code__c != null ? p.HSN_Code__c : '');
                sp.put(KEY_GST, p.Tax__c != null ? String.valueOf(p.Tax__c) : '');
                sp.put(KEY_FIXED_PRICE, 'N');
                sapProducts.add(sp);
            }

            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('data', sapProducts);

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseMap));
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(
                new ApiResponse(false, 'Error: ' + e.getMessage(), null)
            ));
        }
    }

    // Helper to safely get a string value from a map
    private static String getStr(Map<String, Object> m, String key) {
        Object val = m.get(key);
        return val != null ? String.valueOf(val) : '';
    }

    // ---- Response Wrapper ----

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
