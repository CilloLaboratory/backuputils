test_that("depot_s3_uri builds bucket URIs", {
  expect_identical(
    depot_s3_uri("project/run-01", bucket = "lab-bucket"),
    "s3://lab-bucket/project/run-01"
  )
})

test_that("depot_s3_uri rejects missing bucket", {
  expect_error(
    depot_s3_uri("project/run-01", bucket = ""),
    "bucket name is required"
  )
})

test_that("aws_sso_login validates profile names", {
  expect_error(
    aws_sso_login(""),
    "profile name"
  )
})

test_that("build_aws_sso_login_args constructs the device-code command", {
  expect_identical(
    build_aws_sso_login_args("cillo-lab"),
    c("sso", "login", "--use-device-code", "--profile", "cillo-lab")
  )
})

test_that("build_aws_sso_login_args can omit device-code mode", {
  expect_identical(
    build_aws_sso_login_args("cillo-lab", use_device_code = FALSE),
    c("sso", "login", "--profile", "cillo-lab")
  )
})

test_that("aws_copy validates manifest path before shelling out", {
  expect_error(
    aws_copy("missing-manifest.tsv"),
    "Manifest does not exist"
  )
})

test_that("aws_copy validates manifest structure", {
  manifest <- tempfile(fileext = ".tsv")
  on.exit(unlink(manifest), add = TRUE)
  writeLines("only_one_column", manifest)

  expect_error(
    aws_copy(manifest),
    "exactly two tab-delimited columns"
  )
})

test_that("aws_copy validates row source paths", {
  manifest <- tempfile(fileext = ".tsv")
  on.exit(unlink(manifest), add = TRUE)
  writeLines("missing.fastq.gz\ts3://bucket/project", manifest)

  expect_error(
    aws_copy(manifest),
    "Source does not exist"
  )
})

test_that("aws_copy parses headerless two-column manifests", {
  source <- tempfile(fileext = ".fastq.gz")
  manifest <- tempfile(fileext = ".tsv")
  on.exit(unlink(c(source, manifest)), add = TRUE)
  writeLines("seqdata", source)
  writeLines(sprintf("%s\ts3://bucket/project/run-01", source), manifest)

  parsed <- read_copy_manifest(manifest)

  expect_identical(parsed$source[[1]], source)
  expect_identical(parsed$destination_dir[[1]], "s3://bucket/project/run-01")
})

test_that("read_copy_manifest accepts two-column data frames", {
  source <- tempfile(fileext = ".fastq.gz")
  on.exit(unlink(source), add = TRUE)
  writeLines("seqdata", source)

  manifest <- data.frame(
    source = source,
    destination_dir = "s3://bucket/project/run-01",
    stringsAsFactors = FALSE
  )

  parsed <- read_copy_manifest(manifest)

  expect_identical(parsed$source[[1]], source)
  expect_identical(parsed$destination_dir[[1]], "s3://bucket/project/run-01")
})

test_that("prepare_copy_manifest appends source filename to destination directory", {
  source <- tempfile(fileext = ".fastq.gz")
  manifest <- tempfile(fileext = ".tsv")
  on.exit(unlink(c(source, manifest)), add = TRUE)
  writeLines("seqdata", source)
  writeLines(sprintf("%s\ts3://bucket/project/run-01/", source), manifest)

  parsed <- prepare_copy_manifest(manifest)

  expect_identical(
    parsed$destination[[1]],
    sprintf("s3://bucket/project/run-01/%s", basename(source))
  )
})

