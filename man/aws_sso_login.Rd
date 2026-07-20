\name{aws_sso_login}
\alias{aws_sso_login}
\title{Authenticate with AWS SSO for a Named Profile}
\usage{
aws_sso_login(profile, use_device_code = TRUE)
}
\arguments{
  \item{profile}{Character scalar AWS profile name.}
  \item{use_device_code}{Logical indicating whether to include \code{--use-device-code}.}
}
\value{
A list containing the executed command and exit status.
}
\description{
Wraps \code{aws sso login --use-device-code --profile ...} so package users can
start an AWS SSO session from R before running backup commands.
}
