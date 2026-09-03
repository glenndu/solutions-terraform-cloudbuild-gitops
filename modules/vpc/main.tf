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


module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "3.3.0"

  project_id   = "${var.project}"
  network_name = "${var.env}"

  subnets = [
    {
      subnet_name   = "${var.env}-subnet-01"
      subnet_ip     = "10.${var.env == "dev" ? 10 : 20}.10.0/24"
      subnet_region = "${var.region}"

      # Lets nodes without an external IP reach Google APIs (e.g. the
      # kubeadm bootstrap script's gsutil calls) directly over Google's
      # network rather than needing that traffic to go through Cloud NAT.
      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    "${var.env}-subnet-01" = []
  }
}

# Nodes have no external IP (see modules/compute_node), so this is their
# only path to the public internet -- needed for apt package installs and
# container image pulls (registry.k8s.io etc.) during kubeadm bootstrap.
resource "google_compute_router" "router" {
  name    = "${var.env}-router"
  project = "${var.project}"
  region  = "${var.region}"
  network = "${module.vpc.network_name}"
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.env}-nat"
  project                            = "${var.project}"
  router                             = "${google_compute_router.router.name}"
  region                             = "${var.region}"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
