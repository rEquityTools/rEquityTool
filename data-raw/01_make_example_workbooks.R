## data-raw/01_make_example_workbooks.R
##
## Builds the two fabricated EquityTool-format workbooks shipped in
## inst/extdata/. They exist so that examples, tests and the vignette can
## exercise the parser without redistributing any material from
## https://equitytool.org.
##
## EVERY NUMBER IN THESE FILES IS MADE UP. They must never be used to produce
## real wealth estimates.
##
## The layout deliberately reproduces the quirks of the real corpus:
##   * a local-language questionnaire block followed by an English one;
##   * scores stated twice (SPSS syntax + "Other software" table);
##   * an option whose *label* is the digit "1" (as in the real Thailand
##     workbook), which breaks naive positional parsing;
##   * a rural/urban variant with linear rescaling onto a national scale
##     (as in the real Afghanistan, Ethiopia, Vietnam, ... workbooks).
##
## Run with:  source("data-raw/01_make_example_workbooks.R")

library(openxlsx)
set.seed(2026)

out_dir <- "inst/extdata"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

## ---------------------------------------------------------------- questions --

questions <- list(
  Q1 = list(text = "Does your household have... electricity?",     opts = c("Yes", "No")),
  Q2 = list(text = "... a refrigerator?",                          opts = c("Yes", "No")),
  Q3 = list(text = "... a television?",                            opts = c("Yes", "No")),
  Q4 = list(text = "... a motorcycle or scooter?",                 opts = c("Yes", "No")),
  Q5 = list(text = "Does any member of your household have a bank account?",
            opts = c("Yes", "No")),
  Q6 = list(text = "What is the main material of the floor of your dwelling?",
            opts = c("Cement", "Earth or sand", "Other")),
  Q7 = list(text = "What type of fuel does your household mainly use for cooking?",
            opts = c("Electricity or gas", "Wood", "Other")),
  ## Option 3's label is the literal digit "1" -- mirrors the real Thailand
  ## workbook and guards against positional score scraping.
  Q8 = list(text = "How many rooms are used for sleeping?",
            opts = c("Three or more", "Two", "1"))
)

## a pretend "local language" rendering, to exercise the English-block picker
local_text <- paste0("[xx] ", vapply(questions, `[[`, "", "text"))

## ------------------------------------------------------------------- scores --

## Fabricated weights: option 1 is the "wealthier" answer for Q1-Q6, reversed
## for Q7-Q8, so the index is not trivially monotone in the response codes.
make_scores <- function(seed, spread) {
  set.seed(seed)
  res <- list()
  for (q in names(questions)) {
    k <- length(questions[[q]]$opts)
    v <- sort(stats::runif(k, -spread, spread), decreasing = !q %in% c("Q7", "Q8"))
    res[[q]] <- round(v, 12)
  }
  res
}

nat_scores <- make_scores(101, 0.30)
urb_scores <- make_scores(202, 0.22)
rur_scores <- make_scores(303, 0.26)

## ---------------------------------------------- cut-points from a pretend pop --

## Simulate a large "national population" so the published cut-points are the
## quintile boundaries of a coherent distribution. This makes the example
## behave like a real tool: a representative sample lands ~20% per quintile.
simulate_pop <- function(n, scores, tilt = 0) {
  wealth <- stats::rnorm(n)
  ans <- lapply(names(questions), function(q) {
    k <- length(questions[[q]]$opts)
    p <- stats::plogis(wealth + tilt)
    if (k == 2L) {
      ifelse(stats::runif(n) < p, 1L, 2L)
    } else {
      cut(stats::runif(n) * 0.6 + p * 0.4, breaks = c(-Inf, 0.4, 0.7, Inf),
          labels = FALSE)
    }
  })
  names(ans) <- names(questions)
  ans <- as.data.frame(ans)
  rowSums(vapply(names(questions), function(q) scores[[q]][ans[[q]]],
                 numeric(n)))
}

set.seed(11)
nat_pop <- simulate_pop(40000, nat_scores)
urb_pop <- simulate_pop(15000, urb_scores, tilt = 0.9)
nat_cuts <- unname(stats::quantile(nat_pop, c(0.2, 0.4, 0.6, 0.8)))
urb_cuts <- unname(stats::quantile(urb_pop, c(0.2, 0.4, 0.6, 0.8)))

## --------------------------------------------------------- sheet builders ----

pad <- function(x, n) c(x, rep("", max(0, n - length(x))))

