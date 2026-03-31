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
* 1.1 | Claude AI        | 31-03-2026 | Enhanced per-item response, API key auth
* -----------------------------------------------------------------------------
**************************************************************/

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
     * POST /services/apexrest/api?key=xxx&value=productMaster
     * Accepts: {"data":[{"Company_Id__c":"Dev","Product_Code__c":"F01706",...}]}
     * Upserts products using Product_Code__c mapped to Item_Code__c as external ID.
     * Returns per-item success/failure details.
     */
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
        log.Request__c = data.length() > 32000
            ? data.substring(0, 32000) : data;

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

                String productCode = getStr(sp, KEY_PRODUCT_CODE);
                p.Item_Code__c = productCode;
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
                    lstResponse.add(new Response(
                        ur.getId(),
                        productCodes[i],
                        'Success',
                        ur.isCreated() ? 'Created' : 'Updated'
                    ));
                } else {
                    failCount++;
                    String errorMsg = '';
                    for (Database.Error err : ur.getErrors()) {
                        errorMsg += err.getStatusCode() + ': ' + err.getMessage() + '; ';
                    }
                    lstResponse.add(new Response(
                        null,
                        productCodes[i],
                        'Failure',
                        errorMsg
                    ));
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

    /**
     * GET /services/apexrest/api?key=xxx&productCode=F01706
     * GET /services/apexrest/api?key=xxx&category=Critical+Care
     * GET /services/apexrest/api?key=xxx (returns all active, limit 200)
     * Returns: {"data":[{"Company_Id__c":"...","Product_Code__c":"...",...}]}
     */
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

            // Build response in SAP JSON format
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
            responseMap.put('success', true);
            responseMap.put('message', products.size() + ' product(s) found');
            responseMap.put('data', sapProducts);

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseMap));
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
