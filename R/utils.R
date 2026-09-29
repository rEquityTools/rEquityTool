#' @keywords internal
"_PACKAGE"

## ---- small internal helpers -------------------------------------------------

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

stop_et <- function(...) stop(paste0(...), call. = FALSE)
warn_et <- function(...) warning(paste0(...), call. = FALSE)

## Read one worksheet as a character matrix with empty strings instead of NA.
## Everything is read as text so that numeric-looking option labels (e.g. the
## Thailand urban Q11 label, which is literally "1") are never mistaken for
## scores.
sheet_grid <- function(path, sheet) {
  d <- suppressMessages(readxl::read_excel(
    path,
    sheet = sheet,
    col_names = FALSE,
    col_types = "text",
    .name_repair = "minimal"
  ))
  m <- as.matrix(d)
  m[is.na(m)] <- ""
  dimnames(m) <- NULL
  m
}

## Find a sheet by case-insensitive regex; NA if absent.
find_sheet <- function(sheets, pattern) {
  hit <- grep(pattern, sheets, ignore.case = TRUE, value = TRUE)
  if (length(hit)) hit[[1]] else NA_character_
}

## Parse a numeric literal out of text, tolerating the trailing "." that
## terminates every SPSS statement and the "+-" that appears in some rescaling
## equations (e.g. Tunisia).
as_num <- function(x) {
  x <- trimws(x)
  x <- sub("[.]$", "", x)
  suppressWarnings(as.numeric(x))
}

num_re <- "-?[0-9]*[.]?[0-9]+(?:[eE][+-]?[0-9]+)?"

## Weighted quantiles, used for sample-based cut-points.
##
## Uses the standard "cumulative weight at the midpoint of each observation's
## weight" definition with linear interpolation, which reduces to
## stats::quantile(type = 7)-like behaviour when all weights are equal and is
## the convention used for weighted survey quantiles.
weighted_quantile <- function(x, w = NULL, probs) {
  keep <- !is.na(x)
  if (is.null(w)) w <- rep(1, length(x)) else keep <- keep & !is.na(w) & w > 0
  x <- x[keep]
  w <- w[keep]
  if (!length(x)) return(rep(NA_real_, length(probs)))
  o <- order(x)
  x <- x[o]
  w <- w[o]
  cw <- cumsum(w)
  p <- (cw - 0.5 * w) / sum(w)
  stats::approx(p, x, xout = probs, rule = 2, ties = "ordered")$y
}
