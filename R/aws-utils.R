assert_existing_source <- function(path, recursive) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("`source` must be a single non-empty path.", call. = FALSE)
  }

  if (!file.exists(path)) {
    stop(sprintf("Source does not exist: %s", path), call. = FALSE)
  }

  if (isTRUE(recursive) && !dir.exists(path)) {
    stop("`recursive = TRUE` requires `source` to be a directory.", call. = FALSE)
  }

  if (!isTRUE(recursive) && dir.exists(path)) {
    stop("Directory sources require `recursive = TRUE`.", call. = FALSE)
  }
}

assert_existing_file <- function(path, what = "path") {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop(sprintf("`%s` must be a single non-empty path.", what), call. = FALSE)
  }

  if (!file.exists(path)) {
    stop(sprintf("%s does not exist: %s", tools::toTitleCase(what), path), call. = FALSE)
  }

  if (dir.exists(path)) {
    stop(sprintf("`%s` must be a file, not a directory.", what), call. = FALSE)
  }
}

assert_s3_uri <- function(x) {
  if (!is.character(x) || length(x) != 1L || !grepl("^s3://[^/]+(/.*)?$", x)) {
    stop("`destination` must be a valid S3 URI such as `s3://bucket/key`.", call. = FALSE)
  }
}

assert_s3_directory_uri <- function(x) {
  if (!is.character(x) || length(x) != 1L || !grepl("^s3://[^/]+(/.*)?$", x)) {
    stop(
      "`destination` must be a valid S3 directory URI such as `s3://bucket/prefix`.",
      call. = FALSE
    )
  }
}

aws_binary <- function() {
  path <- Sys.which("aws")

  if (!nzchar(path)) {
    stop("AWS CLI was not found on the PATH.", call. = FALSE)
  }

  path
}

assert_profile_name <- function(profile) {
  if (!is.character(profile) || length(profile) != 1L || !nzchar(trimws(profile))) {
    stop("`profile` must be a single non-empty AWS profile name.", call. = FALSE)
  }
}

build_aws_sso_login_args <- function(profile, use_device_code = TRUE) {
  assert_profile_name(profile)

  args <- c("sso", "login")

  if (isTRUE(use_device_code)) {
    args <- c(args, "--use-device-code")
  }

  c(args, "--profile", trimws(profile))
}

