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


variable "project" {}
variable "network" {}
variable "subnet_cidr" {}

variable "iap_source_range" {
  # Google's fixed range for IAP TCP forwarding (used by `gcloud compute ssh
  # --tunnel-through-iap` and `start-iap-tunnel`). It is NOT the Cloud Shell
  # session's own IP -- that's ephemeral -- so this never needs to track a
  # developer's changing IP address.
  default = "35.235.240.0/20"
}

variable "node_tag" {
  # Must match the tag every compute_node instance gets (see
  # modules/compute_node/main.tf) so the internal-traffic and IAP-SSH rules
  # apply to all cluster members regardless of role.
  default = "k8s-node"
}

variable "control_tag" {
  # Must match the role value passed to compute_node for control-plane
  # instances, so only they get the 6443 rule -- workers don't run
  # kube-apiserver and shouldn't be reachable on that port.
  default = "k8s-control"
}
