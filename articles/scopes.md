# Choosing a wealth quintile scope

``` r

library(rEquityTool)
tool <- et_parse_workbook(et_example())
data(demo_survey)
```

[`et_score()`](https://requitytools.github.io/rEquityTool/reference/et_score.md)
has a `scope` argument with four settings. It is the most consequential
choice in the package, and it is a **substantive** one, not a technical
detail: it decides *what your quintiles are relative to*.

| `scope` | Cut-points come from | Quintile 1 is the poorest fifth of… |
|----|----|----|
| `"national"` | The published national index | the country, at the time of the source survey |
| `"urban"` | The published urban index | the national urban population |
| `"rural"` | The published rural index, where one exists | the national rural population |
| `"sample"` | **Your own data** | your respondents |

## The score does not change. The cut-points do.

This is the thing to internalise. All four scopes on the same
households:

``` r

nat <- et_score(demo_survey, tool, scope = "national")
smp <- et_score(demo_survey, tool, scope = "sample", weights = "wt")

all.equal(nat$score, smp$score)
#> [1] TRUE
```

The wealth score is a property of the household’s assets. The *quintile*
is a statement about where that score sits relative to some reference
population. Changing `scope` changes the reference population, nothing
else.

``` r

rbind(
  national = table(nat$quintile),
  sample   = table(smp$quintile)
)
#>          Poorest Poorer Middle Richer Richest
#> national      90    122    176    135      54
#> sample       116    112    112    116     121
```

## `"national"` — position in the country

Use this when you want to say where your respondents sit in the national
distribution. This is the default and the right choice for most
programme reporting.

``` r

round(100 * prop.table(table(nat$quintile)), 1)
#> 
#> Poorest  Poorer  Middle  Richer Richest 
#>    15.6    21.1    30.5    23.4     9.4
```

**The groups will not be equal, and they are not supposed to be.** If
you survey a poor district, most households land in the bottom
quintiles. That is the finding. A published midline survey of
conflict-affected townships in Kayin State, Myanmar found 59.0% of
households in the poorest national quintile and 2.6% in the richest — an
informative result that sample-based quintiles would have concealed
entirely.

A common mistake is to see an uneven distribution, assume something is
broken, and switch to `"sample"` to “fix” it. That discards the finding.

## `"urban"` — position among urban residents

Against the national distribution, urban residents mostly look rich,
because they mostly are. If your survey is of a city, that comparison is
uninformative:

``` r

urb_only <- demo_survey[demo_survey$residence == "urban", ]
table(et_score(urb_only, tool, scope = "national")$quintile)
#> 
#> Poorest  Poorer  Middle  Richer Richest 
#>      32      44      53      50      18
```

The urban index gives a reference population that discriminates within
that group:

``` r

table(et_score(urb_only, tool, scope = "urban")$quintile)
#> 
#> Poorest  Poorer  Middle  Richer Richest 
#>      72      56      51      15       3
```

Note that this is not merely a different set of cut-points — the urban
index **weights the assets differently**, because what distinguishes
rich from poor in a city differs from what distinguishes them
nationally:

``` r

s <- et_scores(tool)
merge(
  s[s$scope == "national" & s$option == 1, c("var", "score")],
  s[s$scope == "urban"    & s$option == 1, c("var", "score")],
  by = "var", suffixes = c("_national", "_urban")
)
#>   var score_national score_urban
#> 1  Q1    -0.07668097  0.07486654
#> 2  Q2     0.12581041 -0.07489246
#> 3  Q3    -0.11996710  0.12421357
#> 4  Q4     0.05091998 -0.12360569
#> 5  Q5     0.07320718  0.06260182
#> 6  Q6     0.22787744 -0.12009694
#> 7  Q7    -0.02692764 -0.20829651
#> 8  Q8    -0.16552891  0.05406593
```

Apply the urban index only to urban respondents. An urban quintile 1
household is **not** necessarily poorer than a rural quintile 5
household; the two are measured against different populations.

## `"rural"` — where the tool publishes it

Some tools publish a rural index. Many do not: in the 14 “rural + urban”
country tools the rural score is an *intermediate* quantity that gets
rescaled onto the national scale, and no rural cut-points are published.
Ask the tool:

``` r

et_scopes(tool)
#> [1] "national" "urban"
```

Requesting a scope the tool does not support is an error, not a silent
fallback:

``` r

et_score(demo_survey, tool, scope = "rural")
#> Error:
#> ! This tool has no 'rural' scores. Available: national, urban.
```

## `"sample"` — position among your own respondents

Sometimes the question is not “how poor are these households compared
with the country” but “who is worst off **among the people we
surveyed**”. That is a legitimate question — it is the right one when
you are analysing a gradient *within* a study population, or when
national quintiles leave you with three households in the top group and
no power to say anything about them.

``` r

table(smp$quintile)
#> 
#> Poorest  Poorer  Middle  Richer Richest 
#>     116     112     112     116     121
```

The groups are now approximately equal by construction, and the
cut-points came from your data:

``` r

attr(smp, "cutoffs")
#> [1] -0.18470574 -0.06970372  0.01415650  0.11675876
```

### Always pass `weights`

Without weights the cut-points describe your *achieved sample*. With
weights they describe the population your sample was designed to
represent. These are different, sometimes materially:

``` r

unweighted <- et_score(demo_survey, tool, scope = "sample")
weighted   <- et_score(demo_survey, tool, scope = "sample", weights = "wt")

rbind(unweighted = attr(unweighted, "cutoffs"),
      weighted   = attr(weighted,   "cutoffs"))
#>                  [,1]        [,2]       [,3]      [,4]
#> unweighted -0.1853950 -0.06888150 0.02054755 0.1178355
#> weighted   -0.1847057 -0.06970372 0.01415650 0.1167588
```

``` r

table(unweighted = unweighted$quintile, weighted = weighted$quintile)
#>           weighted
#> unweighted Poorest Poorer Middle Richer Richest
#>    Poorest     113      0      0      0       0
#>    Poorer        3    112      3      0       0
#>    Middle        0      0    109      6       0
#>    Richer        0      0      0    110       5
#>    Richest       0      0      0      0     116
```

### You are not limited to fifths

`probs` takes any set of cut probabilities, so tertiles, quartiles and
deciles all work. Useful when a sample is too small to support five
groups:

``` r

tertiles <- et_score(demo_survey, tool, scope = "sample", probs = c(1, 2) / 3)
table(tertiles$quintile)
#> 
#>  Lowest  Middle Highest 
#>     191     194     192
```

``` r

deciles <- et_score(demo_survey, tool, scope = "sample", probs = seq(0.1, 0.9, 0.1))
table(deciles$quintile)
#> 
#>  G1  G2  G3  G4  G5  G6  G7  G8  G9 G10 
#>  58  55  58  60  55  60  58  57  58  58
```

## How much does the choice actually matter?

A lot. Here is where households end up under the two classifications:

``` r

table(national = nat$quintile, sample = smp$quintile)
#>          sample
#> national  Poorest Poorer Middle Richer Richest
#>   Poorest      90      0      0      0       0
#>   Poorer       26     96      0      0       0
#>   Middle        0     16    112     48       0
#>   Richer        0      0      0     68      67
#>   Richest       0      0      0      0      54
```

Off-diagonal cells are households that would be described completely
differently depending on a single argument.

## Reporting rules

1.  **State which scope you used, in the methods.** “Wealth quintiles”
    is not sufficient. Write “national wealth quintiles from the Myanmar
    EquityTool” or “quintiles of the weighted sample wealth score
    distribution”.
2.  **Never call sample quintiles national quintiles.** They are
    different groups of people. This is a substantive error, not a
    presentational one.
3.  **If you report national quintiles, say when the reference survey
    was.** Cut-points are anchored to the national distribution at that
    date.
4.  **Do not switch to `"sample"` because the national distribution
    looks lopsided.** That lopsidedness is usually your headline result.

A reasonable default for programme evaluation: report **national**
quintiles to place your population in its country context, and use
**sample** quintiles when you need groups of workable size for
within-study gradient analysis. Report both if they tell different
stories — that difference is itself informative.

## See also

- [`vignette("myanmar-worked-example")`](https://requitytools.github.io/rEquityTool/articles/myanmar-worked-example.md)
  — the whole workflow with a real country workbook.
- [`vignette("workbooks")`](https://requitytools.github.io/rEquityTool/articles/workbooks.md)
  — what to do when a tool has rural/urban scales or internal
  contradictions.
