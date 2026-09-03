# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  env = "dev"
}

provider "google" {
  project = "${var.project}"
}

module "vpc" {
  source  = "../../modules/vpc"
  project = "${var.project}"
  env     = "${local.env}"
}

module "firewall" {
  source      = "../../modules/firewall"
  project     = "${var.project}"
  network     = "${module.vpc.network}"
  subnet_cidr = "${module.vpc.subnet_cidr}"
}

# Handoff channel for kubeadm join commands between nodes (see
# modules/compute_node's bootstrap template) -- nodes have no external IP,
# so a bucket reachable via Private Google Access is the simplest way for
# control-0 to publish join credentials the other 4 nodes can poll for.
# force_destroy: this is throwaway bootstrap state, not something to
# protect on `terraform destroy` in a POC environment.
resource "google_storage_bucket" "k8s_bootstrap" {
  name                        = "${var.project}-${local.env}-k8s-bootstrap"
  project                     = "${var.project}"
  location                    = "europe-north2"
  uniform_bucket_level_access = true
  force_destroy               = true
}

module "k8s_control" {
  source  = "../../modules/compute_node"
  project = "${var.project}"
  env     = "${local.env}"
  subnet  = "${module.vpc.subnet}"
  role    = "k8s-control"

  # etcd needs an odd number of members >= 3 for quorum/HA; 3 tolerates
  # 1 node failure without losing quorum.
  instance_count = 3
  machine_type   = "${var.control_machine_type}"

  # GCE-internal DNS hostname of control-0 -- see the bootstrap template
  # for why this isn't a real HA load-balanced endpoint yet.
  control_endpoint = "${local.env}-k8s-control-0"
  join_bucket       = "${google_storage_bucket.k8s_bootstrap.name}"
}

module "k8s_workers" {
  source  = "../../modules/compute_node"
  project = "${var.project}"
  env     = "${local.env}"
  subnet  = "${module.vpc.subnet}"
  role    = "k8s-worker"

  # No quorum constraint for workers -- 2 is just enough to test pod
  # scheduling/eviction across nodes.
  instance_count = 2

  # Sized per-environment (see variables.tf/terraform.tfvars) rather than
  # hardcoded here: dev stays cheap since it's a POC with no real workload
  # target; a prod environment would set this higher.
  machine_type = "${var.worker_machine_type}"

  control_endpoint = "${local.env}-k8s-control-0"
  join_bucket       = "${google_storage_bucket.k8s_bootstrap.name}"
}
