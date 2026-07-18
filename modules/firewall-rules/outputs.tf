output "ssh_firewall_id" {
  value = google_compute_firewall.allow_ssh.id
}

output "web_firewall_id" {
  value = google_compute_firewall.allow_http_https.id
}