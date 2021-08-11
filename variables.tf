variable "google_apis" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["iam.googleapis.com",
                "cloudresourcemanager.googleapis.com",
                "compute.googleapis.com",
                "bigquery.googleapis.com"]
}

variable "service_accounts_roles" {
  description = "Assign roles to service account"
  type        = list(string)
  default     = ["roles/viewer",
                "cloudresourcemanager.googleapis.com",
                "compute.googleapis.com",
                "bigquery.googleapis.com"]
}


variable "project" {
    type = string
    default = "stanford-r"
}

variable "bucket" {
    type = string
    default = "stanford-r-bucket"
}

variable "region" {
    type = string
    default = "us-west1"
}

variable "subnetwork_self_link" {
    type = string
    default = "module.vpc.network_self_link"
}


variable "user" {
    type = string
    default = "gurpreet.singh"
}
variable "email" {
    type = string
    default = "harsh.gaur@vertisystem.com"
}
variable "privatekeypath" {
    type = string
    default = "~/.ssh/id_rsa"
}
variable "publickeypath" {
    type = string
    default = "~/.ssh/id_rsa.pub"
}