#' Score survey data and assign wealth quintiles
#'
#' Applies an EquityTool to a data frame of respondent answers, returning the
#' wealth score and the wealth quintile for each row.
#'
#' @section Choosing a scope:
#' `scope` decides **what the quintiles are relative to**, which is a
#' substantive choice, not a technical one.
#'
#' \describe{
#'   \item{`"national"`}{Published national cut-points. Quintile 1 is the
#'     poorest fifth *of the country* at the time of the source survey. In a
#'     targeted or non-representative sample the quintiles will not be evenly
#'     filled -- that is the intended behaviour and usually the finding.}
#'   \item{`"urban"`}{Published urban cut-points, for surveys of urban
#'     residents. Position is relative to the national *urban* population.}
#'   \item{`"rural"`}{Rural cut-points, where the tool publishes them. Most
#'     tools do not; see the note below.}
#'   \item{`"sample"`}{Cut-points computed from your own sample's weighted score
#'     distribution. Quintile 1 is the poorest fifth *of your respondents*, so
#'     the groups are approximately equal in size by construction. Use this when
#'     relative position within the surveyed population is what you want to
#'     report, and say so explicitly -- these are not national quintiles.}
#' }
#'
#' Use [et_scopes()] to see which published scopes a given tool supports. In the
#' currently published corpus the 14 "rural + urban" tools provide national and
#' urban cut-points but no rural ones: the rural score is an intermediate
#' quantity that is rescaled onto the national scale. For those tools use
#' `scope = "national"` with `area`, or `scope = "sample"`.
#'
#' @section Rural/urban tools:
#' For tools with `variant == "rural_urban"`, urban and rural respondents are
#' scored on different scales and then mapped onto a common national scale by a
#' published linear equation. Scoring therefore requires `area`, a vector
#' identifying each respondent as urban or rural.
#'
#' @section Missing data:
#' The EquityTool rule is that a respondent with **any** missing or
#' out-of-range answer receives no score. Such rows get `NA` for both `score`
#' and `quintile`. Set `na_rule = "partial"` to instead sum the available items
#' -- this is **not** the official method, makes scores non-comparable across
#' respondents, and should only be used for diagnostics.
#'
#' @param data A data frame of respondent answers, one row per household.
#' @param tool An `equitytool` object from [et_parse_workbook()].
#' @param scope One of `"national"`, `"urban"`, `"rural"` or `"sample"`. See
#'   Details.
#' @param vars Optional named character vector mapping question names to columns
#'   in `data`, e.g. `c(Q1 = "tv", Q2 = "mobile")`.
#' @param area For `variant == "rural_urban"` tools, a vector marking each row
#'   as urban or rural. Either a column name in `data` or a vector as long as
#'   `nrow(data)`. Values are matched leniently: `1`/`"urban"`/`"u"` mean urban
#'   and `2`/`"rural"`/`"r"` mean rural (case-insensitive).
#' @param weights Optional survey weights, used only when `scope = "sample"`.
#'   Either a column name in `data` or a numeric vector.
#' @param probs Cut-point probabilities for `scope = "sample"`. Defaults to
#'   quintiles, `c(0.2, 0.4, 0.6, 0.8)`. Use e.g. `c(1, 2)/3` for tertiles.
#' @param na_rule `"complete"` (default, the official rule) or `"partial"`.
#' @param append If `TRUE`, return `data` with the new columns added. If `FALSE`
#'   (default), return just the results.
#'
#' @return A data frame with one row per row of `data` and columns `score` and
#'   `quintile` (an ordered factor). For `rural_urban` tools an `area_score`
#'   column holds the pre-rescaling score. If `append = TRUE`, these columns are
#'   added to `data`.
#'
#' @seealso [et_validate()] to check coding first, [et_scopes()] for the
#'   available scopes.
#' @export
#' @examples
#' tool <- et_parse_workbook(et_example())
#' data(demo_survey)
#'
#' # National quintiles, using the tool's published cut-points
#' nat <- et_score(demo_survey, tool, scope = "national")
#' table(nat$quintile, useNA = "ifany")
#'
#' # Quintiles relative to this sample instead
#' smp <- et_score(demo_survey, tool, scope = "sample", weights = "wt")
#' table(smp$quintile, useNA = "ifany")
#'
#' # Attach the results to the survey data
#' scored <- et_score(demo_survey, tool, scope = "national", append = TRUE)
#' names(scored)
et_score <- function(data, tool,
                     scope = c("national", "urban", "rural", "sample"),
                     vars = NULL, area = NULL, weights = NULL,
                     probs = c(0.2, 0.4, 0.6, 0.8),
                     na_rule = c("complete", "partial"),
                     append = FALSE) {
  stopifnot_tool(tool)
  if (!is.data.frame(data)) stop_et("`data` must be a data frame.")
  scope <- match.arg(scope)
  na_rule <- match.arg(na_rule)

  map <- resolve_vars(tool, data, vars, error_if_missing = TRUE)

  ## ---- which score scale do we need? ----
  needs_area <- identical(tool$variant, "rural_urban")
  score_scope <- if (scope %in% c("national", "sample")) {
    if (needs_area) NA_character_ else "national"
  } else {
    scope
  }

  if (!needs_area && !is.na(score_scope) &&
      !score_scope %in% unique(tool$scores$scope)) {
    stop_et("This tool has no '", score_scope, "' scores. Available: ",
            paste(sort(unique(tool$scores$scope)), collapse = ", "), ".")
  }

  extra <- list()

  if (needs_area && scope %in% c("national", "sample")) {
    av <- resolve_area(data, area, nrow(data))
    urb <- raw_score(data, tool, map, "urban", na_rule)
    rur <- raw_score(data, tool, map, "rural", na_rule)
    if ("urban" %in% tool$inverted) urb <- -urb
    if ("rural" %in% tool$inverted) rur <- -rur

    area_score <- ifelse(av == "urban", urb, rur)
    if (is.null(tool$rescale)) {
      stop_et("This tool needs rural/urban rescaling coefficients but none ",
              "were found in the workbook.")
    }
    int <- stats::setNames(tool$rescale$intercept, tool$rescale$area)
    slp <- stats::setNames(tool$rescale$slope, tool$rescale$area)
    score <- unname(int[av]) + unname(slp[av]) * area_score
    score[is.na(av)] <- NA_real_
    extra$area_score <- area_score
  } else if (needs_area && scope %in% c("urban", "rural")) {
    score <- raw_score(data, tool, map, scope, na_rule)
    if (scope %in% tool$inverted) score <- -score
  } else {
    score <- raw_score(data, tool, map, score_scope, na_rule)
    if (score_scope %in% tool$inverted) score <- -score
  }

  ## ---- cut into quintiles ----
  if (scope == "sample") {
    cuts <- weighted_quantile(score, resolve_weights(data, weights, nrow(data)), probs)
    q <- cut_scores(score, cuts)
    labels <- quintile_labels(length(cuts) + 1L)
  } else {
    cut_tbl <- tool$cutoffs[tool$cutoffs$scope == scope, , drop = FALSE]
    if (!nrow(cut_tbl)) {
      stop_et("This tool does not publish '", scope, "' quintile cut-points. ",
              "Available: ", paste(et_scopes(tool), collapse = ", "),
              ". Use scope = \"sample\" to cut on your own sample instead.")
    }
    cuts <- sort(cut_tbl$lower)
    q <- cut_scores(score, cuts)
    labels <- quintile_labels(length(cuts) + 1L)
  }

  res <- data.frame(score = score,
                    quintile = factor(q, levels = seq_along(labels),
                                      labels = labels, ordered = TRUE))
  if (length(extra)) res <- cbind(res, as.data.frame(extra))

  attr(res, "scope") <- scope
  attr(res, "cutoffs") <- cuts
  attr(res, "tool") <- format(tool)

  if (append) cbind(data, res) else res
}