questionnaire_sheet <- function() {
  ncol <- 5
  rows <- list(
    pad(c("", "Instructions:"), ncol),
    pad(c("", "Below are the questions that should be used. Option 1 should be coded '1', option 2 coded '2', and so on."), ncol),
    pad(c(""), ncol),
    pad(c("Variable name", "Question", "Option 1", "Option 2", "Option 3 (if applicable)"), ncol)
  )
  for (i in seq_along(questions)) {
    q <- names(questions)[i]
    rows[[length(rows) + 1]] <- pad(c(q, local_text[i], questions[[q]]$opts), ncol)
  }
  rows[[length(rows) + 1]] <- pad("", ncol)
  rows[[length(rows) + 1]] <- pad(c("Translated into:", "English"), ncol)
  for (q in names(questions)) {
    rows[[length(rows) + 1]] <- pad(c(q, questions[[q]]$text, questions[[q]]$opts), ncol)
  }
  do.call(rbind, rows)
}

recode_line <- function(q, scores, suffix) {
  parts <- paste0("(", seq_along(scores[[q]]), "=",
                  format(scores[[q]], digits = 15, scientific = FALSE), ")",
                  collapse = " ")
  paste0("recode ", q, " ", parts, "  INTO ", q, "_", suffix, ".")
}

doif_block <- function(cuts, name) {
  n <- length(cuts) + 1L
  ord <- sort(cuts, decreasing = TRUE)
  out <- c(sprintf("DO IF %s >=%s.", name, format(ord[1], digits = 15)),
           sprintf("COMPUTE %sQuintile =%d.", sub("Score", "", name), n))
  for (i in 2:length(ord)) {
    out <- c(out,
             sprintf("ELSE IF %s >=%s.", name, format(ord[i], digits = 15)),
             sprintf("COMPUTE %sQuintile =%d.", sub("Score", "", name), n - i + 1L))
  }
  c(out,
    sprintf("ELSE IF %s <%s.", name, format(ord[length(ord)], digits = 15)),
    sprintf("COMPUTE %sQuintile =1.", sub("Score", "", name)),
    "END IF.")
}

sum_line <- function(suffix, name, invert = FALSE) {
  terms <- paste0(names(questions), "_", suffix, collapse = "+")
  if (invert) sprintf("compute %s =0-( %s).", name, terms)
  else        sprintf("compute %s = %s.", name, terms)
}

spss_sheet_national_urban <- function() {
  txt <- c(
    "Copy the following to an SPSS syntax file and run it on your data.",
    "** FABRICATED EXAMPLE FILE - NOT REAL EQUITYTOOL DATA.",
    "** This syntax assumes you used the variable names and coding on the 'Questionnaire' tab",
    "** of the file 'Example Country DHS 2020 public file.xlsx'.",
    "",
    "** NATIONAL QUINTILE SYNTAX",
    "** The following syntax generates national wealth quintiles for people using the EquityTool for ExampleCountryDHS2020",
    vapply(names(questions), recode_line, "", scores = nat_scores, suffix = "NAT"),
    "",
    sum_line("NAT", "NationalScore"),
    "",
    doif_block(nat_cuts, "NationalScore"),
    "",
    "** URBAN QUINTILE SYNTAX",
    vapply(names(questions), recode_line, "", scores = urb_scores, suffix = "URB"),
    "",
    sum_line("URB", "UrbanScore"),
    "",
    doif_block(urb_cuts, "UrbanScore")
  )
  matrix(unname(txt), ncol = 1)
}

other_block <- function(scores, scope) {
  maxk <- max(vapply(questions, function(q) length(q$opts), 1L))
  hdr <- c("", "Questions",
           sprintf("Use these variable names to store the %s scores", scope))
  for (k in seq_len(maxk)) {
    hdr <- c(hdr, sprintf("Option %d:", k), sprintf("Option %d %s score:", k, scope))
  }
  rows <- list(hdr)
  for (q in names(questions)) {
    r <- c(q, questions[[q]]$text, paste0(q, "_", toupper(substr(scope, 1, 3))))
    for (k in seq_len(maxk)) {
      if (k <= length(questions[[q]]$opts)) {
        r <- c(r, questions[[q]]$opts[k],
               format(scores[[q]][k], digits = 15, scientific = FALSE))
      } else {
        r <- c(r, "", "")
      }
    }
    rows[[length(rows) + 1]] <- r
  }
  do.call(rbind, rows)
}

cut_block <- function(cuts, scope) {
  n <- ncol_pad <- NULL
  rows <- list(c("", sprintf("Lower limits for each %s quintile", scope), ""))
  rows[[2]] <- c("", "Quintile 1", "Lowest score")
  ord <- sort(cuts)
  for (i in seq_along(ord)) {
    rows[[i + 2]] <- c("", sprintf("Quintile %d", i + 1L),
                       format(ord[i], digits = 15, scientific = FALSE))
  }
  do.call(rbind, rows)
}

bind_ragged <- function(...) {
  bits <- list(...)
  bits <- bits[!vapply(bits, is.null, logical(1))]
  w <- max(vapply(bits, ncol, 1L))
  do.call(rbind, lapply(bits, function(m) {
    if (ncol(m) < w) cbind(m, matrix("", nrow(m), w - ncol(m))) else m
  }))
}

blank <- function(n = 2, w = 1) matrix("", n, w)

