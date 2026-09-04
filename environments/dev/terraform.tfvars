project="project-047f223b-18be-4ad5-9ef"

# dev is a POC: keep sizing cheap. control still needs enough headroom for
# etcd + control-plane components; worker doesn't run real workloads here.
control_machine_type="e2-medium"
worker_machine_type="e2-small"

# europe-west4 (Netherlands): a large, well-provisioned region, unlike
# europe-north2 which ran out of e2-family capacity in all 3 zones.
region="europe-west4"
zone="europe-west4-a"
