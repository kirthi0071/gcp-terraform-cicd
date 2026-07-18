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
    # No access_config block = no public IP
  }

  metadata = {
    enable-oslogin          = "TRUE"
    block-project-ssh-keys  = "true"
  }

  shielded_instance_config {
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  #tfsec:ignore:google-compute-vm-disk-encryption-customer-key -- using Google-managed encryption, sufficient for this environment
  labels = {
    creator     = var.creator
    environment = var.environment
  }
}
