# Read an EquityTool country workbook

Parses one of the Excel workbooks published for each country at
<https://equitytool.org> ("public file" / "other platforms file") into
an `equitytool` object that
[`et_score()`](https://requitytools.github.io/rEquityTool/reference/et_score.md)
can apply to survey data.

## Usage

``` r
et_parse_workbook(path, country = NULL, survey = NULL, verbose = TRUE)
```

## Arguments

- path:

  Path to an EquityTool country workbook (`.xls` or `.xlsx`).

- country, survey:

  Optional labels. If not supplied they are guessed from the file name
  and the workbook's own comments.

- verbose:

  Warn about cross-check failures between the syntax tab and the *Other
  software* tab. Default `TRUE`.

## Value

An object of class `equitytool`.

## Details

Each workbook states the scoring rules twice: as runnable SPSS and Stata
syntax, and as a printed score table on the *Other software* tab. This
function takes the **syntax** as authoritative, because it maps a
response *code* to a score with no ambiguity, and uses the *Other
software* tab only for option labels and as an independent cross-check.

When the two disagree the difference is recorded in the object (see
[`et_checks()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md))
and, if `verbose = TRUE`, reported as a warning. This is not
hypothetical: in the published Cambodia DHS 2021 workbook the national
block of the *Other software* tab lists the `Q8` response options in a
different order from the syntax tabs, so the two documented routes give
different scores for the same household.

Three structural variants occur in the published corpus and all are
handled:

- `"national_urban"` – separate national and urban score sets (most
  tools).

- `"rural_urban"` – separate rural and urban score sets that are mapped
  onto a common national scale by a linear equation. Scoring on the
  national scale therefore requires an urban/rural indicator; see the
  `area` argument of
  [`et_score()`](https://requitytools.github.io/rEquityTool/reference/et_score.md).

- `"national_only"` – national scores with no urban tool.

## See also

[`et_score()`](https://requitytools.github.io/rEquityTool/reference/et_score.md),
[`et_validate()`](https://requitytools.github.io/rEquityTool/reference/et_validate.md),
[`et_questions()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md),
[`et_checks()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)

## Examples

``` r
# A small fabricated workbook ships with the package so that examples and
# tests run without redistributing EquityTool material.
path <- et_example()
tool <- et_parse_workbook(path)
tool
#> <equitytool>
#>   Country      : equitytool_example_workbook
#>   Survey       : ExampleCountryDHS2020
#>   Source file  : equitytool_example_workbook.xlsx
#>   Variant      : national_urban
#>   Questions    : 8 (1-8)
#>   Score scopes : national, urban
#>   Quintiles for: national, urban
#>   Cross-check  : 38 score(s) compared with the 'Other software' tab, 0 mismatch(es)
```
