\name{depot_s3_uri}
\alias{depot_s3_uri}
\title{Build a Depot S3 URI}
\usage{
depot_s3_uri(key = "", bucket = Sys.getenv("CILLO_AWS_BUCKET", ""))
}
\arguments{
  \item{key}{Character scalar key or prefix inside the bucket.}
  \item{bucket}{Character scalar bucket name. Defaults to the \code{CILLO_AWS_BUCKET} environment variable when set.}
}
\value{
A character scalar S3 URI.
}
\description{
Creates an S3 URI from a bucket name and optional key prefix so higher-level
backup workflows do not need to manually assemble paths.
}
