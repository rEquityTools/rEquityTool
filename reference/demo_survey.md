# A small synthetic household survey

Six hundred simulated households, generated to match the fabricated
example workbook returned by
[`et_example()`](https://requitytools.github.io/rEquityTool/reference/et_example.md).
Used in examples, tests and the vignette so that the package can be
demonstrated without redistributing EquityTool material or anyone's real
survey data.

## Usage

``` r
demo_survey
```

## Format

A data frame with 600 rows and 14 columns:

- hhid:

  Household identifier.

- region:

  Factor: `North`, `Central`, `South`, `East`. Regions differ in average
  wealth, so they can be compared.

- residence:

  Factor: `urban` or `rural`.

- wt:

  Survey weight. Correlated with `residence`, so weighting changes the
  answers noticeably.

- Q1:

  Electricity. `1` yes, `2` no.

- Q2:

  Refrigerator. `1` yes, `2` no.

- Q3:

  Television. `1` yes, `2` no. Contains `NA`s.

- Q4:

  Motorcycle or scooter. `1` yes, `2` no.

- Q5:

  Bank account. `1` yes, `2` no. Contains invalid code `9`.

- Q6:

  Floor material. `1` cement, `2` earth or sand, `3` other.

- Q7:

  Cooking fuel. `1` electricity or gas, `2` wood, `3` other. Contains
  invalid code `0`.

- Q8:

  Sleeping rooms. `1` three or more, `2` two, `3` one.

- improved_water:

  Binary outcome (`0`/`1`) for the equity example in the vignette.

## Source

Simulated. See `data-raw/02_make_demo_survey.R` in the package source.
These are not real households and carry no personal data.

## Details

The data are deliberately imperfect: twelve households have a missing
answer to `Q3`, seven have `Q5` coded `9` ("don't know"), and four have
`Q7` coded `0`. These are the two failure modes
[`et_validate()`](https://requitytools.github.io/rEquityTool/reference/et_validate.md)
exists to catch.

## Examples

``` r
data(demo_survey)
str(demo_survey)
#> 'data.frame':    600 obs. of  13 variables:
#>  $ hhid          : chr  "HH0001" "HH0002" "HH0003" "HH0004" ...
#>  $ region        : Factor w/ 4 levels "North","Central",..: 3 3 4 4 1 3 3 2 3 4 ...
#>  $ residence     : Factor w/ 2 levels "urban","rural": 2 2 1 2 2 1 1 1 2 2 ...
#>  $ wt            : num  0.874 1.331 0.867 1.271 1.415 ...
#>  $ Q1            : int  1 1 1 1 2 1 2 2 1 1 ...
#>  $ Q2            : int  2 2 1 2 2 1 2 1 1 2 ...
#>  $ Q3            : int  NA 2 2 2 2 1 2 1 1 1 ...
#>  $ Q4            : int  2 1 1 2 2 2 1 2 2 2 ...
#>  $ Q5            : int  2 2 2 2 2 1 2 2 1 1 ...
#>  $ Q6            : int  2 2 2 2 1 2 3 2 2 2 ...
#>  $ Q7            : int  1 2 2 3 3 1 1 2 1 2 ...
#>  $ Q8            : int  1 2 1 1 2 1 1 1 1 2 ...
#>  $ improved_water: int  0 1 0 0 0 1 1 1 1 1 ...
table(demo_survey$region, demo_survey$residence)
#>          
#>           urban rural
#>   North      69   119
#>   Central    44    99
#>   South      52    94
#>   East       38    85
```