test_that("aws_copy places profile immediately after the destination path", {
  source <- tempfile(fileext = ".fastq.gz")
  manifest <- tempfile(fileext = ".tsv")
  on.exit(unlink(c(source, manifest)), add = TRUE)
  writeLines("seqdata", source)
  writeLines(sprintf("%s\ts3://bucket/project/run-01", source), manifest)

  captured_args <- NULL
  aws_copy_env <- environment(aws_copy)
  original_run_aws_command <- get("run_aws_command", envir = aws_copy_env)
  assign(
    "run_aws_command",
    function(args) {
      captured_args <<- args
      list(command = c("aws", args), status = 0L, stdout = character(), stderr = character())
    },
    envir = aws_copy_env
  )
  on.exit(
    assign("run_aws_command", original_run_aws_command, envir = aws_copy_env),
    add = TRUE
  )

  result <- aws_copy(
    manifest,
    profile = "input_profile",
    quiet = FALSE
  )

  expect_identical(
    result$uploads[[1]]$command,
    c("aws", captured_args)
  )
  expect_identical(
    captured_args,
    c(
      "s3",
      "cp",
      normalizePath(source, winslash = "/", mustWork = TRUE),
      sprintf("s3://bucket/project/run-01/%s", basename(source)),
      "--profile",
      "input_profile"
    )
  )
})

test_that("aws_copy tolerates a matching header row", {
  source <- tempfile(fileext = ".fastq.gz")
  manifest <- tempfile(fileext = ".tsv")
  on.exit(unlink(c(source, manifest)), add = TRUE)
  writeLines("seqdata", source)
  writeLines(
    c(
      "source\tdestination_dir",
      sprintf("%s\ts3://bucket/project/run-01", source)
    ),
    manifest
  )

  parsed <- read_copy_manifest(manifest)

  expect_identical(nrow(parsed), 1L)
  expect_identical(parsed$source[[1]], source)
})

test_that("aws_verify_copy validates manifest path before shelling out", {
  expect_error(
    aws_verify_copy("missing-manifest.tsv"),
    "Manifest does not exist"
  )
})

test_that("backup_fastqs validates manifest path before shelling out", {
  expect_error(
    backup_fastqs("missing-manifest.tsv"),
    "Manifest does not exist"
  )
})

test_that("normalize_manifest_reference marks data-frame inputs", {
  manifest <- data.frame(
    source = "/tmp/a.fastq.gz",
    destination_dir = "s3://bucket/run",
    stringsAsFactors = FALSE
  )

  expect_identical(normalize_manifest_reference(manifest), "<data.frame>")
})

test_that("resolve_backup_report_path validates explicit paths", {
  expect_error(
    resolve_backup_report_path(""),
    "report_path"
  )
})

test_that("build_backup_report returns one row per uploaded file", {
  copy_result <- list(
    manifest = "/tmp/manifest.tsv",
    uploads = list(
      list(source = "/tmp/a.fastq.gz", destination = "s3://bucket/run/a.fastq.gz", status = 0L),
      list(source = "/tmp/b.fastq.gz", destination = "s3://bucket/run/b.fastq.gz", status = 0L)
    )
  )
  verify_result <- list(
    verifications = list(
      list(ok = TRUE, local = list(total_bytes = 10), remote = list(total_bytes = 10)),
      list(ok = TRUE, local = list(total_bytes = 20), remote = list(total_bytes = 20))
    )
  )

  report <- build_backup_report(
    copy_result = copy_result,
    verify_result = verify_result,
    profile = "default",
    dry_run = FALSE,
    started_at = "2026-07-20T09:00:00-0400",
    finished_at = "2026-07-20T09:05:00-0400"
  )

  expect_identical(nrow(report), 2L)
  expect_identical(report$destination[[1]], "s3://bucket/run/a.fastq.gz")
  expect_identical(report$profile[[2]], "default")
  expect_identical(report$remote_bytes[[2]], 20)
})

test_that("write_backup_report writes a tab-delimited file", {
  report <- data.frame(
    manifest = "/tmp/manifest.tsv",
    source = "/tmp/a.fastq.gz",
    destination = "s3://bucket/run/a.fastq.gz",
    started_at = "2026-07-20T09:00:00-0400",
    finished_at = "2026-07-20T09:05:00-0400",
    profile = "",
    dry_run = FALSE,
    copy_status = 0L,
    verify_ok = TRUE,
    local_bytes = 10,
    remote_bytes = 10,
    stringsAsFactors = FALSE
  )
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)

  write_backup_report(report, path)
  written <- utils::read.delim(path, sep = "\t", stringsAsFactors = FALSE)

  expect_identical(nrow(written), 1L)
  expect_identical(written$destination[[1]], "s3://bucket/run/a.fastq.gz")
})
