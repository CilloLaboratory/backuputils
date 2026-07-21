# backuputils

`backuputils` is a lightweight R package for wrapping `awscli` backup commands.
It is structured around two core jobs:

- Copy local FASTQ files to S3 from a two-column manifest with `aws s3 cp`
- Verify the uploaded FASTQ files from the same manifest

The current backbone is intentionally small. It establishes the public
interface, manifest parsing, command execution helpers, and tests so
depot-specific behavior can be layered on without rewriting the package
structure.

## Planned workflow

```r
library(backuputils)

aws_sso_login("cillo-lab")

manifest <- tempfile(fileext = ".tsv")
writeLines(
  c(
    "/data/run-01/sample_1.fastq.gz\ts3://lab-bucket/my-project/run-01",
    "/data/run-01/sample_2.fastq.gz\ts3://lab-bucket/my-project/run-01"
  ),
  manifest
)

aws_copy(
  manifest = manifest
)

aws_verify_copy(
  manifest = manifest
)

backup_fastqs(
  manifest = manifest
)
```

`backup_fastqs()` writes a tab-delimited run report by default, with one row
per FASTQ file copied and verified. It can take either a manifest file path or
an in-memory `data.frame` with the same two columns.

## Requirements

- R 4.3 or newer is recommended
- `aws` must be available on the command line
- AWS credentials and permissions must already be configured outside the package

## Next likely additions

- Depot-specific path builders and naming rules
- Richer logging and manifest generation
- Optional checksum-based verification
- Upload helpers for common lab data layouts
