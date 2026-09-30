# Find EquityTool workbooks in a folder

Scans a directory for EquityTool country workbooks and reports what it
finds. Useful when you have downloaded several countries from
<https://equitytool.org/countries/> into one folder, typically with one
sub-folder per country.

## Usage

``` r
et_find_workbooks(dir, recursive = TRUE, inspect = FALSE)
```

## Arguments

- dir:

  Directory to scan.

- recursive:

  Search sub-folders. Default `TRUE`.

- inspect:

  Parse each workbook and add `variant`, `n_questions`, `scopes` and
  `issues` columns. Default `FALSE`.

## Value

A data frame with one row per candidate workbook: `country`, `file` and
`path`, plus the inspection columns when `inspect = TRUE`.

## Details

Only the file listing is done eagerly. Set `inspect = TRUE` to open each
workbook and report its variant, number of questions and any cross-check
problems – slower, but it tells you whether a file will actually work
before you build an analysis around it.

The country name is taken from the containing sub-folder when there is
one, which matches how the EquityTool download is normally organised.

## See also

[`et_parse_workbook()`](https://requitytools.github.io/rEquityTool/reference/et_parse_workbook.md)

## Examples

``` r
# scan the folder holding the package's bundled example workbooks
dir <- dirname(et_example())
et_find_workbooks(dir)
#>                          country                                file
#> 1 equitytool_example_rural_urban equitytool_example_rural_urban.xlsx
#> 2    equitytool_example_workbook    equitytool_example_workbook.xlsx
#>                                                                                      path
#> 1 /home/runner/work/_temp/Library/rEquityTool/extdata/equitytool_example_rural_urban.xlsx
#> 2    /home/runner/work/_temp/Library/rEquityTool/extdata/equitytool_example_workbook.xlsx

# \donttest{
# with a real download folder, inspect = TRUE reports what each file contains
et_find_workbooks(dir, inspect = TRUE)
#>                          country                                file
#> 1 equitytool_example_rural_urban equitytool_example_rural_urban.xlsx
#> 2    equitytool_example_workbook    equitytool_example_workbook.xlsx
#>                                                                                      path
#> 1 /home/runner/work/_temp/Library/rEquityTool/extdata/equitytool_example_rural_urban.xlsx
#> 2    /home/runner/work/_temp/Library/rEquityTool/extdata/equitytool_example_workbook.xlsx
#>          variant n_questions         scopes issues
#> 1    rural_urban           8 national/urban       
#> 2 national_urban           8 national/urban       
# }
```
