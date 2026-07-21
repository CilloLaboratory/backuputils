\name{aws_copy}
\alias{aws_copy}
\title{Copy FASTQ Files to S3 from a Tab-Delimited Manifest}
\usage{
aws_copy(
  manifest,
  has_header = FALSE,
  profile = NULL,
  extra_args = character(),
  dry_run = FALSE,
  quiet = TRUE
)
}
\arguments{
  \item{manifest}{Either a path to a tab-delimited text file with two columns or a two-column data frame. Column 1 must be the local source path and column 2 must be the remote S3 directory.}
  \item{has_header}{Logical indicating whether the manifest includes a header row when \code{manifest} is a file.}
  \item{profile}{Optional AWS profile name.}
  \item{extra_args}{Optional character vector of extra \code{aws s3 cp} arguments.}
  \item{dry_run}{Logical indicating whether to append \code{--dryrun}.}
  \item{quiet}{Logical indicating whether to suppress normal AWS CLI progress output.}
}
\value{
A list with the parsed manifest and one command result per uploaded file.
}
\description{
Reads a two-column tab-delimited text file and performs one \code{aws s3 cp}
operation per row. Column 1 must be the local FASTQ path. Column 2 must be the
target S3 directory. The local filename is appended to the target directory
automatically. The same two-column input can also be supplied as an in-memory
data frame.
}
