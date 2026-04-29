/**
 * Discount-tier evaluator for QuoteLineItem and OrderItem.
 *
 * The org's tier system lives on Pricebook2 records whose
 * Price_Book_Type__c picklist points at one of:
 *   Price List 1  (CEO / CFO band, most permissive)
 *   Price List 2  (VP band)
 *   Price List 3  (TSM band)
 *   Price List 4  (ASM band)
 *   Price List 5  (default / standard price on the quote/order)
 *
 * Each PricebookEntry on a tier carries Discount__c — the maximum
 * discount allowed at that tier for the product. Max_Discount_Percentage__c
 * is deprecated and is no longer read.
 *
 * Algorithm (per spec, run per line item on add and on every discount edit):
 *
 *   1. Service item (Product2.Service_Item__c = 'Yes')
 *        -> Price_Status__c = 'Not Required'
 *        -> keep the existing pricebook on the line, don't touch UnitPrice
 *
 *   2. Non-service, entered discount within the running user's ceiling
 *      tier's Discount__c
 *        -> Price_Status__c = 'Not Required'
 *        -> map Price List 5 to the line
 *
 *   3. Non-service, entered discount exceeds the ceiling
 *        -> walk the escalation ladder above the ceiling (tightest band
 *           first) and pick the first tier whose Discount__c covers the
 *           entered discount
 *        -> Price_Status__c = 'Approval Required'
 *        -> map that tier's Pricebook to the line
 *
 *   4. Non-service, entered discount exceeds every tier in the ladder
 *        -> map Price List 1 (top of the ladder)
 *        -> Price_Status__c = 'Approval Required'
 *        -> evaluation flags exceedsAllTiers = true so the UI can warn
 *
 * Profile -> ceiling map (per spec):
 *   Sales Engineer       -> Price List 4
 *   ASM                  -> Price List 3
 *   TSM                  -> Price List 2
 *   VP / Vice President  -> Price List 2
 *   CFO / CEO            -> Price List 1
 *   Anything else        -> Price List 5 (no implicit allowance)
 *
 * A missing PricebookEntry for a tier is skipped silently (the ladder
 * walks past it) — never thrown.
 */
