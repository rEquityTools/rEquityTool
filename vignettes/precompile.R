## vignettes/precompile.R -----------------------------------------------------
##
## The Myanmar article uses a real EquityTool workbook, which the package must
## not redistribute. So that article is *pre-computed*: this script knits
##
##     vignettes/myanmar-worked-example.Rmd.orig   (live code)
##  -> vignettes/myanmar-worked-example.Rmd        (outputs baked in)
##
## and the baked .Rmd is what ships. `R CMD build` then only has to render
## already-computed markdown, so no EquityTool file is needed at build or check
## time. See https://ropensci.org/blog/2019/12/08/precompute-vignettes/
##
## Re-run this whenever the article or the package behaviour changes:
##
##     source("vignettes/precompile.R")
##
## Point it at your own download with either
##   * options(rEquityTool.myanmar = "path/to/Myanmar-...xlsx"), or
##   * Sys.setenv(EQUITYTOOL_MYANMAR = "path/to/Myanmar-...xlsx"), or
##   * the EQUITYTOOL_DIR env var, holding the folder you downloaded into.

library(knitr)

## Compatibility shim. knitr >= 1.52 calls `%||%` expecting it in base, but
## base gained `%||%` only in R 4.4.0, while knitr still declares R >= 3.6.0.
## On older R the lookup falls through to the global environment, so defining
## it here is enough. Harmless, and inert once R is 4.4 or newer.
if (getRversion() < "4.4.0" && !exists("%||%", envir = baseenv())) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}

## --- locate the Myanmar workbook --------------------------------------------

default_dir <- "C:/Users/Nicholus Tint Zaw/Documents/rEquityTools_Projects/EquityTool"

equitytool_dir <- Sys.getenv("EQUITYTOOL_DIR", unset = default_dir)

myanmar_path <- getOption(
  "rEquityTool.myanmar",
  Sys.getenv("EQUITYTOOL_MYANMAR", unset = "")
)
if (!nzchar(myanmar_path)) {
  hits <- list.files(file.path(equitytool_dir, "Myanmar"),
                     pattern = "[.]xlsx?$", full.names = TRUE)
  hits <- hits[!grepl("^~\\$", basename(hits))]
  if (!length(hits)) {
    stop("Could not find the Myanmar workbook.\n",
         "Set options(rEquityTool.myanmar = ) or EQUITYTOOL_MYANMAR to the ",
         "downloaded file, or EQUITYTOOL_DIR to the folder holding it.\n",
         "Looked in: ", file.path(equitytool_dir, "Myanmar"))
  }
  myanmar_path <- hits[[1]]
}
message("Using workbook: ", myanmar_path)

## release date, read off the file name (e.g. ...-2018-08-30.xlsx)
myanmar_release <- regmatches(
  basename(myanmar_path),
  regexpr("[0-9]{4}-[0-9]{2}-[0-9]{2}", basename(myanmar_path))
)
if (!length(myanmar_release)) myanmar_release <- "see file name"

## --- simulate the survey used in the article --------------------------------
##
## Real household data is not ours to publish. This stands in for it: a survey
## of poor, remote townships, so the national/sample cut-point contrast in the
## article is the one that actually arises in practice.

make_survey <- function(n = 800) {
  set.seed(20260929)
  townships <- c("Hpapun", "Kyainseikgyi", "Hlaingbwe", "Myawaddy", "Kawkareik")
  township_mean <- c(Hpapun = -1.15, Kyainseikgyi = -0.75, Hlaingbwe = -0.55,
                     Myawaddy = -0.10, Kawkareik = -0.65)

  township <- sample(townships, n, replace = TRUE,
                     prob = c(0.24, 0.22, 0.20, 0.14, 0.20))
  residence <- ifelse(stats::runif(n) < 0.13, "urban", "rural")
  latent <- stats::rnorm(n, township_mean[township] + 0.8 * (residence == "urban"),
                         sd = 0.85)
  p <- stats::plogis(latent)

  bin <- function(mult) ifelse(stats::runif(n) < p * mult, 1L, 2L)

  svy <- data.frame(
    hhid      = sprintf("MM%04d", seq_len(n)),
    township  = factor(township, levels = townships),
    residence = factor(residence, levels = c("urban", "rural")),
    Q1  = bin(0.85),  # television
    Q2  = bin(1.05),  # mobile telephone
    Q3  = bin(0.35),  # refrigerator
    Q4  = bin(0.95),  # table
    Q5  = bin(0.95),  # chair
    Q6  = bin(0.90),  # bed
    Q7  = bin(0.70),  # cupboard
    Q8  = bin(0.55),  # electric fan
    Q9  = bin(0.18),  # computer
    Q10 = bin(0.80),  # watch
    Q11 = bin(0.30),  # bank account
    Q12 = bin(0.25),  # bottled drinking water
    Q13 = bin(0.30),  # cement floor
    Q14 = bin(0.75),  # meshed bamboo walls
    stringsAsFactors = FALSE
  )
  # Q15: cooking fuel, 1 electricity / 2 wood / 3 other
  svy$Q15 <- ifelse(stats::runif(n) < p * 0.22, 1L,
                    ifelse(stats::runif(n) < 0.85, 2L, 3L))

  svy$wt <- round(ifelse(svy$residence == "urban", 0.55, 1.25) *
                    stats::rlnorm(n, 0, 0.3), 4)
  svy$improved_water <- stats::rbinom(n, 1, stats::plogis(-0.5 + 1.0 * latent))

  # realistic field problems
  svy$Q9[sample(n, 9)]   <- NA
  svy$Q11[sample(n, 14)] <- 9L   # "don't know", mis-coded
  svy$Q12[sample(n, 5)]  <- NA
  svy
}

svy <- make_survey()

## --- knit --------------------------------------------------------------------

orig <- "vignettes/myanmar-worked-example.Rmd.orig"
out  <- "vignettes/myanmar-worked-example.Rmd"
if (!file.exists(orig)) stop("Run this from the package root. Missing: ", orig)

knitr::opts_chunk$set(error = FALSE)
knitr::knit(orig, out, quiet = FALSE)

message("Wrote ", out)
message("Now rebuild the package so the vignette is picked up.")
