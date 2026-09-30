# rEquityTool 0.1.0

First release.

## Reading EquityTool workbooks

* `et_parse_workbook()` reads a country workbook published at
  <https://equitytool.org> into an `equitytool` object. All three structural
  variants in the published corpus are handled:
  * `national_urban` — national and urban score sets (53 of 69 countries);
  * `rural_urban` — separate rural and urban scales mapped onto a common
    national scale by a published linear equation (14 countries), including
    Burkina Faso's score inversion and Tunisia's negative rescaling slopes;
  * `national_only` — national scores only (Argentina, Uruguay).
* `et_find_workbooks()` scans a download folder and reports what is in it,
  optionally parsing each file to check it works before you rely on it.
* `et_example()` returns a fabricated example workbook, in two variants, so
  examples and tests run without redistributing EquityTool material.
* Accessors: `et_vars()`, `et_questions()`, `et_scores()`, `et_cutoffs()`,
  `et_scopes()`, `et_checks()`, plus `print()`, `summary()` and `format()`
  methods.

## Scoring

* `et_validate()` reports missing and out-of-range response codes *before*
  scoring. Mis-coded answers otherwise fail silently, which is the most common
  way EquityTool results go wrong.
* `et_score()` computes the wealth score and assigns quintiles under four
  scopes:
  * `"national"`, `"urban"`, `"rural"` — the published cut-points;
  * `"sample"` — weighted quantiles of your own sample's score distribution,
    for when relative position within the surveyed population is the quantity
    of interest. Supports `weights` and arbitrary `probs`, so tertiles and
    deciles work too.
* Follows the official missing-data rule: any missing or out-of-range item
  means no score. `na_rule = "partial"` is available for diagnostics.
* Column names are matched automatically, with `vars` for partial overrides.

## Cross-checking the published workbooks

Each workbook states its scoring rules twice — as SPSS/Stata syntax and as a
printed table. The package reads the syntax and compares. Across all 69
published workbooks this surfaced three problems in the official files, none
previously documented:

* **Cambodia DHS 2021** — the *Other software* tab's national block lists the
  `Q8` response options in a different order from the syntax tabs and from its
  own urban block, so the two documented routes give different scores for the
  same household. Reported via `et_checks()$mismatches`.
* **Djibouti EDAM 2017** — the urban quintile block opens with
  `DO IF NationalScore >=1.090269434498.` guarding `COMPUTE UrbanQuintile =5.`;
  the condition names the wrong variable. Cut-points are therefore read from
  the `COMPUTE` assignment rather than the condition. Reported via
  `et_checks()$mislabelled_conditions`.
* **Djibouti EDAM 2017** — the SPSS tab self-identifies as `VietnamMICS2021`.
  The survey label is resolved by majority vote across tabs.

None of these has been confirmed with Metrics for Management.

## Documentation

* `vignette("rEquityTool")` — getting started.
* `vignette("myanmar-worked-example")` — a full analysis with the real Myanmar
  DHS 2015–16 workbook, from opening the spreadsheet to reporting national,
  urban and sample-based quintiles.

## Notes

* The package contains **no EquityTool data**. Country scores are read from the
  workbook you supply.
