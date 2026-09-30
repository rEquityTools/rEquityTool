# Package index

## Package

- [`rEquityTool`](https://requitytools.github.io/rEquityTool/reference/rEquityTool-package.md)
  [`rEquityTool-package`](https://requitytools.github.io/rEquityTool/reference/rEquityTool-package.md)
  : rEquityTool: Wealth Scores and Wealth Quintiles from 'EquityTool'
  Questionnaires

## Loading an EquityTool

Find and read the country workbooks published at equitytool.org. The
package ships no EquityTool data; you supply the workbook.

- [`et_find_workbooks()`](https://requitytools.github.io/rEquityTool/reference/et_find_workbooks.md)
  : Find EquityTool workbooks in a folder
- [`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md)
  : Read an EquityTool country workbook
- [`et_example()`](https://requitytools.github.io/rEquityTool/reference/et_example.md)
  : Paths to the bundled example workbooks

## Inspecting a tool

What questions it asks, what each answer scores, where the quintile
boundaries fall, and whether the workbook contradicts itself.

- [`et_vars()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
  [`et_questions()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
  [`et_scores()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
  [`et_cutoffs()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
  [`et_scopes()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
  [`et_checks()`](https://requitytools.github.io/rEquityTool/reference/et_accessors.md)
  : Components of an EquityTool object

## Scoring survey data

Check response coding, then compute wealth scores and assign quintiles.

- [`et_validate()`](https://requitytools.github.io/rEquityTool/reference/et_validate.md)
  : Check survey data against an EquityTool before scoring
- [`et_score()`](https://requitytools.github.io/rEquityTool/reference/et_score.md)
  : Score survey data and assign wealth quintiles

## Data

A small synthetic survey used throughout the examples.

- [`demo_survey`](https://requitytools.github.io/rEquityTool/reference/demo_survey.md)
  : A small synthetic household survey
