\name{backup_fastqs}
\alias{backup_fastqs}
\title{Copy and Verify FASTQ Backups from a Tab-Delimited Manifest}
\usage{
backup_fastqs(
  manifest,
  has_header = FALSE,
  profile = NULL,
  extra_args = character(),
  dry_run = FALSE,
  quiet = TRUE,
  report_path = NULL
)
}
\arguments{
  \item{manifest}{Path to a tab-delimited text file with two columns: local source path and remote S3 directory.}
  \item{has_header}{Logical indicating whether the manifest includes a header row.}
  \item{profile}{Optional AWS profile name.}
  \item{extra_args}{Optional character vector of extra \code{aws s3 cp} arguments.}
  \item{dry_run}{Logical indicating whether to append \code{--dryrun} during copy.}
  \item{quiet}{Logical indicating whether to suppress normal AWS CLI progress output.}
  \item{report_path}{Optional path for a tab-delimited run report. When \code{NULL}, a timestamped report is written in the working directory.}
}
\value{
A list containing the upload results, verification results, and written report data.
}
\description{
Runs \code{\link{aws_copy}} and then \code{\link{aws_verify_copy}} against the
same two-column manifest so the common FASTQ backup workflow can be executed in
one call. A tab-delimited report with one row per FASTQ is written for audit
and downstream parsing.
}
