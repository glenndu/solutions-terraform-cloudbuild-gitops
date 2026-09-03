In this example, we show how to provision a Cloud Storage bucket, generate a
Terraform backend configuration file, and set up the Cloud Build triggers
that plan/apply `dev` and `prod` on pull request / push.

To run this example, do the following:

 1. Connect the Cloud Build GitHub App to this repo (one-time, interactive --
    opens a browser for GitHub OAuth/App install, so it can't be scripted
    into `main.tf`). The connection name must match
    `var.cloudbuild_connection_name` (`github-connection` by default):

    gcloud builds connections create github github-connection \
      --region=europe-north2 --project=<PROJECT_ID>

 2. Initialize Terraform with a local backend:

    terraform init

 3. Provision the state bucket, backend.tf files, and Cloud Build triggers
    (`dev-plan`, `dev-apply`, `prod-plan`, `prod-apply`):

    terraform apply

 4. Migrate Terraform state to the remote Cloud Storage backend:

    terraform init -migrate-state

Once this is applied, a pull request into `dev`/`prod` runs `terraform plan`
only; merging to `dev`/`prod` runs `terraform apply`. See the root README's
"Automated deploys via Cloud Build" section for more detail.



<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

No inputs.

## Outputs

# the name of the terraform remote state bucket
state_bucket_name

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