public with sharing class PricebookTierService {

    public static final String TIER1 = 'Price List 1';
    public static final String TIER2 = 'Price List 2';
    public static final String TIER3 = 'Price List 3';
    public static final String TIER4 = 'Price List 4';
    public static final String TIER5 = 'Price List 5';

    public static final List<String> TIER_ORDER_HIGH_TO_LOW = new List<String>{
        TIER5, TIER4, TIER3, TIER2, TIER1
    };

    public static final String STATUS_NOT_REQUIRED      = 'Not Required';
    public static final String STATUS_APPROVAL_REQUIRED = 'Approval Required';

    // PL5 is the lowest "rank"; PL1 is the highest. Ladder walks from
    // ceiling+1 up to PL1.
    private static final Map<String, Integer> RANK_BY_TIER = new Map<String, Integer>{
        TIER5 => 0,
        TIER4 => 1,
        TIER3 => 2,
        TIER2 => 3,
        TIER1 => 4
    };

    /**
     * Per-product tier map: tier name -> active PricebookEntry on that
     * tier's Pricebook2. Skips inactive tiers and inactive entries.
     */
    public class ProductTiers {
        public Map<String, PricebookEntry> byTier = new Map<String, PricebookEntry>();
        public PricebookEntry tier(String name) { return byTier.get(name); }
        public Boolean has(String name) { return byTier.containsKey(name); }
        public Boolean isEmpty() { return byTier.isEmpty(); }
    }

    /**
     * Outcome of evaluating one line item against the algorithm.
     * mappedPricebookId / mappedPricebookEntryId / mappedUnitPrice are
     * populated when the algorithm wants the caller to (re)assign the
     * line's pricebook reference and re-fetch the unit price from the
     * resolved entry. exceedsAllTiers is true when even Price List 1's
     * Discount__c can't cover the entered discount.
     */
    public class Evaluation {
        @AuraEnabled public String  status;
        @AuraEnabled public Id      mappedPricebookId;
        @AuraEnabled public Id      mappedPricebookEntryId;
        @AuraEnabled public String  mappedTierName;
        @AuraEnabled public Decimal mappedUnitPrice;
        @AuraEnabled public Decimal mappedTierDiscount;
        @AuraEnabled public String  ceilingTierName;
        @AuraEnabled public Decimal ceilingTierDiscount;
        @AuraEnabled public Boolean exceedsAllTiers;
    }

    /**
     * Single SOQL: load active tier PricebookEntries for the requested
     * products. Standard pricebook (IsStandard = true) is excluded — tiers
     * are stored on custom Pricebook2 records keyed by Price_Book_Type__c.
     */
    public static Map<Id, ProductTiers> loadTiers(Set<Id> productIds) {
        Map<Id, ProductTiers> out = new Map<Id, ProductTiers>();
        if (productIds == null || productIds.isEmpty()) return out;

        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice, IsActive,
                   Discount__c,
                   Pricebook2Id, Pricebook2.Name, Pricebook2.Price_Book_Type__c,
                   Pricebook2.IsActive
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
              AND IsActive = true
              AND Pricebook2.IsActive = true
              AND Pricebook2.Price_Book_Type__c IN :TIER_ORDER_HIGH_TO_LOW
        ]) {
            String tier = pbe.Pricebook2.Price_Book_Type__c;
            ProductTiers pt = out.get(pbe.Product2Id);
            if (pt == null) {
                pt = new ProductTiers();
                out.put(pbe.Product2Id, pt);
            }
            pt.byTier.put(tier, pbe);
        }
        return out;
    }

    /**
     * Map a profile name to the user's self-approval ceiling tier.
     * Short codes match exactly (so 'Receptionist' doesn't bleed into
     * a substring), long-form titles match via contains().
     *
     * Anything that doesn't map to a band returns TIER5 — i.e. no
     * implicit discount allowance, every non-zero discount escalates.
     */
    public static String ceilingTierFor(String profileName) {
        if (profileName == null) return TIER5;
        String n = profileName.toLowerCase().trim();
        if (n == 'sales engineer' || n == 'sales_engineer') return TIER4;
        if (n == 'asm' || n.contains('area sales manager')) return TIER3;
        if (n == 'tsm' || n.contains('territory sales manager')) return TIER2;
        if (n == 'vp' || n.contains('vp sales') || n.contains('vp_sales')
                || n.contains('vice president')) return TIER2;
        if (n == 'ceo' || n == 'cfo'
                || n.contains('chief financial') || n.contains('chief executive')) return TIER1;
        return TIER5;
    }

    /**
     * Ordered escalation ladder above the ceiling, tightest-band first.
     * A user at PL4 walks PL3 -> PL2 -> PL1; a CEO at PL1 has an empty
     * ladder.
     */
    public static List<String> escalationLadderAbove(String ceilingTier) {
        Integer ceilingRank = RANK_BY_TIER.get(ceilingTier);
        if (ceilingRank == null) ceilingRank = 0;
        List<String> result = new List<String>();
        for (String t : new List<String>{ TIER4, TIER3, TIER2, TIER1 }) {
            Integer r = RANK_BY_TIER.get(t);
            if (r != null && r > ceilingRank) result.add(t);
        }
        return result;
    }

    // Cached per-transaction so repeated LWC pings don't burn SOQL.
    private static String cachedProfileName;
    public static String runningUserProfileName() {
        if (cachedProfileName != null) return cachedProfileName;
        Id pid = UserInfo.getProfileId();
        if (pid == null) {
            cachedProfileName = '';
            return cachedProfileName;
        }
        List<Profile> ps = [SELECT Name FROM Profile WHERE Id = :pid LIMIT 1];
        cachedProfileName = ps.isEmpty() ? '' : (ps[0].Name == null ? '' : ps[0].Name);
        return cachedProfileName;
    }

    /**
     * Run the algorithm for one line item.
     *
     *   tiers           - the product's tier map from loadTiers()
     *   enteredDiscount - the discount the user entered on the line (%)
     *   isService       - Product2.Service_Item__c == 'Yes' shortcut
     *   profileName     - running user profile (drives ceiling)
     *
     * The Evaluation result is shaped so the caller can simply copy
     * mappedPricebookId / mappedPricebookEntryId / mappedUnitPrice onto
     * the line and stamp status. When mappedPricebookId is null the
     * caller should leave the line's pricebook reference alone (no tier
     * data; nothing safe to map).
     */
    public static Evaluation evaluate(
        ProductTiers tiers,
        Decimal enteredDiscount,
        Boolean isService,
        String profileName
    ) {
        Evaluation ev = new Evaluation();
        ev.status = STATUS_NOT_REQUIRED;
        ev.exceedsAllTiers = false;

        // Step 1 — service item shortcut. Don't touch the pricebook,
        // status is always Not Required.
        if (isService == true) return ev;

        // No tier data at all. Nothing safe to evaluate against — leave
        // the line as-is.
        if (tiers == null || tiers.isEmpty()) return ev;

        Decimal disc = enteredDiscount == null ? 0 : enteredDiscount;
        String ceiling = ceilingTierFor(profileName);
        ev.ceilingTierName = ceiling;

        // Default mapping is Price List 5 (the standard).
        PricebookEntry pl5 = tiers.tier(TIER5);
        if (pl5 != null) {
            ev.mappedPricebookId      = pl5.Pricebook2Id;
            ev.mappedPricebookEntryId = pl5.Id;
            ev.mappedTierName         = TIER5;
            ev.mappedUnitPrice        = pl5.UnitPrice;
        }

        // Step 2 — within ceiling. A zero discount always passes this
        // check (regardless of whether the ceiling tier exists).
        PricebookEntry ceilingPbe = tiers.tier(ceiling);
        Decimal ceilingDiscount = (ceilingPbe == null) ? null : ceilingPbe.Discount__c;
        ev.ceilingTierDiscount = ceilingDiscount;

        if (disc == 0) return ev;
        // Strict less-than: a discount that exactly hits the ceiling tier's
        // Discount__c still escalates. Reps must stay below the cap to skip
        // approval.
        if (ceilingDiscount != null && disc < ceilingDiscount) return ev;

        // Step 3 — escalation ladder. Walk tightest band first; pick
        // the first tier whose Discount__c can cover the entered
        // discount. Skip missing tiers gracefully.
        for (String t : escalationLadderAbove(ceiling)) {
            PricebookEntry tierPbe = tiers.tier(t);
            if (tierPbe == null) continue;
            Decimal tierDisc = tierPbe.Discount__c;
            if (tierDisc == null) continue;
            if (disc < tierDisc) {
                ev.status                 = STATUS_APPROVAL_REQUIRED;
                ev.mappedPricebookId      = tierPbe.Pricebook2Id;
                ev.mappedPricebookEntryId = tierPbe.Id;
                ev.mappedTierName         = t;
                ev.mappedUnitPrice        = tierPbe.UnitPrice;
                ev.mappedTierDiscount     = tierDisc;
                return ev;
            }
        }

        // Step 4 — exceeds every tier in the ladder. Map Price List 1
        // (top of ladder) and flag exceedsAllTiers so callers can warn
        // the rep that the discount is past the broadest allowance.
        PricebookEntry pl1 = tiers.tier(TIER1);
        if (pl1 != null) {
            ev.mappedPricebookId      = pl1.Pricebook2Id;
            ev.mappedPricebookEntryId = pl1.Id;
            ev.mappedTierName         = TIER1;
            ev.mappedUnitPrice        = pl1.UnitPrice;
            ev.mappedTierDiscount     = pl1.Discount__c;
        }
        ev.status = STATUS_APPROVAL_REQUIRED;
        ev.exceedsAllTiers = true;
        return ev;
    }
}