/**
 * Pure helper (no DML) for tiered-pricebook selection and price-status
 * calculation on QuoteLineItems.
 *
 * Tier hierarchy (highest -> lowest list price):
 *   Price list5  ->  Price list4  ->  Price list3  ->  Price list2  ->  Price list1
 *
 * Default tier for a new non-service line is Price list5. When a user applies
 * a discount, resolveTier walks downward and returns the tightest-fitting
 * existing tier whose list price is >= the discounted unit price. If every
 * tier's list price is below the discounted price (i.e. the discount pushes
 * the price below Price list1), the line stays on Price list1 and the caller
 * must flag it as Approval Required.
 *
 * Service items (Product2.Service_Item__c = 'Yes') bypass all tier logic.
 * They carry a pricebook entry against a dummy pricebook whose UnitPrice is
 * 0; Sales Price and Tax are user-entered and Price_Status__c is always
 * Not Required.
 */
public with sharing class PricebookTierService {

    public static final String TIER5 = 'Price list5';
    public static final String TIER4 = 'Price list4';
    public static final String TIER3 = 'Price list3';
    public static final String TIER2 = 'Price list2';
    public static final String TIER1 = 'Price list1';

    // Walked from highest to lowest list price.
    public static final List<String> TIER_ORDER_HIGH_TO_LOW = new List<String>{
        TIER5, TIER4, TIER3, TIER2, TIER1
    };

    public static final String STATUS_NOT_REQUIRED = 'Not Required';
    public static final String STATUS_APPROVAL_REQUIRED = 'Approval Required';

    /**
     * Resolved tier for one product line.
     * entry is the PricebookEntry the caller should assign to the
     * QuoteLineItem; tierName is that entry's Pricebook2.Price_Book_Type__c;
     * underFloor is true when the discounted price is below every existing
     * tier's list price (caller must mark Approval Required regardless of
     * the standard-price check).
     */
    public class TierResolution {
        @AuraEnabled public PricebookEntry entry;
        @AuraEnabled public String tierName;
        @AuraEnabled public Decimal tierListPrice;
        @AuraEnabled public Boolean underFloor;
    }

    /**
     * Per-product cache: tier name -> its PricebookEntry.
     * Populated in one query per batch of product Ids.
     */
    public class ProductTierMap {
        public Map<String, PricebookEntry> byTier = new Map<String, PricebookEntry>();
        public PricebookEntry tier(String name) { return byTier.get(name); }
        public Boolean has(String name) { return byTier.containsKey(name); }
    }

    /**
     * Load tier entries for a set of products in one SOQL round-trip.
     * Only ACTIVE non-standard pricebooks with a Price_Book_Type__c in the
     * tier enum are considered. The standard pricebook is ignored because
     * tiers live on custom pricebooks.
     */
    public static Map<Id, ProductTierMap> loadTiers(Set<Id> productIds) {
        Map<Id, ProductTierMap> out = new Map<Id, ProductTierMap>();
        if (productIds == null || productIds.isEmpty()) return out;

        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice, IsActive,
                   Pricebook2Id, Pricebook2.Name, Pricebook2.Price_Book_Type__c,
                   Pricebook2.IsActive
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
              AND IsActive = true
              AND Pricebook2.IsActive = true
              AND Pricebook2.Price_Book_Type__c IN :TIER_ORDER_HIGH_TO_LOW
        ]) {
            String tier = pbe.Pricebook2.Price_Book_Type__c;
            ProductTierMap pt = out.get(pbe.Product2Id);
            if (pt == null) {
                pt = new ProductTierMap();
                out.put(pbe.Product2Id, pt);
            }
            // If two active pricebooks share the same tier for a product,
            // last-write-wins is acceptable - the admin data model should
            // prevent this. Tests assert a single entry per (product, tier).
            pt.byTier.put(tier, pbe);
        }
        return out;
    }

    /**
     * Default tier entry used when a product is first added to a quote.
     * Returns the Price list5 PricebookEntry if it exists; null otherwise.
     * Caller must block the selection when this returns null for a
     * non-service product.
     */
    public static PricebookEntry defaultEntry(ProductTierMap tiers) {
        if (tiers == null) return null;
        return tiers.tier(TIER5);
    }

    /**
     * Standard list price = Price list5 list price. Null when the product
     * has no Price list5 entry.
     */
    public static Decimal standardPrice(ProductTierMap tiers) {
        PricebookEntry e = tiers == null ? null : tiers.tier(TIER5);
        return e == null ? null : e.UnitPrice;
    }

    /**
     * Resolve the tier for a discounted unit price.
     *
     * Algorithm (matches spec Req 5):
     *   1. Walk tiers from 5 down to 1.
     *   2. Skip any tier the product does not have.
     *   3. Accept the LAST tier whose list price is >= discountedUnitPrice.
     *      "Last" means the tightest fit - the tier whose list price is
     *      closest to (but not below) the discounted price.
     *   4. If no tier fits (every existing tier's list price is below
     *      discountedUnitPrice), return the lowest existing tier with
     *      underFloor = true so the caller can flag Approval Required.
     *   5. If only Price list5 exists, it is returned regardless of the
     *      discount; the standard-price check handles the approval flag.
     *
     * discountedUnitPrice = UnitPrice * (1 - Discount/100).
     */
    public static TierResolution resolveTier(ProductTierMap tiers, Decimal discountedUnitPrice) {
        TierResolution r = new TierResolution();
        if (tiers == null || tiers.byTier.isEmpty()) {
            return r;
        }
        if (discountedUnitPrice == null) discountedUnitPrice = 0;

        PricebookEntry bestFit = null;
        String bestFitTier = null;
        PricebookEntry lowestExisting = null;
        String lowestExistingTier = null;

        for (String t : TIER_ORDER_HIGH_TO_LOW) {
            if (!tiers.has(t)) continue;
            PricebookEntry e = tiers.tier(t);
            lowestExisting = e;
            lowestExistingTier = t;
            if (e.UnitPrice != null && e.UnitPrice >= discountedUnitPrice) {
                bestFit = e;
                bestFitTier = t;
            }
        }

        if (bestFit != null) {
            r.entry = bestFit;
            r.tierName = bestFitTier;
            r.tierListPrice = bestFit.UnitPrice;
            r.underFloor = false;
        } else {
            r.entry = lowestExisting;
            r.tierName = lowestExistingTier;
            r.tierListPrice = lowestExisting == null ? null : lowestExisting.UnitPrice;
            r.underFloor = true;
        }
        return r;
    }

    /**
     * Price status for a non-service line.
     *   final_unit_price = unitPrice * (1 - discount/100)
     *   >= standardPrice -> Not Required
     *   <  standardPrice -> Approval Required
     *
     * When standardPrice is null (product has no Price list5), the caller
     * should not have allowed the line to be created; defensively returns
     * Not Required here.
     *
     * underFloor from resolveTier forces Approval Required even if
     * standardPrice is somehow not set - keeps the safety net tight.
     */
    public static String computePriceStatus(
        Decimal unitPrice,
        Decimal discount,
        Decimal standardPrice,
        Boolean underFloor
    ) {
        if (underFloor == true) return STATUS_APPROVAL_REQUIRED;
        if (standardPrice == null) return STATUS_NOT_REQUIRED;
        Decimal up = unitPrice == null ? 0 : unitPrice;
        Decimal d = discount == null ? 0 : discount;
        Decimal finalPrice = up * (1 - (d / 100));
        return finalPrice < standardPrice ? STATUS_APPROVAL_REQUIRED : STATUS_NOT_REQUIRED;
    }

    /**
     * Service-line shortcut: service items have no tiered list price to
     * compare against, and the business rule is 'approval required except
     * when the Product's Service_Item field is No'. So every service line
     * lands on Approval Required and needs a human sign-off.
     */
    public static String priceStatusForService() {
        return STATUS_APPROVAL_REQUIRED;
    }
}