tool <- et_parse_workbook(et_example())

test_that("validation finds the seeded problems in demo_survey", {
  chk <- et_validate(demo_survey, tool)

  expect_s3_class(chk, "equitytool_check")
  expect_length(chk$missing_columns, 0)

  items <- chk$items
  expect_equal(items$n_na[items$var == "Q3"], 12)
  expect_equal(items$n_invalid[items$var == "Q5"], 7)
  expect_equal(items$n_invalid[items$var == "Q7"], 4)
  expect_equal(items$invalid_values[items$var == "Q5"], "9")
})

test_that("the complete-record count matches what scoring keeps", {
  chk <- et_validate(demo_survey, tool)
  res <- et_score(demo_survey, tool, scope = "national")
  expect_equal(chk$n_complete, sum(!is.na(res$score)))
})

test_that("clean data validates clean", {
  clean <- demo_survey
  clean$Q3[is.na(clean$Q3)] <- 2L
  clean$Q5[!clean$Q5 %in% 1:2] <- 2L
  clean$Q7[!clean$Q7 %in% 1:3] <- 3L

  chk <- et_validate(clean, tool)
  expect_equal(sum(chk$items$n_na), 0)
  expect_equal(sum(chk$items$n_invalid), 0)
  expect_equal(chk$n_complete, nrow(clean))
})

test_that("missing columns are reported, not thrown", {
  d <- demo_survey[setdiff(names(demo_survey), c("Q2", "Q4"))]
  chk <- et_validate(d, tool)
  expect_setequal(chk$missing_columns, c("Q2", "Q4"))
  expect_true(is.na(chk$n_complete))
})

test_that("printing a check does not error", {
  expect_output(print(et_validate(demo_survey, tool)), "equitytool_check")
})

test_that("printing a tool does not error", {
  expect_output(print(tool), "equitytool")
  expect_output(summary(tool), "Quintile lower bounds")
})

test_that("weighted_quantile matches unweighted quantiles when weights are equal", {
  x <- c(5, 1, 4, 2, 3, 8, 7, 6, 9, 10)
  p <- c(0.2, 0.4, 0.6, 0.8)
  expect_equal(
    rEquityTool:::weighted_quantile(x, rep(1, length(x)), p),
    rEquityTool:::weighted_quantile(x, rep(3, length(x)), p)
  )
})

test_that("weighted_quantile shifts toward heavily weighted observations", {
  x <- c(1, 2, 3, 4, 5)
  lo <- rEquityTool:::weighted_quantile(x, c(10, 1, 1, 1, 1), 0.5)
  hi <- rEquityTool:::weighted_quantile(x, c(1, 1, 1, 1, 10), 0.5)
  expect_lt(lo, hi)
})

test_that("weighted_quantile ignores NA scores", {
  x <- c(1, 2, NA, 4, 5)
  expect_false(anyNA(rEquityTool:::weighted_quantile(x, NULL, c(0.25, 0.75))))
})
