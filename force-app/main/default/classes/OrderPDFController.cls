/**
 * Stub controller — kept so historical metadata references resolve.
 * The Send Order Email action does not use this class; it lives in
 * OrderPDFEmailController.
 */
public with sharing class OrderPDFController {
    public Id orderId { get; set; }

    public OrderPDFController(ApexPages.StandardController stdController) {
        orderId = stdController.getId();
    }
}
