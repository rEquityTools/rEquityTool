tool <- et_parse_workbook(et_example())

test_that("scoring returns one row per input row", {
  res <- et_score(demo_survey, tool, scope = "national")
  expect_equal(nrow(res), nrow(demo_survey))
  expect_true(all(c("score", "quintile") %in% names(res)))
  expect_s3_class(res$quintile, "ordered")
  expect_identical(levels(res$quintile),
                   c("Poorest", "Poorer", "Middle", "Richer", "Richest"))
})

test_that("the score is the sum of the item scores for a known row", {
  s <- et_scores(tool)
  s <- s[s$scope == "national", ]
  row <- demo_survey[1, ]
  manual <- sum(vapply(paste0("Q", 1:8), function(q) {
    sv <- s[s$var == q, ]
    sv$score[match(row[[q]], sv$option)]
  }, numeric(1)))

  res <- et_score(demo_survey, tool, scope = "national")
  expect_equal(res$score[1], manual)
})

test_that("quintiles follow the published cut-points exactly", {
  res <- et_score(demo_survey, tool, scope = "national")
  cuts <- sort(et_cutoffs(tool)$lower[et_cutoffs(tool)$scope == "national"])
  ok <- !is.na(res$score)
  expected <- vapply(res$score[ok], function(v) sum(v >= cuts) + 1L, integer(1))
  expect_equal(as.integer(res$quintile[ok]), expected)
})

test_that("incomplete records get NA under the official rule", {
  res <- et_score(demo_survey, tool, scope = "national")
  # demo_survey has 12 NA in Q3, 7 invalid in Q5, 4 invalid in Q7
  bad <- is.na(demo_survey$Q3) | !demo_survey$Q5 %in% 1:2 | !demo_survey$Q7 %in% 1:3
  expect_true(all(is.na(res$score[bad])))
  expect_true(all(!is.na(res$score[!bad])))
  expect_equal(sum(is.na(res$quintile)), sum(bad))
})

test_that("na_rule = 'partial' scores every row instead", {
  res <- et_score(demo_survey, tool, scope = "national", na_rule = "partial")
  expect_equal(sum(is.na(res$score)), 0)
})

test_that("sample scope produces approximately equal groups", {
  res <- et_score(demo_survey, tool, scope = "sample")
  tab <- table(res$quintile)
  n <- sum(tab)
  expect_length(tab, 5)
  # each group should be within a few percentage points of a fifth
  expect_true(all(abs(tab / n - 0.2) < 0.05))
})

test_that("sample scope respects weights", {
  unw <- et_score(demo_survey, tool, scope = "sample")
  wtd <- et_score(demo_survey, tool, scope = "sample", weights = "wt")
  expect_false(identical(attr(unw, "cutoffs"), attr(wtd, "cutoffs")))
  expect_length(attr(wtd, "cutoffs"), 4)
})

test_that("national and sample scopes give the same score but different groups", {
  nat <- et_score(demo_survey, tool, scope = "national")
  smp <- et_score(demo_survey, tool, scope = "sample")
  expect_equal(nat$score, smp$score)
  expect_false(identical(nat$quintile, smp$quintile))
})

test_that("probs controls the number of sample groups", {
  res <- et_score(demo_survey, tool, scope = "sample", probs = c(1, 2) / 3)
  expect_identical(levels(res$quintile), c("Lowest", "Middle", "Highest"))
  expect_equal(length(unique(stats::na.omit(res$quintile))), 3)
})

test_that("append = TRUE keeps the original columns", {
  res <- et_score(demo_survey, tool, scope = "national", append = TRUE)
  expect_true(all(names(demo_survey) %in% names(res)))
  expect_equal(nrow(res), nrow(demo_survey))
})

test_that("a partial vars mapping overrides only the renamed column", {
  d <- demo_survey
  names(d)[names(d) == "Q1"] <- "electricity"
  expect_error(et_score(d, tool, scope = "national"), "Columns not found")

  res <- et_score(d, tool, scope = "national", vars = c(Q1 = "electricity"))
  ref <- et_score(demo_survey, tool, scope = "national")
  expect_equal(res$score, ref$score)
})

test_that("vars pointing at a missing column errors", {
  expect_error(
    et_score(demo_survey, tool, scope = "national", vars = c(Q1 = "nope")),
    "not in `data`"
  )
})

test_that("an unavailable scope errors with the available ones listed", {
  expect_error(et_score(demo_survey, tool, scope = "rural"),
               "no 'rural' scores")
})

## ---- rural/urban tools ------------------------------------------------------

ru <- et_parse_workbook(et_example("rural_urban"))

test_that("rural/urban tools require an area indicator", {
  expect_error(et_score(demo_survey, ru, scope = "national"),
               "rural/urban tool")
})

test_that("rural/urban scoring applies the published rescaling", {
  res <- et_score(demo_survey, ru, scope = "national", area = "residence")
  expect_true("area_score" %in% names(res))

  urb <- demo_survey$residence == "urban"
  i <- which(urb & !is.na(res$score))[1]
  co <- ru$rescale
  expect_equal(res$score[i],
               co$intercept[co$area == "urban"] +
                 co$slope[co$area == "urban"] * res$area_score[i])

  j <- which(!urb & !is.na(res$score))[1]
  expect_equal(res$score[j],
               co$intercept[co$area == "rural"] +
                 co$slope[co$area == "rural"] * res$area_score[j])
})

test_that("area accepts codes, words and a bare vector", {
  a <- et_score(demo_survey, ru, scope = "national", area = "residence")
  b <- et_score(demo_survey, ru, scope = "national",
                area = ifelse(demo_survey$residence == "urban", 1L, 2L))
  c3 <- et_score(demo_survey, ru, scope = "national",
                 area = toupper(as.character(demo_survey$residence)))
  expect_equal(a$score, b$score)
  expect_equal(a$score, c3$score)
})

test_that("an uninterpretable area errors", {
  expect_error(
    et_score(demo_survey, ru, scope = "national", area = rep("village", nrow(demo_survey))),
    "Could not interpret"
  )
})

test_that("a wrong-length area errors", {
  expect_error(et_score(demo_survey, ru, scope = "national", area = c("urban", "rural")),
               "one value per row")
})

test_that("rural/urban tools have no published rural quintiles", {
  expect_error(et_score(demo_survey, ru, scope = "rural", area = "residence"),
               "does not publish 'rural' quintile cut-points")
})
