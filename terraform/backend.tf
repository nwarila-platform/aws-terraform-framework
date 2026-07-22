# Partial S3 backend; real values arrive via -backend-config (see backend.hcl.example).
# Secrets and bucket identities never live in-repo.

terraform {

  # Store state file in S3 bucket.
  backend "s3" {}

}
