#!/bin/bash
set -euo pipefail

# ---- common node prep (control-plane and worker alike) ----

# kubeadm's preflight checks refuse to start kubelet with swap enabled.
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Kernel modules + sysctl kubeadm requires so bridged pod traffic is
# actually visible to iptables and can be forwarded between nodes.
cat <<MODULES > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
MODULES
modprobe overlay
modprobe br_netfilter

cat <<SYSCTL > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYSCTL
sysctl --system

export DEBIAN_FRONTEND=noninteractive
apt-get update
# google-cloud-cli (gsutil) is how nodes exchange join credentials below --
# there's no external IP on any node, so a bucket reachable over Google's
# private API path is the simplest coordination channel available to all of them.
apt-get install -y apt-transport-https ca-certificates curl gnupg containerd google-cloud-cli

# containerd defaults to the cgroupfs driver; kubelet defaults to systemd.
# That mismatch is one of the most common kubeadm preflight failures, so
# force containerd to match.
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Pin to one k8s minor-version repo rather than "whatever's newest" -- an
# unpinned install could pull a kubelet/kubeadm skew newer than this
# startup script (and the join commands it generates) was written against.
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" |
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

BUCKET="gs://${join_bucket}"

# ---- role-specific bootstrap ----

%{ if role == "k8s-control" && node_index == 0 }
# This is the one node that actually runs `kubeadm init`; the other 2
# control nodes and both workers just join what it creates.
#
# control_endpoint here is this node's own GCE-internal DNS hostname, NOT
# a load balancer -- there's no HA front door for the API server yet
# (that's Stage 4 of the deployment plan, not built). The other control
# nodes below join etcd for quorum/HA, but any kubectl client only has one
# reachable API server address until that LB exists.
kubeadm init \
  --control-plane-endpoint="${control_endpoint}:6443" \
  --upload-certs \
  --pod-network-cidr="${pod_cidr}"

mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# CNI: Calico, matching --pod-network-cidr above. Swap this block out if
# you'd rather run Cilium/Flannel/etc.
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply \
  -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

# Publish join credentials for the other 4 nodes to pick up. Not encrypted
# beyond the bucket's own IAM/default encryption -- acceptable for a POC,
# but tighten bucket access (or use Secret Manager instead) before this
# pattern goes anywhere near production.
kubeadm token create --print-join-command > /tmp/worker-join.sh

CERT_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -1)
echo "$(cat /tmp/worker-join.sh) --control-plane --certificate-key $${CERT_KEY}" \
  > /tmp/control-join.sh

gsutil cp /tmp/worker-join.sh "$BUCKET/worker-join.sh"
gsutil cp /tmp/control-join.sh "$BUCKET/control-join.sh"
%{ endif }

%{ if role == "k8s-control" && node_index != 0 }
# Additional control-plane node: wait for control-0 to publish the
# certificate-key join command, then join etcd/the control plane with it.
until gsutil cp "$BUCKET/control-join.sh" /tmp/control-join.sh; do
  sleep 10
done
bash /tmp/control-join.sh
%{ endif }

%{ if role == "k8s-worker" }
until gsutil cp "$BUCKET/worker-join.sh" /tmp/worker-join.sh; do
  sleep 10
done
bash /tmp/worker-join.sh
%{ endif }
