\name{aws_verify_copy}
\alias{aws_verify_copy}
\title{Verify FASTQ Uploads from a Tab-Delimited Manifest}
\usage{
aws_verify_copy(manifest, has_header = FALSE, profile = NULL)
}
\arguments{
  \item{manifest}{Either a path to a tab-delimited text file with two columns or a two-column data frame. Column 1 must be the local source path and column 2 must be the remote S3 directory.}
  \item{has_header}{Logical indicating whether the manifest includes a header row when \code{manifest} is a file.}
  \item{profile}{Optional AWS profile name.}
}
\value{
A list with the parsed manifest and one verification result per row.
}
\description{
Reads the same two-column tab-delimited manifest used by
\code{\link{aws_copy}} and verifies each uploaded FASTQ by comparing the local
file size against the remote object reported by \code{aws s3api head-object}.
The same two-column input can also be supplied as an in-memory data frame.
}
