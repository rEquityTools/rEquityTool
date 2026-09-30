# Paths to the bundled example workbooks

Small, deliberately **fabricated** EquityTool-format workbooks shipped
with the package so that examples, tests and the vignette run without
redistributing any material from <https://equitytool.org>.

## Usage

``` r
et_example(variant = c("national_urban", "rural_urban"))
```

## Arguments

- variant:

  Which example workbook to return.

## Value

A file path.

## Details

The files mimic the layout of real country workbooks – a `Questionnaire`
tab, an `SPSS Syntax` tab and an `Other software` tab – but every number
in them is made up. They must never be used to produce real wealth
estimates. For that, download the workbook for your country from
<https://equitytool.org/countries/> and pass it to
[`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md).

Two variants are provided, matching two of the three structural variants
found in the real corpus:

- `"national_urban"` (default) – national and urban score sets.

- `"rural_urban"` – separate rural and urban score sets rescaled onto a
  common national scale, which is what the 14 rural/urban country tools
  do.

## Examples

``` r
et_example()
#> [1] "/home/runner/work/_temp/Library/rEquityTool/extdata/equitytool_example_workbook.xlsx"
et_parse_workbook(et_example())
#> <equitytool>
#>   Country      : equitytool_example_workbook
#>   Survey       : ExampleCountryDHS2020
#>   Source file  : equitytool_example_workbook.xlsx
#>   Variant      : national_urban
#>   Questions    : 8 (1-8)
#>   Score scopes : national, urban
#>   Quintiles for: national, urban
#>   Cross-check  : 38 score(s) compared with the 'Other software' tab, 0 mismatch(es)

# the rural/urban variant needs an area indicator when scoring
et_parse_workbook(et_example("rural_urban"))
#> <equitytool>
#>   Country      : equitytool_example_rural_urban
#>   Survey       : NA
#>   Source file  : equitytool_example_rural_urban.xlsx
#>   Variant      : rural_urban
#>   Questions    : 8 (1-8)
#>   Score scopes : rural, urban
#>   Quintiles for: national, urban
#>   Rescaling    : national score = intercept + slope * area score
#>                  urban  +1.18421 +0.9134 * score
#>                  rural  -0.40261 +0.66482 * score
#>   Cross-check  : 38 score(s) compared with the 'Other software' tab, 0 mismatch(es)
```
