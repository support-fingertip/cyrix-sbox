@isTest
private class PricebookTierServiceTest {

    // Builds a product, N custom pricebooks keyed by tier, and one active
    // PricebookEntry per tier at the requested UnitPrice. Skip a tier by
    // leaving its key out of tierPrices.
    private static Id setupProductWithTiers(Map<String, Decimal> tierPrices) {
        Product2 p = new Product2(Name = 'Tier Test ' + String.valueOf(Math.abs(Crypto.getRandomLong())), IsActive = true);
        insert p;

        Id stdPbId = Test.getStandardPricebookId();
        // Standard entry is a Salesforce requirement for any custom PBE.
        insert new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = p.Id,
            UnitPrice = 9999,
            IsActive = true,
            UseStandardPrice = false
        );

        List<Pricebook2> pbs = new List<Pricebook2>();
        for (String tier : tierPrices.keySet()) {
            pbs.add(new Pricebook2(
                Name = tier + ' ' + p.Id,
                IsActive = true,
                Price_Book_Type__c = tier
            ));
        }
        insert pbs;

        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Pricebook2 pb : pbs) {
            entries.add(new PricebookEntry(
                Pricebook2Id = pb.Id,
                Product2Id = p.Id,
                UnitPrice = tierPrices.get(pb.Price_Book_Type__c),
                IsActive = true,
                UseStandardPrice = false
            ));
        }
        insert entries;
        return p.Id;
    }

    @isTest
    static void allFiveTiersPresent_tightestFitChosen() {
        Id pid = setupProductWithTiers(new Map<String, Decimal>{
            'Price list5' => 1000,
            'Price list4' => 800,
            'Price list3' => 600,
            'Price list2' => 400,
            'Price list1' => 200
        });
        PricebookTierService.ProductTierMap tiers = PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);

        // discounted = 1000 * (1 - 0.35) = 650 -> Price list4 (800) fits, Price list3 (600) does not
        PricebookTierService.TierResolution r = PricebookTierService.resolveTier(tiers, 650);
        System.assertEquals('Price list4', r.tierName, 'Tightest fit for 650 should be Price list4');
        System.assertEquals(false, r.underFloor);
        System.assertEquals(800, r.tierListPrice);

        // discounted = 400 -> Price list2 (400) fits exactly
        r = PricebookTierService.resolveTier(tiers, 400);
        System.assertEquals('Price list2', r.tierName);

        // discounted = 399.99 -> Price list1 (200) is below, so Price list2 is still the fit
        r = PricebookTierService.resolveTier(tiers, 399.99);
        System.assertEquals('Price list2', r.tierName);

        // discounted = 200 -> Price list1
        r = PricebookTierService.resolveTier(tiers, 200);
        System.assertEquals('Price list1', r.tierName);
    }

    @isTest
    static void missingMiddleTiers_skipsToNextExisting() {
        // Only 5 and 2 exist.
        Id pid = setupProductWithTiers(new Map<String, Decimal>{
            'Price list5' => 1000,
            'Price list2' => 400
        });
        PricebookTierService.ProductTierMap tiers = PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);

        // discounted = 650 -> Price list5 (1000) is the only tier >= 650
        PricebookTierService.TierResolution r = PricebookTierService.resolveTier(tiers, 650);
        System.assertEquals('Price list5', r.tierName);

        // discounted = 450 -> Price list5 still the tightest >= 450 (400 is below)
        r = PricebookTierService.resolveTier(tiers, 450);
        System.assertEquals('Price list5', r.tierName);

        // discounted = 400 -> Price list2 fits exactly, tightest
        r = PricebookTierService.resolveTier(tiers, 400);
        System.assertEquals('Price list2', r.tierName);
    }

    @isTest
    static void onlyTier5_staysOnTier5() {
        Id pid = setupProductWithTiers(new Map<String, Decimal>{'Price list5' => 1000});
        PricebookTierService.ProductTierMap tiers = PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);

        PricebookTierService.TierResolution r = PricebookTierService.resolveTier(tiers, 1000);
        System.assertEquals('Price list5', r.tierName);
        System.assertEquals(false, r.underFloor);

        // discounted below 1000 but no lower tier exists -> stays on 5, underFloor true
        r = PricebookTierService.resolveTier(tiers, 500);
        System.assertEquals('Price list5', r.tierName);
        System.assertEquals(true, r.underFloor, 'Below-floor when only tier5 exists and discount is applied');
    }

    @isTest
    static void zeroDiscount_staysOnTier5_notRequired() {
        Id pid = setupProductWithTiers(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list4' => 800, 'Price list1' => 200
        });
        PricebookTierService.ProductTierMap tiers = PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);

        // Zero discount - discounted price = list price of tier5
        PricebookTierService.TierResolution r = PricebookTierService.resolveTier(tiers, 1000);
        System.assertEquals('Price list5', r.tierName);

        String status = PricebookTierService.computePriceStatus(1000, 0, 1000, r.underFloor);
        System.assertEquals(PricebookTierService.STATUS_NOT_REQUIRED, status);
    }

    @isTest
    static void discountBelowTier1_assignsTier1_underFloor_approvalRequired() {
        Id pid = setupProductWithTiers(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list2' => 400, 'Price list1' => 200
        });
        PricebookTierService.ProductTierMap tiers = PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);

        // discounted = 100 - below every existing tier
        PricebookTierService.TierResolution r = PricebookTierService.resolveTier(tiers, 100);
        System.assertEquals('Price list1', r.tierName, 'Should land on lowest existing tier');
        System.assertEquals(true, r.underFloor);

        Decimal standard = PricebookTierService.standardPrice(tiers);
        String status = PricebookTierService.computePriceStatus(1000, 90, standard, r.underFloor);
        System.assertEquals(PricebookTierService.STATUS_APPROVAL_REQUIRED, status);
    }

    @isTest
    static void priceAboveStandard_notRequired() {
        Id pid = setupProductWithTiers(new Map<String, Decimal>{'Price list5' => 1000, 'Price list3' => 500});
        PricebookTierService.ProductTierMap tiers = PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);

        // UnitPrice raised above standard, zero discount - should stay on tier5 and be Not Required
        PricebookTierService.TierResolution r = PricebookTierService.resolveTier(tiers, 1200);
        System.assertEquals('Price list5', r.tierName);
        // Above-standard qualifies as Not Required because 1200 >= 1000
        String status = PricebookTierService.computePriceStatus(1200, 0, 1000, r.underFloor);
        System.assertEquals(PricebookTierService.STATUS_NOT_REQUIRED, status);
    }

    @isTest
    static void priceBelowStandard_approvalRequired() {
        Id pid = setupProductWithTiers(new Map<String, Decimal>{
            'Price list5' => 1000, 'Price list3' => 600, 'Price list1' => 200
        });
        PricebookTierService.ProductTierMap tiers = PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);

        // UnitPrice 1000, 25% discount -> 750. 750 < 1000 -> Approval Required.
        Decimal standard = PricebookTierService.standardPrice(tiers);
        String status = PricebookTierService.computePriceStatus(1000, 25, standard, false);
        System.assertEquals(PricebookTierService.STATUS_APPROVAL_REQUIRED, status);
    }

    @isTest
    static void serviceItem_helperReturnsNotRequired() {
        System.assertEquals(
            PricebookTierService.STATUS_NOT_REQUIRED,
            PricebookTierService.priceStatusForService()
        );
    }

    @isTest
    static void defaultEntry_returnsTier5_orNull() {
        Id withTier5 = setupProductWithTiers(new Map<String, Decimal>{'Price list5' => 1000});
        Id withoutTier5 = setupProductWithTiers(new Map<String, Decimal>{'Price list3' => 500});

        Map<Id, PricebookTierService.ProductTierMap> loaded =
            PricebookTierService.loadTiers(new Set<Id>{withTier5, withoutTier5});

        System.assertNotEquals(null, PricebookTierService.defaultEntry(loaded.get(withTier5)));
        System.assertEquals(1000, PricebookTierService.standardPrice(loaded.get(withTier5)));
        System.assertEquals(null, PricebookTierService.defaultEntry(loaded.get(withoutTier5)),
            'Product without Price list5 must have null default entry');
        System.assertEquals(null, PricebookTierService.standardPrice(loaded.get(withoutTier5)));
    }

    @isTest
    static void loadTiers_bulk_singleQuery() {
        Set<Id> pids = new Set<Id>();
        for (Integer i = 0; i < 5; i++) {
            pids.add(setupProductWithTiers(new Map<String, Decimal>{
                'Price list5' => 1000, 'Price list4' => 800, 'Price list1' => 200
            }));
        }
        Test.startTest();
        Map<Id, PricebookTierService.ProductTierMap> loaded = PricebookTierService.loadTiers(pids);
        Test.stopTest();

        System.assertEquals(5, loaded.size());
        for (Id pid : pids) {
            System.assertEquals(3, loaded.get(pid).byTier.size(), 'Each product has 3 tier entries');
        }
        // Single SOQL query consumed regardless of product count
        System.assert(Limits.getQueries() <= 2, 'loadTiers should be a single query');
    }

    @isTest
    static void resolveTier_nullInputs_safe() {
        PricebookTierService.TierResolution r = PricebookTierService.resolveTier(null, 500);
        System.assertEquals(null, r.entry);
        System.assertEquals(null, r.tierName);

        PricebookTierService.ProductTierMap empty = new PricebookTierService.ProductTierMap();
        r = PricebookTierService.resolveTier(empty, 500);
        System.assertEquals(null, r.entry);
    }
}
