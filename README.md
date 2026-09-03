# Managing infrastructure as code with Terraform, Cloud Build, and GitOps

This is the repo for the [Managing infrastructure as code with Terraform, Cloud Build, and GitOps](https://cloud.google.com/solutions/managing-infrastructure-as-code) tutorial. This tutorial explains how to manage infrastructure as code with Terraform and Cloud Build using the popular GitOps methodology. 

Terraform remote state storage has been added to this demo in the environments/stage0 dir.
It creates the bucket used by the dev and prod environments for state storage.
It also places the backup.tf file in their directories.
It is located outside of the dev and prod environment directories because it will be shared.
If this demo used different GCP projects or accounts then stage0 would be replicated to dev and prod separately.

## Configuring shared terraform state bucket and locking
```bash
cd environments/stage0
# consult README in stage0 for deployment steps


## Configuring your **dev** environment

This step deploys a small (3 control / 2 worker) kubeadm cluster's compute
nodes onto network '**dev**' and subnet '**dev**-subnet-01', all in the
`europe-north2` region:
 1. VPC + subnet (Private Google Access on, so nodes without an external IP
    can still reach Google APIs) plus Cloud Router/NAT for outbound internet
 2. Firewall rules scoped to IAP TCP forwarding + internal cluster traffic
    only -- no `0.0.0.0/0` rules, no external IPs on any node
 3. 3 control-plane + 2 worker `google_compute_instance`s, sized via
    `control_machine_type`/`worker_machine_type` in `terraform.tfvars`
 4. A `kubeadm init`/`join` bootstrap baked into each node's startup script
    (see `modules/compute_node/templates/kubeadm-bootstrap.sh.tpl`), using a
    GCS bucket to hand join credentials between nodes

```bash
cd ../environments/dev
terraform init
terraform plan
terraform apply
terraform destroy
```

### Connecting once the cluster is up

Nodes have no external IP, so everything goes through IAP TCP forwarding:

```bash
# SSH to any node
gcloud compute ssh dev-k8s-control-0 --tunnel-through-iap \
  --zone=europe-north2-a --project=<PROJECT_ID>

# kubectl, via a tunnel to the API server on control-0
gcloud compute start-iap-tunnel dev-k8s-control-0 6443 \
  --local-host-port=localhost:6443 \
  --zone=europe-north2-a --project=<PROJECT_ID>
# then, in another shell:
gcloud compute ssh dev-k8s-control-0 --tunnel-through-iap \
  --zone=europe-north2-a --project=<PROJECT_ID> \
  --command="sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
kubectl config set-cluster kubernetes --server=https://127.0.0.1:6443
kubectl get nodes
```

Note: `control_endpoint` (in `environments/dev/main.tf`) points at control-0's
own hostname, not a load balancer, so this is the only reachable API server
address until an HA front-end for the 3 control nodes is added.

## Promoting your environment to **production**

Once you've tested your cluster in dev, you can promote the same
configuration to production on network '**prod**' and subnet
'**prod**-subnet-01'.

```bash
cd ../prod
terraform init
terraform plan
terraform apply
terraform destroy
```

## Automated deploys via Cloud Build

`cloudbuild.yaml` runs `terraform plan` always, and `terraform apply` only
when the `_ACTION` substitution is `"apply"` (default: `"plan"`). The
triggers that set `_ACTION` are defined in `environments/stage0` --
`dev-plan`/`prod-plan` fire on pull requests (plan-only, posts to the PR),
`dev-apply`/`prod-apply` fire on push/merge to the corresponding branch.

Before applying `stage0`, connect the Cloud Build GitHub App to this repo
(one-time, interactive -- can't be scripted):

```bash
gcloud builds connections create github github-connection \
  --region=europe-north2 --project=<PROJECT_ID>
```
