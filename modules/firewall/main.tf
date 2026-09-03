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


# Cluster-internal traffic: nodes talk to each other on any protocol/port
# (etcd, kubelet, CNI overlay, NodePort range, etc.) within the subnet.
# Full port range rather than an itemized list: k8s/CNI traffic isn't
# confined to a fixed port set, and this rule is already scoped to
# source_ranges = subnet_cidr, so opening it wide only matters for traffic
# already inside the VPC.
resource "google_compute_firewall" "allow-internal" {
  name    = "${var.network}-allow-internal"
  network = "${var.network}"
  project = "${var.project}"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["${var.subnet_cidr}"]
  target_tags   = ["${var.node_tag}"]
}

# SSH via IAP TCP forwarding (e.g. gcloud compute ssh --tunnel-through-iap
# from Cloud Shell) instead of a public 0.0.0.0/0 rule. No external IPs
# are needed on the nodes for this to work.
resource "google_compute_firewall" "allow-iap-ssh" {
  name    = "${var.network}-allow-iap-ssh"
  network = "${var.network}"
  project = "${var.project}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["${var.iap_source_range}"]
  target_tags   = ["${var.node_tag}"]
}

# kube-apiserver access via an IAP tunnel to a control-plane node
# (e.g. gcloud compute start-iap-tunnel ... --local-host-port=localhost:6443).
resource "google_compute_firewall" "allow-iap-k8s-api" {
  name    = "${var.network}-allow-iap-k8s-api"
  network = "${var.network}"
  project = "${var.project}"

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["${var.iap_source_range}"]
  target_tags   = ["${var.control_tag}"]
}
