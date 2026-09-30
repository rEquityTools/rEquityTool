# Score survey data and assign wealth quintiles

Applies an EquityTool to a data frame of respondent answers, returning
the wealth score and the wealth quintile for each row.

## Usage

``` r
et_score(
  data,
  tool,
  scope = c("national", "urban", "rural", "sample"),
  vars = NULL,
  area = NULL,
  weights = NULL,
  probs = c(0.2, 0.4, 0.6, 0.8),
  na_rule = c("complete", "partial"),
  append = FALSE
)
```

## Arguments

- data:

  A data frame of respondent answers, one row per household.

- tool:

  An `equitytool` object from
  [`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md).

- scope:

  One of `"national"`, `"urban"`, `"rural"` or `"sample"`. See Details.

- vars:

  Optional named character vector mapping question names to columns in
  `data`, e.g. `c(Q1 = "tv", Q2 = "mobile")`.

- area:

  For `variant == "rural_urban"` tools, a vector marking each row as
  urban or rural. Either a column name in `data` or a vector as long as
  `nrow(data)`. Values are matched leniently: `1`/`"urban"`/`"u"` mean
  urban and `2`/`"rural"`/`"r"` mean rural (case-insensitive).

- weights:

  Optional survey weights, used only when `scope = "sample"`. Either a
  column name in `data` or a numeric vector.

- probs:

  Cut-point probabilities for `scope = "sample"`. Defaults to quintiles,
  `c(0.2, 0.4, 0.6, 0.8)`. Use e.g. `c(1, 2)/3` for tertiles.

- na_rule:

  `"complete"` (default, the official rule) or `"partial"`.

- append:

  If `TRUE`, return `data` with the new columns added. If `FALSE`
  (default), return just the results.

## Value

A data frame with one row per row of `data` and columns `score` and
`quintile` (an ordered factor). For `rural_urban` tools an `area_score`
column holds the pre-rescaling score. If `append = TRUE`, these columns
are added to `data`.

## Choosing a scope

`scope` decides **what the quintiles are relative to**, which is a
substantive choice, not a technical one.

- `"national"`:

  Published national cut-points. Quintile 1 is the poorest fifth *of the
  country* at the time of the source survey. In a targeted or
  non-representative sample the quintiles will not be evenly filled –
  that is the intended behaviour and usually the finding.

- `"urban"`:

  Published urban cut-points, for surveys of urban residents. Position
  is relative to the national *urban* population.

- `"rural"`:

  Rural cut-points, where the tool publishes them. Most tools do not;
  see the note below.

- `"sample"`:

  Cut-points computed from your own sample's weighted score
  distribution. Quintile 1 is the poorest fifth *of your respondents*,
  so the groups are approximately equal in size by construction. Use
  this when relative position within the surveyed population is what you
  want to report, and say so explicitly – these are not national
  quintiles.

Use
[`et_scopes()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
to see which published scopes a given tool supports. In the currently
published corpus the 14 "rural + urban" tools provide national and urban
cut-points but no rural ones: the rural score is an intermediate
quantity that is rescaled onto the national scale. For those tools use
`scope = "national"` with `area`, or `scope = "sample"`.

## Rural/urban tools

For tools with `variant == "rural_urban"`, urban and rural respondents
are scored on different scales and then mapped onto a common national
scale by a published linear equation. Scoring therefore requires `area`,
a vector identifying each respondent as urban or rural.

## Missing data

The EquityTool rule is that a respondent with **any** missing or
out-of-range answer receives no score. Such rows get `NA` for both
`score` and `quintile`. Set `na_rule = "partial"` to instead sum the
available items – this is **not** the official method, makes scores
non-comparable across respondents, and should only be used for
diagnostics.

## See also

[`et_validate()`](https://requitytools.github.io/rEquityTool/reference/et_validate.md)
to check coding first,
[`et_scopes()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
for the available scopes.

## Examples

``` r
tool <- et_parse_workbook(et_example())
data(demo_survey)

# National quintiles, using the tool's published cut-points
nat <- et_score(demo_survey, tool, scope = "national")
table(nat$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>      90     122     176     135      54      23 

# Quintiles relative to this sample instead
smp <- et_score(demo_survey, tool, scope = "sample", weights = "wt")
table(smp$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>     116     112     112     116     121      23 

# Attach the results to the survey data
scored <- et_score(demo_survey, tool, scope = "national", append = TRUE)
names(scored)
#>  [1] "hhid"           "region"         "residence"      "wt"            
#>  [5] "Q1"             "Q2"             "Q3"             "Q4"            
#>  [9] "Q5"             "Q6"             "Q7"             "Q8"            
#> [13] "improved_water" "score"          "quintile"      
```
