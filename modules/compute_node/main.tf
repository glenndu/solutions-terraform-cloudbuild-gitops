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


resource "google_compute_instance" "node" {
  count        = "${var.instance_count}"
  project      = "${var.project}"
  zone         = "${var.zone}"
  name         = "${var.env}-${var.role}-${count.index}"
  machine_type = "${var.machine_type}"

  boot_disk {
    initialize_params {
      image = "${var.image}"
      size  = "${var.disk_size_gb}"
    }
  }

  network_interface {
    subnetwork = "${var.subnet}"

    # No access_config block: nodes get no external IP. Reach them only via
    # IAP TCP forwarding (see modules/firewall's allow-iap-ssh rule) -- keeps
    # the whole cluster off the public internet by construction, not by
    # firewall discipline alone. Outbound internet (apt, container image
    # pulls) instead goes through Cloud NAT -- see modules/vpc.
  }

  # "k8s-node" matches the internal-traffic and IAP-SSH firewall rules;
  # the role tag ("k8s-control"/"k8s-worker") matches role-specific rules
  # (e.g. the IAP rule that opens 6443 only on control-plane nodes).
  tags = ["k8s-node", "${var.role}"]

  # cloud-platform scope so the bootstrap script's `gsutil` calls (join-
  # command handoff via the bucket) work with the default service account.
  # Scope alone doesn't grant access -- the default SA still needs an IAM
  # role (e.g. storage.objectAdmin) on the join bucket for this to succeed.
  service_account {
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/templates/kubeadm-bootstrap.sh.tpl", {
    role             = var.role
    node_index       = count.index
    k8s_version      = var.k8s_version
    pod_cidr         = var.pod_cidr
    control_endpoint = var.control_endpoint
    join_bucket      = var.join_bucket
  })
}
