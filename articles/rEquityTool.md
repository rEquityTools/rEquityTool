# Wealth scores and quintiles with rEquityTool

``` r

library(rEquityTool)
```

## What this package does

The [EquityTool](https://equitytool.org) is a short asset questionnaire
that places a household in a wealth quintile. It is built by simplifying
the full Demographic and Health Survey (DHS) or Multiple Indicator
Cluster Survey (MICS) wealth index down to the fewest questions that
still reproduce it, validated to a kappa of at least 0.75.

Metrics for Management publish, for each country, an Excel workbook
containing the questionnaire, a score for every response option, and the
quintile cut-points. Applying them is arithmetic: look up a score for
each answer, add them up, compare the total with four thresholds.

Doing that by hand is where it goes wrong. `rEquityTool` reads the
workbook, checks your data, and does the arithmetic.

## A worked example

The package ships a **fabricated** workbook so that everything here runs
without redistributing EquityTool material. Every number in it is made
up.

``` r

et_example()
#> [1] "/home/runner/work/_temp/Library/rEquityTool/extdata/equitytool_example_workbook.xlsx"
```

For real work, download your country’s workbook from
<https://equitytool.org/countries/> and pass the path to
[`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md).

``` r

tool <- et_parse_workbook(et_example())
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

The questionnaire, with the response option each code refers to:

``` r

head(et_questions(tool), 6)
#>   var                                 question option label
#> 1  Q1 Does your household have... electricity?      1   Yes
#> 2  Q1 Does your household have... electricity?      2    No
#> 3  Q2                      ... a refrigerator?      1   Yes
#> 4  Q2                      ... a refrigerator?      2    No
#> 5  Q3                        ... a television?      1   Yes
#> 6  Q3                        ... a television?      2    No
```

and the scores behind it:

``` r

head(et_scores(tool), 6)
#>   var    scope option       score
#> 1  Q1 national      1 -0.07668097
#> 2  Q1 national      2 -0.27370511
#> 3  Q2 national      1  0.12581041
#> 4  Q2 national      2  0.09461424
#> 5  Q3 national      1 -0.11996710
#> 6  Q3 national      2 -0.15008657
et_cutoffs(tool)
#>      scope quintile       lower
#> 1 national        5  0.21749465
#> 2 national        4  0.05101651
#> 3 national        3 -0.08476243
#> 4 national        2 -0.22374402
#> 5    urban        5 -0.11265000
#> 6    urban        4 -0.19017797
#> 7    urban        3 -0.32798657
#> 8    urban        2 -0.46984075
```

## Check your data before you score

The most common error is a mis-coded response option, and it fails
*silently*: an unrecognised code becomes `NA`, the household drops out,
and the quintiles that remain still look perfectly reasonable. Check
first.

``` r

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

`demo_survey` is deliberately imperfect: twelve households never
answered `Q3`, seven have `Q5` coded `9` for “don’t know”, and four have
`Q7` coded `0`. Those are the two failure modes to look for — genuinely
missing answers, and codes that are not in the tool’s list.

If your columns are not named `Q1`, `Q2`, …, map them. A partial mapping
is fine: name only the ones that differ.

``` r

survey2 <- demo_survey
names(survey2)[names(survey2) == "Q1"] <- "has_electricity"

head(et_score(survey2, tool, scope = "national",
              vars = c(Q1 = "has_electricity")), 3)
#>         score quintile
#> 1          NA     <NA>
#> 2 0.086639298   Richer
#> 3 0.005306461   Middle
```

## Choosing a scope

`scope` decides **what the quintiles are relative to**. This is a
substantive choice, not a technical one, and it should be stated in your
methods section.

### National quintiles

`scope = "national"` uses the published cut-points. Quintile 1 is the
poorest fifth *of the country* at the time of the source survey.

``` r

nat <- et_score(demo_survey, tool, scope = "national")
table(nat$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>      90     122     176     135      54      23
```

The groups are **not** equal in size, and they are not supposed to be.
If you survey a poor district, most of your households land in the
bottom quintiles. That is the finding. A published survey of
conflict-affected townships in southeast Myanmar, for instance, found
59% of households in the poorest national quintile.

### Urban quintiles

`scope = "urban"` compares urban respondents with the national *urban*
population, which is the right reference for a city survey.

``` r

table(et_score(demo_survey, tool, scope = "urban")$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>     215     175     137      37      13      23
```

### Sample quintiles

Sometimes the question is not “how poor are these households compared
with the country” but “who is worst off *among the people we surveyed*”.
For that, cut on your own sample’s score distribution.

``` r

smp <- et_score(demo_survey, tool, scope = "sample", weights = "wt")
table(smp$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>     116     112     112     116     121      23
```

Now the groups are approximately equal by construction. Pass `weights`
so the cut-points reflect the population your sample represents rather
than the achieved sample.

The scores are identical across scopes — only the cut-points change:

``` r

all.equal(nat$score, smp$score)
#> [1] TRUE
attr(smp, "cutoffs")
#> [1] -0.18470574 -0.06970372  0.01415650  0.11675876
```

**Say which you used.** Sample quintiles are not national quintiles, and
reporting one as the other is a real error: “the poorest quintile in our
sample” and “the poorest national quintile” can be very different groups
of people.

You are not restricted to fifths:

``` r

tertiles <- et_score(demo_survey, tool, scope = "sample", probs = c(1, 2) / 3)
table(tertiles$quintile)
#> 
#>  Lowest  Middle Highest 
#>     191     194     192
```

## Missing data

The official rule is that a household with **any** missing or
out-of-range answer gets no score at all. `rEquityTool` follows it:

``` r

sum(is.na(nat$score))
#> [1] 23
```

`na_rule = "partial"` will instead sum whatever is available. This is
**not** the official method — a household answering six of eight
questions gets a score that is not comparable with one answering all
eight. Use it for diagnostics only.

``` r

sum(is.na(et_score(demo_survey, tool, na_rule = "partial")$score))
#> [1] 0
```

## Rural/urban tools

Fourteen of the published country tools do not have a single national
score set. Instead they score urban and rural respondents on *separate*
scales and map both onto a common national scale with a published linear
equation. For those tools you must say who lives where.

``` r

ru <- et_parse_workbook(et_example("rural_urban"))
ru
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

``` r

res <- et_score(demo_survey, ru, scope = "national", area = "residence")
head(res, 3)
#>        score quintile area_score
#> 1         NA     <NA>         NA
#> 2 -0.2662853   Middle  0.2050551
#> 3  0.8113179   Richer -0.4082463
```

`area` accepts the EquityTool’s own coding (`1` urban, `2` rural), the
words `"urban"`/`"rural"`, or a bare vector. `area_score` holds the
pre-rescaling score. Forgetting `area` is an error rather than a
silently wrong answer:

``` r

et_score(demo_survey, ru, scope = "national")
#> Error:
#> ! This is a rural/urban tool: urban and rural respondents are scored on different scales. Supply `area`, e.g. area = "residence" or area = c("urban", "rural", ...).
```

## Putting it to work

Attach the results to your data with `append = TRUE` and go:

``` r

scored <- et_score(demo_survey, tool, scope = "national", append = TRUE)

round(100 * prop.table(table(scored$region, scored$quintile), 1), 1)
#>          
#>           Poorest Poorer Middle Richer Richest
#>   North      16.5   18.1   30.8   23.6    11.0
#>   Central    17.6   22.8   25.7   26.5     7.4
#>   South      10.1   23.9   39.1   21.7     5.1
#>   East       18.2   20.7   25.6   21.5    14.0
```

``` r

# coverage of an outcome across wealth groups -- the input to an equiplot
# or a concentration index
aggregate(improved_water ~ quintile, data = scored, FUN = mean)
#>   quintile improved_water
#> 1  Poorest      0.4000000
#> 2   Poorer      0.4918033
#> 3   Middle      0.5227273
#> 4   Richer      0.4074074
#> 5  Richest      0.3333333
```

## Two defects in the published workbooks

The package reads each workbook’s scoring rules from the SPSS syntax tab
and then cross-checks them against the score table printed on the *Other
software* tab. Across the 69 country workbooks published as of September
2026, two disagree.

**Cambodia (DHS 2021).** The national block of the *Other software* tab
lists the `Q8` response options in a different order from the syntax
tabs and from its own urban block. The two documented routes give
different scores for the same household. `rEquityTool` uses the syntax
and records the conflict:

``` r

tool <- et_parse_workbook("Cambodia-DHS-2021-public-file-2023-11-14.xlsx")
#> Warning: 2 score(s) differ between the 'SPSS Syntax' tab and the
#> 'Other software' tab. The syntax tab has been used.
et_checks(tool)$mismatches
```

**Djibouti (EDAM 2017).** The urban quintile block opens with
`DO IF NationalScore >=1.090269434498.` followed by
`COMPUTE UrbanQuintile =5.` — the condition names the wrong variable.
Running that syntax verbatim assigns the top urban quintile on the basis
of the national score. The workbook’s own table confirms 1.0903 is the
urban boundary. Because `rEquityTool` reads the `COMPUTE` assignment
rather than the condition, it gets this right, and flags it.

Always look at the cross-check before trusting a run:

``` r

et_checks(tool)$mismatches
#> [1] var       scope     option    syntax    other_tab
#> <0 rows> (or 0-length row.names)
et_checks(tool)$cutoff_mismatches
#> [1] scope     quintile  syntax    other_tab
#> <0 rows> (or 0-length row.names)
```

## Caveats worth carrying into your write-up

- The EquityTool is a **simplified** index. Agreement with the full
  DHS/MICS wealth index is around kappa 0.75–0.85, so individual
  households can be misclassified by one quintile. It is designed for
  describing groups, not for adjudicating a single household’s status.
- Cut-points are anchored to the **national distribution at the time of
  the source survey**. The Myanmar tool, for example, is built on DHS
  2015–16. The further your fieldwork is from that date, the more the
  “national quintile” label is a comparison with a historical benchmark.
- Urban and rural indices measure position **within** those populations.
  An urban quintile 1 household is not necessarily poorer than a rural
  quintile 5 household.
- These are **relative** measures of wealth, not absolute measures of
  poverty.

## Where the wealth index goes next

The score and quintile from this package are the ranking variable for
the usual equity analyses:

- concentration indices and decomposition — see the
  [`rineq`](https://cran.r-project.org/package=rineq) package;
- equiplots and the slope index of inequality — see
  [`ICEHmeasures`](https://cran.r-project.org/package=ICEHmeasures).

Use `score` rather than `quintile` when you need a continuous ranking
variable, and remember to carry your survey design through into those
analyses.
