/**
 * Coverage for the discount-vs-Discount__c evaluator in
 * PricebookTierService — the single source of truth for Price_Status
 * and Source_Pricebook_Ref mapping on QuoteLineItem / OrderItem.
 *
 * Each test sets up tier pricebooks (PL1..PL5) via the helper, drives
 * one Evaluation, and asserts (status, mappedTier, exceedsAllTiers).
 */
@isTest
private class PricebookTierServiceTest {

    private class TierSpec {
        Decimal unitPrice;
        Decimal discount;
        TierSpec(Decimal up, Decimal d) { this.unitPrice = up; this.discount = d; }
    }

    /**
     * Creates a product, a Standard PBE (required by the platform), and
     * one custom-pricebook PricebookEntry per tier in `specs`. The tier
     * key is one of PricebookTierService.TIER1..TIER5 and the value
     * pairs UnitPrice with Discount__c (the per-tier max discount).
     */
    private static Id setupProductWithTiers(Map<String, TierSpec> specs) {
        Product2 p = new Product2(
            Name = 'Tier Test ' + String.valueOf(Math.abs(Crypto.getRandomLong())),
            IsActive = true
        );
        insert p;

        Id stdPbId = Test.getStandardPricebookId();
        insert new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = p.Id,
            UnitPrice = 9999,
            IsActive = true,
            UseStandardPrice = false
        );

