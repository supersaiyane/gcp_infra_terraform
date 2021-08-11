resource "google_project_service" "projectpolicies" {
  project = "stanford-r"
  count = length(var.google_apis)
  service  = var.google_apis[count.index]
}

module "service_accounts" {
  source        = "terraform-google-modules/service-accounts/google"
  version       = "~> 3.0"
  project_id    = "stanford-r"
  prefix        = "stanford-test"
  names         = ["tide"]
  project_roles = [
    "stanford-r=>roles/viewer",
    "stanford-r=>roles/storage.objectViewer"
  ]
}

resource "google_storage_bucket" "my_bucket" {
name     = var.bucket
location = var.region
project =  var.project
}

data "google_storage_transfer_project_service_account" "kube-resource-access" {
  project = var.project
}

resource "google_storage_bucket_iam_binding" "my_bucket" {
  bucket = google_storage_bucket.my_bucket.name
  role = "roles/storage.admin"
  members = [
    "user:harsh.gaur@vertisystem.com",
    "serviceAccount:${data.google_storage_transfer_project_service_account.kube-resource-access.email}"
  ]
}


module "vpc" {
    source  = "terraform-google-modules/network/google"
    version = "~> 3.0"

    project_id   = "stanford-r"
    network_name = "stanford-tide-vpc"
    routing_mode = "REGIONAL"
    subnets = [
        {
            subnet_name           = "subnet-01"
            subnet_ip             = "10.10.10.0/24"
            subnet_region         = "us-west1"
            subnet_flow_logs      = "true"
            subnet_flow_logs_interval = "INTERVAL_10_MIN"
            subnet_flow_logs_sampling = 0.7
            subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
        }
    ]   
    secondary_ranges = {
        subnet-01 = [
            {
                range_name    = "subnet-01-secondary-01"
                ip_cidr_range = "192.168.64.0/24"
            }
        ]
    }

    routes = [
        {
            name                   = "egress-internet"
            description            = "route through IGW to access internet"
            destination_range      = "0.0.0.0/0"
            tags                   = "egress-inet"
            next_hop_internet      = "true"
        }
    ]
}


resource "google_compute_firewall" "firewall" {
  name    = "firewall-externalssh"
  network = "${module.vpc.network_name}"
  project = var.project
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["externalssh"]
}

resource "google_compute_firewall" "icmp" {
  name    = "firewall-icmp"
  network = "${module.vpc.network_name}"
  project = var.project
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["icmp"]
}

resource "google_compute_firewall" "webserverrule" {
  name    = "webserver"
  network = "${module.vpc.network_name}"
  project = var.project
  allow {
    protocol = "tcp"
    ports    = ["80","443","3389"]
  }
  source_ranges = ["0.0.0.0/0"] # Not So Secure. Limit the Source Range
  target_tags   = ["webserver"]
}

resource "google_compute_address" "static" {
  name = "vm-public-address"
  project = var.project
  region = var.region
  depends_on = [ google_compute_firewall.firewall ]
}


# data "google_compute_network" "network" {
#   name    = basename(data.google_compute_subnetwork.subnetwork.network)
#   project = data.google_compute_subnetwork.subnetwork.project
# }

# data "google_compute_subnetwork" "subnetwork" {
#   self_link = module.vpc.network_self.link
# }

resource "google_compute_instance" "dev" {
  name         = "devserver"
  machine_type = "f1-micro"
  project = var.project
  zone         = "us-west1-a"
  tags         = ["externalssh","webserver","icmp"]
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }
  network_interface {
    network = module.vpc.network_name
    subnetwork = 

    access_config {
      nat_ip = google_compute_address.static.address
    }
  }
  provisioner "remote-exec" {
    connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = var.user
      timeout     = "500s"
      private_key = file(var.privatekeypath)
    }
    inline = [
      "sudo yum -y install epel-release",
      "sudo yum -y install nginx",
      "sudo nginx -v",
    ]
  }
  # Ensure firewall rule is provisioned before server, so that SSH doesn't fail.
  depends_on = [ google_compute_firewall.firewall, google_compute_firewall.webserverrule ]
  service_account {
    email  = var.email
    scopes = ["compute-rw","storage-full","bigquery"]
  }
  metadata = {
    ssh-keys = "${var.user}:${file(var.publickeypath)}"
  }
}
