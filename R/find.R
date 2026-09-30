#' Find EquityTool workbooks in a folder
#'
#' Scans a directory for EquityTool country workbooks and reports what it
#' finds. Useful when you have downloaded several countries from
#' <https://equitytool.org/countries/> into one folder, typically with one
#' sub-folder per country.
#'
#' @details
#' Only the file listing is done eagerly. Set `inspect = TRUE` to open each
#' workbook and report its variant, number of questions and any cross-check
#' problems -- slower, but it tells you whether a file will actually work
#' before you build an analysis around it.
#'
#' The country name is taken from the containing sub-folder when there is one,
#' which matches how the EquityTool download is normally organised.
#'
#' @param dir Directory to scan.
#' @param recursive Search sub-folders. Default `TRUE`.
#' @param inspect Parse each workbook and add `variant`, `n_questions`,
#'   `scopes` and `issues` columns. Default `FALSE`.
#'
#' @return A data frame with one row per candidate workbook: `country`, `file`
#'   and `path`, plus the inspection columns when `inspect = TRUE`.
#'
#' @seealso [et_parse_workbook()]
#' @export
#' @examples
#' # scan the folder holding the package's bundled example workbooks
#' dir <- dirname(et_example())
#' et_find_workbooks(dir)
#'
#' \donttest{
#' # with a real download folder, inspect = TRUE reports what each file contains
#' et_find_workbooks(dir, inspect = TRUE)
#' }
et_find_workbooks <- function(dir, recursive = TRUE, inspect = FALSE) {
  if (!dir.exists(dir)) stop_et("Directory not found: ", dir)

  files <- list.files(dir, pattern = "[.]xlsx?$", recursive = recursive,
                      full.names = TRUE)
  ## Excel writes lock files as ~$name.xlsx when a workbook is open
  files <- files[!grepl("^~\\$", basename(files))]

  if (!length(files)) {
    return(data.frame(country = character(), file = character(),
                      path = character(), stringsAsFactors = FALSE))
  }

  parent <- basename(dirname(files))
  root <- basename(normalizePath(dir, winslash = "/", mustWork = FALSE))
  country <- ifelse(parent == root, tools::file_path_sans_ext(basename(files)), parent)

  out <- data.frame(country = country, file = basename(files), path = files,
                    stringsAsFactors = FALSE)

  if (!inspect) return(out[order(out$country), ])

  info <- lapply(seq_len(nrow(out)), function(i) {
    tool <- tryCatch(
      suppressWarnings(et_parse_workbook(out$path[i], country = out$country[i],
                                         verbose = FALSE)),
      error = function(e) e
    )
    if (inherits(tool, "error")) {
      return(data.frame(variant = NA_character_, n_questions = NA_integer_,
                        scopes = NA_character_,
                        issues = paste("parse failed:", conditionMessage(tool)),
                        stringsAsFactors = FALSE))
    }
    ck <- et_checks(tool)
    bits <- c(
      if (nrow(ck$mismatches)) paste0(nrow(ck$mismatches), " score mismatch(es)"),
      if (nrow(ck$cutoff_mismatches)) paste0(nrow(ck$cutoff_mismatches), " cut-point mismatch(es)"),
      if (nrow(ck$mislabelled_conditions)) paste0(nrow(ck$mislabelled_conditions), " mislabelled condition(s)")
    )
    data.frame(variant = tool$variant, n_questions = length(et_vars(tool)),
               scopes = paste(et_scopes(tool), collapse = "/"),
               issues = if (length(bits)) paste(bits, collapse = "; ") else "",
               stringsAsFactors = FALSE)
  })

  out <- cbind(out, do.call(rbind, info))
  out[order(out$country), ]
}
