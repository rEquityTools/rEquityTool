# Worked example: Myanmar

This article walks through a complete analysis with a **real**
EquityTool country workbook — Myanmar DHS 2015–16 — from opening the
spreadsheet to reporting wealth quintiles three different ways.

> **Why the outputs are real but the households are not.** The workbook
> used here is the genuine file published by Metrics for Management, so
> every score and cut-point you see below is the real Myanmar tool. The
> *survey responses* are simulated, because household survey data is not
> ours to publish. Everything else — the parsing, the scores, the
> cut-points, the arithmetic — is exactly what you would get with your
> own data.
>
> This article is **pre-computed**: the code was run against a local
> copy of the workbook and the results were baked in, so the package
> does not have to ship EquityTool material. See
> `vignettes/precompile.R` in the package source.

``` r

library(rEquityTool)
```

## Step 1 — Get the workbook

Go to <https://equitytool.org/countries/>, choose your country, and
download the **“public file”** / **“other platforms file”** spreadsheet.
For Myanmar that is
`Myanmar-DHS-2015-16-Other-Platforms-file-2018-08-30.xlsx`.

Keep the file name. It records the survey and the release date, and you
will want both in your methods section.

If you have downloaded several countries into one folder,
[`et_find_workbooks()`](https://requitytools.github.io/rEquityTool/reference/et_find_workbooks.md)
will tell you what is there (showing the first few of 69):

``` r

head(et_find_workbooks(equitytool_dir)[, c("country", "file")], 6)
#>       country                                                            file
#> 1 Afghanistan           AfghanistanDHS2015_Public-Sharing-File-2017-06-20.xls
#> 2      Angola                       Angola-DHS-2015-public-file-2017-9-20.xls
#> 3   Argentina Argentina-MICS-2012_-EquityTool-other-platforms-2018-07-17.xlsx
#> 4     Armenia                Armenia-DHS-2015-Other-Platforms-2018-04-26.xlsx
#> 5  Bangladesh               Bangladesh-DHS-2017-public-file-2022-12-19-1.xlsx
#> 6      Belize         Belize-MICS-2016_EquityTool-public-file-2018-12-30.xlsx
```

Add `inspect = TRUE` to open each file and report what it contains
before you commit to it:

``` r

et_find_workbooks(file.path(equitytool_dir, "Myanmar"), inspect = TRUE)[
  , c("country", "variant", "n_questions", "scopes", "issues")]
#>                                               country        variant n_questions
#> 1 Myanmar-DHS-2015-16-Other-Platforms-file-2018-08-30 national_urban          15
#>           scopes issues
#> 1 national/urban
```

## Step 2 — Load the spreadsheet

``` r

myanmar <- et_parse_workbook(myanmar_path, country = "Myanmar")
myanmar
#> <equitytool>
#>   Country      : Myanmar
#>   Survey       : MyanmarDHS2015
#>   Source file  : Myanmar-DHS-2015-16-Other-Platforms-file-2018-08-30.xlsx
#>   Variant      : national_urban
#>   Questions    : 15 (1-15)
#>   Score scopes : national, urban
#>   Quintiles for: national, urban
#>   Cross-check  : 62 score(s) compared with the 'Other software' tab, 0 mismatch(es)
```

Read that summary before going further:

- **Variant `national_urban`** — Myanmar publishes national and urban
  score sets. (Fourteen other countries instead publish *rural* and
  urban sets that must be rescaled onto a national scale; those need an
  `area` argument. Two countries publish national only.)
- **15 questions** — that is what your questionnaire must contain.
- **Cross-check: 0 mismatches** — the package read the scores from the
  SPSS syntax tab and compared them against the score table printed on
  the *Other software* tab. For Myanmar the two agree exactly. They do
  not always: see the end of this article.

## Step 3 — See the questions you need to ask

This is the questionnaire to put in your instrument. The response
options must be coded `1`, `2`, `3` in the order shown — that is the
single most important thing to get right.

``` r

q <- et_questions(myanmar)
head(q, 12)
#>    var                                question option label
#> 1   Q1 Does your household have… a television?      1   Yes
#> 2   Q1 Does your household have… a television?      2    No
#> 3   Q2                   … a mobile telephone?      1   Yes
#> 4   Q2                   … a mobile telephone?      2    No
#> 5   Q3                       … a refrigerator?      1   Yes
#> 6   Q3                       … a refrigerator?      2    No
#> 7   Q4                              … a table?      1   Yes
#> 8   Q4                              … a table?      2    No
#> 9   Q5                              … a chair?      1   Yes
#> 10  Q5                              … a chair?      2    No
#> 11  Q6                                … a bed?      1   Yes
#> 12  Q6                                … a bed?      2    No
```

The 15 questions, one row each:

``` r

unique(q[, c("var", "question")])
#>    var                                                                 question
#> 1   Q1                                  Does your household have… a television?
#> 3   Q2                                                    … a mobile telephone?
#> 5   Q3                                                        … a refrigerator?
#> 7   Q4                                                               … a table?
#> 9   Q5                                                               … a chair?
#> 11  Q6                                                                 … a bed?
#> 13  Q7                                                            … a cupboard?
#> 15  Q8                                                       … an electric fan?
#> 17  Q9                                                            … a computer?
#> 19 Q10                           Does any member of your household own a watch?
#> 21 Q11                   Does any member of your household have a bank account?
#> 23 Q12 What is the main source of drinking water for members of your household?
#> 25 Q13                 What is the main material of the floor of your dwelling?
#> 27 Q14        What is the main material of the exterior walls of your dwelling?
#> 29 Q15            What type of fuel does your household mainly use for cooking?
```

## Step 4 — Inspect the scores and cut-points

Each answer carries a score:

``` r

s <- et_scores(myanmar)
head(s[s$scope == "national", ], 10)
#>    var    scope option       score
#> 1   Q1 national      1  0.06908232
#> 2   Q1 national      2 -0.09056438
#> 3   Q2 national      1  0.04251595
#> 4   Q2 national      2 -0.10201746
#> 5   Q3 national      1  0.19615190
#> 6   Q3 national      2 -0.03472369
#> 7   Q4 national      1  0.03984670
#> 8   Q4 national      2 -0.09322404
#> 9   Q5 national      1  0.06016968
#> 10  Q5 national      2 -0.09146762
```

And the quintile boundaries — the numbers your household totals get
compared against:

``` r

et_cutoffs(myanmar)
#>      scope quintile       lower
#> 1 national        5  0.58736483
#> 2 national        4  0.07573200
#> 3 national        3 -0.23114069
#> 4 national        2 -0.52385813
#> 5    urban        5  0.56679960
#> 6    urban        4  0.31742564
#> 7    urban        3 -0.01971703
#> 8    urban        2 -0.41238716
```

So a Myanmar household is in the richest national quintile if its 15
item scores sum to at least 0.587364826752, and in the poorest if the
total falls below -0.523858129524.

## Step 5 — Your survey data

Here is a simulated survey of 800 households, in the shape `rEquityTool`
expects: one row per household, one column per question, named
`Q1`–`Q15`.

It is deliberately drawn to resemble a survey in poor, remote areas
rather than a nationally representative sample, because that is the
situation where the choice of cut-points actually matters.

``` r

str(svy[, c("hhid", "township", "residence", "wt", "Q1", "Q2", "Q3")])
#> 'data.frame':    800 obs. of  7 variables:
#>  $ hhid     : chr  "MM0001" "MM0002" "MM0003" "MM0004" ...
#>  $ township : Factor w/ 5 levels "Hpapun","Kyainseikgyi",..: 5 3 4 4 1 5 3 2 5 5 ...
#>  $ residence: Factor w/ 2 levels "urban","rural": 2 2 2 2 2 1 2 2 2 2 ...
#>  $ wt       : num  0.959 1.081 1.152 1.742 1.179 ...
#>  $ Q1       : int  2 1 1 2 2 1 1 1 1 2 ...
#>  $ Q2       : int  2 1 1 2 2 2 2 2 1 2 ...
#>  $ Q3       : int  2 2 2 2 2 2 2 2 2 2 ...
```

``` r

table(svy$township)
#> 
#>       Hpapun Kyainseikgyi    Hlaingbwe     Myawaddy    Kawkareik 
#>          212          162          156          114          156
```

## Step 6 — Validate before you score

Mis-coded answers fail *silently*: an unrecognised code becomes `NA`,
the household drops out, and the quintiles that remain still look
reasonable. Always check first.

``` r

et_validate(svy, myanmar)
#> <equitytool_check> Myanmar
#>   rows in data : 800
#>   all required columns present
#>   questions with missing or out-of-range codes:
#>  var column valid_codes n_na n_invalid invalid_values
#>   Q9     Q9         1,2    9         0               
#>  Q11    Q11         1,2    0        14              9
#>  Q12    Q12         1,2    5         0               
#>   complete records: 773 of 800 (96.6%)
#>   note: EquityTool scores only complete records; the rest get NA.
```

Our simulated data has a handful of `NA`s and a few `9` (“don’t know”)
codes, which is what real fieldwork looks like. The report tells you
exactly which questions and how many records you will lose.

If your columns are not called `Q1`…`Q15`, map them — a partial mapping
is fine, you only name the ones that differ:

``` r

et_score(svy, myanmar, scope = "national",
         vars = c(Q1 = "has_tv", Q2 = "has_mobile"))
```

## Step 7 — National wealth quintiles

This uses the published Myanmar cut-points. Quintile 1 is the poorest
fifth **of Myanmar** as measured by DHS 2015–16.

``` r

nat <- et_score(svy, myanmar, scope = "national")
table(nat$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>     209     262     195     100       7      27
```

``` r

round(100 * prop.table(table(nat$quintile)), 1)
#> 
#> Poorest  Poorer  Middle  Richer Richest 
#>    27.0    33.9    25.2    12.9     0.9
```

The groups are nowhere near equal, and that is the result, not a bug. A
survey concentrated in poor rural townships should land
disproportionately in the bottom national quintiles. For comparison, the
published midline survey of conflict-affected townships in Kayin State
found 59.0% of households in the poorest national quintile and 2.6% in
the richest.

## Step 8 — Urban quintiles

If your respondents are urban residents, the national distribution is
the wrong benchmark: almost everyone looks rich. Compare them with the
national **urban** population instead.

``` r

urb <- et_score(svy, myanmar, scope = "urban")
table(urb$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>     701      62      10       0       0      27
```

Note this uses a *different score set as well as* different cut-points —
the urban index weights assets differently from the national one:

``` r

head(s[s$scope == "urban", ], 4)
#>    var scope option       score
#> 32  Q1 urban      1  0.03406337
#> 33  Q1 urban      2 -0.18114370
#> 34  Q2 urban      1  0.01788888
#> 35  Q2 urban      2 -0.20004768
```

Apply it only to urban respondents. An urban quintile 1 household is not
necessarily poorer than a rural quintile 5 household — the two are
measured against different reference populations.

## Step 9 — Sample-based quintiles

Sometimes the question is not “how poor are these households compared
with the country” but “who is worst off **among the people we
surveyed**”. For that, cut on your own sample’s score distribution.

Pass `weights` so the boundaries reflect the population your sample
represents rather than the achieved sample.

``` r

smp <- et_score(svy, myanmar, scope = "sample", weights = "wt")
table(smp$quintile, useNA = "ifany")
#> 
#> Poorest  Poorer  Middle  Richer Richest    <NA> 
#>     141     152     145     163     172      27
```

Now the groups are approximately equal in size, by construction. The
cut-points came from your data:

``` r

attr(smp, "cutoffs")
#> [1] -0.63196152 -0.46272628 -0.28412921 -0.05426768
```

You are not limited to fifths:

``` r

ter <- et_score(svy, myanmar, scope = "sample", probs = c(1, 2) / 3)
table(ter$quintile)
#> 
#>  Lowest  Middle Highest 
#>     257     258     258
```

## Step 10 — The three side by side

The **score is identical** in all three. Only the cut-points change.

``` r

all.equal(nat$score, smp$score)
#> [1] TRUE
```

``` r

comparison <- data.frame(
  national = as.integer(nat$quintile),
  urban    = as.integer(urb$quintile),
  sample   = as.integer(smp$quintile)
)
sapply(comparison, function(x) round(100 * prop.table(table(factor(x, 1:5))), 1))
#>   national urban sample
#> 1     27.0  90.7   18.2
#> 2     33.9   8.0   19.7
#> 3     25.2   1.3   18.8
#> 4     12.9   0.0   21.1
#> 5      0.9   0.0   22.3
```

``` r

# how households move between the national and the sample classification
table(national = nat$quintile, sample = smp$quintile)
#>          sample
#> national  Poorest Poorer Middle Richer Richest
#>   Poorest     141     68      0      0       0
#>   Poorer        0     84    145     33       0
#>   Middle        0      0      0    130      65
#>   Richer        0      0      0      0     100
#>   Richest       0      0      0      0       7
```

**Say which one you used.** “The poorest quintile in our sample” and
“the poorest national quintile” are different groups of people, and
reporting one as the other is a substantive error, not a presentational
one.

A reasonable default: report **national** quintiles to place your
population in its country context, and **sample** quintiles when you are
analysing gradients *within* your study population and need groups of
usable size.

## Step 11 — Use the result

Attach the scores to your data and carry on:

``` r

scored <- et_score(svy, myanmar, scope = "national", append = TRUE)
names(scored)
#>  [1] "hhid"           "township"       "residence"      "Q1"            
#>  [5] "Q2"             "Q3"             "Q4"             "Q5"            
#>  [9] "Q6"             "Q7"             "Q8"             "Q9"            
#> [13] "Q10"            "Q11"            "Q12"            "Q13"           
#> [17] "Q14"            "Q15"            "wt"             "improved_water"
#> [21] "score"          "quintile"
```

Wealth distribution by township — the kind of table that goes in a
baseline report:

``` r

round(100 * prop.table(table(scored$township, scored$quintile), 1), 1)
#>               
#>                Poorest Poorer Middle Richer Richest
#>   Hpapun          37.9   36.9   18.2    6.4     0.5
#>   Kyainseikgyi    30.3   33.5   21.9   13.5     0.6
#>   Hlaingbwe       19.9   35.8   30.5   12.6     1.3
#>   Myawaddy        19.8   26.1   31.5   20.7     1.8
#>   Kawkareik       21.6   34.0   28.1   15.7     0.7
```

Outcome coverage across wealth groups, which is the input to an equiplot
or a concentration index:

``` r

aggregate(improved_water ~ quintile, data = scored, FUN = function(x) round(mean(x), 3))
#>   quintile improved_water
#> 1  Poorest          0.172
#> 2   Poorer          0.225
#> 3   Middle          0.328
#> 4   Richer          0.390
#> 5  Richest          0.857
```

For the continuous ranking variable that concentration indices want, use
`score` rather than `quintile`:

``` r

summary(scored$score)
#>     Min.  1st Qu.   Median     Mean  3rd Qu.     Max.     NA's 
#> -0.88747 -0.56609 -0.34364 -0.30204 -0.08774  0.91322       27
```

## Step 12 — Check for workbook problems

Always look at the cross-check. Myanmar is clean:

``` r

et_checks(myanmar)$mismatches
#> [1] var       scope     option    syntax    other_tab
#> <0 rows> (or 0-length row.names)
et_checks(myanmar)$cutoff_mismatches
#> [1] scope     quintile  syntax    other_tab
#> <0 rows> (or 0-length row.names)
et_checks(myanmar)$mislabelled_conditions
#> [1] scope         quintile      condition_var
#> <0 rows> (or 0-length row.names)
```

Two of the 69 published workbooks are not. In **Cambodia DHS 2021** the
printed score table and the syntax tabs disagree about the order of the
`Q8` response options, so the two documented routes give different
scores for the same household. In **Djibouti EDAM 2017** the urban
quintile block tests `NationalScore` where it should test `UrbanScore`.
`rEquityTool` handles both and reports them through
[`et_checks()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md);
if you are working in either country, read that output before you trust
the numbers.

## What to write in your methods section

Something like:

> Household wealth was measured with the Myanmar EquityTool
> (MyanmarDHS2015, released 2018-08-30), a 15-item asset index derived
> from the DHS 2015–16 wealth index. Households were assigned to
> national wealth quintiles using the published cut-points. Scoring was
> carried out in R with the `rEquityTool` package (version 0.1.0);
> households with any missing or out-of-range item were excluded from
> the wealth analysis (n = 27 of 800).

And carry these caveats:

- The EquityTool is a **simplified** index. Agreement with the full DHS
  wealth index for Myanmar is 84.0%, kappa 0.751 (national) and 84.1%,
  kappa 0.751 (urban). Individual households can be misclassified by one
  quintile; the tool is designed for describing groups.
- Cut-points are anchored to the national distribution **in 2015–16**.
  The further your fieldwork is from that date, the more “national
  quintile” means “position relative to a historical benchmark”.
- These are **relative** measures of wealth, not absolute measures of
  poverty.

## Where to go next

The score and quintile are the ranking variable for the usual equity
analyses: concentration indices and decomposition with
[`rineq`](https://cran.r-project.org/package=rineq), equiplots and the
slope index of inequality with
[`ICEHmeasures`](https://cran.r-project.org/package=ICEHmeasures).
Remember to carry your survey design into those analyses.
