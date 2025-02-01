output "aws_public_ips" {
  value = aws_instance.performance_test[*].public_ip
}

output "gcp_public_ips" {
  value = google_compute_instance.performance_test[*].network_interface[0].access_config[0].nat_ip
}

output "azure_public_ips" {
  value = azurerm_public_ip.pip[*].ip_address
}