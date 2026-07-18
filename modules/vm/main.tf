resource "google_compute_instance" "vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.network_tags

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_self_link

    # Remove this block for a VM with no public IP (recommended for prod)
    access_config {}
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    creator     = var.creator
    environment = var.environment
  }
}