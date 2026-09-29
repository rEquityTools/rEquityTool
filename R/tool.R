#' @export
print.equitytool <- function(x, ...) {
  cat("<equitytool>", "\n", sep = "")
  cat("  Country      : ", x$country %||% "<unknown>", "\n", sep = "")
  cat("  Survey       : ", x$survey %||% "<unknown>", "\n", sep = "")
  cat("  Source file  : ", x$source_file, "\n", sep = "")
  cat("  Variant      : ", x$variant, "\n", sep = "")
  cat("  Questions    : ", length(et_vars(x)), " (",
      paste(range(as.integer(sub("Q", "", et_vars(x)))), collapse = "-"), ")\n", sep = "")
  cat("  Score scopes : ", paste(sort(unique(x$scores$scope)), collapse = ", "), "\n", sep = "")
  cat("  Quintiles for: ", paste(sort(unique(x$cutoffs$scope)), collapse = ", "), "\n", sep = "")
  if (length(x$inverted)) {
    cat("  Inverted     : ", paste(x$inverted, collapse = ", "),
        " score is negated before rescaling\n", sep = "")
  }
  if (!is.null(x$rescale)) {
    cat("  Rescaling    : national score = intercept + slope * area score\n")
    for (i in seq_len(nrow(x$rescale))) {
      cat(sprintf("                 %-6s %+.6g %+.6g * score\n",
                  x$rescale$area[i], x$rescale$intercept[i], x$rescale$slope[i]))
    }
  }
  nm <- nrow(x$checks$mismatches)
  cat("  Cross-check  : ", x$checks$compared, " score(s) compared with the ",
      "'Other software' tab, ", nm, " mismatch(es)",
      if (nm) " - see et_checks()" else "", "\n", sep = "")
  nc <- nrow(x$checks$cutoff_mismatches %||% data.frame())
  if (!is.null(nc) && nc > 0) {
    cat("  WARNING      : ", nc, " quintile cut-point(s) disagree between tabs",
        " - see et_checks()$cutoff_mismatches\n", sep = "")
  }
  nl <- nrow(x$checks$mislabelled_conditions %||% data.frame())
  if (!is.null(nl) && nl > 0) {
    cat("  Note         : ", nl, " cut-point condition(s) in the published syntax",
        " name the wrong score variable;\n",
        "                 the quintile assignment they guard has been used instead",
        " - see et_checks()\n", sep = "")
  }
  invisible(x)
}

#' @export
format.equitytool <- function(x, ...) {
  paste0("<equitytool: ", x$country %||% "?", " / ", x$survey %||% "?", ">")
}

#' @export
summary.equitytool <- function(object, ...) {
  print(object)
  cat("\nScores by scope:\n")
  print(table(scope = object$scores$scope))
  cat("\nQuintile lower bounds:\n")
  print(object$cutoffs, row.names = FALSE)
  invisible(object)
}

#' Components of an EquityTool object
#'
#' Accessors for the pieces of an `equitytool` object created by
#' [et_parse_workbook()].
#'
#' @param tool An `equitytool` object.
#'
#' @return
#' * `et_vars()` a character vector of the question variable names (`"Q1"`, ...)
#'   in question order.
#' * `et_questions()` a data frame of question text and response option labels.
#' * `et_scores()` a data frame with columns `var`, `scope`, `option`, `score`.
#' * `et_cutoffs()` a data frame of quintile lower bounds by scope.
#' * `et_scopes()` the scopes for which this tool can assign published
#'   quintiles.
#' * `et_checks()` the result of cross-checking the syntax tab against the
#'   *Other software* tab, including any mismatching scores.
#'
#' @name et_accessors
#' @examples
#' tool <- et_parse_workbook(et_example())
#' et_vars(tool)
#' head(et_questions(tool))
#' et_scopes(tool)
#' et_checks(tool)$mismatches
NULL

#' @rdname et_accessors
#' @export
et_vars <- function(tool) {
  stopifnot_tool(tool)
  v <- unique(tool$scores$var)
  v[order(as.integer(sub("Q", "", v)))]
}

#' @rdname et_accessors
#' @export
et_questions <- function(tool) {
  stopifnot_tool(tool)
  tool$questions
}

#' @rdname et_accessors
#' @export
et_scores <- function(tool) {
  stopifnot_tool(tool)
  tool$scores
}

#' @rdname et_accessors
#' @export
et_cutoffs <- function(tool) {
  stopifnot_tool(tool)
  tool$cutoffs
}

#' @rdname et_accessors
#' @export
et_scopes <- function(tool) {
  stopifnot_tool(tool)
  sort(unique(tool$cutoffs$scope))
}

#' @rdname et_accessors
#' @export
et_checks <- function(tool) {
  stopifnot_tool(tool)
  tool$checks
}

stopifnot_tool <- function(tool) {
  if (!inherits(tool, "equitytool")) {
    stop_et("`tool` must be an <equitytool> object, as returned by ",
            "et_parse_workbook(). Got <", class(tool)[1], ">.")
  }
  invisible(TRUE)
}

#' Paths to the bundled example workbooks
#'
#' Small, deliberately **fabricated** EquityTool-format workbooks shipped with
#' the package so that examples, tests and the vignette run without
#' redistributing any material from <https://equitytool.org>.
#'
#' @details
#' The files mimic the layout of real country workbooks -- a `Questionnaire`
#' tab, an `SPSS Syntax` tab and an `Other software` tab -- but every number in
#' them is made up. They must never be used to produce real wealth estimates.
#' For that, download the workbook for your country from
#' <https://equitytool.org/countries/> and pass it to [et_parse_workbook()].
#'
#' Two variants are provided, matching two of the three structural variants
#' found in the real corpus:
#'
#' * `"national_urban"` (default) -- national and urban score sets.
#' * `"rural_urban"` -- separate rural and urban score sets rescaled onto a
#'   common national scale, which is what the 14 rural/urban country tools do.
#'
#' @param variant Which example workbook to return.
#' @return A file path.
#' @export
#' @examples
#' et_example()
#' et_parse_workbook(et_example())
#'
#' # the rural/urban variant needs an area indicator when scoring
#' et_parse_workbook(et_example("rural_urban"))
et_example <- function(variant = c("national_urban", "rural_urban")) {
  variant <- match.arg(variant)
  f <- switch(variant,
    national_urban = "equitytool_example_workbook.xlsx",
    rural_urban    = "equitytool_example_rural_urban.xlsx"
  )
  system.file("extdata", f, package = "rEquityTool", mustWork = TRUE)
}