run_aws_command <- function(args) {
  stdout <- character()
  stderr <- character()

  status <- system2(
    command = aws_binary(),
    args = args,
    stdout = TRUE,
    stderr = TRUE
  )

  result <- list(
    command = c(aws_binary(), args),
    status = attr(status, "status") %||% 0L,
    stdout = unname(status),
    stderr = stderr
  )

  if (!identical(result$status, 0L)) {
    stop(
      paste(
        "AWS CLI command failed.",
        paste(result$command, collapse = " "),
        paste(result$stdout, collapse = "\n"),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  result
}

run_aws_command_interactive <- function(args) {
  status <- system2(
    command = aws_binary(),
    args = args,
    stdout = "",
    stderr = ""
  )

  result <- list(
    command = c(aws_binary(), args),
    status = status %||% 0L
  )

  if (!identical(result$status, 0L)) {
    stop(
      paste(
        "AWS CLI command failed.",
        paste(result$command, collapse = " "),
        sep = "\n"
      ),
      call. = FALSE
    )
  }

  result
}

read_copy_manifest <- function(path, has_header = FALSE) {
  assert_existing_file(path, what = "manifest")

  manifest <- utils::read.delim(
    path,
    header = isTRUE(has_header),
    sep = "\t",
    stringsAsFactors = FALSE,
    quote = "",
    comment.char = ""
  )

  if (!isTRUE(has_header) && nrow(manifest) > 0L && looks_like_manifest_header(manifest[1, , drop = FALSE])) {
    manifest <- manifest[-1, , drop = FALSE]
  }

  if (ncol(manifest) != 2L) {
    stop("`manifest` must contain exactly two tab-delimited columns.", call. = FALSE)
  }

  names(manifest) <- c("source", "destination_dir")

  if (nrow(manifest) == 0L) {
    stop("`manifest` does not contain any upload rows.", call. = FALSE)
  }

  manifest$source <- trimws(manifest$source)
  manifest$destination_dir <- trimws(manifest$destination_dir)

  if (any(!nzchar(manifest$source))) {
    stop("Each manifest row must include a local source path in column 1.", call. = FALSE)
  }

  if (any(!nzchar(manifest$destination_dir))) {
    stop("Each manifest row must include an S3 destination directory in column 2.", call. = FALSE)
  }

  for (i in seq_len(nrow(manifest))) {
    assert_existing_source(manifest$source[[i]], recursive = FALSE)
    assert_s3_directory_uri(manifest$destination_dir[[i]])
  }

  manifest
}

prepare_copy_manifest <- function(path, has_header = FALSE) {
  manifest <- read_copy_manifest(path, has_header = has_header)
  manifest$destination <- vapply(
    seq_len(nrow(manifest)),
    function(i) s3_path_join(manifest$destination_dir[[i]], basename(manifest$source[[i]])),
    character(1)
  )
  manifest
}

resolve_backup_report_path <- function(path = NULL) {
  if (is.null(path)) {
    stamp <- format(Sys.time(), "%Y%m%dT%H%M%S")
    return(file.path(getwd(), sprintf("backup_fastqs_%s.tsv", stamp)))
  }

  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("`report_path` must be NULL or a single non-empty file path.", call. = FALSE)
  }

  path
}

build_backup_report <- function(
  copy_result,
  verify_result,
  profile = NULL,
  dry_run = FALSE,
  started_at,
  finished_at
) {
  uploads <- copy_result$uploads
  verifications <- verify_result$verifications

  if (!identical(length(uploads), length(verifications))) {
    stop("Copy and verification results have different lengths.", call. = FALSE)
  }

  rows <- lapply(seq_along(uploads), function(i) {
    upload <- uploads[[i]]
    verification <- verifications[[i]]

    data.frame(
      manifest = copy_result$manifest,
      source = upload$source,
      destination = upload$destination,
      started_at = started_at,
      finished_at = finished_at,
      profile = profile %||% "",
      dry_run = isTRUE(dry_run),
      copy_status = upload$status,
      verify_ok = isTRUE(verification$ok),
      local_bytes = verification$local$total_bytes,
      remote_bytes = verification$remote$total_bytes,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

write_backup_report <- function(report_data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(
    report_data,
    file = path,
    sep = "\t",
    quote = TRUE,
    row.names = FALSE,
    col.names = TRUE
  )
  invisible(path)
}

looks_like_manifest_header <- function(row) {
  values <- tolower(trimws(unlist(row, use.names = FALSE)))

  if (length(values) != 2L) {
    return(FALSE)
  }

  identical(values, c("source", "destination")) ||
    identical(values, c("source", "destination_dir")) ||
    identical(values, c("local_path", "destination")) ||
    identical(values, c("local_path", "destination_dir")) ||
    identical(values, c("fastq_path", "destination")) ||
    identical(values, c("fastq_path", "destination_dir"))
}

s3_path_join <- function(prefix, leaf) {
  prefix <- sub("/+$", "", prefix)
  leaf <- sub("^/+", "", leaf)
  paste(prefix, leaf, sep = "/")
}

summarize_local_file <- function(path) {
  info <- file.info(path)
  list(
    file_count = 1L,
    total_bytes = unname(as.numeric(info$size))
  )
}

summarize_remote_file <- function(destination, profile = NULL) {
  parts <- parse_s3_uri(destination)
  args <- c("s3api", "head-object", "--bucket", parts$bucket, "--key", parts$key)

  if (!is.null(profile)) {
    args <- c(args, "--profile", profile)
  }

  output <- run_aws_command(args)$stdout
  size_line <- grep("\"ContentLength\"", output, value = TRUE)

  if (length(size_line) != 1L) {
    stop("Could not read remote object size from AWS CLI output.", call. = FALSE)
  }

  size <- sub('.*"ContentLength"\\s*:\\s*([0-9]+).*', "\\1", size_line)

  list(
    file_count = 1L,
    total_bytes = as.numeric(size)
  )
}

parse_s3_uri <- function(uri) {
  stripped <- sub("^s3://", "", uri)
  parts <- strsplit(stripped, "/", fixed = TRUE)[[1]]

  bucket <- parts[[1]]
  key <- paste(parts[-1], collapse = "/")

  if (!nzchar(bucket) || !nzchar(key)) {
    stop("S3 object verification requires a full `s3://bucket/key` URI.", call. = FALSE)
  }

  list(bucket = bucket, key = key)
}

format_verification_error <- function(result) {
  sprintf(
    paste(
      "Upload verification failed for %s.",
      "Local bytes: %s, remote bytes: %s."
    ),
    result$destination,
    result$local$total_bytes,
    result$remote$total_bytes
  )
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
