#' Check survey data against an EquityTool before scoring
#'
#' Mis-coded response options are the most common cause of wrong EquityTool
#' results, and they fail *silently*: an unrecognised code becomes `NA`, the
#' household is dropped, and the remaining quintiles still look plausible. This
#' function reports the problems before you score.
#'
#' @param data A data frame of respondent answers, one row per household.
#' @param tool An `equitytool` object from [et_parse_workbook()].
#' @param vars Optional named character vector mapping the tool's question names
#'   to columns in `data`, e.g. `c(Q1 = "tv", Q2 = "mobile")`. If `NULL`
#'   (default) the tool's own names (`Q1`, `Q2`, ...) are looked up in `data`.
#'
#' @return An object of class `equitytool_check`, invisibly a list with elements
#'   `missing_columns`, `items` (a per-question summary) and `n_complete`.
#'   Printing it gives a readable report.
#'
#' @seealso [et_score()]
#' @export
#' @examples
#' tool <- et_parse_workbook(et_example())
#' data(demo_survey)
#' et_validate(demo_survey, tool)
et_validate <- function(data, tool, vars = NULL) {
  stopifnot_tool(tool)
  if (!is.data.frame(data)) stop_et("`data` must be a data frame.")

  map <- resolve_vars(tool, data, vars, error_if_missing = FALSE)
  present <- map[!is.na(map)]
  missing_cols <- names(map)[is.na(map)]

  items <- lapply(names(present), function(q) {
    col <- data[[present[[q]]]]
    valid <- sort(unique(tool$scores$option[tool$scores$var == q]))
    x <- suppressWarnings(as.integer(as.character(col)))
    bad <- !is.na(x) & !x %in% valid
    data.frame(
      var        = q,
      column     = unname(present[[q]]),
      valid_codes = paste(valid, collapse = ","),
      n_na       = sum(is.na(x)),
      n_invalid  = sum(bad),
      invalid_values = if (any(bad)) {
        paste(sort(unique(x[bad])), collapse = ",")
      } else "",
      stringsAsFactors = FALSE
    )
  })
  items <- if (length(items)) do.call(rbind, items) else NULL

  n_complete <- if (length(present) == length(map) && !is.null(items)) {
    ok <- rep(TRUE, nrow(data))
    for (q in names(present)) {
      valid <- tool$scores$option[tool$scores$var == q]
      x <- suppressWarnings(as.integer(as.character(data[[present[[q]]]])))
      ok <- ok & !is.na(x) & x %in% valid
    }
    sum(ok)
  } else {
    NA_integer_
  }

  structure(
    list(country = tool$country, n_rows = nrow(data),
         missing_columns = missing_cols, items = items, n_complete = n_complete),
    class = "equitytool_check"
  )
}

#' @export
print.equitytool_check <- function(x, ...) {
  cat("<equitytool_check> ", x$country %||% "", "\n", sep = "")
  cat("  rows in data : ", x$n_rows, "\n", sep = "")

  if (length(x$missing_columns)) {
    cat("  MISSING columns (", length(x$missing_columns), "): ",
        paste(x$missing_columns, collapse = ", "), "\n", sep = "")
  } else {
    cat("  all required columns present\n")
  }

  if (!is.null(x$items)) {
    prob <- x$items[x$items$n_na > 0 | x$items$n_invalid > 0, , drop = FALSE]
    if (nrow(prob)) {
      cat("  questions with missing or out-of-range codes:\n")
      print(prob[c("var", "column", "valid_codes", "n_na", "n_invalid",
                   "invalid_values")], row.names = FALSE)
    } else {
      cat("  all responses are valid codes\n")
    }
  }

  if (!is.na(x$n_complete)) {
    cat("  complete records: ", x$n_complete, " of ", x$n_rows,
        sprintf(" (%.1f%%)", 100 * x$n_complete / max(x$n_rows, 1L)), "\n", sep = "")
    if (x$n_complete < x$n_rows) {
      cat("  note: EquityTool scores only complete records; the rest get NA.\n")
    }
  }
  invisible(x)
}

## Map tool question names -> data column names.
resolve_vars <- function(tool, data, vars = NULL, error_if_missing = TRUE) {
  qs <- et_vars(tool)
  map <- stats::setNames(rep(NA_character_, length(qs)), qs)

  ## Start from same-name matching, then let `vars` override. This means a
  ## partial mapping works: you only name the columns that differ.
  for (q in qs) {
    hit <- names(data)[toupper(names(data)) == q]
    if (length(hit)) map[[q]] <- hit[[1]]
  }

  if (!is.null(vars)) {
    if (is.null(names(vars))) {
      if (length(vars) != length(qs)) {
        stop_et("`vars` given without names must have one entry per question (",
                length(qs), "), got ", length(vars), ". ",
                "Supply names instead, e.g. vars = c(", qs[[1]], " = \"my_column\").")
      }
      vars <- stats::setNames(vars, qs)
    }
    unknown <- setdiff(names(vars), qs)
    if (length(unknown)) {
      stop_et("`vars` names not in this tool: ", paste(unknown, collapse = ", "),
              ". Expected some of: ", paste(qs, collapse = ", "), ".")
    }
    absent <- vars[!vars %in% names(data)]
    if (length(absent)) {
      stop_et("`vars` points at columns that are not in `data`: ",
              paste(unique(absent), collapse = ", "), ".")
    }
    for (q in names(vars)) map[[q]] <- unname(vars[[q]])
  }

  if (error_if_missing && anyNA(map)) {
    miss <- names(map)[is.na(map)]
    stop_et("Columns not found in `data` for: ", paste(miss, collapse = ", "),
            ".\nEither rename them to match the tool, or pass a mapping via ",
            "`vars`, e.g. vars = c(", miss[[1]], " = \"your_column\").",
            "\nRun et_validate() for a full report.")
  }
  map
}
