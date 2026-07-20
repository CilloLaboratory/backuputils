pkg_r_files <- list.files(
  file.path(testthat::test_path("..", ".."), "R"),
  pattern = "\\.[Rr]$",
  full.names = TRUE
)

invisible(lapply(pkg_r_files, source, local = FALSE))
