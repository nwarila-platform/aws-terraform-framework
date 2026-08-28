# Partial S3 backend; real values arrive via -backend-config (see backend.hcl.example).
# Secrets and bucket identities never live in-repo.

terraform {

  # PARTIAL by design, split along ownership: the framework fixes the invariants that hold for
  # EVERY consumer, and the consumer supplies only what is specific to its deployment (bucket,
  # key, region) via -backend-config. Setting `encrypt` here rather than merely documenting it
  # is deliberate — org state buckets deny uploads whose REQUEST carries no
  # x-amz-server-side-encryption header, and bucket-default encryption does not satisfy that
  # condition (it tests the request, not the stored object), so a consumer that simply omits the
  # flag gets an opaque 403 on its very first init.
  backend "s3" {
    encrypt      = true
    use_lockfile = true # S3-native state locking (Terraform >= 1.10); no DynamoDB table
  }

}