## Sum the per-item scores for one scope.
raw_score <- function(data, tool, map, scope, na_rule) {
  s <- tool$scores[tool$scores$scope == scope, , drop = FALSE]
  if (!nrow(s)) stop_et("This tool has no '", scope, "' scores.")
  qs <- intersect(names(map), unique(s$var))

  mat <- vapply(qs, function(q) {
    sv <- s[s$var == q, , drop = FALSE]
    x <- suppressWarnings(as.integer(as.character(data[[map[[q]]]])))
    sv$score[match(x, sv$option)]
  }, numeric(nrow(data)))
  if (is.null(dim(mat))) mat <- matrix(mat, nrow = nrow(data))

  if (na_rule == "complete") rowSums(mat) else rowSums(mat, na.rm = TRUE)
}

## Assign 1..length(cuts)+1 by comparing against sorted lower bounds.
cut_scores <- function(score, cuts) {
  cuts <- sort(cuts)
  q <- rep(NA_integer_, length(score))
  ok <- !is.na(score)
  if (any(ok)) q[ok] <- vapply(score[ok], function(v) sum(v >= cuts) + 1L, integer(1))
  q
}

quintile_labels <- function(n) {
  if (n == 5L) {
    c("Poorest", "Poorer", "Middle", "Richer", "Richest")
  } else if (n == 3L) {
    c("Lowest", "Middle", "Highest")
  } else {
    paste0("G", seq_len(n))
  }
}

resolve_area <- function(data, area, n) {
  if (is.null(area)) {
    stop_et("This is a rural/urban tool: urban and rural respondents are scored ",
            "on different scales. Supply `area`, e.g. area = \"residence\" or ",
            "area = c(\"urban\", \"rural\", ...).")
  }
  v <- if (length(area) == 1L && is.character(area) && area %in% names(data)) {
    data[[area]]
  } else {
    area
  }
  if (length(v) != n) {
    stop_et("`area` must have one value per row of `data` (", n, "), got ",
            length(v), ".")
  }
  ch <- tolower(trimws(as.character(v)))
  out <- rep(NA_character_, length(ch))
  out[ch %in% c("1", "urban", "u")] <- "urban"
  out[ch %in% c("2", "rural", "r")] <- "rural"
  if (all(is.na(out))) {
    stop_et("Could not interpret `area`. Use 1/\"urban\"/\"u\" for urban and ",
            "2/\"rural\"/\"r\" for rural. Saw: ",
            paste(utils::head(unique(ch), 5), collapse = ", "), ".")
  }
  out
}

resolve_weights <- function(data, weights, n) {
  if (is.null(weights)) return(NULL)
  w <- if (length(weights) == 1L && is.character(weights) && weights %in% names(data)) {
    data[[weights]]
  } else {
    weights
  }
  if (length(w) != n) {
    stop_et("`weights` must have one value per row of `data` (", n, "), got ",
            length(w), ".")
  }
  as.numeric(w)
}
