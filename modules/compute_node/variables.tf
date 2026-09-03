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
variable "env" {}
variable "subnet" {}

variable "role" {
  description = "k8s-control or k8s-worker"
}

variable "instance_count" {
  default = 1
}

variable "machine_type" {
  # e2-medium is the default sizing for control-plane nodes: etcd + the
  # control-plane components aren't CPU/memory heavy at this cluster size.
  # environments/dev overrides this per role (e.g. smaller for workers in
  # a POC that doesn't need real workload capacity).
  default = "e2-medium"
}

variable "zone" {
  # europe-north2-a AND -b both hit ZONE_RESOURCE_POOL_EXHAUSTED on real
  # apply attempts -- trying -c next. Transient GCP capacity issue, not a
  # config bug; if -c also runs out, this region may just be capacity-
  # constrained for these machine types right now and worth retrying later
  # or switching region.
  default = "europe-north2-c"
}

variable "image" {
  # Ubuntu 22.04 LTS: current kubeadm docs assume the systemd cgroup driver,
  # which 22.04's systemd version supports out of the box (avoids the
  # cgroupfs/systemd driver mismatch that breaks kubelet on older images).
  default = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "disk_size_gb" {
  # 20GB covers the OS + container image/pull cache comfortably for a
  # small dev cluster; bump this if workers pull large images or need
  # local storage headroom.
  default = 20
}

variable "k8s_version" {
  # Pinned minor version for the pkgs.k8s.io apt repo (see bootstrap
  # template) -- keeps kubelet/kubeadm/kubectl in lockstep across all 5 nodes.
  default = "1.30"
}

variable "pod_cidr" {
  # Must match the CNI manifest applied in the bootstrap script (Calico
  # here); changing one without the other breaks pod networking.
  default = "192.168.0.0/16"
}

variable "control_endpoint" {
  description = "Host[:port] the API server listens on -- see bootstrap template for why this isn't an LB yet"
}

variable "join_bucket" {
  description = "GCS bucket name used to hand kubeadm join commands from control-0 to the other nodes"
}
