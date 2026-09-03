terraform {
  backend "gcs" {
    bucket = "2f751b7c9fde3e9a-terraform-remote-backend"
    prefix = "dev"
  }
}
