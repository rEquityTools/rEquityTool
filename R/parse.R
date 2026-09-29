## Parsing an EquityTool country workbook -------------------------------------
##
## Every workbook published by Metrics for Management states the same
## information twice: once as runnable SPSS/Stata syntax, and once as a
## human-readable score table on the "Other software" tab. We parse the syntax
## tab (which is unambiguous, because it maps a response *code* directly to a
## score) and use the "Other software" tab only for option labels and as an
## independent cross-check. See vignette("rEquityTool") for why this matters.

scope_from_suffix <- function(x) {
  c(NAT = "national", URB = "urban", RUR = "rural")[toupper(x)]
}

## ---- scores -----------------------------------------------------------------

parse_scores_syntax <- function(grid) {
  txt <- trimws(grid[, 1])
  lines <- grep("^recode\\s+Q[0-9]+", txt, ignore.case = TRUE, value = TRUE)
  if (!length(lines)) return(NULL)

  out <- lapply(lines, function(ln) {
    suffix <- regmatches(ln, regexpr("_(NAT|URB|RUR)\\b", ln, ignore.case = TRUE))
    if (!length(suffix)) return(NULL)
    scope <- scope_from_suffix(sub("_", "", suffix))

    pairs <- regmatches(
      ln,
      gregexpr(paste0("\\(\\s*[0-9]+\\s*=\\s*", num_re, "\\s*\\)"), ln)
    )[[1]]
    if (!length(pairs)) return(NULL)

    data.frame(
      var    = toupper(sub("^recode\\s+(Q[0-9]+).*$", "\\1", ln, ignore.case = TRUE)),
      scope  = unname(scope),
      option = as.integer(sub("^\\(\\s*([0-9]+).*$", "\\1", pairs)),
      score  = as_num(sub(paste0("^.*=\\s*(", num_re, ")\\s*\\)$"), "\\1", pairs)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, out)
  if (is.null(out)) return(NULL)
  out[order(out$scope, as.integer(sub("Q", "", out$var)), out$option), ]
}

## Header-anchored read of the "Other software" tab. Columns are located from
## the "Option n:" / "Option n <scope> score:" header cells rather than by
## position, so a numeric option *label* is never read as a score.
parse_other_tab <- function(grid) {
  hdr_rows <- which(apply(grid, 1, function(r) any(grepl("Option\\s*1\\b", r))))
  if (!length(hdr_rows)) return(NULL)

  blocks <- lapply(hdr_rows, function(h) {
    hdr <- trimws(grid[h, ])
    lab_col <- which(grepl("^Option\\s*([0-9]+)\\s*:?$", hdr))
    sc_col  <- which(grepl("^Option\\s*([0-9]+).*(national|urban|rural)\\s*score", hdr,
                           ignore.case = TRUE))
    if (!length(lab_col) || !length(sc_col)) return(NULL)

    lab_n <- as.integer(sub("^Option\\s*([0-9]+).*$", "\\1", hdr[lab_col]))
    sc_n  <- as.integer(sub("^Option\\s*([0-9]+).*$", "\\1", hdr[sc_col]))
    scope <- unique(tolower(sub("^.*(national|urban|rural).*$", "\\1",
                                hdr[sc_col], ignore.case = TRUE)))[1]

    ## the column holding Qn_NAT / Qn_URB / Qn_RUR variable names
    var_col <- which(grepl("variable\\s*names", hdr, ignore.case = TRUE))
    var_col <- if (length(var_col)) var_col[[1]] else NA_integer_
    ## the column holding the question text
    q_col <- which(grepl("^Questions?$", hdr, ignore.case = TRUE))
    q_col <- if (length(q_col)) q_col[[1]] else NA_integer_

    ## data rows: from just below the header until the first row with no Qn id
    ids <- trimws(grid[, 1])
    rows <- integer(0)
    i <- h + 1L
    while (i <= nrow(grid)) {
      if (grepl("^Q[0-9]+$", ids[i])) rows <- c(rows, i) else if (length(rows)) break
      i <- i + 1L
    }
    if (!length(rows)) return(NULL)

    recs <- lapply(rows, function(i) {
      vals  <- as_num(grid[i, sc_col])
      labs  <- trimws(grid[i, lab_col])
      keep  <- !is.na(vals)
      if (!any(keep)) return(NULL)
      data.frame(
        var      = toupper(ids[i]),
        scope    = scope,
        option   = sc_n[keep],
        score    = vals[keep],
        label    = labs[match(sc_n[keep], lab_n)],
        question = if (is.na(q_col)) NA_character_ else trimws(grid[i, q_col]),
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, recs)
  })

  blocks <- do.call(rbind, blocks)
  if (is.null(blocks)) return(NULL)
  blocks[!duplicated(blocks[c("var", "scope", "option")]), ]
}

## ---- quintile cut-points -----------------------------------------------------

## Cut-points are read structurally: each "... >= <threshold>" condition is
## paired with the `COMPUTE <scope>Quintile = <k>` statement that follows it, so
## the scope and the quintile number come from the assignment rather than from
## the variable named in the condition.
##
## This matters. In the published Djibouti EDAM 2017 workbook the urban block
## opens with `DO IF NationalScore >=1.090269434498.` followed by
## `COMPUTE UrbanQuintile =5.` -- the condition names the wrong variable. The
## workbook's own "Other software" table confirms 1.0903 is the *urban*
## quintile 5 boundary. Reading the assignment gets this right; reading the
## condition does not.
parse_cutoffs_syntax <- function(grid) {
  txt <- trimws(grid[, 1])
  cond_re <- paste0("(\\w*)Score\\s*>=\\s*(", num_re, ")")
  comp_re <- "COMPUTE\\s+(\\w+)Quintile\\s*=\\s*([0-9]+)"

  recs <- list()
  for (i in seq_along(txt)) {
    m <- regmatches(txt[i], regexec(cond_re, txt[i], ignore.case = TRUE))[[1]]
    if (length(m) != 3L) next
    lower <- as_num(m[3])
    if (is.na(lower)) next
    ## the assignment that this condition guards
    j <- i + 1L
    while (j <= length(txt) && !grepl(comp_re, txt[j], ignore.case = TRUE)) {
      if (grepl("^(DO IF|ELSE IF|END IF)", txt[j], ignore.case = TRUE)) break
      j <- j + 1L
    }
    if (j > length(txt)) next
    cm <- regmatches(txt[j], regexec(comp_re, txt[j], ignore.case = TRUE))[[1]]
    if (length(cm) != 3L) next
    recs[[length(recs) + 1L]] <- data.frame(
      scope     = tolower(cm[2]),
      quintile  = as.integer(cm[3]),
      lower     = lower,
      cond_var  = tolower(m[2]),
      stringsAsFactors = FALSE
    )
  }
  if (!length(recs)) return(NULL)
  out <- do.call(rbind, recs)
  out <- out[out$quintile > 1L, , drop = FALSE]   # quintile 1 has no lower bound
  out[!duplicated(out[c("scope", "quintile")]), , drop = FALSE]
}

## The same cut-points are printed on the "Other software" tab under headings
## like "Lower limits for each national quintile". Parsed independently so the
## two can be compared.
parse_cutoffs_other <- function(grid) {
  if (is.null(grid)) return(NULL)
  txt <- apply(grid, 1, paste, collapse = " ")
  scope_now <- NA_character_
  recs <- list()
  for (i in seq_len(nrow(grid))) {
    hdr <- regmatches(txt[i], regexec(
      "lower limits for each\\s+(national|urban|rural)", txt[i], ignore.case = TRUE))[[1]]
    if (length(hdr) == 2L) {
      scope_now <- tolower(hdr[2])
      next
    }
    row <- trimws(grid[i, ])
    k <- grep("^Quintile\\s*([1-5])$", row, ignore.case = TRUE)
    if (!length(k) || is.na(scope_now)) next
    qn <- as.integer(sub("^Quintile\\s*", "", row[k[1]], ignore.case = TRUE))
    vals <- as_num(row[-seq_len(k[1])])
    vals <- vals[!is.na(vals)]
    if (!length(vals)) next
    recs[[length(recs) + 1L]] <- data.frame(scope = scope_now, quintile = qn,
                                            lower = vals[1], stringsAsFactors = FALSE)
  }
  if (!length(recs)) return(NULL)
  out <- do.call(rbind, recs)
  out <- out[out$quintile > 1L, , drop = FALSE]
  out[!duplicated(out[c("scope", "quintile")]), , drop = FALSE]
}

## ---- rural/urban rescaling ---------------------------------------------------

## In the 14 "rural + urban" tools, respondents are scored on separate rural and
## urban scales which are then mapped onto a common national scale by a linear
## equation, e.g.
##   if (UrbanM4M =1) NationalScore = 1.316983+0.9253775*UrbanScore.
parse_rescale <- function(grid) {
  txt <- trimws(grid[, 1])
  lines <- grep("NationalScore\\s*=", txt, ignore.case = TRUE, value = TRUE)
  if (!length(lines)) return(NULL)

  recs <- lapply(lines, function(ln) {
    src <- if (grepl("UrbanScore", ln, ignore.case = TRUE)) "urban" else
           if (grepl("RuralScore", ln, ignore.case = TRUE)) "rural" else NA_character_
    if (is.na(src)) return(NULL)
    rhs <- sub("^.*NationalScore\\s*=\\s*", "", ln, ignore.case = TRUE)
    m <- regmatches(rhs, regexec(
      paste0("^\\s*(", num_re, ")\\s*\\+\\s*(", num_re, ")\\s*\\*"), rhs))[[1]]
    if (length(m) != 3L) return(NULL)
    data.frame(area = src, intercept = as_num(m[2]), slope = as_num(m[3]),
               stringsAsFactors = FALSE)
  })
  recs <- do.call(rbind, recs)
  if (is.null(recs) || !nrow(recs)) return(NULL)
  recs[!duplicated(recs$area), ]
}

## Burkina Faso is the only tool in the published corpus whose urban score must
## be negated before the rescaling step:
##   if (UrbanM4M =1) UrbanScore =0-( Q1_URB+...+Q15_URB).
parse_inverted <- function(grid) {
  txt <- trimws(grid[, 1])
  inv <- character(0)
  for (sc in c("Urban", "Rural", "National")) {
    ln <- grep(paste0(sc, "Score\\s*=\\s*0\\s*-\\s*\\("), txt, ignore.case = TRUE,
               value = TRUE)
    if (length(ln)) inv <- c(inv, tolower(sc))
  }
  inv
}

## ---- questionnaire -----------------------------------------------------------

## The Questionnaire tab lists items in the local language and then, usually,
## again in English after a "Translated into: English" marker. Prefer English.
parse_questions <- function(grid) {
  ids <- trimws(grid[, 1])
  qrows <- which(grepl("^Q[0-9]+$", ids))
  if (!length(qrows)) return(NULL)

  ## split contiguous runs into blocks
  brk <- c(0, which(diff(qrows) > 1L), length(qrows))
  blocks <- lapply(seq_len(length(brk) - 1L),
                   function(i) qrows[(brk[i] + 1L):brk[i + 1L]])

  eng <- which(apply(grid, 1, function(r) any(grepl("english", r, ignore.case = TRUE))))
  pick <- blocks[[1]]
  if (length(eng)) {
    after <- vapply(blocks, function(b) b[[1]] > min(eng), logical(1))
    if (any(after)) pick <- blocks[[which(after)[[1]]]]
  }

  recs <- lapply(pick, function(i) {
    row <- trimws(grid[i, ])
    text <- row[2]
    opts <- row[-(1:2)]
    opts <- opts[nzchar(opts)]
    if (!length(opts)) return(NULL)
    data.frame(var = toupper(ids[i]), question = text,
               option = seq_along(opts), label = opts,
               stringsAsFactors = FALSE)
  })
  do.call(rbind, recs)
}

## ---- top level ---------------------------------------------------------------

#' Read an EquityTool country workbook
#'
#' Parses one of the Excel workbooks published for each country at
#' <https://equitytool.org> ("public file" / "other platforms file") into an
#' `equitytool` object that [et_score()] can apply to survey data.
#'
#' @details
#' Each workbook states the scoring rules twice: as runnable SPSS and Stata
#' syntax, and as a printed score table on the *Other software* tab. This
#' function takes the **syntax** as authoritative, because it maps a response
#' *code* to a score with no ambiguity, and uses the *Other software* tab only
#' for option labels and as an independent cross-check.
#'
#' When the two disagree the difference is recorded in the object (see
#' [et_checks()]) and, if `verbose = TRUE`, reported as a warning. This is not
#' hypothetical: in the published Cambodia DHS 2021 workbook the national block
#' of the *Other software* tab lists the `Q8` response options in a different
#' order from the syntax tabs, so the two documented routes give different
#' scores for the same household.
#'
#' Three structural variants occur in the published corpus and all are handled:
#'
#' * `"national_urban"` -- separate national and urban score sets (most tools).
#' * `"rural_urban"` -- separate rural and urban score sets that are mapped onto
#'   a common national scale by a linear equation. Scoring on the national scale
#'   therefore requires an urban/rural indicator; see the `area` argument of
#'   [et_score()].
#' * `"national_only"` -- national scores with no urban tool.
#'
#' @param path Path to an EquityTool country workbook (`.xls` or `.xlsx`).
#' @param country,survey Optional labels. If not supplied they are guessed from
#'   the file name and the workbook's own comments.
#' @param verbose Warn about cross-check failures between the syntax tab and the
#'   *Other software* tab. Default `TRUE`.
#'
#' @return An object of class `equitytool`.
#' @seealso [et_score()], [et_validate()], [et_questions()], [et_checks()]
#' @export
#' @examples
#' # A small fabricated workbook ships with the package so that examples and
#' # tests run without redistributing EquityTool material.
#' path <- et_example()
#' tool <- et_parse_workbook(path)
#' tool
et_parse_workbook <- function(path, country = NULL, survey = NULL, verbose = TRUE) {
  if (!file.exists(path)) stop_et("File not found: ", path)
  sheets <- readxl::excel_sheets(path)

  syn_sheet <- find_sheet(sheets, "^spss")
  oth_sheet <- find_sheet(sheets, "^other\\s*software$")
  qn_sheet  <- find_sheet(sheets, "^questionnaire$")
  sta_sheet <- find_sheet(sheets, "^stata")
  if (is.na(syn_sheet) && is.na(oth_sheet)) {
    stop_et("'", basename(path), "' does not look like an EquityTool workbook: ",
            "no 'SPSS Syntax' or 'Other software' sheet found.")
  }

  syn <- if (!is.na(syn_sheet)) sheet_grid(path, syn_sheet) else NULL
  oth <- if (!is.na(oth_sheet)) sheet_grid(path, oth_sheet) else NULL

  scores <- if (!is.null(syn)) parse_scores_syntax(syn) else NULL
  other  <- if (!is.null(oth)) parse_other_tab(oth) else NULL
  source_of_scores <- "SPSS Syntax"
  if (is.null(scores)) {
    if (is.null(other)) stop_et("Could not extract any scores from '", basename(path), "'.")
    scores <- other[c("var", "scope", "option", "score")]
    source_of_scores <- "Other software"
  }

  cutoffs  <- if (!is.null(syn)) parse_cutoffs_syntax(syn) else NULL
  cut_other <- parse_cutoffs_other(oth)
  cutoff_source <- "SPSS Syntax"
  if (is.null(cutoffs)) {
    cutoffs <- cut_other
    cutoff_source <- "Other software"
  }
  if (is.null(cutoffs)) stop_et("Could not extract quintile cut-points from '",
                                basename(path), "'.")
  rescale  <- if (!is.null(syn)) parse_rescale(syn) else NULL
  inverted <- if (!is.null(syn)) parse_inverted(syn) else character(0)

  questions <- if (!is.na(qn_sheet)) parse_questions(sheet_grid(path, qn_sheet)) else NULL
  if (is.null(questions) && !is.null(other)) {
    questions <- unique(other[c("var", "question", "option", "label")])
    names(questions)[names(questions) == "question"] <- "question"
  }

  ## cross-check the syntax tab against the printed tables
  checks <- cross_check(scores, other, source_of_scores)
  checks$cutoff_mismatches <- cross_check_cutoffs(cutoffs, cut_other)
  checks$mislabelled_conditions <- mislabelled_conditions(cutoffs)
  checks$cutoff_source <- cutoff_source

  if (verbose && nrow(checks$mismatches)) {
    warn_et(
      "In '", basename(path), "': ", nrow(checks$mismatches),
      " score(s) differ between the '", source_of_scores,
      "' tab and the 'Other software' tab. The syntax tab has been used. ",
      "See et_checks() for details."
    )
  }
  if (verbose && nrow(checks$cutoff_mismatches)) {
    warn_et(
      "In '", basename(path), "': ", nrow(checks$cutoff_mismatches),
      " quintile cut-point(s) differ between the syntax tab and the ",
      "'Other software' tab. See et_checks()$cutoff_mismatches."
    )
  }

  scopes <- sort(unique(scores$scope))
  variant <- if ("rural" %in% scopes) "rural_urban" else
             if ("urban" %in% scopes) "national_urban" else "national_only"

  structure(
    list(
      country      = country %||% guess_country(path),
      survey       = survey %||% guess_survey(list(
                       if (!is.null(syn)) syn[, 1] else NULL,
                       if (!is.null(oth)) as.vector(oth) else NULL,
                       if (!is.na(sta_sheet)) sheet_grid(path, sta_sheet)[, 1] else NULL
                     )),
      source_file  = basename(path),
      variant      = variant,
      questions    = questions,
      scores       = scores,
      cutoffs      = cutoffs[c("scope", "quintile", "lower")],
      rescale      = rescale,
      inverted     = inverted,
      score_source = source_of_scores,
      checks       = checks
    ),
    class = "equitytool"
  )
}

guess_country <- function(path) {
  nm <- basename(dirname(normalizePath(path, winslash = "/", mustWork = FALSE)))
  if (nzchar(nm) && !nm %in% c(".", "extdata", "")) return(nm)
  tools::file_path_sans_ext(basename(path))
}

## The workbooks name themselves in comments, e.g.
## "** ... for people using the EquityTool for MyanmarDHS2015" and
## "**similar to those found in the DjiboutiEDAM2017 public shared file".
##
## These comments are copy-pasted between country files and are sometimes
## stale: the published Djibouti workbook's SPSS tab says "VietnamMICS2021"
## while its Stata tab and its other comments correctly say "DjiboutiEDAM2017".
## Take the value that appears most often rather than the first one seen.
guess_survey <- function(texts) {
  texts <- unlist(texts, use.names = FALSE)
  texts <- texts[nzchar(texts)]
  if (!length(texts)) return(NA_character_)

  grab <- function(pattern) {
    ln <- grep(pattern, texts, ignore.case = TRUE, value = TRUE)
    if (!length(ln)) return(character(0))
    sub(paste0("^.*", pattern, ".*$"), "\\1", ln, ignore.case = TRUE)
  }
  cand <- c(
    ## end-anchored first, so multi-word names such as "El Salvador MICS2014"
    ## survive; then the single-token form as a fallback
    grab("EquityTool for\\s+([A-Za-z0-9_ '-]+?)\\s*[.,]?\\s*$"),
    grab("EquityTool for\\s+([A-Za-z0-9_-]+)"),
    grab("found in the\\s+([A-Za-z0-9_-]+)\\s+public shared file")
  )
  cand <- trimws(cand)
  cand <- cand[nzchar(cand) & !grepl("^[0-9]+$", cand) & nchar(cand) >= 4]
  if (!length(cand)) return(NA_character_)

  tab <- sort(table(cand), decreasing = TRUE)
  names(tab)[1]
}

cross_check <- function(scores, other, source_of_scores) {
  empty <- data.frame(var = character(), scope = character(), option = integer(),
                      syntax = numeric(), other_tab = numeric(),
                      stringsAsFactors = FALSE)
  if (is.null(other) || source_of_scores == "Other software") {
    return(list(compared = 0L, mismatches = empty, n_scores = nrow(scores)))
  }
  key <- function(d) paste(d$scope, d$var, d$option)
  common <- intersect(key(scores), key(other))
  if (!length(common)) {
    return(list(compared = 0L, mismatches = empty, n_scores = nrow(scores)))
  }
  a <- scores[match(common, key(scores)), ]
  b <- other[match(common, key(other)), ]
  bad <- which(abs(a$score - b$score) > 1e-9)
  mm <- if (length(bad)) {
    data.frame(var = a$var[bad], scope = a$scope[bad], option = a$option[bad],
               syntax = a$score[bad], other_tab = b$score[bad],
               stringsAsFactors = FALSE)
  } else {
    empty
  }
  list(compared = length(common), mismatches = mm, n_scores = nrow(scores))
}

cross_check_cutoffs <- function(cut_syn, cut_oth) {
  empty <- data.frame(scope = character(), quintile = integer(),
                      syntax = numeric(), other_tab = numeric(),
                      stringsAsFactors = FALSE)
  if (is.null(cut_syn) || is.null(cut_oth)) return(empty)
  key <- function(d) paste(d$scope, d$quintile)
  common <- intersect(key(cut_syn), key(cut_oth))
  if (!length(common)) return(empty)
  a <- cut_syn[match(common, key(cut_syn)), ]
  b <- cut_oth[match(common, key(cut_oth)), ]
  bad <- which(abs(a$lower - b$lower) > 1e-9)
  if (!length(bad)) return(empty)
  data.frame(scope = a$scope[bad], quintile = a$quintile[bad],
             syntax = a$lower[bad], other_tab = b$lower[bad],
             stringsAsFactors = FALSE)
}

## Rows where the variable named in the `DO IF`/`ELSE IF` condition does not
## match the scope of the `COMPUTE ...Quintile` it guards -- i.e. a copy-paste
## slip in the published syntax, as in the Djibouti workbook.
mislabelled_conditions <- function(cut_syn) {
  empty <- data.frame(scope = character(), quintile = integer(),
                      condition_var = character(), stringsAsFactors = FALSE)
  if (is.null(cut_syn) || !"cond_var" %in% names(cut_syn)) return(empty)
  bad <- which(nzchar(cut_syn$cond_var) & cut_syn$cond_var != cut_syn$scope)
  if (!length(bad)) return(empty)
  data.frame(scope = cut_syn$scope[bad], quintile = cut_syn$quintile[bad],
             condition_var = cut_syn$cond_var[bad], stringsAsFactors = FALSE)
}
