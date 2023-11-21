# AWS Instance to reproduce the bug with all infra set up
resource "aws_instance" "bug_node" {
  depends_on = [
    aws_route_table_association.rancher_route_table_association,
    aws_instance.default_registry
  ]

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  key_name                    = aws_key_pair.nick_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.rancher_sg_allowall.id]
  subnet_id                   = aws_subnet.rancher_subnet.id
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    tags = {
      "Name" = "${var.prefix}-volume-bug-node"
    }
  }

  provisioner "file" {
    source      = "${path.module}/certs/domain.crt"
    destination = "/home/ubuntu/domain.crt"

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "cloud-init status --wait > /dev/null",
      "echo 'Completed cloud-init!'",
    ]

    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  tags = {
    Name    = "${var.prefix}-bug-node"
    Creator = "${var.creator}"
  }
}

provider "rancher2" {
  alias = "BUG"

  api_url  = "https://${join(".", ["rancher", aws_instance.rancher_server.public_ip, "sslip.io"])}"
  insecure = true
  token_key = rancher2_bootstrap.admin.token
}
        # nodes {
        #     role = ["controlplane", "worker", "etcd"]
        #     address = "50.0.0.120"
        #     user = "root"
        # }
        # private_registries {
        # url = "50.0.0.1:5000"
        # is_default = true
        # }
# Create RKE Imported cluster resource
resource "rancher2_cluster" "bug_cluster" {
    provider = rancher2.BUG

    depends_on = [
        aws_instance.bug_node
    ]

    name = "${var.prefix}-bug-cluster"
    enable_cluster_alerting = false
    enable_cluster_monitoring = false

    rke_config {
      network {
        plugin = "canal"
      }
      kubernetes_version = "v1.25.9-rancher2-1"
      ignore_docker_version = true
      private_registries {
        is_default = true
        url = "${aws_instance.default_registry.public_dns}:5000"
      }
    }
}

# download kubeconfig for debugging
resource "local_file" "kube_config_bug_yaml" {
  depends_on = [ rancher2_cluster.bug_cluster ]
  filename = format("%s/%s/%s", path.root, "kubeconfigs", "kube_config_bug.yaml")
  content  = rancher2_cluster.bug_cluster.kube_config
}

# Exec script for installing necessary dependencies and import rke cluster into rancher
resource "null_resource" "bug_node_cmd" {
  depends_on = [ rancher2_cluster.bug_cluster ]

  provisioner "file" {
    source      = "${path.module}/scripts/bug_node_cmd.sh"
    destination = "/home/ubuntu/bug_node_cmd.sh"

    connection {
      type        = "ssh"
      host        = aws_instance.bug_node.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "starting remote execution",
      "cd /home/ubuntu",
      "sudo chmod +x bug_node_cmd.sh",
      "echo '${rancher2_cluster.bug_cluster.cluster_registration_token.0.node_command}'",
      "echo './bug_node_cmd.sh ${rancher2_cluster.bug_cluster.cluster_registration_token.0.node_command} ${aws_instance.default_registry.public_dns}:5000' > node_command.txt",
      "timeout 15m sudo ./bug_node_cmd.sh '${rancher2_cluster.bug_cluster.cluster_registration_token.0.node_command}' ${aws_instance.default_registry.public_dns}:5000"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.bug_node.public_ip
      user        = local.node_username
      private_key = tls_private_key.global_key.private_key_pem
    }
  }
}

# # Wait for cluster to be ready before creating any apps on it
# resource "rancher2_cluster_sync" "bug_sync" {
#   provider = rancher2.BUG
#   depends_on = [ null_resource.bug_node_cmd ]
#   cluster_id = rancher2_cluster.bug_cluster.id
# }

# # Create Rancher-CIS-Benchark App from Helm chart
# resource "rancher2_app_v2" "cis_benchmark_bug_cluster" {
#   provider = rancher2.BUG

#   depends_on = [
#     rancher2_cluster_sync.bug_sync
#   ]

#   cluster_id = rancher2_cluster_sync.bug_sync.cluster_id
#   name = "rancher-cis-benchmark"
#   namespace = "cis-operator-system"
#   repo_name = "rancher-charts"
#   chart_name = "rancher-cis-benchmark"
#   cleanup_on_fail = true
# }

# import rke cluster command for debugging
output "rke_insecure_node_command" {
  value = rancher2_cluster.bug_cluster.cluster_registration_token.0.insecure_node_command
  description = "Import/create cluster command for RKE bug_cluster"
}
output "rke_insecure_command" {
  value = rancher2_cluster.bug_cluster.cluster_registration_token.0.insecure_command
  description = "Import/create cluster command for RKE bug_cluster"
}
output "rke_node_command" {
  value = rancher2_cluster.bug_cluster.cluster_registration_token.0.node_command
  description = "Import/create cluster command for RKE bug_cluster"
}

output "bug_ip" {
  value = aws_instance.bug_node.public_ip
}

output "bug_dns" {
  value = aws_instance.bug_node.public_dns
}

output "debug_bug" {
  value = "ssh -i ./certs/id_rsa ubuntu@${aws_instance.bug_node.public_dns}"
}