# rEquityTool

<!-- badges: start -->
<!-- badges: end -->

Wealth scores and wealth quintiles from
[EquityTool](https://equitytool.org) questionnaires, in R.

The EquityTool is a simple and easy-to-use tool to measure relative wealth.
Using a short asset questionnaire, it lets you compare the wealth of your
respondents with the national or urban population in over 60 countries. It is
built by simplifying the full DHS or MICS wealth index down to the fewest
questions that still reproduce it (validated to kappa ≥ 0.75). Metrics for
Management publish, for each country, an Excel workbook containing the
questionnaire, a score for every response option, and the quintile cut-points.

Applying those scores is arithmetic. Doing it by hand is where it goes wrong.
`rEquityTool` reads the workbook, validates your data, and does the arithmetic.

## Installation

```r
# install.packages("remotes")
remotes::install_github("rEquityTools/rEquityTool")
```

## Usage

Download your country's workbook from <https://equitytool.org/countries/>, then:

```r
library(rEquityTool)

tool <- et_parse_workbook("Myanmar-DHS-2015-16-Other-Platforms-file.xlsx")
tool
#> <equitytool>
#>   Country      : Myanmar
#>   Survey       : MyanmarDHS2015
#>   Variant      : national_urban
#>   Questions    : 15 (1-15)
#>   Score scopes : national, urban
#>   Quintiles for: national, urban
#>   Cross-check  : 62 score(s) compared with the 'Other software' tab, 0 mismatch(es)

# check response coding before you score
et_validate(my_survey, tool)

# score and assign quintiles
et_score(my_survey, tool, scope = "national", append = TRUE)
```

A fabricated example workbook and a synthetic survey ship with the package, so
you can try it without downloading anything:

```r
tool <- et_parse_workbook(et_example())
data(demo_survey)
et_score(demo_survey, tool, scope = "national")
```

See `vignette("rEquityTool")` for the full walkthrough.

## What `scope` means

`scope` decides what the quintiles are *relative to* — a substantive choice
that belongs in your methods section.

| `scope` | Quintile 1 is the poorest fifth of... | Groups equal in size? |
|---|---|---|
| `"national"` | the country, at the time of the source survey | No — and that is the finding |
| `"urban"` | the national urban population | No |
| `"rural"` | the national rural population, where published | No |
| `"sample"` | **your own respondents** (weighted) | Approximately, by construction |

Sample quintiles are not national quintiles. Reporting one as the other is a
real error. A survey of a poor district will legitimately put most households
in the bottom national quintiles: a published survey of conflict-affected
townships in southeast Myanmar found 59% in the poorest national quintile.

## Structural variants

All three variants in the published corpus are handled:

- **national + urban** (53 countries) — the common case.
- **rural + urban** (14 countries) — separate rural and urban scales mapped
  onto a common national scale by a published linear equation. Scoring on the
  national scale requires an urban/rural indicator (`area`).
- **national only** (2 countries: Argentina, Uruguay).

## Cross-checking

Each workbook states its scoring rules twice — as runnable SPSS/Stata syntax,
and as a printed table on the *Other software* tab. `rEquityTool` reads the
syntax and cross-checks it against the table. Across the 69 published
workbooks, two disagree:

- **Cambodia (DHS 2021)** — the national block of the *Other software* tab
  lists the `Q8` response options in a different order from the syntax tabs and
  from its own urban block, so the two documented routes give different scores
  for the same household.
- **Djibouti (EDAM 2017)** — the urban quintile block opens with
  `DO IF NationalScore >=1.090269434498.` guarding `COMPUTE UrbanQuintile =5.`;
  the condition names the wrong variable. The package reads the assignment
  rather than the condition, so it gets this right.

Both are reported by `et_checks()`. Neither has yet been confirmed with
Metrics for Management.

## Caveats

- The EquityTool is a **simplified** index (kappa ≈ 0.75–0.85 against the full
  wealth index). Individual households can be misclassified by one quintile; it
  is designed for describing groups.
- Cut-points are anchored to the national distribution **at the time of the
  source survey**.
- These are **relative** measures of wealth, not absolute measures of poverty.

## Licence and attribution

This package is GPL (≥ 3). It contains **no EquityTool data**: the example
workbook is fabricated, and country scores are read from the workbook you
supply.

The EquityTool itself is a product of
[Metrics for Management](https://equitytool.org). Its published materials carry
a CC BY-NC mark. Cite the tool and the country workbook version you used
alongside this package.

## Related packages

- [`rineq`](https://cran.r-project.org/package=rineq) — concentration indices
  and decomposition.
- [`ICEHmeasures`](https://cran.r-project.org/package=ICEHmeasures) — equiplots,
  slope index of inequality.