other_sheet_national_urban <- function() {
  bind_ragged(
    matrix(c("", "FABRICATED EXAMPLE - NOT REAL EQUITYTOOL DATA."), 1),
    matrix(c("", "Be sure to give the code 1 for answers corresponding to Option 1, 2 for Option 2 and 3 for Option 3."), 1),
    blank(1),
    other_block(nat_scores, "national"),
    blank(2),
    cut_block(nat_cuts, "national"),
    blank(2),
    matrix(c("", "Below are the same figures for urban quintiles."), 1),
    other_block(urb_scores, "urban"),
    blank(2),
    cut_block(urb_cuts, "urban")
  )
}

## ------------------------------------------------- workbook 1: national/urban --

wb <- createWorkbook()
addWorksheet(wb, "Questionnaire")
addWorksheet(wb, "SPSS Syntax")
addWorksheet(wb, "Other software")
writeData(wb, "Questionnaire",  questionnaire_sheet(),           colNames = FALSE)
writeData(wb, "SPSS Syntax",    spss_sheet_national_urban(),     colNames = FALSE)
writeData(wb, "Other software", other_sheet_national_urban(),    colNames = FALSE)
saveWorkbook(wb, file.path(out_dir, "equitytool_example_workbook.xlsx"), overwrite = TRUE)

## --------------------------------------------------- workbook 2: rural/urban --

## rescaling coefficients, fabricated but in the style of the real corpus
resc <- list(urban = c(1.184210, 0.913400), rural = c(-0.402610, 0.664820))

set.seed(21)
rur_pop <- simulate_pop(25000, rur_scores, tilt = -0.6)
urb_pop2 <- simulate_pop(12000, urb_scores, tilt = 0.9)
nat_pop2 <- c(resc$urban[1] + resc$urban[2] * urb_pop2,
              resc$rural[1] + resc$rural[2] * rur_pop)
nat_cuts2 <- unname(stats::quantile(nat_pop2, c(0.2, 0.4, 0.6, 0.8)))
urb_cuts2 <- unname(stats::quantile(urb_pop2, c(0.2, 0.4, 0.6, 0.8)))

spss_sheet_rural_urban <- function() {
  txt <- c(
    "Copy the following to an SPSS syntax file and run it on your data.",
    "** FABRICATED EXAMPLE FILE - NOT REAL EQUITYTOOL DATA.",
    "** This syntax assumes that your dataset includes a variable called UrbanM4M indicating whether each respondent lives in an urban or rural area,",
    "** where 'urban' is coded 1 and 'rural' is coded 2.",
    "",
    "** RURAL SCORE SYNTAX",
    vapply(names(questions), recode_line, "", scores = rur_scores, suffix = "RUR"),
    "",
    sprintf("if (UrbanM4M =2)   RuralScore = %s.",
            paste0(names(questions), "_RUR", collapse = "+")),
    "",
    "** URBAN QUINTILE SYNTAX",
    vapply(names(questions), recode_line, "", scores = urb_scores, suffix = "URB"),
    "",
    sprintf("if (UrbanM4M =1)  UrbanScore = %s.",
            paste0(names(questions), "_URB", collapse = "+")),
    "",
    "** Calculate national scores based on the urban and rural scores.",
    sprintf("if (UrbanM4M =1)   NationalScore = %s+%s*UrbanScore.",
            format(resc$urban[1], digits = 15), format(resc$urban[2], digits = 15)),
    sprintf("if (UrbanM4M =2)   NationalScore = %s+%s*RuralScore.",
            format(resc$rural[1], digits = 15), format(resc$rural[2], digits = 15)),
    "",
    doif_block(nat_cuts2, "NationalScore"),
    "",
    doif_block(urb_cuts2, "UrbanScore")
  )
  matrix(unname(txt), ncol = 1)
}

wb2 <- createWorkbook()
addWorksheet(wb2, "Questionnaire")
addWorksheet(wb2, "SPSS Syntax")
addWorksheet(wb2, "Other software")
writeData(wb2, "Questionnaire", questionnaire_sheet(), colNames = FALSE)
writeData(wb2, "SPSS Syntax",   spss_sheet_rural_urban(), colNames = FALSE)
writeData(wb2, "Other software",
          bind_ragged(
            matrix(c("", "FABRICATED EXAMPLE - NOT REAL EQUITYTOOL DATA."), 1),
            blank(1),
            other_block(rur_scores, "rural"),
            blank(2),
            other_block(urb_scores, "urban"),
            blank(2),
            cut_block(nat_cuts2, "national"),
            blank(2),
            cut_block(urb_cuts2, "urban")
          ),
          colNames = FALSE)
saveWorkbook(wb2, file.path(out_dir, "equitytool_example_rural_urban.xlsx"),
             overwrite = TRUE)

message("Wrote ", file.path(out_dir, "equitytool_example_workbook.xlsx"))
message("Wrote ", file.path(out_dir, "equitytool_example_rural_urban.xlsx"))
