variable "zone" {
  default = "us-central1-c"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  project = "cis91-397621"  # Hardcoded project ID
}

resource "google_compute_firewall" "firewall" {
  name    = "terraform-network-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_firewall" "http_firewall" {
  name    = "allow-http-alt"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

resource "google_service_account" "cis91-397621" {
  account_id   = "cis91-397621"
  display_name = "service account for operations"
  project      = "cis91-397621"  # Hardcoded project ID
}

resource "google_project_iam_member" "owner-role" {
  project = "cis91-397621"  # Hardcoded project ID
  role    = "roles/owner"
  member  = google_service_account.cis91-397621.member
}

resource "google_compute_instance" "vm_instance" {
  name                      = "terraform-instance"
  machine_type              = "e2-small"
  zone                      = var.zone
  tags                      = ["dev", "web"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      # image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

  lifecycle {
    ignore_changes = [attached_disk]
  }

  service_account {
    email  = "dev-boxcs91@cis91-397621.iam.gserviceaccount.com"  # Hardcoded service account email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_disk" "datadisk" {
  name = "data"
  type = "pd-balanced"
  zone = var.zone
  size = 10
}

resource "google_compute_attached_disk" "datadisk_attach" {
  disk     = google_compute_disk.datadisk.id
  instance = google_compute_instance.vm_instance.id
}

resource "google_storage_bucket" "db-backups" {
  name                      = "luis-database-backup-archive"
  location                  = "US"
  public_access_prevention  = "enforced"
  lifecycle_rule {
    condition {
      age               = 180
      num_newer_versions = 180
    }
    action {
      type = "Delete"
    }
  }
}

output "ip" {
  value = google_compute_instance.vm_instance.network_interface.0.network_ip
}

output "external-ip" {
  value = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}
