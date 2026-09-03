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


variable "project" {}

variable "github_owner" {
  default = "glenndu"
}

variable "github_repo" {
  default = "solutions-terraform-cloudbuild-gitops"
}

variable "region" {
  default = "europe-north2"
}

# Must match the name used when creating the connection by hand, e.g.:
#   gcloud builds connections create github github-connection \
#     --region=europe-north2 --project=<project>
# Terraform can't create this resource itself -- it requires an interactive
# GitHub OAuth grant (see the PREREQUISITE comment in main.tf).
variable "cloudbuild_connection_name" {
  default = "github-connection"
}
