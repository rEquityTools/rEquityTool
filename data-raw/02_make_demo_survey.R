## data-raw/02_make_demo_survey.R
##
## Builds `demo_survey`, the small synthetic household survey used in examples,
## tests and the vignette. It is generated to match the fabricated example
## workbook in inst/extdata/, so the two can be used together.
##
## Run with:  source("data-raw/02_make_demo_survey.R")

set.seed(20260929)

n <- 600

regions <- c("North", "Central", "South", "East")
## regions differ in latent wealth, so the vignette has something to compare
region_mean <- c(North = -0.55, Central = 0.10, South = 0.55, East = -0.20)

region <- sample(regions, n, replace = TRUE, prob = c(0.28, 0.27, 0.25, 0.20))
residence <- ifelse(stats::runif(n) < 0.32, "urban", "rural")

latent <- stats::rnorm(n, mean = region_mean[region] + 0.45 * (residence == "urban"))

## answers: option 1 is the "wealthier" answer for Q1-Q6; Q7/Q8 are reversed
p <- stats::plogis(latent)
bin <- function(p) ifelse(stats::runif(n) < p, 1L, 2L)
tri <- function(p) cut(0.55 * stats::runif(n) + 0.45 * p,
                       breaks = c(-Inf, 0.38, 0.68, Inf), labels = FALSE)

demo_survey <- data.frame(
  hhid      = sprintf("HH%04d", seq_len(n)),
  region    = factor(region, levels = regions),
  residence = factor(residence, levels = c("urban", "rural")),
  Q1 = bin(p), Q2 = bin(p * 0.8), Q3 = bin(p * 0.9),
  Q4 = bin(p * 0.7), Q5 = bin(p * 0.6),
  Q6 = tri(p), Q7 = tri(1 - p), Q8 = tri(1 - p),
  stringsAsFactors = FALSE
)

## survey weights, correlated with residence to make weighting visibly matter
demo_survey$wt <- round(ifelse(demo_survey$residence == "urban", 0.6, 1.3) *
                          stats::rlnorm(n, 0, 0.25), 4)

## a binary outcome for the equity illustration in the vignette
demo_survey$improved_water <- stats::rbinom(n, 1, stats::plogis(-0.4 + 1.1 * latent))

## realistic data problems: a few missing answers and a few out-of-range codes
demo_survey$Q3[sample(n, 12)] <- NA
demo_survey$Q5[sample(n, 7)]  <- 9L    # "don't know", mis-coded
demo_survey$Q7[sample(n, 4)]  <- 0L    # skipped, mis-coded

demo_survey <- demo_survey[c("hhid", "region", "residence", "wt",
                             paste0("Q", 1:8), "improved_water")]

usethis::use_data(demo_survey, overwrite = TRUE)
message("Wrote data/demo_survey.rda  (", nrow(demo_survey), " rows)")
