output "vm_name" {
  value = google_compute_instance.vm.name
}

output "vm_self_link" {
  value = google_compute_instance.vm.self_link
}

output "vm_internal_ip" {
  value = google_compute_instance.vm.network_interface[0].network_ip
}

output "vm_external_ip" {
  value = try(google_compute_instance.vm.network_interface[0].access_config[0].nat_ip, null)
}