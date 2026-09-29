test_that("the national/urban example workbook parses", {
  tool <- et_parse_workbook(et_example())

  expect_s3_class(tool, "equitytool")
  expect_identical(tool$variant, "national_urban")
  expect_identical(et_vars(tool), paste0("Q", 1:8))
  expect_setequal(unique(et_scores(tool)$scope), c("national", "urban"))
  expect_setequal(et_scopes(tool), c("national", "urban"))
})

test_that("every scope has exactly four quintile cut-points", {
  tool <- et_parse_workbook(et_example())
  counts <- table(et_cutoffs(tool)$scope)
  expect_true(all(counts == 4))
  expect_setequal(et_cutoffs(tool)$quintile[et_cutoffs(tool)$scope == "national"], 2:5)
})

test_that("cut-points are strictly increasing with quintile", {
  tool <- et_parse_workbook(et_example())
  for (sc in et_scopes(tool)) {
    d <- et_cutoffs(tool)[et_cutoffs(tool)$scope == sc, ]
    d <- d[order(d$quintile), ]
    expect_true(all(diff(d$lower) > 0), info = sc)
  }
})

test_that("the syntax tab and the 'Other software' tab agree in the example", {
  tool <- et_parse_workbook(et_example())
  expect_equal(nrow(et_checks(tool)$mismatches), 0)
  expect_equal(nrow(et_checks(tool)$cutoff_mismatches), 0)
  expect_gt(et_checks(tool)$compared, 0)
})

test_that("question text and option labels come through, in English", {
  q <- et_questions(et_parse_workbook(et_example()))
  expect_true(all(c("var", "question", "option", "label") %in% names(q)))
  expect_true(any(grepl("electricity", q$question, ignore.case = TRUE)))
  # the local-language block is prefixed "[xx] " and must not have been chosen
  expect_false(any(grepl("^\\[xx\\]", q$question)))
})

test_that("a numeric option label is not mistaken for a score", {
  # Q8 option 3 is labelled with the literal digit "1", as in the real
  # Thailand workbook. It must appear as a label, never as a score.
  tool <- et_parse_workbook(et_example())
  q8 <- et_questions(tool)[et_questions(tool)$var == "Q8", ]
  expect_identical(q8$label[q8$option == 3], "1")
  s8 <- et_scores(tool)[et_scores(tool)$var == "Q8" & et_scores(tool)$scope == "national", ]
  expect_equal(nrow(s8), 3)
  expect_false(any(s8$score == 1))
})

test_that("the rural/urban example workbook parses with rescaling", {
  tool <- et_parse_workbook(et_example("rural_urban"))

  expect_identical(tool$variant, "rural_urban")
  expect_setequal(unique(et_scores(tool)$scope), c("rural", "urban"))
  expect_setequal(et_scopes(tool), c("national", "urban"))
  expect_setequal(tool$rescale$area, c("urban", "rural"))
  expect_true(all(is.finite(tool$rescale$intercept)))
  expect_true(all(is.finite(tool$rescale$slope)))
})

test_that("a non-EquityTool file is rejected with a useful message", {
  tmp <- withr::local_tempfile(fileext = ".xlsx")
  openxlsx_missing <- !requireNamespace("openxlsx", quietly = TRUE)
  skip_if(openxlsx_missing, "openxlsx not installed")
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sheet1")
  openxlsx::writeData(wb, "Sheet1", data.frame(a = 1:3))
  openxlsx::saveWorkbook(wb, tmp, overwrite = TRUE)

  expect_error(et_parse_workbook(tmp), "does not look like an EquityTool workbook")
})

test_that("a missing file errors clearly", {
  expect_error(et_parse_workbook("no_such_file.xlsx"), "File not found")
})

test_that("accessors reject non-tool input", {
  expect_error(et_vars(data.frame()), "must be an <equitytool> object")
  expect_error(et_score(data.frame(), "not a tool"), "must be an <equitytool> object")
})
