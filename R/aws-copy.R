#' Build a depot S3 URI
#'
#' Creates an S3 URI from a bucket name and optional key prefix. This is a small
#' convenience wrapper so higher-level workflows do not need to manually stitch
#' paths together.
#'
#' @param key Character scalar key or prefix inside the bucket.
#' @param bucket Character scalar bucket name. Defaults to the
#'   `CILLO_AWS_BUCKET` environment variable when set.
#'
#' @return A character scalar S3 URI.
depot_s3_uri <- function(key = "", bucket = Sys.getenv("CILLO_AWS_BUCKET", "")) {
  if (!nzchar(bucket)) {
    stop(
      "A bucket name is required. Supply `bucket` or set `CILLO_AWS_BUCKET`.",
      call. = FALSE
    )
  }

  key <- sub("^/+", "", key)

  if (!nzchar(key)) {
    return(sprintf("s3://%s", bucket))
  }

  sprintf("s3://%s/%s", bucket, key)
}

#' Authenticate with AWS SSO for a named profile
#'
#' Wraps `aws sso login --use-device-code --profile ...` so package users can
#' start an AWS SSO session from R before running backup commands.
#'
#' @param profile Character scalar AWS profile name.
#' @param use_device_code Logical indicating whether to include
#'   `--use-device-code`. Defaults to `TRUE`.
#'
#' @return A list containing the executed command and exit status.
#' @export
aws_sso_login <- function(profile, use_device_code = TRUE) {
  args <- build_aws_sso_login_args(profile, use_device_code = use_device_code)
  run_aws_command_interactive(args)
}

#' Copy FASTQ files to S3 from a tab-delimited manifest
#'
#' Reads a two-column tab-delimited text file and performs one `aws s3 cp`
#' operation per row. Column 1 must be the local FASTQ path. Column 2 must be
#' the target S3 directory. The local filename is appended to the target
#' directory automatically.
#'
#' @param manifest Path to a tab-delimited text file with two columns:
#'   local source path and remote S3 directory.
#' @param has_header Logical indicating whether the manifest includes a header
#'   row. When `FALSE`, the function will still ignore a leading header row if
#'   it looks like one.
#' @param profile Optional AWS profile name.
#' @param extra_args Optional character vector of extra `aws s3 cp` arguments.
#' @param dry_run Logical indicating whether to append `--dryrun`.
#' @param quiet Logical indicating whether to suppress normal AWS CLI progress
#'   output with `--only-show-errors`.
#'
#' @return A list with the parsed manifest and one command result per uploaded
#'   file. An error is raised if any row is invalid or any command fails.
#' @export
aws_copy <- function(
  manifest,
  has_header = FALSE,
  profile = NULL,
  extra_args = character(),
  dry_run = FALSE,
  quiet = TRUE
) {
  manifest_data <- prepare_copy_manifest(manifest, has_header = has_header)
  uploads <- lapply(seq_len(nrow(manifest_data)), function(i) {
    source <- manifest_data$source[[i]]
    destination <- manifest_data$destination[[i]]

    args <- c("s3", "cp", normalizePath(source, winslash = "/", mustWork = TRUE), destination)

    if (isTRUE(dry_run)) {
      args <- c(args, "--dryrun")
    }

    if (isTRUE(quiet)) {
      args <- c(args, "--only-show-errors")
    }

    if (!is.null(profile)) {
      args <- c(args, "--profile", profile)
    }

    if (length(extra_args) > 0) {
      args <- c(args, extra_args)
    }

    result <- run_aws_command(args)
    result$source <- source
    result$destination <- destination
    result
  })

  list(
    manifest = normalizePath(manifest, winslash = "/", mustWork = TRUE),
    plan = manifest_data,
    uploads = uploads
  )
}

#' Copy and verify FASTQ backups from a tab-delimited manifest
#'
#' Runs [aws_copy()] and then [aws_verify_copy()] against the same two-column
#' manifest so the common FASTQ backup workflow can be executed in one call.
#'
#' @param manifest Path to a tab-delimited text file with two columns:
#'   local source path and remote S3 directory.
#' @param has_header Logical indicating whether the manifest includes a header
#'   row. When `FALSE`, the function will still ignore a leading header row if
#'   it looks like one.
#' @param profile Optional AWS profile name.
#' @param extra_args Optional character vector of extra `aws s3 cp` arguments.
#' @param dry_run Logical indicating whether to append `--dryrun` during copy.
#' @param quiet Logical indicating whether to suppress normal AWS CLI progress
#'   output with `--only-show-errors`.
#' @param report_path Optional path for a tab-delimited run report. When `NULL`,
#'   a timestamped report is written in the working directory.
#'
#' @return A list containing both the upload results and verification results.
#'   An error is raised if either step fails.
#' @export
backup_fastqs <- function(
  manifest,
  has_header = FALSE,
  profile = NULL,
  extra_args = character(),
  dry_run = FALSE,
  quiet = TRUE,
  report_path = NULL
) {
  started_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  copy_result <- aws_copy(
    manifest = manifest,
    has_header = has_header,
    profile = profile,
    extra_args = extra_args,
    dry_run = dry_run,
    quiet = quiet
  )

  verify_result <- aws_verify_copy(
    manifest = manifest,
    has_header = has_header,
    profile = profile
  )

  finished_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  resolved_report_path <- resolve_backup_report_path(report_path)
  report_data <- build_backup_report(
    copy_result = copy_result,
    verify_result = verify_result,
    profile = profile,
    dry_run = dry_run,
    started_at = started_at,
    finished_at = finished_at
  )
  write_backup_report(report_data, resolved_report_path)

  list(
    manifest = copy_result$manifest,
    plan = copy_result$plan,
    copy = copy_result,
    verify = verify_result,
    report_path = resolved_report_path,
    report = report_data
  )
}
