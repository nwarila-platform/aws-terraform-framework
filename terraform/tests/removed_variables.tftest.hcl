mock_provider "aws" {
  alias = "us_east_1"
}

run "rejects_a_stale_managed_networks_assignment" {
  command = plan

  variables {
    environment = "TEST"
    managed_networks = {
      "poc-net" = {
        any = "shape"
      }
    }
  }

  expect_failures = [var.managed_networks]
}
