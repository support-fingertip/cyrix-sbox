/* Class Name   : SFToSAPIntegrationController
* Company      : Fingertipplus
* Created Date : 01-04-2026
* @description : Controller for Salesforce to SAP outbound integration.
*                Sends data FROM Salesforce TO SAP via HTTP callouts.
*                Handles customer, product, and order sync to SAP.
*
* Change Log:
* -----------------------------------------------------------------------------
* Ver | Author           | Date       | Description
* -----------------------------------------------------------------------------
* 1.0 | Claude AI        | 01-04-2026 | Initial version
* -----------------------------------------------------------------------------
**************************************************************/
public without sharing class SFToSAPIntegrationController {

    private static final String SAP_ENDPOINT = 'callout:SAP_API_Endpoint';

    // Send Account/Customer data to SAP
    public static SAPResponse sendCustomerToSAP(Id accountId) {
        Account acc = [
            SELECT Id, Name, Phone, Website, Industry,
                Customer_Code__c, SAP_Customer_Code__c, Status__c, Customer_Type__c,
                Customer_Category__c, Customer_Rating__c, Email__c,
                GST_Number__c, PAN_Number__c, Payment_Terms__c,
                BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('Customer_Code', acc.Customer_Code__c);
        payload.put('SAP_Customer_Code', acc.SAP_Customer_Code__c);
        payload.put('Name', acc.Name);
        payload.put('Phone', acc.Phone);
        payload.put('Website', acc.Website);
        payload.put('Industry', acc.Industry);
        payload.put('Status', acc.Status__c);
        payload.put('Customer_Type', acc.Customer_Type__c);
        payload.put('Customer_Category', acc.Customer_Category__c);
        payload.put('Customer_Rating', acc.Customer_Rating__c);
        payload.put('Email', acc.Email__c);
        payload.put('GST_Number', acc.GST_Number__c);
        payload.put('PAN_Number', acc.PAN_Number__c);
        payload.put('Payment_Terms', acc.Payment_Terms__c);

        Map<String, String> billing = new Map<String, String>();
        billing.put('Street', acc.BillingStreet);
        billing.put('City', acc.BillingCity);
        billing.put('State', acc.BillingState);
        billing.put('PostalCode', acc.BillingPostalCode);
        billing.put('Country', acc.BillingCountry);
        payload.put('BillingAddress', billing);

        Map<String, String> shipping = new Map<String, String>();
        shipping.put('Street', acc.ShippingStreet);
        shipping.put('City', acc.ShippingCity);
        shipping.put('State', acc.ShippingState);
        shipping.put('PostalCode', acc.ShippingPostalCode);
        shipping.put('Country', acc.ShippingCountry);
        payload.put('ShippingAddress', shipping);

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('data', new List<Object>{ payload });

        return sendToSAP('/api/customer', JSON.serialize(requestBody));
    }

    // Send Product data to SAP
    public static SAPResponse sendProductToSAP(Id productId) {
        Product2 prod = [
            SELECT Id, Name, ProductCode, Item_Code__c, SAP_Item_Code__c,
                Product_Category__c, Family, Product_Type__c,
                Make__c, Model__c, OEM_Part_Number__c, HSN_Code__c,
                Tax__c, IsActive, Description, QuantityUnitOfMeasure
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('ProductCode', prod.ProductCode);
        payload.put('Item_Code', prod.Item_Code__c);
        payload.put('SAP_Item_Code', prod.SAP_Item_Code__c);
        payload.put('Name', prod.Name);
        payload.put('Product_Category', prod.Product_Category__c);
        payload.put('Product_Vertical', prod.Family);
        payload.put('Product_Type', prod.Product_Type__c);
        payload.put('Make', prod.Make__c);
        payload.put('Model', prod.Model__c);
        payload.put('OEM_Part_Number', prod.OEM_Part_Number__c);
        payload.put('HSN_Code', prod.HSN_Code__c);
        payload.put('Tax', prod.Tax__c);
        payload.put('IsActive', prod.IsActive);
        payload.put('Description', prod.Description);
        payload.put('UOM', prod.QuantityUnitOfMeasure);

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('data', new List<Object>{ payload });

        return sendToSAP('/api/product', JSON.serialize(requestBody));
    }

    // Generic method to send data to SAP
    private static SAPResponse sendToSAP(String endpoint, String body) {
        SAPResponse result = new SAPResponse();
        Log__c log = new Log__c();
        log.Object__c = 'SAP Outbound';
        log.Request__c = body.length() > 32000 ? body.substring(0, 32000) : body;

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(SAP_ENDPOINT + endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + Label.SAP_API);
            req.setTimeout(120000);
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);

            result.statusCode = res.getStatusCode();
            result.responseBody = res.getBody();
            result.success = (res.getStatusCode() >= 200 && res.getStatusCode() < 300);

            log.Response__c = result.responseBody != null && result.responseBody.length() > 32000
                ? result.responseBody.substring(0, 32000)
                : result.responseBody;
            log.Status_Code__c = String.valueOf(result.statusCode);
        } catch (Exception e) {
            result.success = false;
            result.statusCode = 500;
            result.responseBody = 'Error: ' + e.getMessage();
            log.Response__c = 'Error: ' + e.getMessage();
            log.Status_Code__c = '500';
        }

        if (Label.Enable_Logs == 'TRUE') {
            insert log;
        }

        return result;
    }

    // Future method for async callouts from triggers
    @future(callout=true)
    public static void sendCustomerToSAPAsync(Id accountId) {
        sendCustomerToSAP(accountId);
    }

    @future(callout=true)
    public static void sendProductToSAPAsync(Id productId) {
        sendProductToSAP(productId);
    }

    public class SAPResponse {
        public Boolean success;
        public Integer statusCode;
        public String responseBody;
    }
}