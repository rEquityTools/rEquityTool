# Working with different country workbooks

``` r

library(rEquityTool)
```

The 69 country workbooks published at
<https://equitytool.org/countries/> are not all the same shape. This
article covers the structural variants, how to find your way around a
folder of downloads, and how to check a workbook before you trust it.

## Finding what you have

If you have downloaded several countries,
[`et_find_workbooks()`](https://requitytools.github.io/rEquityTool/reference/et_find_workbooks.md)
inventories a folder. With `inspect = TRUE` it opens each file and
reports what is in it:

``` r

dir <- dirname(et_example())
et_find_workbooks(dir, inspect = TRUE)[, c("country", "variant", "n_questions",
                                           "scopes", "issues")]
#>                          country        variant n_questions         scopes issues
#> 1 equitytool_example_rural_urban    rural_urban           8 national/urban       
#> 2    equitytool_example_workbook national_urban           8 national/urban
```

`issues` is the column to read. An empty string means the workbook is
internally consistent; anything else needs attention before you use it.

## The three structural variants

[`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md)
reports which variant a tool uses, and
[`et_score()`](https://requitytools.github.io/rEquityTool/reference/et_score.md)
adapts.

| Variant | Countries | What it means |
|----|----|----|
| `national_urban` | 53 | Separate national and urban indices. The common case |
| `rural_urban` | 14 | Separate **rural** and **urban** indices, rescaled onto a national scale |
| `national_only` | 2 | National index only (Argentina, Uruguay) |

### `national_urban` — the common case

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

Nothing special is required. Pick a scope and score:

``` r

data(demo_survey)
table(et_score(demo_survey, tool, scope = "national")$quintile)
#> 
#> Poorest  Poorer  Middle  Richer Richest 
#>      90     122     176     135      54
```

### `rural_urban` — needs an area indicator

Fourteen tools (Afghanistan, Armenia, Burkina Faso, Chad, Djibouti,
Egypt, Ethiopia, Laos, Niger, Tajikistan, Thailand, Tunisia, Vietnam,
Zimbabwe) score urban and rural respondents on **different scales**,
then map both onto a common national scale with a published linear
equation:

    RuralScore    = sum of the rural item scores
    UrbanScore    = sum of the urban item scores   (negated in Burkina Faso)
    NationalScore = a_urban + b_urban x UrbanScore    if the household is urban
    NationalScore = a_rural + b_rural x RuralScore    if the household is rural

The package reads those coefficients out of the workbook and reports
them:

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

Because the two scales are different, scoring on the national scale is
impossible without knowing who lives where. Omitting `area` is an error
rather than a wrong answer:

``` r

et_score(demo_survey, ru, scope = "national")
#> Error:
#> ! This is a rural/urban tool: urban and rural respondents are scored on different scales. Supply `area`, e.g. area = "residence" or area = c("urban", "rural", ...).
```

``` r

res <- et_score(demo_survey, ru, scope = "national", area = "residence")
head(res, 4)
#>        score quintile  area_score
#> 1         NA     <NA>          NA
#> 2 -0.2662853   Middle  0.20505508
#> 3  0.8113179   Richer -0.40824627
#> 4 -0.3401521   Middle  0.09394715
```

`area_score` is the pre-rescaling value on the household’s own scale;
`score` is after rescaling onto the national scale.

`area` is matched leniently — the EquityTool’s own coding (`1` urban,
`2` rural), the words, or an abbreviation, in any case:

``` r

a <- et_score(demo_survey, ru, "national", area = "residence")
b <- et_score(demo_survey, ru, "national",
              area = ifelse(demo_survey$residence == "urban", 1L, 2L))
c3 <- et_score(demo_survey, ru, "national",
               area = toupper(as.character(demo_survey$residence)))
c(identical(a$score, b$score), identical(a$score, c3$score))
#> [1] TRUE TRUE
```

**These tools publish national and urban cut-points but no rural ones.**
The rural score is an intermediate. Check before assuming:

``` r

et_scopes(ru)
#> [1] "national" "urban"
```

Two of them have further quirks the package handles automatically:
**Burkina Faso** negates the urban score before rescaling, and
**Tunisia** has negative rescaling slopes.

### `national_only`

Argentina and Uruguay publish no urban tool.
[`et_scopes()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
will say so, and requesting `"urban"` errors.

## Checking a workbook before you trust it

Every EquityTool workbook states its scoring rules **twice**: once as
runnable SPSS and Stata syntax, and once as a printed table on the
*Other software* tab.

`rEquityTool` reads the **syntax** — it maps a response *code* directly
to a score, with no ambiguity about option ordering — and cross-checks
it against the printed table. Disagreements are recorded:

``` r

str(et_checks(tool), max.level = 1)
#> List of 6
#>  $ compared              : int 38
#>  $ mismatches            :'data.frame':  0 obs. of  5 variables:
#>  $ n_scores              : int 38
#>  $ cutoff_mismatches     :'data.frame':  0 obs. of  4 variables:
#>  $ mislabelled_conditions:'data.frame':  0 obs. of  3 variables:
#>  $ cutoff_source         : chr "SPSS Syntax"
```

``` r

et_checks(tool)$mismatches
#> [1] var       scope     option    syntax    other_tab
#> <0 rows> (or 0-length row.names)
et_checks(tool)$cutoff_mismatches
#> [1] scope     quintile  syntax    other_tab
#> <0 rows> (or 0-length row.names)
et_checks(tool)$mislabelled_conditions
#> [1] scope         quintile      condition_var
#> <0 rows> (or 0-length row.names)
```

Three empty data frames means the workbook agrees with itself. Make this
a habit: it takes one line and it is the only way to catch the problems
below.

## Three real defects in the published corpus

Checking all 69 workbooks turned up three problems in the official
files. None is documented by the publisher, and none had been reported
at the time of writing.

### Cambodia DHS 2021 — the two routes disagree

The *national* block of the *Other software* tab lists the `Q8` response
options (floor material) in a **different order** from the syntax tabs,
and from its own urban block:

| Route | Option 1 | Option 2 |
|----|----|----|
| *Other software* tab, national | ceramic tiles → 0.177085 | wood planks → 0.686445 |
| SPSS / Stata / R tabs | 0.686445 | 0.177085 |

A household scored by hand from the printed table gets a different
wealth score than one scored with the supplied syntax. Parsing warns,
and records it:

``` r

cam <- et_parse_workbook("Cambodia-DHS-2021-public-file-2023-11-14.xlsx")
#> Warning: 2 score(s) differ between the 'SPSS Syntax' tab and the
#> 'Other software' tab. The syntax tab has been used. See et_checks() for details.

et_checks(cam)$mismatches
#>   var    scope option    syntax other_tab
#> 1  Q8 national      1 0.6864448 0.1770851
#> 2  Q8 national      2 0.1770851 0.6864448
```

### Djibouti EDAM 2017 — the urban cut-point tests the wrong variable

The urban quintile block opens:

    DO IF NationalScore >=1.090269434498.
    COMPUTE UrbanQuintile =5.

The condition names `NationalScore` where it should name `UrbanScore`.
The workbook’s own table confirms 1.0903 is the **urban** quintile-5
boundary. Anyone running the published SPSS syntax verbatim assigns the
top urban quintile on the wrong variable.

This is why the package reads cut-points **structurally** — pairing each
threshold with the `COMPUTE <scope>Quintile = k` statement it guards, so
the scope and quintile number come from the assignment rather than from
the condition:

``` r

dji <- et_parse_workbook("Djibouti-EDAM-2017-public-file-2022-10-12.xlsx")

et_checks(dji)$mislabelled_conditions
#>   scope quintile condition_var
#> 1 urban        5      national

subset(et_cutoffs(dji), scope == "urban")
#>   scope quintile      lower
#> 5 urban        5  1.0902694   <- correctly attributed to urban
#> 6 urban        4  0.1376637
#> 7 urban        3 -0.3511468
#> 8 urban        2 -0.9498314
```

### Djibouti EDAM 2017 — a stale country name

The SPSS tab identifies itself as `VietnamMICS2021`, while the Stata tab
and the rest of the file correctly say `DjiboutiEDAM2017` — a copy-paste
left in place. Cosmetic, but it would mislabel your output. The package
resolves the survey name by majority vote across tabs.

## A defensive reading routine

``` r

tool <- et_parse_workbook("your-country-file.xlsx")

# 1. Is it the tool you expected, and what variant?
tool

# 2. Does the workbook contradict itself?
ck <- et_checks(tool)
stopifnot(nrow(ck$mismatches) == 0, nrow(ck$cutoff_mismatches) == 0)

# 3. Which scopes can you actually use?
et_scopes(tool)

# 4. Does your data match the questionnaire?
et_validate(my_survey, tool)

# 5. Only now, score.
et_score(my_survey, tool, scope = "national")
```

## Reporting a problem

If you hit a workbook that contradicts itself, the output of
[`et_checks()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
is exactly what the publisher needs. Contact Metrics for Management at
<equitytool@m4mgmt.org>, and please also open an issue at
<https://github.com/rEquityTools/rEquityTool/issues> so the finding is
recorded for other users.

## See also

- [`vignette("scopes")`](https://requitytools.github.io/rEquityTool/articles/scopes.md)
  — choosing between national, urban, rural and sample cut-points.
- [`vignette("myanmar-worked-example")`](https://requitytools.github.io/rEquityTool/articles/myanmar-worked-example.md)
  — the whole workflow with a real country workbook.
