# Step 1 - Manual K3s install
resource "ssh_resource" "install_k3s" {
  host = aws_instance.rancher_server.public_ip

  depends_on = [ aws_instance.rancher_server ]

 commands = [
    "sudo mkdir -p /etc/rancher/k3s",
    "echo '${templatefile("${path.module}/files/registries.tpl", { registry_url = aws_instance.default_registry.public_dns })}' | sudo tee /etc/rancher/k3s/registries.yaml",
    "sudo cp /home/ubuntu/domain.crt /etc/ssl/certs/domain.crt",
    "sudo chmod +r /etc/ssl/certs/domain.crt",
    "bash -c 'curl https://get.k3s.io | INSTALL_K3S_EXEC=\"server --node-external-ip ${aws_instance.rancher_server.public_ip} --node-ip ${aws_instance.rancher_server.private_ip}\" INSTALL_K3S_VERSION=${var.rancher_kubernetes_version} sh -'"
  ]

  user        = local.node_username
  private_key = tls_private_key.global_key.private_key_pem
}
# Step 1.1 - Retrieve kubeconfig for local debugging
resource "ssh_resource" "retrieve_config" {
  depends_on = [
    ssh_resource.install_k3s
  ]
  host = aws_instance.rancher_server.public_ip
  commands = [
    "sudo sed \"s/127.0.0.1/${aws_instance.rancher_server.public_ip}/g\" /etc/rancher/k3s/k3s.yaml"
  ]
  user        = local.node_username
  private_key = tls_private_key.global_key.private_key_pem
}
#---------------------------------------------------------------------------------------------------------------
# Step 2 - Helm Resources
# Local resources - (Helm providers depends on these)
# Save kubeconfig file for interacting with the RKE cluster on your local machine
resource "local_file" "kube_config_server_yaml" {
  depends_on = [ ssh_resource.retrieve_config ]
  filename = format("%s/%s/%s", path.root, "kubeconfigs",  "kube_config_server.yaml")
  content  = ssh_resource.retrieve_config.result
}


# Install cert-manager helm chart
resource "helm_release" "cert_manager" {

  depends_on = [ local_file.kube_config_server_yaml]

  name             = "cert-manager"
  chart            = "https://charts.jetstack.io/charts/cert-manager-v${var.cert_manager_version}.tgz"
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Install Rancher helm chart
resource "helm_release" "rancher_server" {
  depends_on = [
    helm_release.cert_manager,
  ]

  name             = "rancher"
  chart            = "${var.rancher_helm_repository}/rancher-${var.rancher_version}.tgz"
  namespace        = "cattle-system"
  create_namespace = true
  wait             = true

  set {
    name  = "hostname"
    value = join(".", ["rancher", aws_instance.rancher_server.public_ip, "sslip.io"])
    # output "rancher_server_dns"
  }

  set {
    name  = "replicas"
    value = "1"
  }

  set {
    name  = "bootstrapPassword"
    value = "admin" # TODO: change this once the terraform provider has been updated with the new pw bootstrap logic
  }
}

# Rancher resources
# Initialize Rancher server
resource "rancher2_bootstrap" "admin" {
  depends_on = [
    helm_release.rancher_server
  ]

  provider = rancher2.MASTER

  password  = var.rancher_server_admin_password
  telemetry = false
}

# resource "rancher2_app_v2" "cis_benchmark_rancher" {
#   provider = rancher2.MASTER

#   depends_on = [
#     helm_release.rancher_server,
#     rancher2_bootstrap.admin
#   ]

#   cluster_id = "local"
#   name = "rancher-cis-benchmark"
#   namespace = "cis-operator-system"
#   repo_name = "rancher-charts"
#   chart_name = "rancher-cis-benchmark"
#   chart_version = "4.2.0"
# }
