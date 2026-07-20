#' Verify FASTQ uploads from a tab-delimited manifest
#'
#' Reads the same two-column tab-delimited manifest used by [aws_copy()] and
#' verifies each uploaded FASTQ by comparing the local file size against the
#' remote object reported by `aws s3api head-object`.
#'
#' @param manifest Path to a tab-delimited text file with two columns:
#'   local source path and remote S3 directory.
#' @param has_header Logical indicating whether the manifest includes a header
#'   row. When `FALSE`, the function will still ignore a leading header row if
#'   it looks like one.
#' @param profile Optional AWS profile name.
#'
#' @return A list with the parsed manifest and one verification result per row.
#'   An error is raised on any mismatch.
#' @export
aws_verify_copy <- function(
  manifest,
  has_header = FALSE,
  profile = NULL
) {
  manifest_data <- prepare_copy_manifest(manifest, has_header = has_header)
  verifications <- lapply(seq_len(nrow(manifest_data)), function(i) {
    source <- manifest_data$source[[i]]
    destination <- manifest_data$destination[[i]]

    local_summary <- summarize_local_file(source)
    remote_summary <- summarize_remote_file(destination, profile = profile)
    ok <- identical(local_summary$total_bytes, remote_summary$total_bytes)

    result <- list(
      ok = ok,
      source = normalizePath(source, winslash = "/", mustWork = TRUE),
      destination = destination,
      local = local_summary,
      remote = remote_summary
    )

    if (!isTRUE(ok)) {
      stop(format_verification_error(result), call. = FALSE)
    }

    result
  })

  list(
    manifest = normalizePath(manifest, winslash = "/", mustWork = TRUE),
    plan = manifest_data,
    verifications = verifications
  )
}