        List<Pricebook2> pbs = new List<Pricebook2>();
        for (String tier : specs.keySet()) {
            pbs.add(new Pricebook2(
                Name = tier + ' ' + p.Id,
                IsActive = true,
                Price_Book_Type__c = tier
            ));
        }
        insert pbs;

        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Pricebook2 pb : pbs) {
            TierSpec s = specs.get(pb.Price_Book_Type__c);
            entries.add(new PricebookEntry(
                Pricebook2Id = pb.Id,
                Product2Id = p.Id,
                UnitPrice = s.unitPrice,
                Discount__c = s.discount,
                IsActive = true,
                UseStandardPrice = false
            ));
        }
        insert entries;
        return p.Id;
    }

    private static PricebookTierService.ProductTiers loadTiersFor(Id pid) {
        return PricebookTierService.loadTiers(new Set<Id>{pid}).get(pid);
    }

    // ==================== ceilingTierFor / escalationLadderAbove ====================

    @isTest
    static void ceilingTierFor_mapsKnownProfilesToBands() {
        System.assertEquals(PricebookTierService.TIER4,
            PricebookTierService.ceilingTierFor('Sales Engineer'));
        System.assertEquals(PricebookTierService.TIER3,
            PricebookTierService.ceilingTierFor('ASM'));
        System.assertEquals(PricebookTierService.TIER2,
            PricebookTierService.ceilingTierFor('TSM'));
        System.assertEquals(PricebookTierService.TIER2,
            PricebookTierService.ceilingTierFor('VP'));
        System.assertEquals(PricebookTierService.TIER2,
            PricebookTierService.ceilingTierFor('Vice President - Sales'));
        System.assertEquals(PricebookTierService.TIER1,
            PricebookTierService.ceilingTierFor('CEO'));
        System.assertEquals(PricebookTierService.TIER1,
            PricebookTierService.ceilingTierFor('CFO'));
        System.assertEquals(PricebookTierService.TIER5,
            PricebookTierService.ceilingTierFor('Receptionist'),
            'Unknown profile defaults to PL5 (no implicit allowance)');
    }

    @isTest
    static void escalationLadder_walksAboveCeiling() {
        // PL4 ceiling -> PL3, PL2, PL1 (tightest first)
        System.assertEquals(
            new List<String>{
                PricebookTierService.TIER3,
                PricebookTierService.TIER2,
                PricebookTierService.TIER1
            },
            PricebookTierService.escalationLadderAbove(PricebookTierService.TIER4)
        );
        // PL2 ceiling -> PL1
        System.assertEquals(
            new List<String>{ PricebookTierService.TIER1 },
            PricebookTierService.escalationLadderAbove(PricebookTierService.TIER2)
        );
        // PL1 ceiling -> empty
        System.assertEquals(0,
            PricebookTierService.escalationLadderAbove(PricebookTierService.TIER1).size(),
            'CEO/CFO has no escalation ladder');
    }

    // ==================== evaluate — Step 1 (service item) ====================

    @isTest
    static void evaluate_serviceItem_alwaysNotRequired_noRemap() {
        // Even a chunky discount on a service item stays Not Required and
        // doesn't remap the pricebook.
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER4 => new TierSpec(900,  10),
            PricebookTierService.TIER1 => new TierSpec(700,  30)
        });
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 50, true, 'Sales Engineer'
        );
        System.assertEquals('Not Required', ev.status);
        System.assertEquals(null, ev.mappedPricebookId,
            'Service items keep their existing pricebook reference');
        System.assertEquals(false, ev.exceedsAllTiers);
    }

    // ==================== evaluate — Step 2 (within ceiling) ====================

    @isTest
    static void evaluate_salesEngineer_withinCeiling_mapsPL5() {
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER4 => new TierSpec(900,  10),
            PricebookTierService.TIER3 => new TierSpec(800,  15),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        // 8% under PL4 ceiling 10%
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 8, false, 'Sales Engineer'
        );
        System.assertEquals('Not Required', ev.status);
        System.assertEquals(PricebookTierService.TIER5, ev.mappedTierName,
            'Within-ceiling discounts stay mapped to PL5');
        System.assertEquals(1000, ev.mappedUnitPrice);
        System.assertEquals(false, ev.exceedsAllTiers);
    }

    @isTest
    static void evaluate_zeroDiscount_passesEvenWithMissingCeiling() {
        // No PL4 entry; ceiling lookup returns null Discount__c.
        // A zero discount must still pass (Not Required, mapped to PL5).
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 0, false, 'Sales Engineer'
        );
        System.assertEquals('Not Required', ev.status);
        System.assertEquals(PricebookTierService.TIER5, ev.mappedTierName);
    }

    // ==================== evaluate — Step 3 (escalation) ====================

    @isTest
    static void evaluate_salesEngineer_oneStepEscalation_mapsPL3() {
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER4 => new TierSpec(900,  10),
            PricebookTierService.TIER3 => new TierSpec(800,  15),
            PricebookTierService.TIER2 => new TierSpec(700,  20),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        // 12% > PL4(10%); ladder PL3(15%) covers it.
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 12, false, 'Sales Engineer'
        );
        System.assertEquals('Approval Required', ev.status);
        System.assertEquals(PricebookTierService.TIER3, ev.mappedTierName);
        // Service exposes the mapped tier's UnitPrice for callers that
        // want it (e.g. UI display); the trigger intentionally does not
        // apply it on save, so the line keeps its PL5-listed Sales Price.
        System.assertEquals(800, ev.mappedUnitPrice);
        System.assertEquals(false, ev.exceedsAllTiers);
    }

    @isTest
    static void evaluate_salesEngineer_multiStepEscalation_mapsPL2() {
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER4 => new TierSpec(900,  10),
            PricebookTierService.TIER3 => new TierSpec(800,  15),
            PricebookTierService.TIER2 => new TierSpec(700,  20),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        // 18% > PL4(10%) > PL3(15%); PL2(20%) covers.
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 18, false, 'Sales Engineer'
        );
        System.assertEquals('Approval Required', ev.status);
        System.assertEquals(PricebookTierService.TIER2, ev.mappedTierName);
        System.assertEquals(700, ev.mappedUnitPrice);
    }

    @isTest
    static void evaluate_skipsMissingTier_continuesUpLadder() {
        // PL3 absent — ladder must skip past it and land on PL2.
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER4 => new TierSpec(900,  10),
            PricebookTierService.TIER2 => new TierSpec(700,  20),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 18, false, 'Sales Engineer'
        );
        System.assertEquals('Approval Required', ev.status);
        System.assertEquals(PricebookTierService.TIER2, ev.mappedTierName,
            'Missing PL3 should cause the ladder to step over it onto PL2');
    }

    @isTest
    static void evaluate_tsm_escalatesToPL1() {
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER2 => new TierSpec(700,  20),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        // TSM ceiling = PL2 (20%). 25% > 20%. Ladder = PL1 (30%) -> covers.
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 25, false, 'TSM'
        );
        System.assertEquals('Approval Required', ev.status);
        System.assertEquals(PricebookTierService.TIER1, ev.mappedTierName);
    }

    // ==================== evaluate — Step 4 (exceeds ladder) ====================

    @isTest
    static void evaluate_ceo_exceedsAllTiers_flagsWarning() {
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        // CEO ceiling = PL1 (30%). 35% > 30% — there's no ladder above PL1.
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 35, false, 'CEO'
        );
        System.assertEquals('Approval Required', ev.status);
        System.assertEquals(PricebookTierService.TIER1, ev.mappedTierName,
            'Falls back to PL1 when the discount overruns even the broadest band');
        System.assertEquals(true, ev.exceedsAllTiers);
        System.assertEquals(600, ev.mappedUnitPrice);
    }

    @isTest
    static void evaluate_salesEngineer_overrunsEntireLadder_flagsWarning() {
        Id pid = setupProductWithTiers(new Map<String, TierSpec>{
            PricebookTierService.TIER5 => new TierSpec(1000, 0),
            PricebookTierService.TIER4 => new TierSpec(900,  10),
            PricebookTierService.TIER3 => new TierSpec(800,  15),
            PricebookTierService.TIER2 => new TierSpec(700,  20),
            PricebookTierService.TIER1 => new TierSpec(600,  30)
        });
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            loadTiersFor(pid), 50, false, 'Sales Engineer'
        );
        System.assertEquals('Approval Required', ev.status);
        System.assertEquals(PricebookTierService.TIER1, ev.mappedTierName);
        System.assertEquals(true, ev.exceedsAllTiers);
    }

    // ==================== evaluate — defensive paths ====================

    @isTest
    static void evaluate_noTierData_leavesLineAsIs() {
        // Nothing in tier maps -> evaluator returns Not Required without
        // mapping anything, so callers don't accidentally clear the line.
        PricebookTierService.Evaluation ev = PricebookTierService.evaluate(
            null, 50, false, 'Sales Engineer'
        );
        System.assertEquals('Not Required', ev.status);
        System.assertEquals(null, ev.mappedPricebookId);
        System.assertEquals(false, ev.exceedsAllTiers);
    }

    // ==================== loadTiers — bulkification ====================

    @isTest
    static void loadTiers_bulk_singleQuery() {
        Set<Id> pids = new Set<Id>();
        for (Integer i = 0; i < 5; i++) {
            pids.add(setupProductWithTiers(new Map<String, TierSpec>{
                PricebookTierService.TIER5 => new TierSpec(1000, 0),
                PricebookTierService.TIER4 => new TierSpec(900,  10),
                PricebookTierService.TIER1 => new TierSpec(600,  30)
            }));
        }

        Test.startTest();
        Map<Id, PricebookTierService.ProductTiers> loaded = PricebookTierService.loadTiers(pids);
        Test.stopTest();

        System.assertEquals(5, loaded.size());
        for (Id pid : pids) {
            System.assertEquals(3, loaded.get(pid).byTier.size(),
                'Each product carries exactly the 3 tier entries we set up');
        }
        System.assert(Limits.getQueries() <= 2,
            'loadTiers should issue a single SOQL query regardless of product count');
    }

    @isTest
    static void runningUserProfileName_returnsTheRunningProfile() {
        // We can't pick the test profile, but we can assert the cache is
        // populated and is non-null after the first call.
        String name = PricebookTierService.runningUserProfileName();
        System.assertNotEquals(null, name);
        // Second call must hit the cache (no extra SOQL).
        Integer beforeQ = Limits.getQueries();
        String again = PricebookTierService.runningUserProfileName();
        System.assertEquals(name, again);
        System.assertEquals(beforeQ, Limits.getQueries(),
            'Subsequent calls must be served from the per-transaction cache');
    }
}
