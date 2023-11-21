#--------------------------------------------------------------------------------------
# AWS OUTPUTS
output "rancher_ip" {
  value = aws_instance.rancher_server.public_ip
}

output "rancher_dns" {
  value = aws_instance.rancher_server.public_dns
}

output "workload_ip" {
  value = aws_instance.workload_node.public_ip
}

output "workload__dns" {
  value = aws_instance.workload_node.public_dns
}

output "default_registry_ip" {
  value = aws_instance.default_registry.public_ip
}

output "default_registry_dns" {
  value = aws_instance.default_registry.public_dns
}
#--------------------------------------------------------------------------------
# Helper outputs
output "debug_default_registry" {
  value = "ssh -i ./certs/id_rsa ubuntu@${aws_instance.default_registry.public_dns}"
}
output "debug_rancher" {
  value = "ssh -i ./certs/id_rsa ubuntu@${aws_instance.rancher_server.public_dns}"
}
output "debug_workload" {
  value = "ssh -i ./certs/id_rsa ubuntu@${aws_instance.workload_node.public_dns}"
}

#----------------------------------------------------------------------------------
# RANCHER OUTPUTS
# Outputs
output "rancher_server_dns" {
  value = join(".", ["rancher", aws_instance.rancher_server.public_ip, "sslip.io"])
  description = "Rancher Server built DNS online"
}

output "rancher_server_url" {
  value = "https://${join(".", ["rancher", aws_instance.rancher_server.public_ip, "sslip.io"])}"
  description = "Rancher Server built URL for HTTPS access"
}

output "workload_cluster_id" {
  value = rancher2_cluster_v2.workload_node.cluster_v1_id
  description = "Actual cluster ID used by workload node"
}

output "rancher_cluster_id" {
  value = "local"
  description = "Actual cluster ID used by Rancher local cluster"
}
