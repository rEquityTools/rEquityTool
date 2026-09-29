#' A small synthetic household survey
#'
#' Six hundred simulated households, generated to match the fabricated example
#' workbook returned by [et_example()]. Used in examples, tests and the
#' vignette so that the package can be demonstrated without redistributing
#' EquityTool material or anyone's real survey data.
#'
#' The data are deliberately imperfect: twelve households have a missing answer
#' to `Q3`, seven have `Q5` coded `9` ("don't know"), and four have `Q7` coded
#' `0`. These are the two failure modes [et_validate()] exists to catch.
#'
#' @format A data frame with 600 rows and 14 columns:
#' \describe{
#'   \item{hhid}{Household identifier.}
#'   \item{region}{Factor: `North`, `Central`, `South`, `East`. Regions differ
#'     in average wealth, so they can be compared.}
#'   \item{residence}{Factor: `urban` or `rural`.}
#'   \item{wt}{Survey weight. Correlated with `residence`, so weighting changes
#'     the answers noticeably.}
#'   \item{Q1}{Electricity. `1` yes, `2` no.}
#'   \item{Q2}{Refrigerator. `1` yes, `2` no.}
#'   \item{Q3}{Television. `1` yes, `2` no. Contains `NA`s.}
#'   \item{Q4}{Motorcycle or scooter. `1` yes, `2` no.}
#'   \item{Q5}{Bank account. `1` yes, `2` no. Contains invalid code `9`.}
#'   \item{Q6}{Floor material. `1` cement, `2` earth or sand, `3` other.}
#'   \item{Q7}{Cooking fuel. `1` electricity or gas, `2` wood, `3` other.
#'     Contains invalid code `0`.}
#'   \item{Q8}{Sleeping rooms. `1` three or more, `2` two, `3` one.}
#'   \item{improved_water}{Binary outcome (`0`/`1`) for the equity example in
#'     the vignette.}
#' }
#'
#' @source Simulated. See `data-raw/02_make_demo_survey.R` in the package
#'   source. These are not real households and carry no personal data.
#' @examples
#' data(demo_survey)
#' str(demo_survey)
#' table(demo_survey$region, demo_survey$residence)
"demo_survey"
