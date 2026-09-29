## Regression tests for the defect patterns found in the published corpus.
## Each builds a minimal workbook exhibiting the defect, so the behaviour is
## pinned without depending on any EquityTool file being present.

skip_if_not_installed("openxlsx")

write_wb <- function(path, spss, other = NULL, questionnaire = NULL) {
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Questionnaire")
  openxlsx::addWorksheet(wb, "SPSS Syntax")
  openxlsx::addWorksheet(wb, "Other software")
  if (is.null(questionnaire)) {
    questionnaire <- rbind(
      c("Variable name", "Question", "Option 1", "Option 2"),
      c("Q1", "Has electricity?", "Yes", "No"),
      c("Q2", "Has a fridge?", "Yes", "No")
    )
  }
  openxlsx::writeData(wb, "Questionnaire", questionnaire, colNames = FALSE)
  openxlsx::writeData(wb, "SPSS Syntax", matrix(spss, ncol = 1), colNames = FALSE)
  if (!is.null(other)) {
    openxlsx::writeData(wb, "Other software", other, colNames = FALSE)
  }
  openxlsx::saveWorkbook(wb, path, overwrite = TRUE)
  path
}

base_spss <- c(
  "recode Q1 (1=0.5) (2=-0.5)  INTO Q1_NAT.",
  "recode Q2 (1=0.3) (2=-0.3)  INTO Q2_NAT.",
  "compute NationalScore = Q1_NAT+Q2_NAT.",
  "DO IF NationalScore >=0.6.",
  "COMPUTE NationalQuintile =5.",
  "ELSE IF NationalScore >=0.2.",
  "COMPUTE NationalQuintile =4.",
  "ELSE IF NationalScore >=-0.2.",
  "COMPUTE NationalQuintile =3.",
  "ELSE IF NationalScore >=-0.6.",
  "COMPUTE NationalQuintile =2.",
  "ELSE IF NationalScore <-0.6.",
  "COMPUTE NationalQuintile =1.",
  "END IF."
)

test_that("SPSS statement-terminating periods do not break cut-point parsing", {
  # "DO IF NationalScore >=0.6." must give 0.6, not NA
  f <- write_wb(withr::local_tempfile(fileext = ".xlsx"), base_spss)
  tool <- et_parse_workbook(f, verbose = FALSE)
  cuts <- et_cutoffs(tool)
  expect_false(anyNA(cuts$lower))
  expect_equal(sort(cuts$lower), c(-0.6, -0.2, 0.2, 0.6))
})

test_that("quintile 1 is not treated as having a lower bound", {
  f <- write_wb(withr::local_tempfile(fileext = ".xlsx"), base_spss)
  tool <- et_parse_workbook(f, verbose = FALSE)
  expect_false(1 %in% et_cutoffs(tool)$quintile)
  expect_equal(nrow(et_cutoffs(tool)), 4)
})

test_that("a cut-point condition naming the wrong score variable is handled", {
  # The Djibouti EDAM 2017 pattern: the urban block opens with
  # `DO IF NationalScore >= x.` but assigns `UrbanQuintile = 5`.
  spss <- c(
    base_spss,
    "recode Q1 (1=0.4) (2=-0.4)  INTO Q1_URB.",
    "recode Q2 (1=0.2) (2=-0.2)  INTO Q2_URB.",
    "compute UrbanScore = Q1_URB+Q2_URB.",
    "DO IF NationalScore >=0.55.",          # <- names the wrong variable
    "COMPUTE UrbanQuintile =5.",
    "ELSE IF UrbanScore >=0.15.",
    "COMPUTE UrbanQuintile =4.",
    "ELSE IF UrbanScore >=-0.15.",
    "COMPUTE UrbanQuintile =3.",
    "ELSE IF UrbanScore >=-0.55.",
    "COMPUTE UrbanQuintile =2.",
    "END IF."
  )
  f <- write_wb(withr::local_tempfile(fileext = ".xlsx"), spss)
  tool <- et_parse_workbook(f, verbose = FALSE)

  # 0.55 must be recorded as the URBAN quintile-5 boundary
  urb <- et_cutoffs(tool)[et_cutoffs(tool)$scope == "urban", ]
  expect_equal(nrow(urb), 4)
  expect_equal(urb$lower[urb$quintile == 5], 0.55)

  # and the discrepancy must be reported, not silently swallowed
  ml <- et_checks(tool)$mislabelled_conditions
  expect_equal(nrow(ml), 1)
  expect_identical(ml$scope, "urban")
  expect_identical(ml$condition_var, "national")
})

test_that("scores disagreeing between the two tabs are flagged, syntax wins", {
  # The Cambodia DHS 2021 pattern: the printed table lists the options for one
  # question in a different order from the syntax.
  other <- rbind(
    c("", "Questions", "Use these variable names to store the national scores:",
      "Option 1:", "Option 1 national score:", "Option 2:", "Option 2 national score:"),
    c("Q1", "Has electricity?", "Q1_NAT", "Yes", "0.5", "No", "-0.5"),
    c("Q2", "Has a fridge?",    "Q2_NAT", "Yes", "-0.3", "No", "0.3")   # swapped
  )
  f <- write_wb(withr::local_tempfile(fileext = ".xlsx"), base_spss, other)

  expect_warning(tool <- et_parse_workbook(f), "differ between")

  tool <- et_parse_workbook(f, verbose = FALSE)
  mm <- et_checks(tool)$mismatches
  expect_equal(nrow(mm), 2)
  expect_true(all(mm$var == "Q2"))

  # the syntax value must be the one used
  s <- et_scores(tool)
  expect_equal(s$score[s$var == "Q2" & s$option == 1], 0.3)
})

test_that("a numeric option label in the printed table is not read as a score", {
  # The Thailand MICS 2019 pattern: an option is labelled with the digit "1".
  other <- rbind(
    c("", "Questions", "Use these variable names to store the national scores:",
      "Option 1:", "Option 1 national score:", "Option 2:", "Option 2 national score:"),
    c("Q1", "Has electricity?", "Q1_NAT", "Yes", "0.5", "1", "-0.5"),
    c("Q2", "Has a fridge?",    "Q2_NAT", "Yes", "0.3", "No", "-0.3")
  )
  f <- write_wb(withr::local_tempfile(fileext = ".xlsx"), base_spss, other)
  tool <- et_parse_workbook(f, verbose = FALSE)

  expect_equal(nrow(et_checks(tool)$mismatches), 0)
  s <- et_scores(tool)
  expect_equal(s$score[s$var == "Q1" & s$option == 2], -0.5)
})

test_that("a stale self-identifying comment loses the majority vote", {
  # The Djibouti pattern: one tab carries another country's name.
  spss <- c(
    "** The following syntax generates quintiles for people using the EquityTool for WrongCountryDHS1999",
    "**similar to those found in the RightCountryDHS2020 public shared file",
    base_spss
  )
  other <- rbind(
    c("", "similar to those found in the RightCountryDHS2020 public shared file")
  )
  f <- write_wb(withr::local_tempfile(fileext = ".xlsx"), spss, other)
  tool <- et_parse_workbook(f, verbose = FALSE)
  expect_identical(tool$survey, "RightCountryDHS2020")
})
