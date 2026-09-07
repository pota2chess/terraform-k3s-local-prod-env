output "kubeconfig_path" {
  value       = abspath("~/.kube/config")
  description = "Path to configuration file kubernetes"
}

output "check_vote-app_command" {
  value       = "curl http://vote.local:8080"
  description = "How to using command for check vote application"
}

output "check_result-app_command" {
  value       = "curl http://result.local:8080"
  description = "How to using command for check result application"
}

output "k3s_container_ip" {
  value       = docker_container.k3s.network_data[0].ip_address
  description = "IP-address container k3s in docker network dev-net"
}

output "registry_container_ip" {
  value       = docker_container.registry.network_data[0].ip_address
  description = "IP-address container registry in docker network dev-net"
}

output "ingress_http_port" {
  value       = docker_container.k3s.ports[0].external
  description = "External port, which mapping HTTP traffic Ingress"
}

output "registry_host_port" {
  value       = docker_container.registry.ports[0].external
  description = "Ports host for access to local registry"
}
