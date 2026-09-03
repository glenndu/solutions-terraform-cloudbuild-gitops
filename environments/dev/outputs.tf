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


output "network" {
  value = "${module.vpc.network}"
}

output "subnet" {
  value = "${module.vpc.subnet}"
}

output "k8s_control_names" {
  value = "${module.k8s_control.names}"
}

output "k8s_control_internal_ips" {
  value = "${module.k8s_control.internal_ips}"
}

output "k8s_worker_names" {
  value = "${module.k8s_workers.names}"
}

output "k8s_worker_internal_ips" {
  value = "${module.k8s_workers.internal_ips}"
}
