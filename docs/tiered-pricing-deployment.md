# Tiered Pricing Engine — Deployment Notes

Reference for deploying the three-commit tiered-pricing / approval-workflow rollout.
Commits on branch `claude/fix-pdf-quote-layout-cI8JO`:

- `492fb64` Commit A — schema + `PricebookTierService` + unit tests
- `e4fb315` Commit B — `QuoteLineItemTrigger` + handler + controller rewire + tests
- *this commit* Commit C — LWC updates, Approval Process, workflow field updates, these notes

## Deploy order

Deploy in this sequence to avoid dangling references:

1. **Fields** — `Product2.Service_Item__c`, updated `Pricebook2.Price_Book_Type__c` picklist.
2. **Apex classes + trigger** — `PricebookTierService`, `QuoteLineItemTriggerHandler`, `QuoteLineItemTrigger`, the updated `QuoteBuilderController` and `quoteTriggerHandler`, plus the new and updated test classes.
3. **LWC** — `newQuoteCmp` (JS + HTML).
4. **Approval Process (manual / separate PR)** — the Quote approval process originally included in this branch was dropped because the target org rejected the `Price_Status__c` literal values `Approved` and `Rejected` during deploy (likely due to picklist configuration drift between source and org). Recreate the approval process in the target org via Setup, or author it in a follow-up PR once the picklist drift is resolved. Entry criteria should still be `Quote.Price_Status__c = 'Approval Required'` - the QuoteLineItem trigger maintains that field automatically.

A single `sf project deploy start` picks the right order for the remaining items.

## Data migration — `Pricebook2.Price_Book_Type__c`

The picklist is now restricted to `Price list1`, `Price list2`, `Price list3`, `Price list4`, `Price list5`. Legacy values are gone:

| Legacy value | Suggested new tier | Rationale |
|---|---|---|
| `Customer Specific` | Varies — pick per record | Customer-specific pricing is usually below standard; `Price list3` or `Price list2` is a reasonable default. |
| `Region Specific` | `Price list3` | Typically mid-band. |
| `Promotional Price` | `Price list2` | Promotions sit near the bottom of the discount ladder. |
| `Dealer Price` | `Price list1` | Lowest tier. |

Before deployment, run the following anonymous Apex in the target org to re-map legacy Pricebook2 records (replace the mapping if your business rules differ):

```apex
Map<String, String> migration = new Map<String, String>{
    'Promotional Price' => 'Price list2',
    'Customer Specific' => 'Price list3',
    'Region Specific'   => 'Price list3',
    'Dealer Price'      => 'Price list1'
};
List<Pricebook2> pbs = [SELECT Id, Price_Book_Type__c FROM Pricebook2 WHERE Price_Book_Type__c IN :migration.keySet()];
for (Pricebook2 pb : pbs) {
    pb.Price_Book_Type__c = migration.get(pb.Price_Book_Type__c);
}
update pbs;
```

Run this script **before** deploying the updated `Price_Book_Type__c.field-meta.xml`, otherwise the restricted-picklist validation will reject the new definition.

## Service-item setup

Each Product with `Service_Item__c = 'Yes'` needs a valid `PricebookEntry` on the Quote's pricebook (Salesforce requires `QuoteLineItem.PricebookEntryId` to be non-null and on the parent Quote's Pricebook2). Recommended one-time setup per org:

1. Create a single service `Pricebook2` named `Service Items` (or add entries directly to the Standard pricebook).
2. For every service product, create an entry with `UnitPrice = 0` and `IsActive = true`.
3. The LWC finds these via `searchProductsWithBestPrice`; Sales Price and Tax are user-entered on the line.

Alternative: put service entries on the Standard pricebook at `UnitPrice = 0`. The trigger ignores pricebook identity for service lines — it only checks `Product2.Service_Item__c`.

## Known deviation from the spec

The spec asked for `QuoteLineItem.PricebookEntryId` to be reassigned to the resolved tier's entry. Salesforce enforces that `QLI.PricebookEntry.Pricebook2Id` must equal `Quote.Pricebook2Id`. Since Quotes live on the Standard Pricebook and tier pricebooks are custom, this reassignment is not possible without either moving the Quote to each tier (not supported on a per-line basis) or duplicating tier entries onto the Standard pricebook (defeats the point).

The implementation therefore tracks the resolved tier via the pre-existing `QuoteLineItem.Source_Pricebook_Ref__c` lookup (to `Pricebook2`). All of the spec's semantic goals are met — the resolved-tier pricebook is the approval and audit signal — only the field name differs. The LWC badge reads it, reports expose it, and the approval process gates on the rolled-up `Quote.Price_Status__c` that the trigger maintains.

## Permissions / FLS

The new fields (`Product2.Service_Item__c`) and the existing `Pricebook2.Price_Book_Type__c` / `QuoteLineItem.Price_Status__c` / `QuoteLineItem.Source_Pricebook_Ref__c` need read (and, where applicable, edit) permission on the profiles or permission sets your Quote editors use:

- `Product2.Service_Item__c` — read for quote creators, edit for admin / product managers.
- `Pricebook2.Price_Book_Type__c` — read for Apex & LWC (usually already granted).
- `QuoteLineItem.Price_Status__c`, `Source_Pricebook_Ref__c` — read for all quote roles, edit restricted to approvers.
- `Quote.Price_Status__c` — read all, edit restricted to approvers (the trigger handles auto-rollup with `with sharing`).

Add these to each profile / permission set in a follow-up commit (out of scope for this PR).

## Historical data

Confirmed out of scope — existing `QuoteLineItem` records are not retroactively recalculated. The trigger only fires on insert / update / delete. If an org-wide recalc is needed later, run:

```apex
// Refresh stamping on existing non-approved QLIs
List<QuoteLineItem> all = [SELECT Id FROM QuoteLineItem WHERE Price_Status__c != 'Approved'];
update all; // trigger re-stamps each
```

## Multi-currency

Not in scope. The helper and trigger use `Decimal` math against `UnitPrice`; multi-currency support would require routing all comparisons through `CurrencyIsoCode` and is not implemented.

## Test coverage

- `PricebookTierServiceTest` — 11 methods covering all tier-resolution edge cases, bulk SOQL, and null-safety.
- `QuoteLineItemTriggerHandlerTest` — 11 methods covering service / non-service branches, floor enforcement, missing Price list5, below-floor discounts, Quote rollup, Approved-never-regressed, update re-stamp, and the bypass flag.
- `QuoteBuilderControllerTest` — updated legacy tests to the new tier model; added tier-search default, orphan exclusion, service-item search, and `getProductPricingPreview` tests.

Run `sf apex test run --class-names PricebookTierServiceTest,QuoteLineItemTriggerHandlerTest,QuoteBuilderControllerTest --result-format human --wait 10` post-deploy.

## Rollback

If the rollout goes sideways, revert in reverse order:

1. Deactivate the Approval Process `Quote.Quote_Price_Approval` via Setup (UI or `sf project deploy start` with `<active>false</active>`).
2. Deactivate `QuoteLineItemTrigger` (change `<status>` to `Inactive` in `QuoteLineItemTrigger.trigger-meta.xml`).
3. Revert the `QuoteBuilderController` change by redeploying from the commit before `e4fb315`.
4. The field / picklist / LWC changes are backwards-compatible once the trigger is off — leave them in place.
