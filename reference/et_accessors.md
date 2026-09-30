# Components of an EquityTool object

Accessors for the pieces of an `equitytool` object created by
[`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md).

## Usage

``` r
et_vars(tool)

et_questions(tool)

et_scores(tool)

et_cutoffs(tool)

et_scopes(tool)

et_checks(tool)
```

## Arguments

- tool:

  An `equitytool` object.

## Value

- `et_vars()` a character vector of the question variable names (`"Q1"`,
  ...) in question order.

- `et_questions()` a data frame of question text and response option
  labels.

- `et_scores()` a data frame with columns `var`, `scope`, `option`,
  `score`.

- `et_cutoffs()` a data frame of quintile lower bounds by scope.

- `et_scopes()` the scopes for which this tool can assign published
  quintiles.

- `et_checks()` the result of cross-checking the syntax tab against the
  *Other software* tab, including any mismatching scores.

## Examples

``` r
tool <- et_parse_workbook(et_example())
et_vars(tool)
#> [1] "Q1" "Q2" "Q3" "Q4" "Q5" "Q6" "Q7" "Q8"
head(et_questions(tool))
#>   var                                 question option label
#> 1  Q1 Does your household have... electricity?      1   Yes
#> 2  Q1 Does your household have... electricity?      2    No
#> 3  Q2                      ... a refrigerator?      1   Yes
#> 4  Q2                      ... a refrigerator?      2    No
#> 5  Q3                        ... a television?      1   Yes
#> 6  Q3                        ... a television?      2    No
et_scopes(tool)
#> [1] "national" "urban"   
et_checks(tool)$mismatches
#> [1] var       scope     option    syntax    other_tab
#> <0 rows> (or 0-length row.names)
```
