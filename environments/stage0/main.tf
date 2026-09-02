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

# [START storage_remote_terraform_backend_template]
# [START storage_bucket_tf_with_versioning_pap_uap_no_destroy]
resource "random_id" "default" {
  byte_length = 8
}

resource "google_storage_bucket" "default" {
  name     = "${random_id.default.hex}-terraform-remote-backend"
  location = "US"

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
