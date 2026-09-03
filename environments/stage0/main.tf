# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = "${var.project}"
}

# [START storage_remote_terraform_backend_template]
# [START storage_bucket_tf_with_versioning_pap_uap_no_destroy]
resource "random_id" "default" {
  byte_length = 8
}

resource "google_storage_bucket" "default" {
  name     = "${random_id.default.hex}-terraform-remote-backend"
  # Regional rather than the original multi-region "US": keeps state storage
  # co-located with the compute region now that everything else moved to
  # europe-north2, trading multi-region durability for locality/latency.
  location = "europe-north2"

  force_destroy               = true
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}
# [END storage_bucket_tf_with_versioning_pap_uap_no_destroy]

# [START storage_remote_backend_local_file]
#Note: fileset only enumerates files, so */* picks up any file one level down in each sibling directory to discover its name — it won't detect an empty directory with no files in it.
locals {
  # List sibling directories, including current directory
  sibling_dirs = toset([
    for f in fileset("${path.module}/..", "*/*") :
    split("/", f)[0]
  ])
}

resource "local_file" "backend" {
  for_each = local.sibling_dirs

  file_permission = "0644"
  filename        = "${path.module}/../${each.value}/backend.tf"

  content = <<-EOT
  terraform {
    backend "gcs" {
      bucket = "${google_storage_bucket.default.name}"
      prefix = "${each.value}"
    }
  }
  EOT
}


# [END storage_remote_backend_local_file]
# [START output]
output "state_bucket_name" {
  value = "${google_storage_bucket.default.name}"
}
# [END output]
# [END storage_remote_terraform_backend_template]

# PREREQUISITE (manual, one-time, cannot be scripted here): create the
# Cloud Build v2 GitHub connection via gcloud -- this opens an interactive
# GitHub OAuth/App-install prompt in a browser, which is why it isn't
# Terraform-managed. The connection name must match
# var.cloudbuild_connection_name ("github-connection" by default):
#
#   gcloud builds connections create github "${var.cloudbuild_connection_name}" \
#     --region="${var.region}" --project="${var.project}"
#
# Terraform can't reference the resulting connection as a data source
# (the provider doesn't expose one for cloudbuildv2 connections), so its
# id is built from the fixed naming convention below instead.
locals {
  cloudbuild_connection_id = "projects/${var.project}/locations/${var.region}/connections/${var.cloudbuild_connection_name}"
}

# 2nd-gen triggers (repository_event_config) require an explicit
# service_account -- unlike the classic github{} trigger, there's no
# implicit legacy-default fallback, and omitting it fails with an opaque
# "Request contains an invalid argument" 400 from the Cloud Build API.
data "google_project" "current" {
  project_id = "${var.project}"
}

locals {
  cloudbuild_service_account = "projects/${var.project}/serviceAccounts/${data.google_project.current.number}@cloudbuild.gserviceaccount.com"
}

# One v2 repository registration, shared by all 4 triggers below -- the
# connection (created manually, see PREREQUISITE) can host many repos, but
# this pipeline only ever builds this one.
resource "google_cloudbuildv2_repository" "repo" {
  project           = "${var.project}"
  location          = "${var.region}"
  name              = "${var.github_repo}"
  parent_connection = "${local.cloudbuild_connection_id}"
  remote_uri        = "https://github.com/${var.github_owner}/${var.github_repo}.git"
}

# Split into a plan-only PR trigger and an apply-on-merge push trigger
# (instead of one trigger that always plans then auto-applies) so a bad
# plan is visible on the PR before anything real happens, and `apply`
# only ever runs after a reviewed merge to the protected branch.
resource "google_cloudbuild_trigger" "dev_plan" {
  name     = "dev-plan"
  project  = "${var.project}"
  location        = "${var.region}"
  filename        = "cloudbuild.yaml"
  service_account = "${local.cloudbuild_service_account}"

  repository_event_config {
    repository = "${google_cloudbuildv2_repository.repo.id}"

    pull_request {
      branch          = "^dev$"
      comment_control = "COMMENTS_ENABLED"
    }
  }

  # Scopes the trigger to changes that actually affect dev -- an unrelated
  # README edit elsewhere in the repo shouldn't fire a dev plan/apply.
  included_files = ["environments/dev/**", "modules/**", "cloudbuild.yaml"]

  substitutions = {
    _ACTION = "plan"
  }
}

resource "google_cloudbuild_trigger" "dev_apply" {
  name     = "dev-apply"
  project  = "${var.project}"
  location        = "${var.region}"
  filename        = "cloudbuild.yaml"
  service_account = "${local.cloudbuild_service_account}"

  repository_event_config {
    repository = "${google_cloudbuildv2_repository.repo.id}"

    push {
      branch = "^dev$"
    }
  }

  included_files = ["environments/dev/**", "modules/**", "cloudbuild.yaml"]

  substitutions = {
    _ACTION = "apply"
  }
}

resource "google_cloudbuild_trigger" "prod_plan" {
  name     = "prod-plan"
  project  = "${var.project}"
  location        = "${var.region}"
  filename        = "cloudbuild.yaml"
  service_account = "${local.cloudbuild_service_account}"

  repository_event_config {
    repository = "${google_cloudbuildv2_repository.repo.id}"

    pull_request {
      branch          = "^prod$"
      comment_control = "COMMENTS_ENABLED"
    }
  }

  included_files = ["environments/prod/**", "modules/**", "cloudbuild.yaml"]

  substitutions = {
    _ACTION = "plan"
  }
}

resource "google_cloudbuild_trigger" "prod_apply" {
  name     = "prod-apply"
  project  = "${var.project}"
  location        = "${var.region}"
  filename        = "cloudbuild.yaml"
  service_account = "${local.cloudbuild_service_account}"

  repository_event_config {
    repository = "${google_cloudbuildv2_repository.repo.id}"

    push {
      branch = "^prod$"
    }
  }

  included_files = ["environments/prod/**", "modules/**", "cloudbuild.yaml"]

  substitutions = {
    _ACTION = "apply"
  }
}
