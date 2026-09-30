# Check survey data against an EquityTool before scoring

Mis-coded response options are the most common cause of wrong EquityTool
results, and they fail *silently*: an unrecognised code becomes `NA`,
the household is dropped, and the remaining quintiles still look
plausible. This function reports the problems before you score.

## Usage

``` r
et_validate(data, tool, vars = NULL)
```

## Arguments

- data:

  A data frame of respondent answers, one row per household.

- tool:

  An `equitytool` object from
  [`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md).

- vars:

  Optional named character vector mapping the tool's question names to
  columns in `data`, e.g. `c(Q1 = "tv", Q2 = "mobile")`. If `NULL`
  (default) the tool's own names (`Q1`, `Q2`, ...) are looked up in
  `data`.

## Value

An object of class `equitytool_check`, invisibly a list with elements
`missing_columns`, `items` (a per-question summary) and `n_complete`.
Printing it gives a readable report.

## See also

[`et_score()`](https://requitytools.github.io/rEquityTool/reference/et_score.md)

## Examples

``` r
tool <- et_parse_workbook(et_example())
data(demo_survey)
et_validate(demo_survey, tool)
#> <equitytool_check> equitytool_example_workbook
#>   rows in data : 600
#>   all required columns present
#>   questions with missing or out-of-range codes:
#>  var column valid_codes n_na n_invalid invalid_values
#>   Q3     Q3         1,2   12         0               
#>   Q5     Q5         1,2    0         7              9
#>   Q7     Q7       1,2,3    0         4              0
#>   complete records: 577 of 600 (96.2%)
#>   note: EquityTool scores only complete records; the rest get NA.
```
